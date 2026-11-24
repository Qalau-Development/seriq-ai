# SerIQ AI

**AI-Powered Home Rehabilitation Assistant**

English | [Русский](README.ru.md)

SerIQ analyzes an elbow extension exercise from a webcam or an uploaded video. It uses pose estimation to track the arm and a custom machine learning classifier to decide whether each exercise cycle was complete. The user sees a neutral result: "Exercise completed" or "Please check the instructions".

> **Status:** in development. The server, CI/CD and a **mock API** are live at [seriq-ai.qalau.com](https://seriq-ai.qalau.com); the web app is live with upload, webcam recording, angle chart, session summary and history; the AI core extracts the elbow angle from video; the classifier and the mobile app are in progress. The mock API returns fixed test responses marked `"source": "mock"`, not model results. See [Current status](#current-status).

## Contents

- [Competition context](#competition-context)
- [Problem statement](#problem-statement)
- [Proposed solution](#proposed-solution)
- [Planned capabilities](#planned-capabilities)
- [System workflow](#system-workflow)
- [Technology stack](#technology-stack)
- [Architecture overview](#architecture-overview)
- [Repository structure](#repository-structure)
- [Installation](#installation)
- [Local development](#local-development)
- [API documentation](#api-documentation)
- [Dataset handling and privacy](#dataset-handling-and-privacy)
- [Model evaluation methodology](#model-evaluation-methodology)
- [Current status](#current-status)
- [Roadmap](#roadmap)
- [Team](#team)
- [Open Source & Acknowledgements](#open-source--acknowledgements)

## Competition context

| | |
|---|---|
| Competition | AI-Sana Shakarim Solveathon: AI & Medicine-2026 |
| Organizer | Shakarim University, Semey, Kazakhstan |
| Track | University and college students |
| Case | SerIQ: AI assistant for home rehabilitation |
| Dates | 24–25 November 2026 |

Official resources:

- [Competition website](https://solveathon.shakarim.edu.kz/)
- [For participants](https://solveathon.shakarim.edu.kz/en/for-participants/): rules, deliverables, evaluation criteria
- [Cases](https://solveathon.shakarim.edu.kz/en/problems/): case brief and dataset

## Problem statement

Patients recovering after a stroke often do rehabilitation exercises at home without a specialist nearby. It is hard for them to tell whether an exercise was performed fully.

The case asks for a prototype that evaluates one exercise, **elbow extension (E02)**, from a camera or an uploaded video. The case specification requires:

1. An exercise workflow: a video instruction and motion capture through the camera or a video upload.
2. Arm keypoint detection with a pose estimation model and tracking of the elbow extension cycle.
3. A custom AI model on sequences of arm coordinates or angles that classifies a cycle as `complete` or `incomplete`, with a confidence estimate and a comparison against a baseline classifier. At low confidence the application suggests reviewing the instruction and gives no corrective medical advice. Train, validation and test data must be split strictly by volunteer ID. Quality is reported with balanced accuracy, F1 and a confusion matrix.
4. A local session summary: the number of recognized cycles, their classes and a visual overview.

## Proposed solution

1. Detect hand keypoints on every video frame with MediaPipe Hand Landmarker. In the dataset the shoulder is usually outside the frame, so the elbow is located as the centre of the circle the wrist moves along (radius tied to the hand size).
2. Convert them into an elbow angle time series that does not depend on camera resolution, orientation or frame rate.
3. Split a recording into individual exercise cycles.
4. Classify each cycle with our own model trained on the case dataset, and compare it with a simple baseline.
5. Show the user a neutral result and a session summary.

## Planned capabilities

None of these are implemented yet.

- Video instruction for the elbow extension exercise
- Video upload and webcam recording
- Pose estimation of the arm
- Cycle detection and per-cycle classification (`complete` / `incomplete`) with confidence
- Neutral messages, with a suggestion to review the instruction at low confidence
- Session summary: total cycles, complete and incomplete counts, per-cycle results, chart
- Interface in Kazakh and Russian or English, designed for older users and patients

## System workflow

```text
Instruction -> Recording or upload -> Pose estimation -> Elbow angle series
            -> Cycle segmentation -> Classification -> Result and session summary
```

## Technology stack

Agreed; not implemented yet.

| Layer | Technology |
|---|---|
| Web | Next.js, TypeScript, Tailwind CSS, Recharts |
| Mobile | Flutter |
| Backend | Python 3.12, FastAPI |
| Hand keypoints | MediaPipe Hand Landmarker |
| Video processing | OpenCV |
| Machine learning | NumPy, scikit-learn |
| Deployment | VPS, Docker Compose, Caddy (HTTPS) |

## Architecture overview

The web app and the Flutter app send a recording to one REST API. The FastAPI backend runs the shared AI core (pose estimation, elbow angle, features, classifier) and returns the result as JSON. The video is deleted after the analysis, there is no database, and the session history stays on the user's device. Details: [docs/architecture.md](docs/architecture.md), API contract: [docs/api.md](docs/api.md).

## Repository structure

Current structure:

```text
seriq-ai/
├── backend/                   # FastAPI backend (mock mode for now)
│   ├── app/                   # routes, schemas, upload checks, mock analysis
│   ├── tests/
│   ├── requirements.txt
│   └── requirements-dev.txt
├── data/
│   └── README.md              # How to obtain and place the dataset
├── docs/
│   ├── api.md                 # API contract
│   ├── api-examples/          # Real mock API responses for client tests
│   ├── architecture.md        # Components, repository map, deployment
│   ├── dataset-analysis.md    # Dataset structure, labels, video properties
│   ├── development-plan.md    # Scope, roles, stages
│   ├── model-evaluation.md    # Evaluation methodology; results pending
│   └── team/                  # Task lists per developer (Russian)
├── infrastructure/            # Dockerfiles, Caddy, deploy script, placeholder page
├── .github/workflows/         # CI/CD
├── docker-compose.yml         # Services on the server
├── docker-compose.ci.yml      # Overrides for the CI stack check
├── .env.example
├── README.md
├── README.ru.md
└── THIRD_PARTY_NOTICES.md     # Open-source components, licenses, AI tools
```

`apps/web/`, `apps/mobile/`, `ai-engine/`, `ml-training/` and `models/` will be added as their implementation starts. Target structure: [docs/architecture.md](docs/architecture.md#repository-map).

## Installation

Requirements for the backend: Python 3.12 (the same version as the Docker image).

```bash
git clone https://github.com/Qalau-Development/seriq-ai.git
cd seriq-ai/backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
```

The dataset is needed only for model training, see [data/README.md](data/README.md). Instructions for the web and mobile apps will be added with their code.

## Local development

Backend in mock mode:

```bash
cd backend
uvicorn app.main:app --reload --port 8000
pytest -q
```

Settings are read from environment variables `SERIQ_MODE` (`mock` or `model`), `SERIQ_MAX_UPLOAD_MB` and `SERIQ_MODEL_PATH`; see [.env.example](.env.example).

Deployment is automatic: every push to `main` passes the checks and is deployed to the server, see [docs/architecture.md](docs/architecture.md#deployment).

## API documentation

- Contract: [docs/api.md](docs/api.md)
- Interactive documentation: [seriq-ai.qalau.com/api/docs](https://seriq-ai.qalau.com/api/docs), locally `http://localhost:8000/api/docs`
- Example responses: [docs/api-examples/](docs/api-examples/)

## Dataset handling and privacy

- The case dataset is **not** stored in this repository. Videos, archives and processed data are excluded by `.gitignore`.
- Source: *An upper limb stroke rehabilitation exercise video dataset*, Mendeley Data, DOI [10.17632/49h9dcwx5v.1](https://data.mendeley.com/datasets/49h9dcwx5v/1), CC BY 4.0.
- The planned application does not need personal data. Uploaded videos are meant to be processed and not kept, and the session summary is meant to stay on the user's device.
- SerIQ is a demonstration tool, **not a medical device**. It does not diagnose, prescribe treatment or give corrective medical advice.

## Model evaluation methodology

Summary of [docs/model-evaluation.md](docs/model-evaluation.md):

- Split by volunteer ID: volunteers 01–05 for training with leave-one-subject-out cross-validation, volunteer 08 as the held-out test set.
- Metrics: balanced accuracy, precision, recall, F1, confusion matrix, compared against a baseline classifier.
- The confidence threshold is chosen on cross-validation folds, not on the test set.

**Results: Pending** (no model trained yet).

## Current status

| Category | Item |
|---|---|
| Implemented | Repository setup and `.gitignore` |
| Implemented | Dataset metadata analysis: [docs/dataset-analysis.md](docs/dataset-analysis.md) |
| Implemented | Evaluation methodology defined: [docs/model-evaluation.md](docs/model-evaluation.md) |
| Implemented | API contract and architecture agreed: [docs/api.md](docs/api.md), [docs/architecture.md](docs/architecture.md) |
| Implemented | Server with HTTPS, CI/CD with automatic deployment and rollback |
| Implemented | Mock API (fixed test responses, not model output), 33 tests, deployed |
| Implemented | Web app: upload, webcam recording, elbow angle chart, session summary and history (Russian) |
| Implemented | AI core: hand keypoints and elbow angle series from video, 8 engine tests |
| In progress | Baseline and main classifier, evaluation; Kazakh interface; Flutter app (Android and iOS) |
| Planned | Cycle segmentation |
| Planned | Real analysis in the backend (`model` mode) |
| Planned | Evaluation report and presentation |

Screenshots: pending, will be added when the interface exists.

## Roadmap

See the stages table in [docs/development-plan.md](docs/development-plan.md#stages). Submission deadline: 25 November 2026, 13:30 (Kazakhstan time).

## Team

Organization: **Qalau Development** ([github.com/Qalau-Development](https://github.com/Qalau-Development))

| GitHub | Area |
|---|---|
| [danshikdev](https://github.com/danshikdev) | Web app |
| [Zenki-Erzat](https://github.com/Zenki-Erzat) | Mobile app, deployment |
| [Yeskendirr](https://github.com/Yeskendirr) | AI core, model, backend |

## Open Source & Acknowledgements

SerIQ uses open-source libraries, a pretrained hand landmark model and a public dataset. Every third-party component, its license and its role in the project are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), together with the AI assistants used in development and a list of what the team builds itself.

- Dataset: B. Nair, S. Nandana, M. T. Dharshini, V. Viswanathan, *An upper limb stroke rehabilitation exercise video dataset*, Mendeley Data, 2026, DOI [10.17632/49h9dcwx5v.1](https://data.mendeley.com/datasets/49h9dcwx5v/1), CC BY 4.0.
- Case and competition: Shakarim University, [AI-Sana Shakarim Solveathon](https://solveathon.shakarim.edu.kz/).
