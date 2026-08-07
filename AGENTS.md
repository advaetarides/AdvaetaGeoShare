# AGENTS.md

Context for the next agent (or human) picking up this repo. Read this before making changes — several decisions here look arbitrary until you know the "why."

## What this app does

Paste a Google Maps link (or type a plain address/postcode) → resolve to coordinates → open in OsmAnd, Google Maps, or Waze (user's choice, per-tap or per-saved-item). Also: save places/routes for later, recent-search history, address autocomplete, export/import backup. See `README.md` for the user-facing feature list — this file is about internals and history, not features.

## Architecture

Small, protocol-based DI throughout — every external dependency (parsing, geocoding, launching another app, persistence) is a protocol with one real implementation and one test mock. `ConversionViewModel` is the orchestrator; everything else is a narrow, single-purpose piece it composes.

| File | Responsibility |
|---|---|
| `GoogleMapsLinkParser.swift` | Parses Google Maps URLs → `ParsedLocation` (`.point` or `.route(stops:)`). Handles short-link redirect resolution, precise-pin vs viewport-center priority, and multi-stop directions links. |
| `AddressGeocoder.swift` | Wraps `CLGeocoder` behind `AddressGeocoding`, used as a fallback when input isn't a URL at all. |
| `AddressAutocompleter.swift` | Wraps `MKLocalSearchCompleter` for the live suggestions dropdown. |
| `MapApp.swift` | The `MapApp` enum (`.osmAnd`, `.googleMaps`, `.waze`) — the single source of truth for which providers are supported. |
| `MapAppLauncher.swift` | Builds the actual deep-link URL per provider and calls `canOpenURL`/`open`. **Read the comments here before touching URL schemes** — see "Map app URL schemes" below. |
| `SavedRoute.swift` | `SavedRoute`/`StoredLocation`/`StoredCoordinate` — the Codable persistence model, distinct from the in-memory `ParsedLocation` (which holds `CLLocationCoordinate2D`, not Codable). `SavedRoute.preferredApp` is chosen once at save time. |
| `RouteStore.swift` | JSON-file-backed CRUD + `importRoutes` (merge-by-id) for saved places/routes. |
| `RecentSearchStore.swift` | Same pattern, capped ring buffer (default 5) of successfully-opened searches. `RecentSearch.app` records which provider it was opened with, so reopening a recent uses the same app rather than a fixed default. |
| `ConversionViewModel.swift` | Orchestrates parse → geocode-fallback → launch, plus save/recent-search recording. |
| `RoutesListViewModel.swift` | Filters the same `RouteStore` into either points-only or routes-only for the two list screens. |
| `ContentView.swift` / `SaveRouteSheet.swift` / `RoutesListView.swift` / `MenuView.swift` | Views. `Theme.swift` holds the AdvaetaRides brand colors/fonts/button styles — reuse it, don't hardcode colors. |

## Non-obvious things learned the hard way

**Map app URL schemes — prefer https:// Universal Links over custom schemes wherever the provider publishes one.** This is the single biggest lesson from this project:
- `osmandmaps://` (and `osmandmaps://navigate`) — old, definitely shipped, works today. Kept because it's verified working on a real device, not because custom schemes are generally safe.
- `geo-navigation://directions` — exists in OsmAnd-iOS's `master` branch source but is **not in the shipped App Store build** (confirmed on a real device via console log: `canOpenURL` fails with OSStatus `-10814`, `kLSApplicationNotFoundErr` — a hard "no such scheme" error, not a permissions issue). Confirmed against OsmAnd 5.3.3. This is why it's *not* used — see below.
- Multi-stop OsmAnd routes use `osmand.net/map?start=&end=&via=` instead — an `https://` Universal Link that OsmAnd's app already handles today, and which can never hard-fail `canOpenURL` (https always "can open," worst case it falls back to Safari showing the site).
- Google Maps and Waze are targeted via their own officially documented `https://` Universal Link formats (`www.google.com/maps/dir|search/?api=1&...`, `waze.com/ul?ll=&navigate=`) for exactly this reason — no custom-scheme risk, no `LSApplicationQueriesSchemes` entry needed for either.
- **Before adding any new OsmAnd (or any provider's) custom-scheme deep-link feature**: check whether it's actually in a *shipped* version, not just in the GitHub source's `master` branch or a blog post. The source can lag/lead the App Store build in ways that aren't obviously flagged. If the provider publishes an official Universal Link/App Link format, use that instead of reverse-engineering a custom scheme.
- Any custom scheme you rely on via `canOpenURL` must be declared in `LSApplicationQueriesSchemes` in `project.yml`'s `info.properties`, or it silently reads as "not available" even when the app is present. There's a regression test for this (`MapAppLauncherTests.testAppDeclaresTheSchemeOsmAndLauncherUses`) — extend it if you add another custom scheme (not needed for https-based providers).
- Waze has no concept of multi-stop routes/waypoints in its URL API at all — `MapAppLauncher` falls back to just the destination (last stop) for Waze routes. Don't be surprised when Waze "loses" the rest of a route; it's not a bug.

**NSDataDetector truncates long URLs** on-device — observed stopping mid-way through directions links full of repeated `!1d..!2d..` segments (specifically before the coordinate data). `GoogleMapsLinkParser.extractURL` works around this by extending from the detector's match *start* to the end of the input string, rather than trusting the detector's own end boundary. If you touch link extraction, keep this in mind — it's easy to "fix" this workaround away by accident while refactoring.

**iOS 16.0 is the deployment target, not 17.** `@Observable`/Observation needs iOS 17, but `NavigationStack`, `.presentationDetents`, `.toolbarBackground`, `.toolbarColorScheme`, and `.tracking()` (used everywhere for the letterspaced headings) are all iOS 16+ and already baked into every view. So: view models use `ObservableObject`/`@Published` + `@StateObject` in views, not `@Observable`. Don't "modernize" this to `@Observable` without also being ready to either bump the deployment target (ask first — it was explicitly requested to be as low as reasonably possible) or accept it'll break iOS 16 support.

**No iCloud sync** — would need the paid Apple Developer Program ($99/yr); explicitly declined. Data portability across reinstalls/devices is handled by manual export/import (JSON file via `ShareLink`/`.fileImporter`) in `MenuView.swift` instead. Don't add iCloud without checking this is still the case.

**No travel-mode selection** (car/bike/walk) for OsmAnd routes — checked, and OsmAnd's own `buildRoute` handler for directions hardcodes car mode regardless of any URL param, so there was nothing to actually wire up for OsmAnd specifically. Explicitly deprioritized either way. (Google Maps' `travelmode` param IS wired up and hardcoded to `driving` in `MapAppLauncher` — a real, if unexposed, extension point if travel mode ever becomes worth doing.)

**No packaged binary / TestFlight** — explicitly deferred (would need the paid Developer Program for TestFlight). Source-build-only for now; don't set up TestFlight without confirming this has changed.

## Design source of truth

Visual identity (colors, fonts, logo) is pulled from `../advaetarides.github.io` (a sibling repo, not this one) — exact hex values, font choices, and logo treatment are in `Theme.swift`'s comments and `docs/superpowers/specs/2026-08-06-geoshare-ios-v1-design.md`. If the website's design changes, this app's `Theme.swift` should be updated to match, not the other way around.

Bundled fonts (`Sources/AdvaetaGeoShare/Fonts/`) are static-weight instances extracted from Google Fonts' *variable* font sources via `fonttools` (the website only references them via CSS `wght` axis; nothing was bundled anywhere to copy from). If you need another weight, don't hand-pick a random static TTF from elsewhere — re-run the same `fonttools.varLib.instancer` extraction against the variable source so the `name` table stays correctly unique (see git history around the theme commit for the exact script; naive instancing leaves every weight with the same internal PostScript name, which silently breaks font registration when more than one weight of the same family is bundled).

## Dev workflow

- `.xcodeproj` is **generated, not committed** — run `xcodegen generate` after pulling or after adding/removing files, before building.
- Primary test/build loop: `xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e'`. If tests fail with bogus "cannot find type" errors after adding new files, try `xcodebuild clean` first — this repo has hit stale-incremental-build ghosts more than once.
- Real-device builds need `-allowProvisioningUpdates` and an Xcode account signed in under **Xcode → Settings → Accounts** — a valid codesigning identity existing in the keychain is *not* sufficient on its own (learned this debugging the OsmAnd scheme issue, where the fix ultimately required reading a real device's console log via `xcrun devicectl device process launch --console`).
- GitHub remote is `git@github.com:advaetarides/AdvaetaGeoShare.git`, pushed via a dedicated SSH key at `~/.ssh/advaetarides` (not the default key). This repo's local `.git/config` already has `core.sshCommand` pointing at it, but that's machine-local config, not committed — a fresh clone on another machine needs `git config core.sshCommand "ssh -i ~/.ssh/advaetarides -o IdentitiesOnly=yes"` (or equivalent) re-set before pushing.

## Suggested next steps (not started, no commitment either way)

- Share Extension, so the app can receive a Google Maps link directly from another app's share sheet instead of requiring manual copy/paste. This was explicitly scoped *out* of v1 (see the original design spec) but nothing since has made it less relevant — it's probably the single highest-leverage next feature.
- A home-screen widget surfacing "Recent" or "My Places" for one-tap access without opening the app.
- Whatever the user asks for next — check with them before assuming any of the above over their actual priorities.
