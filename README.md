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

## Usage

1. Copy a Google Maps link (or its share text) to the clipboard from anywhere.
2. Open AdvaetaGeoShare and paste it into the text field.
3. Tap "Open in OsmAnd".

If OsmAnd isn't installed, the app shows a message telling you so — install OsmAnd from the App Store and try again.

Supported Google Maps link formats: plain links with `@lat,lng`, `q=lat,lng`, or place links with a precise pin (`!3d..!4d..`), and short links (`maps.app.goo.gl`, `goo.gl/maps`, `g.co/kgs`) which are resolved by following redirects. Links that only reveal a location via client-side JavaScript (no coordinates anywhere in the URL or its redirect chain) aren't supported in v1.
