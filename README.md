<div align="center">

<img src="assets/brand/strata_icon.png" width="108" alt="Strata Flutter wallet app icon" />

# Strata: Flutter Wallet App Template

**Every card, one balance.**

A premium **Flutter card wallet and fintech app template** for **iOS and Android**.<br />
Animated splash, onboarding, **Sign in with Apple and Google**, cards, send money, currency conversion,<br />
transactions and dark mode, with physics-driven motion and a demo you can sign in to in one tap.

<br />

[![Website](https://img.shields.io/badge/website-flutterzip.com-245539?style=for-the-badge&logo=googlechrome&logoColor=white)](https://flutterzip.com)
[![Instagram](https://img.shields.io/badge/instagram-@flutter__zip-245539?style=for-the-badge&logo=instagram&logoColor=white)](https://instagram.com/flutter_zip)

<br />

![Flutter](https://img.shields.io/badge/Flutter-3.38-245539?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.5+-245539?style=flat-square&logo=dart&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android-585F54?style=flat-square)
![State](https://img.shields.io/badge/state-Riverpod-585F54?style=flat-square)
![Tests](https://img.shields.io/badge/tests-436%20passing-2E6B4C?style=flat-square)

<br />

<img src="docs/hero.png" alt="Strata Flutter wallet app template screens: onboarding, sign in with Apple and Google, home balance, card carousel and dark mode" />

</div>

<br />

## Contents

- [Highlights](#highlights)
- [Screens](#screens)
  - [First run](#first-run)
  - [Sign in and sign up](#sign-in-and-sign-up)
  - [Wallet](#wallet)
  - [Moving money](#moving-money)
  - [Account](#account)
  - [Dark mode](#dark-mode)
- [Try the demo](#try-the-demo)
- [Getting started](#getting-started)
- [Make it yours](#make-it-yours)
- [Project structure](#project-structure)
- [How it is built](#how-it-is-built)
- [Testing](#testing)
- [Screenshot hooks](#screenshot-hooks)
- [FAQ](#faq)
- [Made by FlutterZip](#made-by-flutterzip)
- [Credits](#credits)
- [License](#license)

<br />

## Highlights

Strata is a complete, production-quality **Flutter banking and payments UI**: a digital wallet app with
real data flows, not a set of static mockups. Use it as a **starting point for a fintech app**, a
**Flutter UI kit** to learn from, or a reference for **Riverpod architecture**, **local persistence** and
**custom animation** in Flutter.

<table>
  <tr>
    <td width="28%"><b>A designed first run</b></td>
    <td>An animated splash that deals the logo in layer by layer, a three-slide intro, and sign in, sign up, password reset, one-time code and PIN, each with its loading, success and error states.</td>
  </tr>
  <tr>
    <td width="28%"><b>Sign in with Apple and Google</b></td>
    <td>On both sign in and sign up, styled to each company's guidelines in light and dark mode.</td>
  </tr>
  <tr>
    <td width="28%"><b>A real wallet</b></td>
    <td>Add, edit, freeze and remove cards. A stacked wallet view and a spring-physics carousel. Card numbers and security codes are never stored.</td>
  </tr>
  <tr>
    <td width="28%"><b>Send and convert</b></td>
    <td>Send to a recipient found by handle or email, convert between currencies with a visible fee, and see both reflected in balances and activity at once.</td>
  </tr>
  <tr>
    <td width="28%"><b>Activity that stays honest</b></td>
    <td>Grouped by day, searchable and filterable. The home spending chart is derived from the same transactions, so the two can never disagree.</td>
  </tr>
  <tr>
    <td width="28%"><b>Motion that is measured</b></td>
    <td>The carousel spring was fitted frame by frame from a reference recording. Every animation respects the system's Reduce Motion setting.</td>
  </tr>
  <tr>
    <td width="28%"><b>Light and dark, one accent</b></td>
    <td>Paper and ink with a single green accent. Every surface is defined once for both modes.</td>
  </tr>
  <tr>
    <td width="28%"><b>Built to be changed</b></td>
    <td>The product name, colours, motion, wait times and demo data each live in one place. Every screen talks to a repository, so a real API drops in without touching a widget.</td>
  </tr>
</table>

<br />

## Screens

### First run

The splash builds the mark from nothing, lifts it, and raises the wordmark letter by letter before dissolving into the first screen.

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/splash.gif" width="220" alt="Animated Flutter splash screen with layered logo" /><br /><sub><b>Splash</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/onboarding-1.png" width="220" alt="Flutter wallet app onboarding screen: every card, one balance" /><br /><sub><b>Every card, one balance</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/onboarding-2.png" width="220" alt="Flutter fintech app onboarding, second slide" /><br /><sub><b>Spending that explains itself</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/onboarding-3.png" width="220" alt="Flutter wallet onboarding: card numbers never stored" /><br /><sub><b>Your numbers never stored</b></sub></td>
  </tr>
</table>

### Sign in and sign up

Field titles sit above each box with a hint and an icon inside. Buttons keep their colour while they work and show a loader drawn from the logo. Demo settings switches the theme, hides the demo hints, or resets everything.

<table>
  <tr>
    <td align="center" width="33%"><img src="docs/screenshots/sign-in.png" width="250" alt="Flutter sign in screen with Sign in with Apple and Google buttons" /><br /><sub><b>Sign in</b></sub></td>
    <td align="center" width="33%"><img src="docs/screenshots/sign-up.png" width="250" alt="Flutter sign up screen with Apple and Google sign-up and labelled fields" /><br /><sub><b>Sign up</b></sub></td>
    <td align="center" width="33%"><img src="docs/screenshots/forgot-password.png" width="250" alt="Flutter forgot password screen" /><br /><sub><b>Forgot password</b></sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/verify-code.png" width="250" alt="Flutter one-time code (OTP) verification screen" /><br /><sub><b>One-time code</b></sub></td>
    <td align="center"><img src="docs/screenshots/create-pin.png" width="250" alt="Flutter PIN code screen with custom keypad" /><br /><sub><b>Create a PIN</b></sub></td>
    <td align="center"><img src="docs/screenshots/demo-settings.png" width="250" alt="Demo settings sheet: theme, hints and reset" /><br /><sub><b>Demo settings</b></sub></td>
  </tr>
</table>

### Wallet

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/screenshots/home.png" width="220" alt="Flutter wallet app home screen with total balance, cards and spending chart" /><br /><sub><b>Home</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/wallet.png" width="220" alt="Flutter stacked card wallet view" /><br /><sub><b>Wallet</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/cards-carousel.png" width="220" alt="Flutter card carousel with spring physics" /><br /><sub><b>Card carousel</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/add-card.png" width="220" alt="Flutter add credit card form with live card preview" /><br /><sub><b>Add a card</b></sub></td>
  </tr>
</table>

### Moving money

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/screenshots/send.png" width="220" alt="Flutter send money screen" /><br /><sub><b>Send</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/convert.png" width="220" alt="Flutter currency converter screen with fee breakdown" /><br /><sub><b>Convert</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/activity.png" width="220" alt="Flutter transaction history grouped by day" /><br /><sub><b>Activity</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/activity-filter.png" width="220" alt="Flutter transaction filter sheet" /><br /><sub><b>Filter</b></sub></td>
  </tr>
</table>

### Account

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/screenshots/profile.png" width="250" alt="Flutter profile screen with avatar upload" /><br /><sub><b>Profile</b></sub></td>
    <td align="center" width="50%"><img src="docs/screenshots/notifications.png" width="250" alt="Flutter in-app notifications sheet" /><br /><sub><b>Notifications</b></sub></td>
  </tr>
</table>

### Dark mode

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/screenshots/sign-in-dark.png" width="220" alt="Flutter sign in screen in dark mode" /><br /><sub><b>Sign in</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/home-dark.png" width="220" alt="Flutter wallet home screen in dark mode" /><br /><sub><b>Home</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/cards-carousel-dark.png" width="220" alt="Flutter card carousel in dark mode" /><br /><sub><b>Cards</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/profile-dark.png" width="220" alt="Flutter profile screen in dark mode" /><br /><sub><b>Profile</b></sub></td>
  </tr>
</table>

<br />

## Try the demo

The sign-in form is filled in for you. Press **Sign in**, or use these anywhere a value is asked for:

<table>
  <tr><td><b>Email</b></td><td><code>hello@flutterzip.com</code></td></tr>
  <tr><td><b>Password</b></td><td><code>strata2026</code></td></tr>
  <tr><td><b>One-time code</b></td><td><code>284917</code></td></tr>
  <tr><td><b>PIN</b></td><td><code>4821</code>, or set your own after signing in</td></tr>
</table>

**Sign in with Apple** and **Sign in with Google** are simulated in the demo: they wait as a real provider would, then continue to PIN setup.

The round button floating at the edge of the screen opens **Demo settings**: theme (Auto, Light, Dark), demo hints on or off, and **Reset demo data**, which puts everything back and replays the intro. Drag it anywhere; it springs to the nearest edge.

<br />

## Getting started

**Requirements**

- Flutter 3.38 or newer (Dart 3.5+)
- Xcode with an iOS simulator, or Android Studio with an emulator

**Run it**

```bash
flutter pub get
flutter run
```

**Run it on a specific simulator**

```bash
xcrun simctl list devices available          # find a UDID
flutter build ios --simulator --debug
xcrun simctl install <udid> build/ios/iphonesimulator/Runner.app
xcrun simctl launch  <udid> dev.strata.strata
```

**Skip every deliberate wait** (splash and simulated network time), for automation:

```bash
flutter run --dart-define=timingScale=0
```

<br />

## Make it yours

Each of these is a single place to edit.

| Change | Where |
|---|---|
| Product name and tagline | `lib/config/app_brand.dart` |
| Colours, light and dark | `lib/config/palette.dart`, applied in `lib/config/app_theme.dart` |
| Spacing, radii, touch targets | `lib/config/design_tokens.dart` |
| Animation durations, curves, springs | `lib/config/motion.dart` |
| Splash timing and every simulated wait | `lib/config/app_timing.dart` |
| Demo data: cards, activity, people, notifications, rates, profile | `assets/data/*.json` (see `assets/data/README.md`) |
| Demo login | `assets/data/auth.json` |
| App icon and logo | Edit the mark in `lib/shared/widgets/strata_mark.dart`, then run `python3 tool/make_icons.py` |
| Real sign-in and backend | Implement `AuthRepository` and the other repository interfaces in `lib/services/` |

Seed copy can say `{app}` instead of the product name; it is filled in when loaded, so a rename is one edit.

<br />

## Project structure

```text
lib/
├── config/        Brand, palette, theme, design tokens, motion, timing
├── models/        Plain data classes with JSON in and out
├── services/      Repository interfaces and their local implementations
├── providers/     Riverpod state, one file per domain
├── screens/
│   ├── splash/        The animated splash over the first screen
│   ├── auth/          Onboarding, sign in, sign up, reset, code, PIN
│   ├── home/          Balance, cards, quick actions, spending, activity
│   ├── cards/         Wallet stack, carousel, card controls
│   ├── add_card/      Add a card and the confirmation
│   ├── send/          Recipient, amount, review, result
│   ├── convert/       Currency exchange with live fee breakdown
│   ├── transactions/  Activity, search, filter, detail and edit
│   ├── profile/       Profile, avatar, notifications
│   ├── more/          Statements, limits, support
│   └── shell/         Navigation bar and rail
└── shared/
    ├── widgets/   Reusable UI: sheets, rows, buttons, card face, loader
    └── utils/     Pure logic: money, validation, rules, grouping

assets/
├── data/      Seed JSON, read on first run
├── brand/     Icon and logo PNGs
└── fonts/     Bricolage Grotesque

tool/          Icon generator, screenshot capture, motion measurement
test/          Widget, provider, service and utility tests
integration_test/  Simulator flows: add a card, carousel fling, persistence
```

<br />

## How it is built

```mermaid
flowchart LR
    Seed["assets/data/*.json<br/>(read-only seed)"] -->|first run| Store["shared_preferences<br/>(state)"]
    Store <--> Repo["Repositories<br/>(async interfaces)"]
    Repo <--> Providers["Riverpod providers"]
    Providers --> Screens["Screens"]
    Providers --> Derived["Derived views<br/>spending chart, limits, statements"]
    Derived --> Screens
```

- **Seed is not state.** Bundled JSON fills storage on first run; anything the user changes lives in storage. Reset re-reads the seed.
- **Derived, never stored twice.** The spending chart, spend limits and statements are calculated from transactions, so editing one transaction moves all of them.
- **Every repository is async**, even locally. Swapping in a real API changes the repository, not the screens.
- **Money is integer minor units**, signed: negative is money out. Each transaction's currency matches its card's.
- **No card number is ever persisted.** Only the last four digits, brand, expiry and holder. A test checks the stored form.
- **Accessibility:** semantics labels on every control, 48pt touch targets, text scaling from 90% to 135%, and Reduce Motion honoured everywhere.

<br />

## Testing

```bash
flutter analyze && flutter test        # 436 tests
flutter test integration_test          # on a running simulator
```

Widget tests run on a phone-sized surface and cover layout at the edges of the text-scale range, both themes, loading and error states, and every flow that moves money.

<br />

## Screenshot hooks

Launch the app straight onto any screen with a define. All are off by default, so release builds are unaffected.

| Define | Opens |
|---|---|
| `startTab=1` / `2` | Cards / Profile |
| `startLayout=0` | Cards on the carousel instead of the wallet stack |
| `startSlide=1` / `2` | Intro on slide two / three |
| `startAuthStep=signUp` / `forgot` / `otp` | That step of the signed-out flow |
| `startRoute=/add-card` / `/send` / `/convert` / `/transactions` | That screen |
| `startFilter=true` | Activity's filter (with `startRoute=/transactions`) |
| `startSheet=notifications` / `demo` | That sheet |
| `hideDemoControl=true` | Hides the floating demo button |
| `timingScale=0` | No splash, no simulated waits |

Every screenshot in this README is produced by one command:

```bash
python3 tool/screenshots.py --sim <udid>
```

<br />

## FAQ

<details>
<summary><b>Is this a Flutter fintech or banking app template?</b></summary>
<br />
Yes. Strata is a card wallet and payments app: balances across cards, adding and freezing cards, spending limits, sending money, currency conversion, statements and a full transaction history. It is built so a real banking or payments API can replace the local demo data.
</details>

<details>
<summary><b>Does it run on iOS and Android?</b></summary>
<br />
Yes. It is one Flutter codebase for iPhone and Android phones, and it adapts to tablets with a navigation rail.
</details>

<details>
<summary><b>Does it include Sign in with Apple and Google sign-in?</b></summary>
<br />
The buttons, screens, loading states and flow are all there, styled to Apple's and Google's guidelines on both sign in and sign up. In the demo they are simulated. To go live, add <code>sign_in_with_apple</code> and <code>google_sign_in</code> inside <code>AuthRepository.signInWith</code>; no screen needs to change.
</details>

<details>
<summary><b>Which state management does it use?</b></summary>
<br />
Riverpod, with one provider file per domain and async repositories underneath.
</details>

<details>
<summary><b>Can I connect my own backend or API?</b></summary>
<br />
Yes. Every screen reads and writes through a repository interface in <code>lib/services/</code>. Implement the interface against your API and swap it in the provider; the widgets stay as they are.
</details>

<details>
<summary><b>Does it support dark mode?</b></summary>
<br />
Yes. Every screen is designed for light and dark from the same colour tokens, and the user can choose Auto, Light or Dark.
</details>

<details>
<summary><b>Can I change the name, colours and branding?</b></summary>
<br />
Yes. The name, colours, typography, motion and timing each live in one file, and the app icon is generated from the logo with one command. See <a href="#make-it-yours">Make it yours</a>.
</details>

<br />

## Made by FlutterZip

Strata is made by **[FlutterZip](https://flutterzip.com)**: premium Flutter app templates and UI, built to ship.

- Website: **[flutterzip.com](https://flutterzip.com)**
- Instagram: **[@flutter_zip](https://instagram.com/flutter_zip)** for new templates, builds and behind-the-scenes

<br />

## Credits

- Typeface: [Bricolage Grotesque](https://github.com/ateliertriay/bricolage) by Mathieu Triay, under the SIL Open Font License 1.1.
- All artwork, including the logo, card faces, backgrounds and onboarding illustrations, is drawn in code.
- Payment networks are named in text and never drawn as logos. The Apple and Google sign-in buttons follow those companies' published guidelines.

<br />

## License

The code is released under the [MIT License](LICENSE): use it in personal and commercial apps, free.
The Bricolage Grotesque font is under the [SIL Open Font License 1.1](assets/fonts/OFL.txt).

<br />

<div align="center">

**[flutterzip.com](https://flutterzip.com)** · **[@flutter_zip](https://instagram.com/flutter_zip)**

<sub>Strata · Flutter wallet app template · fintech UI kit for iOS and Android</sub>

</div>
