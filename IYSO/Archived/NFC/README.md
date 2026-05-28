# Archived NFC code

NFC lens detection is paused. These files are kept for future re-integration.

**Previously used for:**
- Onboarding lens pairing (`NFCCalibrationScreen`, `LensDetectedScreen`)
- Background tag scanning to enter IYSO Mode (`NFCManager`)
- NDEF URL validation on attach (`NFCLensManager`)
- Attach-lens modal and detected banner UI

**To restore:** Re-add these files to the Xcode target, wire `NFCManager` back into `AppRootView`, and restore onboarding steps in `OnboardingCoordinator`.

Not compiled in the current app target.
