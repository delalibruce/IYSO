# Release handoff (IYSO / app.iyso)

Use this when **you** develop locally and **someone else** signs/archives for TestFlight.

## Project layout (after rename)

| Item | Path / value |
|------|----------------|
| Xcode project | `IYSO.xcodeproj` |
| Scheme (shared, Xcode Cloud) | **IYSO** |
| Source folder | `IYSO/` |
| App entry | `IYSO/App/DigicamApp.swift` |
| Bundle ID | `app.iyso` |
| App Store display name | `IYSO*` (`CFBundleDisplayName` in `IYSO/App/Info.plist`) |

Filenames **DigicamApp.swift** and **Digicam.entitlements** are intentional (not renamed).

## Publisher setup (once in Xcode)

1. Open **`IYSO.xcodeproj`**
2. Target **IYSO** → **Signing & Capabilities**
3. Team = publishing Apple Developer team
4. Bundle ID = **`app.iyso`**
5. On [developer.apple.com](https://developer.apple.com), enable on that App ID:
   - Near Field Communication Tag Reading
   - Family Controls
   - Associated Domains (`applinks:iyso.app`)

## Signing / entitlements

| Config | `CODE_SIGN_ENTITLEMENTS` | Purpose |
|--------|--------------------------|---------|
| **Debug** | `IYSO/App/Digicam.entitlements.dev` (empty) | Your Personal Team; UI + simulate NFC |
| **Release** | `IYSO/App/Digicam.entitlements` | TestFlight; NFC + Family Controls + Universal Links |

`Digicam.entitlements.production` mirrors Release entitlements for reference only.

**Release** build settings also set `DEVELOPMENT_TEAM = T73K2F5HAL` (publisher). **Debug** leaves team unset so you pick your Personal Team in Xcode.

## Xcode Cloud

See [`XCODE_CLOUD.md`](XCODE_CLOUD.md). Use only **IYSO** workflows (`IYSO.xcodeproj`, scheme **IYSO**, **Release** archive). Disable all **Digicam | …** workflows.

## AASA (`iyso.app`)

Template: `deployment/iyso.app/.well-known/apple-app-site-association`

Set `"appID": "<TEAM_ID>.app.iyso"` before deploy.

## Git before handoff

```bash
git checkout main
git pull origin main
```

Open **`IYSO.xcodeproj`** (not `Digicam.xcodeproj`).

## Publisher QA (Release, physical iPhone)

1. Fresh install → onboarding
2. Family Controls → pick apps
3. NFC pair lens tag → exit/re-enter → same tag unlocks
4. Different tag → rejected
5. IYSO on → apps blocked; exit → unblocked
