# SerIQ mobile app (Flutter)

One Flutter app for **Android and iOS**. Same flow as the web app: instruction for exercise E02, recording one repetition with the system camera (up to 30 s) or picking a video from the gallery, the result from the API (`completed` / `check_instructions`, confidence, elbow-angle chart) and a session summary. History is stored only on the device (`shared_preferences`, key `seriq.sessions.v1`); the language is stored under `seriq.lang` (`ru` / `kk`). The recorded video is deleted from the app cache right after the analysis.

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

`localhost` on a phone is the phone itself, so the app needs a server with a domain.

In debug builds the session screen shows a mock scenario selector (`complete`, `incomplete`, `uncertain`, `no_pose`) that is sent as `?mock_scenario=`. Release builds do not have it.

## Check and build

```bash
flutter analyze
flutter test                    # uses ../../docs/api-examples
flutter build apk --release --dart-define=API_BASE_URL=https://seriq-ai.qalau.com/api/v1
# APK: build/app/outputs/flutter-apk/app-release.apk (not committed)
```

CI: `flutter analyze` and `flutter test` run in `.github/workflows/ci-cd.yml` on every push; `.github/workflows/mobile.yml` builds the release APK (artifact `seriq-android-apk`) and an unsigned iOS build on pull requests.

## Structure

```text
lib/
├── main.dart, app.dart          # start, theme, routes (/, /exercise, /session, /summary, /history)
├── core/                        # config.dart (API_BASE_URL, INSTRUCTION_VIDEO_URL), strings.dart (kk/ru)
├── models/                      # analysis_result.dart (API response), session.dart (local sessions)
├── services/                    # api_client.dart (POST /analysis, errors), history_storage.dart
├── features/                    # home, exercise, session, result, summary, history screens
└── widgets/                     # big_button, verdict_card, mock_badge, angle_chart
```
