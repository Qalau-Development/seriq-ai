# SerIQ mobile app (Flutter)

One Flutter app for **Android and iOS** with the same functions as the web app: four exercises (E01–E04), recording or picking a video, the result with the measured value, a chart and the hand points over the video, session history, a summary of each session, "My progress", read-aloud, three languages (ru, kk, en) and optional accounts. The design follows the mobile mockups (390 px, content up to 720 px on tablets). All UI texts are taken from the site dictionaries (`apps/web/lib/i18n`), with no medical advice.

API contract: [docs/api.md](../../docs/api.md). Shared names: [docs/team/integration.md](../../docs/team/integration.md).

## Requirements

- Flutter (stable)
- Android: Android SDK and **JDK 21** (with JDK 17 the release build fails in Android Lint)
- iOS: a Mac with Xcode

## Run

```bash
cd apps/mobile
flutter pub get
flutter run                     # production API: https://seriq-ai.qalau.com/api/v1
flutter run --dart-define=API_BASE_URL=https://<host>/api/v1   # another server
```

Local backend with accounts (mock mode, temporary SQLite): `bash infrastructure/scripts/dev-backend.sh`, then `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1` on an Android emulator. Plain HTTP is allowed only in the debug build (`android/app/src/debug/AndroidManifest.xml`).

In debug builds the session screen shows a mock scenario selector (`complete`, `incomplete`, `uncertain`, `no_pose`) sent as `?mock_scenario=`. Release builds do not have it.

## Behaviour

- **Exercises.** The list comes from `GET /api/v1/exercises`; on an error a fallback list is used where only E02 can be recorded. Instruction video exists only for E02.
- **Analysis.** The video goes to `POST /api/v1/analysis` with the chosen exercise. After 15 seconds the screen adds "the server is busy"; the request timeout is 3 minutes. The result is read from `measure`; old E02 answers fall back to `angle_series`. `pose.elbow` is optional: the elbow line is drawn only when it exists.
- **Guest.** History lives on the device (`shared_preferences`, key `seriq.sessions.v1`, format in [architecture.md](../../docs/architecture.md)); the language is under `seriq.lang`. The recorded video is deleted from the app cache after the result is closed.
- **Accounts.** Shown only if `GET /health` has the field `database`. The refresh token is in `flutter_secure_storage`, the access token only in memory. A logged-in user's real results are sent in the background with `PUT /sessions/{id}` and retried at the next start; mock results (`source: mock`) are never sent. On login the guest history can be moved to the account (real attempts only). History, summary and progress come from the server; without a connection the device copies of the account's sessions are shown.

## Check and build

```bash
flutter analyze
flutter test                    # uses ../../docs/api-examples and ../web/lib/i18n
flutter build apk --release --dart-define=API_BASE_URL=https://seriq-ai.qalau.com/api/v1
# APK: build/app/outputs/flutter-apk/app-release.apk (not committed)
dart run tool/sync_strings.dart # regenerate lib/core/texts.dart after the site dictionaries change
```

CI: `flutter analyze` and `flutter test` run in `.github/workflows/ci-cd.yml` on every push; `.github/workflows/mobile.yml` builds the release APK (artifact `seriq-android-apk`) and an unsigned iOS build.

## Structure

```text
lib/
├── main.dart, app.dart          # start, routes (/, /exercise, /session, /summary, /history, /progress, /privacy, /login, /register, /profile)
├── core/                        # theme (design tokens), texts (generated), strings, exercises, measure_text, lift_stats, format
├── models/                      # analysis_result, session, progress, history_view
├── services/                    # api_client, auth, accounts, sync, sync_runtime, server_history, history_view, history_storage, speech
├── features/                    # home, exercise, session, result, summary, history, progress, account, privacy, system
└── widgets/                     # page shell, header, bottom navigation, buttons, cards, charts, video with hand points
assets/                          # Montserrat font (OFL), logo
```
