// Compile-time flag, set only by the App Store screenshot pipeline via
//   flutter build ... --dart-define=SCREENSHOT_MODE=true
// (see /codemagic.yaml's `screenshots-workflow` and
// mobile/.maestro/screenshots.yaml).
//
// In every normal build this is a `const false`, so every branch guarded by
// it -- the auto-login in SplashScreen, the fixed GPS fix in
// location_service -- is tree-shaken away and has no effect on real users.
// It is never passed for Android builds.
const kScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');
