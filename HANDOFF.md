# Release handoff (new Apple team + bundle ID)

Use this when **you** develop locally and **someone else** signs/archives for TestFlight.

## Publisher must set (in Xcode, once)

1. Open `Digicam.xcodeproj`
2. Target **Digicam** → **Signing & Capabilities**
3. Set **Team** to the publishing Apple Developer team
4. Set **Bundle Identifier** to the App ID registered on that team (example: `com.yourcompany.iyso`)
5. Confirm capabilities on that App ID in [developer.apple.com](https://developer.apple.com):
   - Near Field Communication Tag Reading
   - Family Controls
   - Associated Domains (`applinks:iyso.app`)

## Build configurations in this repo

| Config  | Entitlements file              | Runtime NFC / Family Controls |
|---------|--------------------------------|-------------------------------|
| Debug   | `Digicam.entitlements.dev` (empty) | Simulated / UI-only path      |
| Release | `Digicam.entitlements` (full)      | Real hardware + Screen Time   |

**You (local, Personal Team):** run **Debug** on device to test flows with simulate buttons.

**Publisher:** archive **Release** on their team to validate real NFC tags and app shields.

## AASA (`iyso.app`)

File template: `deployment/iyso.app/.well-known/apple-app-site-association`

Before deploy, set:

```json
"appID": "<TEAM_ID>.<BUNDLE_ID>"
```

Example: `AB12CD34EF.com.yourcompany.iyso`

Verify after deploy:

```bash
curl -i https://iyso.app/.well-known/apple-app-site-association
```

## Publisher QA script (15 minutes, Release build, physical iPhone)

1. Fresh install → complete onboarding
2. Family Controls: approve permission → pick apps/categories in picker
3. NFC onboarding: first scan **pairs** lens tag
4. Exit IYSO → re-enter camera → scan **same** tag → unlocks
5. Scan **different** tag → rejected
6. IYSO on → selected apps blocked
7. Exit IYSO → blocks removed
8. Force-quit app → reopen → same tag still unlocks

Record pass/fail for each step.

## What you can verify without publisher access

- Onboarding order and navigation
- Attach-lens modal and exit-IYSO modal
- Toggle gating UI (camera vs memory)
- Settings / app list persistence
- Debug simulate NFC (`Simulate lens connection` on NFC screen)

## Git checklist before handoff

- [ ] Code pushed to GitHub
- [ ] AASA on Vercel (Team ID + bundle ID filled in, or PR ready for publisher)
- [ ] `HANDOFF.md` + README reviewed
- [ ] Publisher has NFC tag for testing
