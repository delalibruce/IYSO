# Xcode Cloud setup (after Digicam → IYSO rename)

## Use only the IYSO project

The app was renamed to **IYSO**. Xcode Cloud workflows tied to the old **Digicam** project will fail because `Digicam.xcodeproj` no longer exists.

In [App Store Connect](https://appstoreconnect.apple.com) → your app → **Xcode Cloud**:

1. **Disable or delete** workflows named `Digicam | …` (Default, First Workflow, etc.).
2. Keep or create a single workflow: **IYSO | Default** (or similar).
3. Set the workflow to build **`IYSO.xcodeproj`**, scheme **IYSO**, **Release** for TestFlight archives.

## Required App Store Connect settings

- Bundle ID: **`app.iyso`**
- Capabilities on that App ID: NFC Tag Reading, Family Controls, Associated Domains (`applinks:iyso.app`)
- Xcode Cloud uses the workflow’s Apple Developer **Team** (must match the App ID).

## If Archive still fails

1. Open the failed **Archive - iOS** log in Xcode Cloud.
2. Common fixes on `main`:
   - Duplicate keys in `IYSO/App/Info.plist` (should not happen after latest `main`)
   - Entitlements mismatch → Release must use `Digicam.entitlements.production`
   - Wrong project selected in workflow (must be **IYSO**, not Digicam)

## Local verify before pushing

```bash
git pull origin main
xcodebuild -project IYSO.xcodeproj -scheme IYSO -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Publisher archives **Release** on device/TestFlight with their team in Xcode or Xcode Cloud.
