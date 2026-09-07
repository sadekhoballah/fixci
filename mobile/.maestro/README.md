# App Store screenshots (iOS)

`screenshots.yaml` is a [Maestro](https://maestro.mobile.dev) flow that
captures the key screens on an iOS Simulator, at the simulator's full native
resolution.

It exists so App Store screenshots can be produced without a Mac or an
iPhone. It is **iOS-only** — it drives the running app, it changes nothing
for Android.

## How the login is skipped

The `screenshots-workflow` builds the app with
`--dart-define=SCREENSHOT_MODE=true`. That flag (read only in
`lib/features/onboarding/screens/splash_screen.dart`, a `const false` in
every normal build) makes the splash screen log straight into the
Apple-review test **client** account (`+2250505050505`, OTP bypass) and jump
to its home shell. So the Maestro flow never drives the onboarding form or
the OTP screen — it just walks the bottom-nav tabs and one trade detail.

Driving the onboarding form from Maestro was tried and abandoned: Flutter's
iOS accessibility merges the form fields into large nodes, and Maestro's
`hideKeyboard` kept tapping the privacy-policy link underneath the keyboard.

## Run it (the normal way)

1. Codemagic → app `fixci` → start build → pick workflow
   **`App Store Screenshots (iOS Simulator)`** (`screenshots-workflow` in
   `/codemagic.yaml`). It has no automatic trigger.
2. When it finishes, download the build artifacts. The PNGs are
   `01_accueil.png` … `05_compte.png` (device: iPhone 16 Pro Max →
   **1320 × 2868**, an accepted App Store 6.9" size).
3. In App Store Connect → the app → the 1.0 version → **Previews and
   Screenshots**, drop the ones you want into the **iPhone 6.9"** well
   (App Store Connect scales that set down for smaller devices).

## Run it locally (only if you get a Mac)

```sh
cd mobile
flutter build ios --simulator --debug \
  --dart-define=API_BASE_URL=https://api.fix-pro.app \
  --dart-define=SCREENSHOT_MODE=true
xcrun simctl boot "iPhone 16 Pro Max"
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
maestro test .maestro/screenshots.yaml
```

## What each screenshot is

| file | screen |
|------|--------|
| `01_accueil`         | service-category grid ("De quoi avez-vous besoin ?") |
| `02_metier_plombier` | trade detail — hero image + description |
| `03_missions`        | missions / freelance board |
| `04_historique`      | job history |
| `05_compte`          | account (test account, no real personal data) |

Keep 01–03; 04–05 are usually too sparse to be worth submitting.

## If a step fails

The selectors are on-screen **French** strings wrapped `(?s).*text.*`. A
failure is almost always one drifting after an `l10n` change — update the
string in `screenshots.yaml`, not the app. Check the artifact
`build/screenshots/_hierarchy_home.txt` (dumped every run) for the exact
`accessibilityText` values Maestro sees.

If `SCREENSHOT_MODE` login itself fails (the flow times out on
"De quoi avez-vous besoin"), the app falls back to the normal
role-selection screen — check that `+2250505050505` is still in the VPS
`OTP_TEST_PHONES` and that the backend is reachable at
`https://api.fix-pro.app`.
