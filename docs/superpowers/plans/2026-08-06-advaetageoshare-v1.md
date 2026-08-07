# AdvaetaGeoShare v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal iOS app, AdvaetaGeoShare, that lets a user paste a Google Maps link and open that exact location in OsmAnd.

**Architecture:** Three independently testable pieces — `GoogleMapsLinkParser` (parses/resolves a Google Maps link into coordinates), `OsmAndLauncher` (opens OsmAnd via its `osmandmaps://` URL scheme), and a `ConversionViewModel` + single-screen SwiftUI `ContentView` that wires them together. No persistence, no history, no other map services.

**Tech Stack:** Swift 5 (language mode), SwiftUI, XCTest, `URLSession` (async/await), `CoreLocation.CLLocationCoordinate2D`. Project scaffolded and built via [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml` → generated `.xcodeproj`, not hand-edited or committed).

## Global Constraints

- App name / display name / bundle identifier prefix: `AdvaetaGeoShare`, `com.advaetarides.AdvaetaGeoShare`.
- iOS deployment target: 17.0 (enables the `@Observable` macro instead of Combine's `ObservableObject`).
- Swift language mode: 5 (set via `SWIFT_VERSION: "5.0"` in `project.yml`) — avoids Swift 6 strict-concurrency friction for this small app.
- v1 input: Google Maps links only (plain URLs and short links). v1 output: OsmAnd only. No other map services, no Share Extension, no persistence/history, no WebView JS-fallback scraping — all explicitly out of scope per the spec.
- Testing: XCTest unit tests + Simulator build/run verification only. No physical-device testing (OsmAnd can't be installed on Simulator, so the "not installed" error path is what Simulator testing actually exercises). Simulator destination used throughout: `platform=iOS Simulator,name=iPhone 16e`.
- Spec reference: `docs/superpowers/specs/2026-08-06-geoshare-ios-v1-design.md`.

---

## Task 1: Scaffold the Xcode project

**Files:**
- Create: `project.yml`
- Create: `.gitignore`
- Create: `Sources/AdvaetaGeoShare/AdvaetaGeoShareApp.swift`
- Create: `Sources/AdvaetaGeoShare/ContentView.swift`
- Create: `README.md`

**Interfaces:**
- Produces: a buildable Xcode project with scheme `AdvaetaGeoShare`, an app target `AdvaetaGeoShare`, and an empty test target `AdvaetaGeoShareTests` (host application = `AdvaetaGeoShare`). Later tasks add real source/test files under `Sources/AdvaetaGeoShare/` and `Tests/AdvaetaGeoShareTests/` — xcodegen picks them up automatically on `xcodegen generate`, no `project.yml` changes needed for adding files (only for new Info.plist keys, see Task 6).

- [ ] **Step 1: Create directory structure and `.gitignore`**

```bash
mkdir -p Sources/AdvaetaGeoShare Tests/AdvaetaGeoShareTests
```

Write `.gitignore`:

```
.build/
DerivedData/
*.xcodeproj
xcuserdata/
.swiftpm/
```

- [ ] **Step 2: Install XcodeGen**

Run: `brew install xcodegen`
Expected: installs successfully (or reports already installed).

- [ ] **Step 3: Write `project.yml`**

```yaml
name: AdvaetaGeoShare
options:
  bundleIdPrefix: com.advaetarides
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "5.0"
targets:
  AdvaetaGeoShare:
    type: application
    platform: iOS
    sources:
      - Sources/AdvaetaGeoShare
    info:
      properties:
        CFBundleDisplayName: AdvaetaGeoShare
        UILaunchScreen: {}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.advaetarides.AdvaetaGeoShare
        TARGETED_DEVICE_FAMILY: "1"
  AdvaetaGeoShareTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - Tests/AdvaetaGeoShareTests
    dependencies:
      - target: AdvaetaGeoShare
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.advaetarides.AdvaetaGeoShareTests
schemes:
  AdvaetaGeoShare:
    build:
      targets:
        AdvaetaGeoShare: all
        AdvaetaGeoShareTests: [test]
    test:
      targets:
        - AdvaetaGeoShareTests
    run:
      config: Debug
```

- [ ] **Step 4: Write placeholder app entry point and view**

`Sources/AdvaetaGeoShare/AdvaetaGeoShareApp.swift`:

```swift
import SwiftUI

@main
struct AdvaetaGeoShareApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`Sources/AdvaetaGeoShare/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("AdvaetaGeoShare")
            .padding()
    }
}
```

(These are placeholders — Task 8 replaces `ContentView` with the real UI and wires up the real view model.)

- [ ] **Step 5: Generate the Xcode project**

Run: `xcodegen generate`
Expected: `Generated project at AdvaetaGeoShare.xcodeproj`

- [ ] **Step 6: Verify it builds on the Simulator**

Run: `xcodebuild build -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e'`
Expected: ends with `** BUILD SUCCEEDED **`

- [ ] **Step 7: Write `README.md`**

```markdown
# AdvaetaGeoShare

Paste a Google Maps link, open it in OsmAnd.

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `AdvaetaGeoShare.xcodeproj` in Xcode, or build from the command line:
   `xcodebuild build -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e'`

The `.xcodeproj` is generated, not committed — re-run `xcodegen generate` after pulling changes to `project.yml` or after adding/removing source files.

## Running tests

```bash
xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e'
```
```

- [ ] **Step 8: Commit**

```bash
git add project.yml .gitignore Sources README.md
git commit -m "Scaffold AdvaetaGeoShare Xcode project via XcodeGen"
```

---

## Task 2: GoogleMapsLinkParser — link detection and the `@lat,lng` pattern

**Files:**
- Create: `Sources/AdvaetaGeoShare/GoogleMapsLinkParser.swift`
- Test: `Tests/AdvaetaGeoShareTests/GoogleMapsLinkParserTests.swift`

**Interfaces:**
- Produces:
  - `enum ParseError: Error, Equatable { case notAMapsLink, case noCoordinatesFound, case networkError(String) }`
  - `protocol LinkParsing { func parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError> }`
  - `struct GoogleMapsLinkParser: LinkParsing` with `init(session: URLSession = .shared)` and `func parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError>`.

- [ ] **Step 1: Write the failing tests**

`Tests/AdvaetaGeoShareTests/GoogleMapsLinkParserTests.swift`:

```swift
import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

final class GoogleMapsLinkParserTests: XCTestCase {

    func testViewportCoordinatePattern() async {
        let parser = GoogleMapsLinkParser()
        let result = await parser.parse("https://www.google.com/maps/@37.7749,-122.4194,15z")

        switch result {
        case .success(let coordinate):
            XCTAssertEqual(coordinate.latitude, 37.7749, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, -122.4194, accuracy: 0.0001)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testNotAMapsLinkReturnsError() async {
        let parser = GoogleMapsLinkParser()
        let result = await parser.parse("just some random text with no link")

        switch result {
        case .failure(.notAMapsLink):
            break
        default:
            XCTFail("Expected .notAMapsLink, got \(result)")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/GoogleMapsLinkParserTests`
Expected: FAIL — `GoogleMapsLinkParser` not found (doesn't exist yet). Note: you'll need to run `xcodegen generate` first so the new test file is picked up by the project.

- [ ] **Step 3: Write the implementation**

`Sources/AdvaetaGeoShare/GoogleMapsLinkParser.swift`:

```swift
import Foundation
import CoreLocation

enum ParseError: Error, Equatable {
    case notAMapsLink
    case noCoordinatesFound
    case networkError(String)
}

protocol LinkParsing {
    func parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError>
}

struct GoogleMapsLinkParser: LinkParsing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private static let viewportCoordinateRegex = try! NSRegularExpression(
        pattern: #"@(-?\d+\.\d+),(-?\d+\.\d+)"#
    )

    func parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError> {
        guard let url = Self.extractURL(from: input) else {
            return .failure(.notAMapsLink)
        }

        let resolvedURLString = url.absoluteString

        if let coordinate = Self.extractCoordinate(from: resolvedURLString) {
            return .success(coordinate)
        }
        return .failure(.noCoordinatesFound)
    }

    private static func extractURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        guard let match = matches.first,
              let range = Range(match.range, in: trimmed),
              let url = URL(string: String(trimmed[range])) else {
            return nil
        }
        guard let host = url.host,
              host.contains("google") || host.contains("goo.gl") || host == "g.co" else {
            return nil
        }
        return url
    }

    private static func extractCoordinate(from urlString: String) -> CLLocationCoordinate2D? {
        for regex in [viewportCoordinateRegex] {
            if let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
               let latRange = Range(match.range(at: 1), in: urlString),
               let lonRange = Range(match.range(at: 2), in: urlString),
               let lat = Double(urlString[latRange]),
               let lon = Double(urlString[lonRange]) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/GoogleMapsLinkParserTests`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/AdvaetaGeoShare/GoogleMapsLinkParser.swift Tests/AdvaetaGeoShareTests/GoogleMapsLinkParserTests.swift
git commit -m "Add GoogleMapsLinkParser: link detection and @lat,lng pattern"
```

---

## Task 3: GoogleMapsLinkParser — precise `!3d!4d` pin pattern takes priority

**Files:**
- Modify: `Sources/AdvaetaGeoShare/GoogleMapsLinkParser.swift`
- Modify: `Tests/AdvaetaGeoShareTests/GoogleMapsLinkParserTests.swift`

**Interfaces:**
- Consumes: `GoogleMapsLinkParser` from Task 2 (same `init`, same `parse` signature — this task only changes internal regex priority).
- Produces: same public interface; `extractCoordinate` now checks the precise pin pattern before the viewport pattern.

Google Maps place links often contain both an `@lat,lng` viewport-center coordinate and a more precise `!3d<lat>!4d<lng>` pin coordinate. The pin is the actual location the user shared; the viewport can be off by a meaningful distance. This task makes the parser prefer the precise pattern when both are present.

- [ ] **Step 1: Write the failing test**

Add to `GoogleMapsLinkParserTests.swift`:

```swift
    func testPrecisePinPatternTakesPriorityOverViewport() async {
        let parser = GoogleMapsLinkParser()
        let input = "https://www.google.com/maps/place/Eiffel+Tower/@48.8583,2.2945,17z/data=!4m5!3m4!1s0x0:0x0!8m2!3d48.8584600!4d2.2945000"
        let result = await parser.parse(input)

        switch result {
        case .success(let coordinate):
            XCTAssertEqual(coordinate.latitude, 48.8584600, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, 2.2945000, accuracy: 0.0001)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/GoogleMapsLinkParserTests/testPrecisePinPatternTakesPriorityOverViewport`
Expected: FAIL — the viewport regex matches `@48.8583,2.2945` (the less precise coordinate), so the assertion on `48.8584600`/`2.2945000` fails.

- [ ] **Step 3: Add the precise pattern with priority**

In `GoogleMapsLinkParser.swift`, add the new regex and put it first in the priority list:

```swift
    private static let pinCoordinateRegex = try! NSRegularExpression(
        pattern: #"!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)"#
    )
```

Change the loop in `extractCoordinate` to check the pin pattern first:

```swift
        for regex in [pinCoordinateRegex, viewportCoordinateRegex] {
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/GoogleMapsLinkParserTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/AdvaetaGeoShare/GoogleMapsLinkParser.swift Tests/AdvaetaGeoShareTests/GoogleMapsLinkParserTests.swift
git commit -m "Prefer precise !3d!4d pin coordinate over viewport center"
```

---

## Task 4: GoogleMapsLinkParser — `q=lat,lng` pattern and no-coordinates-found case

**Files:**
- Modify: `Sources/AdvaetaGeoShare/GoogleMapsLinkParser.swift`
- Modify: `Tests/AdvaetaGeoShareTests/GoogleMapsLinkParserTests.swift`

**Interfaces:**
- Consumes: `GoogleMapsLinkParser` from Tasks 2–3.
- Produces: same public interface; `extractCoordinate` now also checks the `q=` query-parameter pattern (lowest priority, after the pin and viewport patterns).

- [ ] **Step 1: Write the failing tests**

Add to `GoogleMapsLinkParserTests.swift`:

```swift
    func testQueryParamPattern() async {
        let parser = GoogleMapsLinkParser()
        let result = await parser.parse("https://maps.google.com/maps?q=51.5074,-0.1278")

        switch result {
        case .success(let coordinate):
            XCTAssertEqual(coordinate.latitude, 51.5074, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, -0.1278, accuracy: 0.0001)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testMapsLinkWithNoCoordinatesReturnsError() async {
        let parser = GoogleMapsLinkParser()
        let result = await parser.parse("https://www.google.com/maps/search/coffee+near+me")

        switch result {
        case .failure(.noCoordinatesFound):
            break
        default:
            XCTFail("Expected .noCoordinatesFound, got \(result)")
        }
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/GoogleMapsLinkParserTests`
Expected: `testQueryParamPattern` FAILs (no `q=` regex yet); `testMapsLinkWithNoCoordinatesReturnsError` PASSes already (no pattern matches, already falls through to `.noCoordinatesFound` — this confirms the negative path works before adding the new pattern).

- [ ] **Step 3: Add the query-param pattern**

In `GoogleMapsLinkParser.swift`, add:

```swift
    private static let queryCoordinateRegex = try! NSRegularExpression(
        pattern: #"[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)"#
    )
```

Update the priority loop:

```swift
        for regex in [pinCoordinateRegex, viewportCoordinateRegex, queryCoordinateRegex] {
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/GoogleMapsLinkParserTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/AdvaetaGeoShare/GoogleMapsLinkParser.swift Tests/AdvaetaGeoShareTests/GoogleMapsLinkParserTests.swift
git commit -m "Add q=lat,lng query parameter pattern"
```

---

## Task 5: GoogleMapsLinkParser — short-link redirect resolution

**Files:**
- Modify: `Sources/AdvaetaGeoShare/GoogleMapsLinkParser.swift`
- Create: `Tests/AdvaetaGeoShareTests/MockURLProtocol.swift`
- Modify: `Tests/AdvaetaGeoShareTests/GoogleMapsLinkParserTests.swift`

**Interfaces:**
- Consumes: `GoogleMapsLinkParser` from Tasks 2–4, including its `init(session: URLSession = .shared)`.
- Produces:
  - `final class MockURLProtocol: URLProtocol` with `static var stubs: [URL: MockURLProtocol.StubbedResponse]` and nested `struct StubbedResponse { let statusCode: Int; let headers: [String: String] }`, plus `static func mockedSession() -> URLSession` (test helper).
  - `GoogleMapsLinkParser.parse` now follows HTTP redirects for short-link hosts (`maps.app.goo.gl`, `goo.gl`, `g.co`) before running the coordinate regexes, and returns `.failure(.networkError(String))` on request failure.

- [ ] **Step 1: Write the mock URL protocol test helper**

`Tests/AdvaetaGeoShareTests/MockURLProtocol.swift`:

```swift
import Foundation

final class MockURLProtocol: URLProtocol {
    struct StubbedResponse {
        let statusCode: Int
        let headers: [String: String]
    }

    static var stubs: [URL: StubbedResponse] = [:]

    static func mockedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stub = Self.stubs[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

- [ ] **Step 2: Write the failing tests**

Add to `GoogleMapsLinkParserTests.swift` (add a `tearDown` to reset stubs between tests):

```swift
    override func tearDown() {
        MockURLProtocol.stubs = [:]
        super.tearDown()
    }

    func testShortLinkFollowsRedirectChain() async {
        let shortURL = URL(string: "https://maps.app.goo.gl/abc123")!
        let intermediateURL = URL(string: "https://www.google.com/maps/redirect/xyz")!
        let finalURL = URL(string: "https://www.google.com/maps/@40.7128,-74.0060,15z")!

        MockURLProtocol.stubs = [
            shortURL: .init(statusCode: 302, headers: ["Location": intermediateURL.absoluteString]),
            intermediateURL: .init(statusCode: 302, headers: ["Location": finalURL.absoluteString]),
            finalURL: .init(statusCode: 200, headers: [:]),
        ]

        let parser = GoogleMapsLinkParser(session: MockURLProtocol.mockedSession())
        let result = await parser.parse(shortURL.absoluteString)

        switch result {
        case .success(let coordinate):
            XCTAssertEqual(coordinate.latitude, 40.7128, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, -74.0060, accuracy: 0.0001)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testShortLinkNetworkFailureReturnsNetworkError() async {
        let shortURL = URL(string: "https://maps.app.goo.gl/willfail")!
        // No stub registered — MockURLProtocol fails the request.
        let parser = GoogleMapsLinkParser(session: MockURLProtocol.mockedSession())
        let result = await parser.parse(shortURL.absoluteString)

        switch result {
        case .failure(.networkError):
            break
        default:
            XCTFail("Expected .networkError, got \(result)")
        }
    }
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/GoogleMapsLinkParserTests`
Expected: FAIL on both new tests — `maps.app.goo.gl` links are currently parsed directly (no coordinates in the short URL itself), so both hit `.noCoordinatesFound` instead of following redirects.

- [ ] **Step 4: Implement redirect resolution**

In `GoogleMapsLinkParser.swift`, add the short-link host set and the resolver, and call it from `parse`:

```swift
    private static let shortLinkHosts: Set<String> = ["maps.app.goo.gl", "goo.gl", "g.co"]
```

Replace the body of `parse` with:

```swift
    func parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError> {
        guard let url = Self.extractURL(from: input) else {
            return .failure(.notAMapsLink)
        }

        let resolvedURLString: String
        if let host = url.host, Self.shortLinkHosts.contains(host) {
            switch await Self.resolveRedirect(for: url, session: session) {
            case .success(let resolved):
                resolvedURLString = resolved
            case .failure(let error):
                return .failure(error)
            }
        } else {
            resolvedURLString = url.absoluteString
        }

        if let coordinate = Self.extractCoordinate(from: resolvedURLString) {
            return .success(coordinate)
        }
        return .failure(.noCoordinatesFound)
    }

    private static func resolveRedirect(for url: URL, session: URLSession, maxHops: Int = 5) async -> Result<String, ParseError> {
        var currentURL = url
        var hops = 0
        while hops < maxHops {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "HEAD"
            do {
                let (_, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return .failure(.networkError("No HTTP response"))
                }
                if (300..<400).contains(httpResponse.statusCode),
                   let location = httpResponse.value(forHTTPHeaderField: "Location"),
                   let nextURL = URL(string: location, relativeTo: currentURL)?.absoluteURL {
                    currentURL = nextURL
                    hops += 1
                    continue
                }
                // Either the server returned a final response, or (on a real network
                // request, outside of tests) URLSession already auto-followed the
                // redirect chain — httpResponse.url reflects the true final URL either way.
                let finalURL = httpResponse.url ?? currentURL
                return .success(finalURL.absoluteString)
            } catch {
                return .failure(.networkError(error.localizedDescription))
            }
        }
        return .success(currentURL.absoluteString)
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/GoogleMapsLinkParserTests`
Expected: PASS (7 tests)

- [ ] **Step 6: Commit**

```bash
git add Sources/AdvaetaGeoShare/GoogleMapsLinkParser.swift Tests/AdvaetaGeoShareTests/MockURLProtocol.swift Tests/AdvaetaGeoShareTests/GoogleMapsLinkParserTests.swift
git commit -m "Resolve Google Maps short links by following redirects"
```

---

## Task 6: OsmAndLauncher

**Files:**
- Create: `Sources/AdvaetaGeoShare/OsmAndLauncher.swift`
- Test: `Tests/AdvaetaGeoShareTests/OsmAndLauncherTests.swift`
- Modify: `project.yml`

**Interfaces:**
- Produces:
  - `enum LaunchResult: Equatable { case opened, case osmAndNotInstalled }`
  - `protocol URLOpening { func canOpen(_ url: URL) -> Bool; func open(_ url: URL) async -> Bool }`
  - `extension UIApplication: URLOpening`
  - `protocol OsmAndOpening { func open(coordinate: CLLocationCoordinate2D) async -> LaunchResult }`
  - `struct OsmAndLauncher: OsmAndOpening` with `init(urlOpener: URLOpening)` and `func open(coordinate: CLLocationCoordinate2D) async -> LaunchResult`.

- [ ] **Step 1: Write the failing tests**

`Tests/AdvaetaGeoShareTests/OsmAndLauncherTests.swift`:

```swift
import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

private final class MockURLOpener: URLOpening {
    var canOpenResult = true
    var openedURL: URL?

    func canOpen(_ url: URL) -> Bool {
        canOpenResult
    }

    func open(_ url: URL) async -> Bool {
        openedURL = url
        return true
    }
}

final class OsmAndLauncherTests: XCTestCase {

    func testOpensOsmAndWithCorrectURLWhenInstalled() async throws {
        let opener = MockURLOpener()
        opener.canOpenResult = true
        let launcher = OsmAndLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = await launcher.open(coordinate: coordinate)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.scheme, "osmandmaps")
        XCTAssertTrue(openedURL.query?.contains("lat=37.7749") ?? false)
        XCTAssertTrue(openedURL.query?.contains("lon=-122.4194") ?? false)
    }

    func testReturnsNotInstalledWhenOsmAndCannotOpenURL() async {
        let opener = MockURLOpener()
        opener.canOpenResult = false
        let launcher = OsmAndLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)

        let result = await launcher.open(coordinate: coordinate)

        XCTAssertEqual(result, .osmAndNotInstalled)
        XCTAssertNil(opener.openedURL)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/OsmAndLauncherTests`
Expected: FAIL — `OsmAndLauncher` not found.

- [ ] **Step 3: Write the implementation**

`Sources/AdvaetaGeoShare/OsmAndLauncher.swift`:

```swift
import Foundation
import UIKit
import CoreLocation

enum LaunchResult: Equatable {
    case opened
    case osmAndNotInstalled
}

protocol URLOpening {
    func canOpen(_ url: URL) -> Bool
    func open(_ url: URL) async -> Bool
}

extension UIApplication: URLOpening {
    func canOpen(_ url: URL) -> Bool {
        canOpenURL(url)
    }

    func open(_ url: URL) async -> Bool {
        await open(url, options: [:])
    }
}

protocol OsmAndOpening {
    func open(coordinate: CLLocationCoordinate2D) async -> LaunchResult
}

struct OsmAndLauncher: OsmAndOpening {
    private let urlOpener: URLOpening

    init(urlOpener: URLOpening) {
        self.urlOpener = urlOpener
    }

    func open(coordinate: CLLocationCoordinate2D) async -> LaunchResult {
        var components = URLComponents()
        components.scheme = "osmandmaps"
        components.host = ""  // forces "osmandmaps://" (empty authority) to match OsmAnd's documented URL format
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "z", value: "15"),
        ]

        guard let url = components.url, urlOpener.canOpen(url) else {
            return .osmAndNotInstalled
        }
        _ = await urlOpener.open(url)
        return .opened
    }
}
```

- [ ] **Step 4: Declare the `osmandmaps` scheme in Info.plist**

Modify `project.yml` — add `LSApplicationQueriesSchemes` under the `AdvaetaGeoShare` target's `info.properties`:

```yaml
    info:
      properties:
        CFBundleDisplayName: AdvaetaGeoShare
        UILaunchScreen: {}
        LSApplicationQueriesSchemes:
          - osmandmaps
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/OsmAndLauncherTests`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add Sources/AdvaetaGeoShare/OsmAndLauncher.swift Tests/AdvaetaGeoShareTests/OsmAndLauncherTests.swift project.yml
git commit -m "Add OsmAndLauncher and declare osmandmaps query scheme"
```

---

## Task 7: ConversionViewModel

**Files:**
- Create: `Sources/AdvaetaGeoShare/ConversionViewModel.swift`
- Test: `Tests/AdvaetaGeoShareTests/ConversionViewModelTests.swift`

**Interfaces:**
- Consumes: `LinkParsing` (Task 2), `ParseError` (Task 2), `OsmAndOpening` (Task 6), `LaunchResult` (Task 6).
- Produces: `@Observable final class ConversionViewModel` with `enum State: Equatable { case idle, case resolving, case error(String) }`, `private(set) var state: State`, `var inputText: String`, `init(parser: LinkParsing, launcher: OsmAndOpening)`, `func convert() async`.

- [ ] **Step 1: Write the failing tests**

`Tests/AdvaetaGeoShareTests/ConversionViewModelTests.swift`:

```swift
import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

private struct MockParser: LinkParsing {
    let result: Result<CLLocationCoordinate2D, ParseError>
    func parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError> {
        result
    }
}

private struct MockLauncher: OsmAndOpening {
    let result: LaunchResult
    func open(coordinate: CLLocationCoordinate2D) async -> LaunchResult {
        result
    }
}

final class ConversionViewModelTests: XCTestCase {

    func testSuccessfulConversionEndsInIdleState() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(CLLocationCoordinate2D(latitude: 1, longitude: 2))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testNotAMapsLinkShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "not a link"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("That doesn't look like a Google Maps link."))
    }

    func testNoCoordinatesFoundShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.noCoordinatesFound)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/search/coffee"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("Couldn't find a location in that link."))
    }

    func testNetworkErrorShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.networkError("timed out"))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://maps.app.goo.gl/abc"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("Couldn't resolve that link. Check your connection and try again."))
    }

    func testOsmAndNotInstalledShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(CLLocationCoordinate2D(latitude: 1, longitude: 2))),
            launcher: MockLauncher(result: .osmAndNotInstalled)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("OsmAnd isn't installed. Install it from the App Store to continue."))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/ConversionViewModelTests`
Expected: FAIL — `ConversionViewModel` not found.

- [ ] **Step 3: Write the implementation**

`Sources/AdvaetaGeoShare/ConversionViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class ConversionViewModel {
    enum State: Equatable {
        case idle
        case resolving
        case error(String)
    }

    private(set) var state: State = .idle
    var inputText: String = ""

    private let parser: LinkParsing
    private let launcher: OsmAndOpening

    init(parser: LinkParsing, launcher: OsmAndOpening) {
        self.parser = parser
        self.launcher = launcher
    }

    func convert() async {
        state = .resolving
        switch await parser.parse(inputText) {
        case .success(let coordinate):
            switch await launcher.open(coordinate: coordinate) {
            case .opened:
                state = .idle
            case .osmAndNotInstalled:
                state = .error("OsmAnd isn't installed. Install it from the App Store to continue.")
            }
        case .failure(.notAMapsLink):
            state = .error("That doesn't look like a Google Maps link.")
        case .failure(.noCoordinatesFound):
            state = .error("Couldn't find a location in that link.")
        case .failure(.networkError):
            state = .error("Couldn't resolve that link. Check your connection and try again.")
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:AdvaetaGeoShareTests/ConversionViewModelTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/AdvaetaGeoShare/ConversionViewModel.swift Tests/AdvaetaGeoShareTests/ConversionViewModelTests.swift
git commit -m "Add ConversionViewModel orchestrating parser and launcher"
```

---

## Task 8: Real ContentView, wired to ConversionViewModel

**Files:**
- Modify: `Sources/AdvaetaGeoShare/ContentView.swift`
- Modify: `Sources/AdvaetaGeoShare/AdvaetaGeoShareApp.swift`

**Interfaces:**
- Consumes: `ConversionViewModel` (Task 7), `GoogleMapsLinkParser` (Tasks 2–5), `OsmAndLauncher` (Task 6).
- Produces: the real single-screen UI; no new types for later tasks to consume.

This task has no unit tests of its own (per the spec: no UI/snapshot tests for v1) — its testable deliverable is a successful build, verified in Step 3.

- [ ] **Step 1: Replace the placeholder `ContentView`**

`Sources/AdvaetaGeoShare/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var viewModel: ConversionViewModel

    init(viewModel: ConversionViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("AdvaetaGeoShare")
                .font(.title2)
                .bold()

            TextField("Paste a Google Maps link", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button("Open in OsmAnd") {
                Task {
                    await viewModel.convert()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.state == .resolving
            )

            switch viewModel.state {
            case .idle:
                EmptyView()
            case .resolving:
                ProgressView("Resolving location…")
            case .error(let message):
                Text(message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 40)
    }
}
```

- [ ] **Step 2: Wire it up in the app entry point**

`Sources/AdvaetaGeoShare/AdvaetaGeoShareApp.swift`:

```swift
import SwiftUI

@main
struct AdvaetaGeoShareApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: ConversionViewModel(
                    parser: GoogleMapsLinkParser(),
                    launcher: OsmAndLauncher(urlOpener: UIApplication.shared)
                )
            )
        }
    }
}
```

- [ ] **Step 3: Verify the app builds**

Run: `xcodebuild build -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Sources/AdvaetaGeoShare/ContentView.swift Sources/AdvaetaGeoShare/AdvaetaGeoShareApp.swift
git commit -m "Wire real ContentView to ConversionViewModel"
```

---

## Task 9: Full test suite, manual Simulator smoke test, finalize README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the complete app from Tasks 1–8. No new production interfaces.

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e'`
Expected: `** TEST SUCCEEDED **`, all tests from Tasks 2–7 passing (16 tests total: 7 parser + 2 launcher + 5 view model, plus this count should match what's actually in the test files at this point — verify the printed summary line matches the number of test methods across `GoogleMapsLinkParserTests`, `OsmAndLauncherTests`, and `ConversionViewModelTests`).

- [ ] **Step 2: Manual Simulator smoke test**

Run: `xcodebuild -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' build`, then boot the Simulator and install/launch:

```bash
xcrun simctl boot "iPhone 16e" 2>/dev/null || true
open -a Simulator
xcodebuild -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath ./DerivedData build
xcrun simctl install "iPhone 16e" ./DerivedData/Build/Products/Debug-iphonesimulator/AdvaetaGeoShare.app
xcrun simctl launch "iPhone 16e" com.advaetarides.AdvaetaGeoShare
```

In the Simulator: paste a real Google Maps link (e.g. copy one from maps.google.com in a browser) into the text field and tap "Open in OsmAnd". Confirm:
- A plain `@lat,lng` link resolves without error and the app attempts to open `osmandmaps://` (Simulator has no OsmAnd installed, so the app should land in the `.error("OsmAnd isn't installed...")` state — this confirms both the parser and the not-installed fallback path work correctly).
- Pasting random non-Maps text shows "That doesn't look like a Google Maps link."

- [ ] **Step 3: Finalize README with usage instructions**

Append to `README.md`:

```markdown
## Usage

1. Copy a Google Maps link (or its share text) to the clipboard from anywhere.
2. Open AdvaetaGeoShare and paste it into the text field.
3. Tap "Open in OsmAnd".

If OsmAnd isn't installed, the app shows a message telling you so — install OsmAnd from the App Store and try again.

Supported Google Maps link formats: plain links with `@lat,lng`, `q=lat,lng`, or place links with a precise pin (`!3d..!4d..`), and short links (`maps.app.goo.gl`, `goo.gl/maps`, `g.co/kgs`) which are resolved by following redirects. Links that only reveal a location via client-side JavaScript (no coordinates anywhere in the URL or its redirect chain) aren't supported in v1.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Finalize README with usage instructions"
```
