## IYSO (formerly Digicam)

NFC unlock, IYSO mode, and Family Controls are in the `IYSO/` source tree. TestFlight uses the **publisher** Apple Developer account.

**Start here:** [`HANDOFF.md`](HANDOFF.md) · Xcode Cloud: [`XCODE_CLOUD.md`](XCODE_CLOUD.md)

## Quick reference

| Item | Value |
|------|--------|
| Xcode project | `IYSO.xcodeproj` |
| Scheme | **IYSO** |
| Bundle ID | `app.iyso` |
| Display name | `IYSO*` |
| Release entitlements | `IYSO/App/Digicam.entitlements` |
| Debug entitlements (Personal Team) | `IYSO/App/Digicam.entitlements.dev` |
| AASA template | `deployment/iyso.app/.well-known/apple-app-site-association` |

## Local development (Personal Team)

1. `git pull origin main`
2. Open **`IYSO.xcodeproj`**
3. Scheme **IYSO**, configuration **Debug**
4. Signing: your **Personal Team** (Debug has no fixed `DEVELOPMENT_TEAM`)
5. Run on a physical iPhone (`Cmd+R`)
6. Use **Simulate lens connection** on NFC onboarding when needed

## Publisher (TestFlight)

Archive **Release** with team **T73K2F5HAL** (or update `DEVELOPMENT_TEAM` in the project if your team ID differs). See [`HANDOFF.md`](HANDOFF.md).
