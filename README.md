## Digicam / IYSO — release setup

NFC unlock, IYSO mode, and Family Controls shielding are implemented in code.  
Signing and TestFlight are done on the **publishing** Apple Developer account.

**Start here:** [`HANDOFF.md`](HANDOFF.md)

## Quick reference

| Item | Value / location |
|------|------------------|
| Bundle ID (default in project) | `app.iyso` |
| Xcode project | `IYSO.xcodeproj`, scheme **IYSO** |
| Associated domain | `iyso.app` → `IYSO/App/Digicam.entitlements.production` |
| Production entitlements (Release / TestFlight) | `IYSO/App/Digicam.entitlements.production` |
| Local dev entitlements (Personal Team) | `IYSO/App/Digicam.entitlements.dev` (Debug only) |
| Xcode Cloud | See [`XCODE_CLOUD.md`](XCODE_CLOUD.md) |
| AASA template | `deployment/iyso.app/.well-known/apple-app-site-association` |

## Local development (your Mac, Personal Team)

1. Open project in Xcode
2. Select your **Personal Team** under Signing (Debug)
3. Run **Debug** on a physical iPhone (`Cmd+R`)
4. Use **Simulate lens connection** on NFC onboarding when testing without entitlements

Debug builds use empty entitlements so Personal Team signing works; Release uses full NFC + Family Controls for the publisher.

## Publisher (TestFlight)

See [`HANDOFF.md`](HANDOFF.md) for Team ID, bundle ID, AASA, capabilities, and the 15-minute QA script.
