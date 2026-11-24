# SerIQ AI

**AI-Powered Home Rehabilitation Assistant**

English | [Русский](README.ru.md)

SerIQ helps people recovering after a stroke to check a home rehabilitation exercise. A person films one repetition (or uploads a video), pose estimation tracks the hand, and a custom machine learning classifier decides whether the repetition was complete. The user sees a neutral result, the measured value, a chart and a session summary. Trained models exist for elbow extension (E02), wrist lift (E03) and hand opening (E04). The API has a catalog of the four exercises of the dataset (E01–E04) and reports which of them are ready.

> **Status:** working prototype. The site, the API and the trained model are live at [seriq-ai.qalau.com](https://seriq-ai.qalau.com) (`"mode":"model"`): exercise library, upload or webcam recording, analysis by the custom classifiers, chart of the measured value, session summary and history, Kazakh and Russian. The Flutter app for Android and iOS works with the same API. Model metrics and their limitations: [docs/model-evaluation.md](docs/model-evaluation.md). See [Current status](#current-status).

## Contents

- [Origin](#origin)
- [Problem statement](#problem-statement)
- [How it works](#how-it-works)
- [Capabilities](#capabilities)
- [System workflow](#system-workflow)
- [Technology stack](#technology-stack)
- [Architecture overview](#architecture-overview)
- [Repository structure](#repository-structure)
- [Installation](#installation)
- [Local development](#local-development)
- [API documentation](#api-documentation)
- [Dataset handling and privacy](#dataset-handling-and-privacy)
- [Model evaluation](#model-evaluation)
- [Current status](#current-status)
- [Team](#team)
- [Open Source & Acknowledgements](#open-source--acknowledgements)

## Origin

SerIQ started as a case of the AI-Sana Shakarim Solveathon: AI & Medicine-2026 (Shakarim University, Semey, Kazakhstan). The case and the dataset come from this competition; the project continues as a product for home rehabilitation.

- [Competition website](https://solveathon.shakarim.edu.kz/)
- [Cases](https://solveathon.shakarim.edu.kz/en/problems/): case brief and dataset

## Problem statement

Patients recovering after a stroke often do rehabilitation exercises at home without a specialist nearby. It is hard for them to tell whether an exercise was performed fully. SerIQ gives a neutral check of each repetition from a video and keeps the history of sessions on the user's device. It does not give medical advice.

The dataset contains four exercises. The API describes all four; trained models exist for E02, E03 and E04, and `GET /api/v1/exercises` reports which exercises are ready.

| Code | Exercise | Measured value (`measure`) |
|---|---|---|
| `E01` | Lifting an object | `lift_height`, in hand lengths |
| `E02` | Elbow extension | `elbow_angle`, degrees |
| `E03` | Wrist lift | `wrist_lift`, degrees |
| `E04` | Hand opening | `hand_openness`, percent of the start |

## How it works

1. Detect hand keypoints on every video frame with MediaPipe Hand Landmarker. In the dataset the shoulder is usually outside the frame, so for E02 the elbow is located as the centre of the circle the wrist moves along (radius tied to the hand size).
2. Convert the points into a time series that does not depend on camera resolution, orientation or frame rate (E02: the elbow angle, E03: the rotation of the hand, E04: the opening of the hand).
3. Compute features of the series and classify the repetition with our own model trained on the dataset. The model is compared with simple baselines. Low confidence gives `uncertain`.
4. Show the user a neutral result and add it to the session summary.

One recording is one repetition.

## Capabilities

- Video upload and webcam recording (website), recording and upload in the mobile app
- Hand pose estimation; the arm line over the user's own video on the result screen
- Classification of a repetition (`complete` / `incomplete` / `uncertain`) with confidence
- Neutral messages; at low confidence the user is asked to check the instruction, without corrective medical advice
- Website: exercise library and an instruction for each exercise (text steps and filming tips)
- Website: session summary and history on the device with a filter by exercise; chart of the measured value of each exercise
- Interface in Kazakh and Russian, designed for older users
- Exercise catalog in the API for E01–E04 and mock responses for all four

## System workflow

```text
Instruction -> Recording or upload -> Hand landmarks -> Exercise signal
            -> Features -> Classification -> Result and session summary
```

## Technology stack

| Layer | Technology |
|---|---|
| Web | Next.js, TypeScript, Tailwind CSS, Recharts |
| Mobile | Flutter |
| Backend | Python 3.12, FastAPI |
| Hand keypoints | MediaPipe Hand Landmarker |
| Video processing | OpenCV |
| Machine learning | NumPy, scikit-learn |
| Deployment | VPS, Docker Compose, Caddy (HTTPS), GitHub Actions |

## Architecture overview

The web app and the Flutter app send a recording to one REST API. The FastAPI backend runs the shared AI core (pose estimation, elbow angle, features, classifier) and returns the result as JSON. The video is deleted after the analysis, there is no database, and the session history stays on the user's device. Details: [docs/architecture.md](docs/architecture.md), API contract: [docs/api.md](docs/api.md). The backend also reports the exercise catalog (`GET /api/v1/exercises`) and returns the measured value of the exercise in the `measure` field.

## Repository structure

```text
seriq-ai/
├── apps/
│   ├── web/                   # Next.js website
│   └── mobile/                # Flutter app (Android, iOS)
├── backend/                   # FastAPI backend: routes, schemas, upload checks, mock and model modes
├── ai-engine/                 # Python package seriq_engine: video, hand landmarks, angle, features, classifier
├── ml-training/               # Pose extraction, training and evaluation scripts
├── models/                    # Trained classifier
├── data/                      # Dataset is not committed; README.md explains how to place it
├── docs/                      # API contract, architecture, model evaluation, privacy, team documents
├── infrastructure/            # Dockerfiles, Caddy, deploy script, placeholder page
├── .github/workflows/         # CI/CD
├── docker-compose.yml         # Services on the server
├── docker-compose.ci.yml      # Overrides for the CI stack check
├── .env.example
├── README.md
├── README.ru.md
└── THIRD_PARTY_NOTICES.md     # Open-source components, licenses, AI tools
```

More: [docs/architecture.md](docs/architecture.md#repository-map).

## Installation

| Part | Folder | Requirements |
|---|---|---|
| Backend | `backend/` | Python 3.12 (the same version as the Docker image) |
| Website | `apps/web/` | Node.js 22 and npm |
| Mobile app | `apps/mobile/` | Flutter 3.50 (stable), JDK 21, Android SDK; iOS only on macOS with Xcode |

```bash
git clone https://github.com/Qalau-Development/seriq-ai.git
cd seriq-ai
```

Backend:

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
```

Website:

```bash
cd apps/web
npm ci
```

Mobile app:

```bash
cd apps/mobile
flutter pub get
flutter doctor      # "Android toolchain" must be marked ✓
```

If several JDKs are installed, point Flutter to JDK 21: `flutter config --jdk-dir <path to JDK 21>`. With JDK 17 the release build fails in Android Lint.

The dataset is needed only for model training, see [data/README.md](data/README.md).

## Local development

Each part runs in its own terminal; paths are relative to the repository root.

### Backend (mock mode)

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --port 8000    # http://localhost:8000/api/v1/health
pytest -q
```

Settings are read from environment variables `SERIQ_MODE` (`mock` or `model`), `SERIQ_MAX_UPLOAD_MB` and `SERIQ_MODEL_PATH`; see [.env.example](.env.example).

### Website

```bash
cd apps/web
npm run dev        # http://localhost:3000
npm run lint
npm run build
```

The website calls the relative path `/api/v1/...`. In development Next.js forwards `/api` to `SERIQ_API_PROXY` (default `http://localhost:8000`, the local backend above). To use the production API without a local backend:

```bash
SERIQ_API_PROXY=https://seriq-ai.qalau.com npm run dev
```

### Mobile app

Android phone with USB debugging or an emulator:

```bash
cd apps/mobile
flutter run --dart-define=API_BASE_URL=https://seriq-ai.qalau.com/api/v1
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://seriq-ai.qalau.com/api/v1
# APK: apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

The APK is also built by GitHub Actions: Actions → **Mobile** → run → Artifacts → `seriq-android-apk`.

`localhost` on a phone is the phone itself. To use the local backend from a phone connected by USB (debug build): `adb reverse tcp:8000 tcp:8000` and `flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1`.

iOS: on macOS with Xcode run `flutter run` in `apps/mobile` on a simulator or an iPhone (signing with an Apple ID in Xcode). GitHub Actions checks that the iOS build compiles (`flutter build ios --no-codesign`).

More: [apps/mobile/README.md](apps/mobile/README.md).

### Whole project locally with the real model

Backend in `model` mode and the website on one laptop, without the server: [docs/team/offline-demo.md](docs/team/offline-demo.md) (in Russian).

### Deployment

Deployment is automatic, nobody deploys by hand:

1. Every push to any branch runs the checks in GitHub Actions ([.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml)): server configuration, backend and AI engine tests, website lint and build, `flutter analyze` and `flutter test`, and a build of all services with a check that the website and the API answer. Changes in `apps/mobile/` also build the APK and the iOS app ([.github/workflows/mobile.yml](.github/workflows/mobile.yml)).
2. After a merge into `main` and green checks, GitHub Actions connects to the server over SSH and runs [infrastructure/scripts/deploy.sh](infrastructure/scripts/deploy.sh) for that commit.
3. The script builds the services that have code (`caddy`, `backend`, `web` in [docker-compose.yml](docker-compose.yml)), waits for their healthchecks and checks the main page and `/api/v1/health` over HTTPS. If something fails, it rolls back to the previous commit.

On the server Traefik (Dokploy) terminates HTTPS and passes requests to Caddy, which routes `/api/*` to the backend and everything else to the website. Server access, keys and the server `.env` are not in the repository. Details: [docs/architecture.md](docs/architecture.md#deployment).

## API documentation

- Contract: [docs/api.md](docs/api.md)
- Interactive documentation: [seriq-ai.qalau.com/api/docs](https://seriq-ai.qalau.com/api/docs), locally `http://localhost:8000/api/docs`
- Example responses: [docs/api-examples/](docs/api-examples/)

## Dataset handling and privacy

- The dataset is **not** stored in this repository. Videos, archives and processed data are excluded by `.gitignore`.
- Source: *An upper limb stroke rehabilitation exercise video dataset*, Mendeley Data, DOI [10.17632/49h9dcwx5v.1](https://data.mendeley.com/datasets/49h9dcwx5v/1), CC BY 4.0.
- The application needs no personal data and has no accounts. An uploaded video is analyzed and deleted; the session history stays on the user's device. What was checked and how: [docs/privacy-and-security.md](docs/privacy-and-security.md).
- SerIQ is a demonstration tool, **not a medical device**. It does not diagnose, prescribe treatment or give corrective medical advice.

## Model evaluation

Summary of [docs/model-evaluation.md](docs/model-evaluation.md). Same method for every exercise: split by volunteer ID, subject-wise cross-validation, one test run after the model and thresholds are fixed. E02 model `e02-logreg2-1`:

- Split by volunteer ID: volunteers 01–05 for training with leave-one-subject-out cross-validation, volunteer 08 as the test set, evaluated once after the model and thresholds were fixed.
- Metrics: balanced accuracy, precision, recall, F1, confusion matrix, compared with two baselines (majority class and one threshold).
- Cross-validation: balanced accuracy 1.000 (majority-class baseline 0.5, one-threshold baseline 1.000).
- Test volunteer 08 (20 videos): balanced accuracy 1.000. The 95% interval for the share of correct answers is 0.83–1.00, and all test videos come from one person.
- E04 `e04-logreg2-1` (test volunteer 09): balanced accuracy 1.000 on the 16 of 20 videos the model was confident about (coverage 0.80; 4 videos were `uncertain` because the hand was lost). 95% interval for the share of correct answers 0.79–1.00.
- E03 `e03-logreg2-1` (test volunteer 10): balanced accuracy 1.000 on the 13 of 20 confident videos (coverage 0.65; 7 videos `uncertain` because the hand was lost). 95% interval 0.75–1.00.
- Every test set is one person. The limitations of each model are listed in the document.

## Current status

- Repository, `.gitignore`, dataset metadata analysis: [docs/dataset-analysis.md](docs/dataset-analysis.md)
- API contract and architecture: [docs/api.md](docs/api.md), [docs/architecture.md](docs/architecture.md)
- Server with HTTPS, CI/CD with automatic deployment and rollback
- Backend API by the contract; mock mode for development, `model` mode on the server; exercise catalog `GET /api/v1/exercises`; mock answers for E01–E04
- AI core: hand keypoints, exercise signal (E02 elbow angle from the wrist trajectory, E03 hand rotation, E04 hand opening), features, classifiers with an `uncertain` rule
- Models `e02-logreg2-1`, `e03-logreg2-1` and `e04-logreg2-1` with subject-wise cross-validation, one evaluation on the held-out volunteer and comparison with baselines: [docs/model-evaluation.md](docs/model-evaluation.md)
- Website: exercise library, upload, webcam recording, result and chart by the measured value of the exercise, hand points over the video, session summary and history with a filter by exercise, Kazakh and Russian
- Flutter app: the same flow, checked on Android

## Team

Organization: **Qalau Development** ([github.com/Qalau-Development](https://github.com/Qalau-Development))

| GitHub | Area |
|---|---|
| [danshikdev](https://github.com/danshikdev) | Web app (first version), AI engine for the other exercises |
| [Zenki-Erzat](https://github.com/Zenki-Erzat) | Mobile app, deployment, AI engine for the other exercises |
| [Yeskendirr](https://github.com/Yeskendirr) | AI core and model for E02, backend, web and mobile app development |

## Open Source & Acknowledgements

SerIQ uses open-source libraries, a pretrained hand landmark model and a public dataset. Every third-party component, its license and its role in the project are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), together with the AI assistants used in development and a list of what the team builds itself.

- Dataset: B. Nair, S. Nandana, M. T. Dharshini, V. Viswanathan, *An upper limb stroke rehabilitation exercise video dataset*, Mendeley Data, 2026, DOI [10.17632/49h9dcwx5v.1](https://data.mendeley.com/datasets/49h9dcwx5v/1), CC BY 4.0.
- The project started as a case of the competition by Shakarim University: [AI-Sana Shakarim Solveathon](https://solveathon.shakarim.edu.kz/).
