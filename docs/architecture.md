# Architecture

Status: **implemented.** This document describes the structure of the system and of the repository.

## Overview

```text
 ┌──────────────────────┐     ┌──────────────────────┐
 │  Web app             │     │  Mobile app          │
 │  Next.js, responsive │     │  Flutter (Android,   │
 │  apps/web            │     │  iOS) apps/mobile    │
 └──────────┬───────────┘     └──────────┬───────────┘
            │      HTTPS, REST API /api/v1           │
            └──────────────┬─────────────────────────┘
                           ▼
 ┌─────────────────────────────────────────────────────┐
 │  VPS                                                │
 │                                                     │
 │  Traefik (Dokploy) ── 80/443, HTTPS, Let's Encrypt  │
 │     │  network dokploy-network                      │
 │     ▼                                               │
 │  ── project seriq-ai (Docker Compose) ───────────── │
 │  caddy :80 (no public ports) ─┬─ /api/* → backend   │
 │                               └─ /*     → web       │
 │                                                     │
 │  backend (FastAPI) ── imports ── ai-engine          │
 │     video → hand landmarks → elbow angles           │
 │     → features → classifier (models/)               │
 └─────────────────────────────────────────────────────┘

 Developer laptop (not deployed):
   ml-training → trains the classifier on the dataset → models/
```

Principles:

1. **One AI core, one API.** Web and mobile contain no AI code. Both call the same API.
2. **Same feature code for training and inference.** `ml-training` imports feature extraction from `ai-engine`. The code is never duplicated, so the model behaves in the app exactly as in the evaluation report.
3. **No database.** The server stores nothing: the video is temporary, results go back to the client, history stays on the device.
4. **One recording = one repetition** in the MVP. The training data contain one cycle per video.

## Repository map

| Path | Owner | Contents |
|---|---|---|
| `apps/web/` | Developer 1 | Next.js web application |
| `apps/mobile/` | Developer 2 | Flutter application |
| `backend/` | Developer 3 | FastAPI application: routes, schemas, validation |
| `ai-engine/` | Developer 3 | Python package `seriq_engine`: video, pose, angles, features, classifier |
| `ml-training/` | Developer 3 | Scripts for pose extraction, training and evaluation |
| `models/` | Developer 3 | Trained classifier file and its description |
| `infrastructure/` | Developer 2 | Dockerfiles, Caddy configuration, deploy script, placeholder page |
| `docker-compose.yml` | Developer 2 | Services on the VPS |
| `.env.example` | Developer 2 | Configuration template without secrets |
| `.github/workflows/` | Developer 2 | CI/CD |
| `docs/` | All | Documentation |
| `data/` | Developer 3 | Local dataset; only `README.md` is committed |

Tree:

```text
seriq-ai/
├── apps/
│   ├── web/                       # Developer 1
│   │   ├── app/                   # pages (App Router)
│   │   ├── components/
│   │   ├── lib/                   # api client, i18n, local history
│   │   ├── types/                 # TypeScript types of the API contract
│   │   └── public/media/          # instruction video
│   └── mobile/                    # Developer 2
│       └── lib/
│           ├── core/              # config, strings
│           ├── models/            # Dart classes of the API contract
│           ├── services/          # API client, local history
│           ├── features/          # screens
│           └── widgets/
├── backend/                       # Developer 3
│   ├── app/
│   │   ├── main.py
│   │   ├── api/routes/            # health.py, analysis.py, exercises.py
│   │   ├── schemas/               # Pydantic models of the contract
│   │   ├── services/              # mock analysis, real analysis, adapter to the AI engine (engine.py)
│   │   └── core/                  # settings, exercise reference (exercises.py)
│   ├── tests/
│   └── requirements.txt
├── ai-engine/                     # Developer 3
│   ├── pyproject.toml
│   └── seriq_engine/
│       ├── video.py               # frame reading
│       ├── hand.py                # MediaPipe hand landmarks (wrist)
│       ├── angles.py              # elbow position from the wrist trajectory, elbow angle series
│       ├── features.py            # features for the classifier
│       ├── classifier.py          # model loading, prediction, confidence
│       └── pipeline.py            # analyze_video(path) -> result
├── ml-training/                   # Developer 3
│   ├── extract_poses.py           # hand landmarks of all videos → data/processed/poses/
│   ├── explore.py                 # angle curves, quality check of the elbow position
│   ├── recon.py                   # signal check for E01, E03, E04 on the training videos
│   ├── train.py
│   └── evaluate.py
├── models/                        # Developer 3
├── infrastructure/                # Developer 2
│   ├── docker/
│   │   ├── backend.Dockerfile
│   │   └── web.Dockerfile
│   ├── caddy/Caddyfile
│   ├── placeholder/               # page shown until the web app is deployed
│   └── scripts/deploy.sh
├── .github/workflows/ci-cd.yml    # Developer 2
├── data/                          # local only
├── docs/
├── docker-compose.yml
├── .env.example
├── README.md
└── README.ru.md
```

`ai-engine` is a folder name; the importable Python package inside it is `seriq_engine`, because Python package names cannot contain hyphens.

## Analysis flow

1. The client records or selects a video and sends it to `POST /api/v1/analysis`.
2. The backend validates the file and saves it to a temporary file.
3. The backend passes the video and the exercise code to the AI engine through an adapter (`backend/app/services/engine.py`): `seriq_engine.exercises` if the engine has it, otherwise `seriq_engine.pipeline` for E02. For E02 `seriq_engine.pipeline.analyze_video` reads frames, detects hand landmarks, estimates the elbow position from the wrist trajectory, computes the elbow angle series and features, and calls the classifier.
4. The backend returns JSON as described in [api.md](api.md), with the measured value of the exercise in `measure`, and deletes the temporary file. `GET /api/v1/exercises` tells the clients which exercises are ready.
5. The client shows the result and adds it to the local session.

