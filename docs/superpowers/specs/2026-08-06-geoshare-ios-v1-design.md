# GeoShare-iOS v1: Paste a Google Maps link, open it in OsmAnd

## Context

The existing [GeoShare](https://github.com/jakubvalenta/geoshare) Android app lets users convert map links between many map services, using Android's implicit-intent system to silently intercept taps on links. That interception model has no iOS equivalent (Universal Links require domain-owner cooperation; users can't manually reroute arbitrary domains to a third-party app). This spec covers a minimal, standalone iOS app that provides the single highest-value slice of that functionality without relying on interception:

1. User copies a Google Maps link (or its share text) into the clipboard, from anywhere.
2. User opens this app, pastes it into a text field.
3. User taps "Open in OsmAnd".
4. OsmAnd launches, centered on that exact location.

## Scope (v1)

**In scope:**
- Parsing Google Maps URLs: plain lat/lon in `@lat,lng` or `q=lat,lng` patterns, and the more precise `!3d<lat>!4d<lng>` pin-coordinate pattern found on place links.
- Resolving Google Maps short links (`maps.app.goo.gl/...`, `goo.gl/maps/...`, `g.co/kgs/...`) by following HTTP redirects to get the full URL before parsing.
- Launching OsmAnd's iOS app via its `osmandmaps://` URL scheme with the resolved coordinates.
- Clear, distinct error states: not a Maps link, no coordinates found even after redirect resolution, OsmAnd not installed.

**Explicitly out of scope for v1** (YAGNI — can be added later if needed):
- Any map service other than Google Maps as input, or any destination other than OsmAnd as output.
- A hidden `WKWebView` fallback for the rare case where a Google Maps link reveals coordinates only after client-side JavaScript runs (no coordinates anywhere in the URL or its redirect chain). These links will surface a "couldn't extract location" error.
- Share Extension / system share-sheet integration (user pastes manually, per the chosen input method).
- History, persistence, settings, or any output format besides launching OsmAnd (no GPX export, no copy-coordinates, no contact save).
- Physical-device end-to-end verification (OsmAnd can't be installed on Simulator). Verified via unit tests + Simulator run; the OsmAnd hand-off itself is verified by code review of OsmAnd's actual `osmandmaps://` URL scheme handling (confirmed against OsmAnd's live iOS source, see Technical Notes) rather than a live device test.

## Architecture

Three independently testable pieces, no shared mutable state, following the existing project convention of small single-purpose units:

### 1. `GoogleMapsLinkParser`
Pure logic, no UIKit/SwiftUI dependency, injectable `URLSession` for testability.

- `parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError>`
- Step 1: trim/extract a URL from the pasted text (share text often includes a leading label before the URL).
- Step 2: if the host matches a known short-link host (`maps.app.goo.gl`, `goo.gl`, `g.co`), issue a `HEAD` request (falling back to `GET` if the server doesn't support `HEAD`) and follow the `Location` redirect chain to get the resolved URL. Bounded to a small max-redirect count to avoid infinite loops.
- Step 3: run coordinate regexes against the resolved URL, in priority order: `!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)` (precise pin) → `@(-?\d+\.\d+),(-?\d+\.\d+)` (viewport center) → `q=(-?\d+\.\d+),(-?\d+\.\d+)` (query param).
- `ParseError`: `.notAMapsLink`, `.networkError(Error)`, `.noCoordinatesFound`.

### 2. `OsmAndLauncher`
Thin wrapper so `UIApplication` calls are mockable.

- Protocol `URLOpening { func canOpen(_ url: URL) -> Bool; func open(_ url: URL) async -> Bool }`, with a `UIApplication`-backed default implementation.
- `open(coordinate:) -> LaunchResult` builds `osmandmaps://?lat=<lat>&lon=<lon>&z=15`, checks `canOpen`, and either opens it or returns `.osmAndNotInstalled`.
- Requires `osmandmaps` declared under `LSApplicationQueriesSchemes` in Info.plist for `canOpenURL` to return accurate results.

### 3. SwiftUI view + view model
- Single screen: `TextField` (paste target) + "Open in OsmAnd" button + status area.
- `ConversionViewModel` (`@Observable` or `ObservableObject`) holds a `State` enum: `.idle`, `.resolving`, `.error(String)`. On success it immediately delegates to `OsmAndLauncher` and reflects the launch result (including the "not installed" case with an App Store link) rather than holding a separate "resolved" display state — there's nothing useful to show between resolving coordinates and attempting the OsmAnd hand-off.
- No persistence, no history, no settings screen.

## Data Flow

```
User pastes text → taps "Open in OsmAnd"
  → ViewModel.convert(text) [state = .resolving]
    → GoogleMapsLinkParser.parse(text)
      → not a maps link / no coords / network error → [state = .error(message)]
      → coordinate found → OsmAndLauncher.open(coordinate)
        → opened → [state = .idle] (OsmAnd is now foregrounded; nothing left to show)
        → not installed → [state = .error("OsmAnd isn't installed" + App Store link)]
```

## Error Handling

Every failure path produces a distinct, human-readable message in the status area — no silent failures, no generic "something went wrong":
- Pasted text doesn't contain a recognizable Google Maps URL.
- Short link redirect failed (timeout, DNS, non-2xx/3xx final response).
- Redirect resolved but no coordinate pattern matched (the JS-only edge case, out of scope for extraction).
- OsmAnd isn't installed (`canOpenURL` returned false) — message includes a tappable App Store link for OsmAnd.

## Testing

- **`GoogleMapsLinkParserTests`**: table-driven tests over representative URLs for each supported pattern (`@lat,lng`, `q=lat,lng`, `!3d!4d`), a short-link case using a mocked `URLProtocol` to simulate the redirect chain without real network calls, and negative cases (non-Maps URL, Maps URL with no coordinates, simulated network failure).
- **`OsmAndLauncherTests`**: mock `URLOpening` to verify the correct `osmandmaps://` URL is constructed and that `.osmAndNotInstalled` is returned when `canOpen` is false — no real OsmAnd install required.
- **Manual Simulator smoke test**: paste a real Google Maps link, confirm the parser resolves coordinates and the app attempts the `osmandmaps://` open call (Simulator will report OsmAnd as not installed, which itself confirms the "not installed" error path works correctly).
- No UI/snapshot tests for v1 — single screen, three states, not worth the overhead yet.

## Technical Notes (verified, not assumed)

OsmAnd's iOS app (`osmandapp/OsmAnd-ios`, live source checked directly) registers `osmandmaps` and `geo-navigation` as custom URL schemes in `Resources/OsmAnd-Info.plist`. Its `DeepLinkParser.swift` handles `osmandmaps://?lat=<lat>&lon=<lon>&z=<zoom>&title=<title>` to move the map to a location (`handleIncomingActionsURL`). This is the mechanism this app's `OsmAndLauncher` relies on.
