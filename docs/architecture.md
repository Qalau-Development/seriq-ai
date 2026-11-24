# Architecture

Status: **agreed design, not implemented yet.** This document describes the target structure. Folders appear in the repository when their code is written.

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
 │     video → pose estimation → elbow angles          │
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

Target tree:

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
│   │   ├── api/routes/            # health.py, analysis.py
│   │   ├── schemas/               # Pydantic models of the contract
│   │   ├── services/              # mock and real analysis
│   │   └── core/                  # settings
│   ├── tests/
│   └── requirements.txt
├── ai-engine/                     # Developer 3
│   ├── pyproject.toml
│   └── seriq_engine/
│       ├── video.py               # frame reading
│       ├── pose.py                # pose estimation
│       ├── angles.py              # elbow angle series
│       ├── features.py            # features for the classifier
│       ├── classifier.py          # model loading, prediction, confidence
│       └── pipeline.py            # analyze_video(path) -> result
├── ml-training/                   # Developer 3
│   ├── extract_poses.py
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
3. `seriq_engine.pipeline.analyze_video` reads frames, runs pose estimation, computes the elbow angle series and features, and calls the classifier.
4. The backend returns JSON as described in [api.md](api.md) and deletes the temporary file.
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
        "source": "model"
      }
    ]
  }
]
```

The session summary is computed from `attempts`: total, complete, incomplete, uncertain.

## Deployment

Status: **the server, HTTPS and CI/CD are set up.** `https://seriq-ai.qalau.com` serves a placeholder page; `backend` and `web` are not deployed yet.

| Item | Value |
|---|---|
| Server | VPS, 2 vCPU, 4 GB RAM, 40 GB SSD; project directory `/opt/seriq-ai` |
| Edge | **Traefik**, run by Dokploy in Docker (`dokploy-traefik`). Owns ports 80 and 443, obtains Let's Encrypt certificates, redirects HTTP to HTTPS. Shared with other projects on the server: do not change it |
| SerIQ services | Docker Compose project `seriq-ai`. Now: `caddy`. Planned: `backend`, `web` |
| Routing | Traefik → `caddy:80` (by Docker labels, network `dokploy-network`). Caddy → `/api/*` to `backend:8000`, everything else to `web:3000`. Until then Caddy serves `infrastructure/placeholder/` |
| Public ports | None in the SerIQ project; only Traefik is exposed |
| Configuration | `/opt/seriq-ai/.env` on the server only; template `.env.example` |
| CI/CD | GitHub Actions `.github/workflows/ci-cd.yml`: on every push and pull request it validates `docker-compose.yml`, the Caddyfile and `deploy.sh`. On push to `main` it connects over SSH and runs `deploy.sh <commit>`: checks out that commit, runs `docker compose up -d --build`, waits until the site answers through Traefik and rolls back to the previous commit if it does not |
| Upload limit | 100 MB, enforced by Caddy and by the backend |
| Model file | Committed to `models/` (small file), copied into the backend image |
| Dataset | Never on the server |
| Training | Done locally on a developer laptop; the server runs inference only |
| Concurrency | One analysis at a time (`503 busy` otherwise), one backend worker |
| Performance | Analysis time and memory use on this server: **not measured yet** |

HTTPS is required: browsers allow camera access only on secure origins.

Server load:

- Today `deploy.sh` builds images on the server (`--build`). That is fine for Caddy, but building the Next.js app and installing MediaPipe on a 4 GB server is heavy. **Recommended when `backend` and `web` are added:** build images in GitHub Actions, push them to GitHub Container Registry, and only pull them on the server.
- `backend` and `web` join only the project's internal network; only `caddy` joins `dokploy-network`.
- Docker log rotation and a memory limit for `backend`.
- Check Traefik's request read timeout: uploads of large videos over a slow connection must not be cut off.

## Decisions

| Decision | Reason |
|---|---|
| FastAPI for the backend | The AI code is Python; the backend imports it directly. Automatic API docs at `/api/docs` |
| No database | Nothing needs to be stored. Avoids keeping medical data on the server |
| Temporary video only | Privacy; the case requires a local session summary |
| One cycle per recording (MVP) | Training data contain one cycle per video; segmentation is a later step |
| Classical ML before neural networks | 107 training videos from 5 people |
| Flutter in addition to responsive web | Team decision; web stays the main demo |