The backend runs one analysis at a time; a second request while one is running gets `503 busy`. This protects the 4 GB VPS from running out of memory.

## Local session model

Both clients store sessions in the same shape, on the device only (web: `localStorage`, mobile: `shared_preferences`), under the key `seriq.sessions.v1`:

```json
[
  {
    "id": "local-uuid",
    "exercise": "E02",
    "started_at": "2026-11-24T15:02:11Z",
    "attempts": [
      {
        "analysis_id": "3f2b9c1e-...",
        "at": "2026-11-24T15:03:40Z",
        "verdict": "completed",
        "label": "complete",
        "confidence": 0.87,
        "source": "model",
        "measure": {
          "name": "elbow_angle",
          "unit": "deg",
          "value": 167.5,
          "series": { "fps": 10, "values": [62.0, 63.5, null, 167.5] }
        }
      }
    ]
  }
]
```

`exercise` is one of `E01`–`E04`. The optional `measure` field of an attempt repeats the `measure` of the analysis response (series rounded to tenths); attempts saved without it, like all older E02 records, are read as before. The session summary is computed from `attempts`: total, complete, incomplete, uncertain.

## Deployment

Status: **the server, HTTPS and CI/CD are set up.** `https://seriq-ai.qalau.com` serves a placeholder page until `web` appears; `backend` and `web` are deployed automatically as soon as their code is in `main`.

| Item | Value |
|---|---|
| Server | VPS, 2 vCPU, 4 GB RAM, 40 GB SSD; project directory `/opt/seriq-ai` |
| Edge | **Traefik**, run by Dokploy in Docker (`dokploy-traefik`). Owns ports 80 and 443, obtains Let's Encrypt certificates, redirects HTTP to HTTPS. Shared with other projects on the server: do not change it. One deliberate change: `readTimeout: 300s` on the `websecure` entry point (default 60 s cut off video uploads), see below |
| SerIQ services | Docker Compose project `seriq-ai`: `caddy`, `backend`, `web`. `deploy.sh` starts `backend` when `backend/requirements.txt` exists and `web` when `apps/web/package.json` exists |
| Routing | Traefik → `caddy:80` (by Docker labels, network `dokploy-network`). Caddy → `/api/*` to `backend:8000`, everything else to `web:3000`. While `web` is missing or down, Caddy serves `infrastructure/placeholder/` |
| Public ports | None in the SerIQ project; only Traefik is exposed |
| Configuration | `/opt/seriq-ai/.env` on the server only; template `.env.example` |
| CI/CD | GitHub Actions `.github/workflows/ci-cd.yml`: on every push it validates `docker-compose.yml`, the Caddyfile and `deploy.sh`, runs the backend and engine tests, lints and builds the web app, runs `flutter analyze`, and starts the whole stack to check that the site and `/api/v1/health` answer through Caddy. Zones without code are skipped. On push to `main`, after all checks pass, it connects over SSH and runs `deploy.sh <commit>`: checks out that commit, builds the services one by one, starts them with `docker compose up -d --wait` (healthchecks), checks the site and the API through Traefik and rolls back to the previous commit if anything fails. After the deploy the workflow checks the public URL once more |
| Upload limit | 100 MB, enforced by Caddy and by the backend |
| Model file | Committed to `models/` (small file), copied into the backend image |
| Hand landmark weights | MediaPipe `hand_landmarker.task`, version 1. Not in the repository: downloaded while building the backend image and checked by SHA-256 (the build fails on a mismatch). Path in the image: `/srv/models/hand_landmarker.task` (`SERIQ_HAND_MODEL_PATH`) |
| Dataset | Never on the server |
| Training | Done locally on a developer laptop; the server runs inference only |
| Concurrency | One analysis at a time (`503 busy` otherwise), one backend worker |
| Performance | Analysis time and memory use on this server: **not measured yet** |

HTTPS is required: browsers allow camera access only on secure origins.

Server load:

- Today `deploy.sh` builds images on the server (`--build`). That is fine for Caddy, but building the Next.js app and installing MediaPipe on a 4 GB server is heavy. **Recommended when `backend` and `web` are added:** build images in GitHub Actions, push them to GitHub Container Registry, and only pull them on the server.
- `backend` and `web` join only the project's internal network; only `caddy` joins `dokploy-network`.
- Docker log rotation and a memory limit for `backend`.
- Traefik's request read timeout was 60 s by default and cut off video uploads on slow connections (measured: about 0.5 MB/s upload gave `502` at exactly 60 s). It is raised to 300 s in `/etc/dokploy/traefik/traefik.yml`, `entryPoints.websecure.transport.respondingTimeouts.readTimeout`. The previous file is kept as `traefik.yml.bak-20261124-readtimeout`. Dokploy can overwrite this file when it updates Traefik: after any Dokploy or Traefik update check that the line is still there.
- The model file `models/e02_classifier.joblib` is excluded from `.gitignore` on purpose so it cannot be forgotten. The scikit-learn version must be the same in `backend/requirements.txt` (the Docker image) and in the environment where the model is trained.

## Decisions

| Decision | Reason |
|---|---|
| FastAPI for the backend | The AI code is Python; the backend imports it directly. Automatic API docs at `/api/docs` |
| No database | Nothing needs to be stored. Avoids keeping medical data on the server |
| Temporary video only | Privacy; the case requires a local session summary |
| One cycle per recording (MVP) | Training data contain one cycle per video; segmentation is a later step |
| Classical ML before neural networks | 107 training videos from 5 people |
| Flutter in addition to responsive web | Team decision: one codebase for Android and iOS; web stays the main demo |
