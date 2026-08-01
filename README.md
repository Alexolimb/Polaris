# Polaris — investment simulator & academy

Learn to invest without risking money: a virtual $10,000 portfolio, an AI mentor ("Cosmo") and a
30-lesson course. Built with **Flutter** for Windows and Android, in English / Russian / Spanish.

> Personal product, built solo — architecture, UI, content and tests.

## What it does

| Tab | What's in it |
|---|---|
| **Portfolio** | Open positions, total value, performance over time |
| **Market** | Asset catalogue, themed collections, asset card with 1D/1W/1M/1Y charts and dividends |
| **Cosmo** | AI mentor — chat with streaming (SSE) responses |
| **Learn** | 30 lessons + glossary + "try it on your own portfolio" exercises |
| **More** | Settings (language, notifications), brokers, about, privacy, legal |

## Architecture

- **Simulation core** — `lib/services/sim_engine.dart`, pure Dart, no Flutter imports.
  All money is stored as **integer cents**, share quantities to 1e-8. A trade either fully
  succeeds or throws `SimError` — no half-applied state. Starting balance: $10,000.
- **State** — `lib/state/` (`Portfolio` / `Market` / `Chat` / `Learn` / `AppSettings`), distributed
  through `AppScope`. Persistence via `shared_preferences` (`lib/services/storage.dart`).
- **Networking** — `lib/services/api.dart` (REST) and `ai.dart` (SSE stream for Cosmo), both against
  the `v1` contract. Transports are injectable, so **the test suite runs with no network**.
- **Content** — `assets/content/*.json` (lessons, themes, glossary × 3 languages), loaded by
  `lib/services/lessons.dart`.
- **Localisation** — `lib/l10n/app_*.arb`, generated on `flutter pub get` / `build`.

### Runs without a backend

With no `baseUrl` configured the app runs **offline on built-in fixtures** for market data, and
Cosmo shows a clear "no connection" state instead of failing. **No API keys or secrets ship in the
app.** The backend is a separate component — see
[Polaris-server](https://github.com/Alexolimb/Polaris-server).

## Build and run

```bash
flutter pub get              # dependencies
flutter run -d windows       # run on Windows
flutter build windows        # release build  -> build/windows/x64/runner/Release/polaris.exe
flutter build apk            # release build for Android
flutter analyze              # static analysis — expected: 0 issues
flutter test                 # test suite — expected: 236 tests, all green
```

## Requirements

- Flutter SDK, Dart ^3.12
- Keep the project in an ASCII-only path — non-Latin characters in the path break Flutter/Gradle
  tooling on Windows.

## Notes

Market data in the demo backend is synthetic and explicitly labelled `freshness: "demo"` — this is a
teaching simulator, not a brokerage. Cosmo's system prompt forbids personalised investment advice
and any promise of returns.
