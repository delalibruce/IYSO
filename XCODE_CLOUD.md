# Xcode Cloud (IYSO only)

## Required workflow settings

| Setting | Value |
|---------|--------|
| Project | **`IYSO.xcodeproj`** |
| Scheme | **IYSO** (shared: `IYSO.xcodeproj/xcshareddata/xcschemes/IYSO.xcscheme`) |
| Archive configuration | **Release** |
| Bundle ID | **`app.iyso`** |

## Disable old Digicam workflows

Workflows named **`Digicam | …`** fail because **`Digicam.xcodeproj` was removed**. In App Store Connect → Xcode Cloud, delete or disable them. Keep only **IYSO** workflows.

## If Archive fails

1. Open **Archive - iOS** logs.
2. **Signing / entitlements:** App ID `app.iyso` must include NFC, Family Controls, and Associated Domains. Release uses `IYSO/App/Digicam.entitlements`.
3. **Wrong project:** workflow must point at `IYSO.xcodeproj`, not Digicam.
4. **Team:** workflow team must match the `app.iyso` App ID (project Release config uses team `T73K2F5HAL`).

## Verify locally

```bash
git pull origin main
xcodebuild -project IYSO.xcodeproj -scheme IYSO \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Publisher: archive **Release** in Xcode or rerun the **IYSO** Xcode Cloud workflow.
