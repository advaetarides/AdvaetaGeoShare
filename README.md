# AdvaetaGeoShare

A small iOS app for one job: turn a Google Maps link (or a plain address/postcode) into a location open in [OsmAnd](https://osmand.net) — OsmAnd's own search struggles with things Google Maps handles natively (like UK postcodes), so this closes that gap without needing OsmAnd itself to change.

Paste a link, tap a button, you're in OsmAnd.

## Features

- **Paste a Google Maps link** — plain links (`@lat,lng`, `q=lat,lng`), precise place pins (`!3d..!4d..`), and short links (`maps.app.goo.gl`, `goo.gl/maps`, `g.co/kgs`), resolved by following redirects.
- **Multi-stop directions links** — a `/maps/dir/...` link with several stops opens the full route in OsmAnd (via `osmand.net/map`, an existing Universal Link OsmAnd already handles — no dependency on newer URL schemes that may not be in your installed OsmAnd version yet).
- **Type a plain address or postcode** — anything that isn't a recognizable Maps link falls back to Apple's on-device geocoder (`CLGeocoder`), so postcodes and addresses work the same as pasted links.
- **Save routes** — name and store a location or route, with an optional "start navigating automatically" toggle for single points (uses OsmAnd's `osmandmaps://navigate` to begin turn-by-turn guidance from your current location the moment you open it).
- **My Routes** — browse, reopen, and delete saved routes.
- **Paste / Clear buttons** next to the input field.

## Setup

Requires a Mac with Xcode installed.

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `AdvaetaGeoShare.xcodeproj` in Xcode.
4. Select your own team under Signing & Capabilities (needed to run on a real device — Simulator doesn't need this, but OsmAnd can't be installed on Simulator either, so a real device is the only way to see the full flow end-to-end).
5. Build and run.

The `.xcodeproj` is generated, not committed — re-run `xcodegen generate` after pulling changes to `project.yml` or after adding/removing source files.

There's no packaged binary release — iOS requires either a paid Apple Developer account (TestFlight) or building from source to install on a device, so building from source via the steps above is the only way to try it right now.

### Command line

```bash
xcodebuild build -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e'
```

## Running tests

```bash
xcodebuild test -project AdvaetaGeoShare.xcodeproj -scheme AdvaetaGeoShare -destination 'platform=iOS Simulator,name=iPhone 16e'
```

## Usage

1. Copy a Google Maps link (or its share text), or just have an address/postcode ready.
2. Open AdvaetaGeoShare and paste or type it into the text field (the Paste button reads your clipboard directly).
3. Tap **Open in OsmAnd** to go there now, or **Save** to name it and keep it in **My Routes** for later.

If OsmAnd isn't installed, the app tells you so rather than failing silently.

## Requirements

- iOS 17.0+
- [OsmAnd](https://apps.apple.com/app/osmand-maps-travel-navigate/id934850257) installed, to actually open locations

## Design

Visual identity matches [advaetarides.github.io](https://advaetarides.github.io) — the bronze medallion logo, Cinzel/Cormorant Garamond typography, and the site's bronze/teal/black palette. Font files are static-weight instances extracted from Google Fonts' variable font sources (OFL-licensed), since the fonts aren't bundled anywhere in the source project itself.
