# App Store screenshots (iOS)

`screenshots.yaml` is a [Maestro](https://maestro.mobile.dev) flow that logs
into the Apple-review **client** test account and captures the key screens on
an iOS Simulator, at the simulator's full native resolution.

It exists so App Store screenshots can be produced without a Mac or an
iPhone. It is **iOS-only** — it drives the running app, it changes nothing
for Android.

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
flutter build ios --simulator --debug --dart-define=API_BASE_URL=https://api.fix-pro.app
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

The selectors are on-screen **French** strings. A failure is almost always
one of them drifting after an `l10n` change — update the string in
`screenshots.yaml`, not the app. The most fragile steps, in order:

- **district dropdown** (`tapOn: "Cocody.*"`) — if Cocody is ever removed
  from the seeded Côte d'Ivoire districts, pick another one that shows in
  the list.
- **`- back`** after the trade detail — relies on the iOS edge-swipe pop.
- the **phone field** (`tapOn: "Numéro de téléphone"`) — it's an
  `IntlPhoneField`; if focus lands wrong, target the field by index instead.
