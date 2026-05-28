## Digicam / IYSO — release setup

NFC unlock, IYSO mode, and Family Controls shielding are implemented in code.  
Signing and TestFlight are done on the **publishing** Apple Developer account.

**Start here:** [`HANDOFF.md`](HANDOFF.md)

## Quick reference

| Item | Value / location |
|------|------------------|
| Bundle ID (default in project) | `com.iyso.digicam` — publisher may change in Xcode |
| Associated domain | `iyso.app` → `Digicam/App/Digicam.entitlements` |
| Production entitlements | `Digicam/App/Digicam.entitlements` |
| Local dev entitlements (Personal Team) | `Digicam/App/Digicam.entitlements.dev` (Debug only) |
| AASA template | `deployment/iyso.app/.well-known/apple-app-site-association` |

## Local development (your Mac, Personal Team)

1. Open project in Xcode
2. Select your **Personal Team** under Signing (Debug)
3. Run **Debug** on a physical iPhone (`Cmd+R`)
4. Use **Simulate lens connection** on NFC onboarding when testing without entitlements

Debug builds use empty entitlements so Personal Team signing works; Release uses full NFC + Family Controls for the publisher.

## Publisher (TestFlight)

See [`HANDOFF.md`](HANDOFF.md) for Team ID, bundle ID, AASA, capabilities, and the 15-minute QA script.
