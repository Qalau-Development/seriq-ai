# Development Plan

Status: **agreed.** Nothing below is implemented yet unless marked as done.

Deadline: 25 November 2026, 13:30 (Kazakhstan time). Feature freeze: 25 November, 11:00.

Detailed task lists per developer (in Russian): [team/](team/README.md). Shared names and integration order: [team/integration.md](team/integration.md).

## Scope

| In scope | Out of scope for the competition |
|---|---|
| Elbow extension (E02) only | Other three exercises in the dataset |
| One recording = one repetition | Automatic segmentation of long recordings (later step) |
| Responsive web app and Flutter app on one API | Separate desktop app |
| Local session history on the device | Database, accounts, clinician dashboard |
| One VPS with Docker Compose and HTTPS | Separate AI server, real-time video streaming |

## Architecture and stack

See [architecture.md](architecture.md).

| Layer | Technology |
|---|---|
| Web | Next.js, TypeScript, Tailwind CSS, Recharts |
| Mobile | Flutter (Android; iOS if a Mac is available) |
| Backend | Python 3.12, FastAPI |
| AI core | MediaPipe Pose Landmarker (first candidate), OpenCV, NumPy, scikit-learn |
| Deployment | VPS, Docker Compose, Caddy (HTTPS) |

## Roles

| # | GitHub | Area |
|---|---|---|
| 1 | danshikdev | Web, instruction video, presentation |
| 2 | Zenki-Erzat | Flutter, server and deployment, completeness of [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md), run instructions |
| 3 | Yeskendirr | AI core, model training and evaluation, backend, metrics report |

## Stages

| # | Stage | Owner | Status |
|---|---|---|---|
| 1 | Repository setup, documentation | 3 | Done |
| 2 | Dataset metadata analysis | 3 | Done, see [dataset-analysis.md](dataset-analysis.md) |
| 3 | API contract | all | Agreed, see [api.md](api.md) |
| 4 | Mock API | 3 | Planned |
| 5 | Server with domain, HTTPS and mock API | 2 | Planned |
| 6 | Web app on mock API | 1 | Planned |
| 7 | Flutter app on mock API | 2 | Planned |
| 8 | Pose extraction and elbow angle analysis | 3 | Planned |
| 9 | Baseline and main model, cross-validation, test evaluation | 3 | Planned |
| 10 | Real analysis in the backend, server switched to `model` mode | 3, 2 | Planned |
| 11 | End-to-end check, report, presentation | all | Planned |

Third-party components and their licenses: [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

## Open questions

- Is the shoulder visible in the dataset videos? If not, the forearm inclination angle is used instead of the shoulder–elbow–wrist angle.
- How long does one analysis take on the 2 vCPU server?
