# Third-Party Notices

SerIQ is built with open-source libraries, a pretrained pose estimation model and a public dataset. This document lists every third-party component, its license and what it is used for, and separates it from the team's own work.

Status: **no application code exists yet.** Server infrastructure (Traefik, Caddy, Docker, GitHub Actions) is *in use*; all other components are *planned*. A row moves to *in use* when the component is added to the code.

Licenses were checked on 2026-11-24 in the official registries: PyPI, npm, pub.dev, GitHub and Hugging Face. `To verify` means the license has not been confirmed from an official source yet.

## Rules for the team

Any open-source library, tool, algorithm, pretrained model or dataset may be used if its license allows it. Open projects may also be used as a source of technical ideas.

When adding a third-party component, in the same pull request:

1. Add a row to the right table below: name, official source link, license, what it is used for in SerIQ, and whether it was modified.
2. Check the license of **model weights and datasets separately** from the license of the code that loads them.
3. Be careful with copyleft licenses (GPL, AGPL): they can impose obligations on the whole project or on a network service. Discuss with the team before adding one.
4. If code or an idea is adapted from an open project, add it to [Adapted code and ideas](#adapted-code-and-ideas) with a link.
5. Never present third-party code or models as the team's own work.

## Dataset

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| An upper limb stroke rehabilitation exercise video dataset (B. Nair, S. Nandana, M. T. Dharshini, V. Viswanathan, 2026) | [Mendeley Data, DOI 10.17632/49h9dcwx5v.1](https://data.mendeley.com/datasets/49h9dcwx5v/1); distributed to teams by the Solveathon organizers | CC BY 4.0 | Training and evaluation of the E02 classifier. Only the E02 subset (127 videos) is used | Not redistributed. Not stored in this repository |

## Pretrained models

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| MediaPipe Pose Landmarker model bundle (lite / full / heavy; variant to be chosen) | [MediaPipe Pose Landmarker](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker), model cards on [Hugging Face](https://huggingface.co/litert-community/MediaPipe-PoseLandmarker-Full) | Apache-2.0 (Hugging Face model card metadata) | Detection of shoulder, elbow and wrist keypoints on video frames (planned) | None; used as is |

## Libraries — AI core and backend (Python)

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| MediaPipe | [github.com/google-ai-edge/mediapipe](https://github.com/google-ai-edge/mediapipe) | Apache-2.0 | Running the pose estimation model (planned) | None |
| OpenCV (`opencv-python`) | [github.com/opencv/opencv](https://github.com/opencv/opencv) | Apache-2.0 | Reading video frames (planned) | None |
| NumPy | [numpy.org](https://numpy.org/) | BSD-3-Clause AND 0BSD AND MIT AND Zlib AND CC0-1.0 (as declared on PyPI) | Angle and feature computations (planned) | None |
| scikit-learn | [scikit-learn.org](https://scikit-learn.org/) | BSD-3-Clause | Classifiers, cross-validation, metrics (planned) | None |
| joblib | [joblib.readthedocs.io](https://joblib.readthedocs.io/) | BSD-3-Clause | Saving and loading the trained model (planned) | None |
| FastAPI | [fastapi.tiangolo.com](https://fastapi.tiangolo.com/) | MIT | Backend API (in use) | None |
| Pydantic | [docs.pydantic.dev](https://docs.pydantic.dev/) | MIT | API request and response schemas (in use) | None |
| Uvicorn | [uvicorn.dev](https://uvicorn.dev/) | BSD-3-Clause | ASGI server for the backend (in use) | None |
| python-multipart | [github.com/Kludex/python-multipart](https://github.com/Kludex/python-multipart) | Apache-2.0 | Parsing video uploads (in use) | None |
| pytest | [pytest.org](https://pytest.org/) | MIT | Backend tests, development only (in use) | None |
| HTTPX | [python-httpx.org](https://www.python-httpx.org/) | BSD-3-Clause | HTTP client behind FastAPI `TestClient` in backend tests, development only (in use) | None |

## Libraries — web app

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| Next.js | [nextjs.org](https://nextjs.org/) | MIT | Web application framework (planned) | None |
| React | [react.dev](https://react.dev/) | MIT | UI components (planned) | None |
| Tailwind CSS | [tailwindcss.com](https://tailwindcss.com/) | MIT | Styling (planned) | None |
| Recharts | [recharts.org](https://recharts.org/) | MIT | Elbow angle chart (planned) | None |
| Lucide React | [lucide.dev](https://lucide.dev/) | ISC | Icons (planned) | None |

## Libraries — mobile app

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| Flutter | [github.com/flutter/flutter](https://github.com/flutter/flutter) | BSD-3-Clause | Mobile application framework (in use) | None |
| material_ui | [pub.dev/packages/material_ui](https://pub.dev/packages/material_ui) | BSD-3-Clause | Material widgets, added by the `flutter create` template (in use) | None |
| http | [pub.dev/packages/http](https://pub.dev/packages/http) | BSD-3-Clause | Uploading video to the API (in use) | None |
| image_picker | [pub.dev/packages/image_picker](https://pub.dev/packages/image_picker) | BSD-3-Clause; the package's LICENSE also includes the aFileChooser component under Apache-2.0 | Recording video with the system camera, picking from gallery (in use) | None |
| shared_preferences | [pub.dev/packages/shared_preferences](https://pub.dev/packages/shared_preferences) | BSD-3-Clause | Local session history (in use) | None |
| fl_chart | [pub.dev/packages/fl_chart](https://pub.dev/packages/fl_chart) | MIT | Elbow angle chart (in use) | None |
| video_player | [pub.dev/packages/video_player](https://pub.dev/packages/video_player) | BSD-3-Clause | Instruction video (in use) | None |
| uuid | [pub.dev/packages/uuid](https://pub.dev/packages/uuid) | MIT | Local session IDs (in use) | None |
| intl | [pub.dev/packages/intl](https://pub.dev/packages/intl) | BSD-3-Clause | Date formatting (in use) | None |

## Infrastructure and runtimes

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| Traefik | [github.com/traefik/traefik](https://github.com/traefik/traefik) | MIT | Edge proxy on the server: ports 80/443, HTTPS certificates (in use, shared with other projects on the server) | None; SerIQ only adds Docker labels |
| Dokploy | [github.com/Dokploy/dokploy](https://github.com/Dokploy/dokploy) | **To verify** | Runs Traefik on the server (in use) | None |
| Caddy | [github.com/caddyserver/caddy](https://github.com/caddyserver/caddy) | Apache-2.0 | Internal routing of `/api/*` and `/*` behind Traefik; placeholder page (in use) | Configuration only |
| Docker Engine / Docker Compose | [github.com/moby/moby](https://github.com/moby/moby), [github.com/docker/compose](https://github.com/docker/compose) | Apache-2.0 | Running the services on the server (in use) | Configuration only |
| GitHub Actions | [github.com/features/actions](https://github.com/features/actions) | Service, not a library | CI/CD: configuration checks and deployment (in use) | Workflow configuration only |
| Python (`python:3.12-slim` image) | [python.org](https://www.python.org/) | Python Software Foundation License — **To verify** | Backend runtime (planned) | None |
| Node.js (`node:22-alpine` image) | [nodejs.org](https://nodejs.org/) | **To verify** | Web app runtime (planned) | None |

Base container images also contain operating system packages under their own licenses (**To verify** if the images are redistributed).

## Adapted code and ideas

None yet. Add code snippets, algorithms or approaches taken from open projects, papers or articles here, with a link.

## AI assistants used in development

These tools helped the team write code and documentation. They are not part of the product.

| Tool | Provider | Used for |
|---|---|---|
| Claude Code | Anthropic | Repository setup, dataset inspection scripts, documentation drafts |
| ChatGPT | OpenAI | Initial analysis of the case, planning |

Each developer adds the tools they used. All AI-assisted output is reviewed by the team.

## The team's own work

Built by the team on top of the components above (all planned, nothing implemented yet):

- Elbow angle and motion analysis for the E02 exercise: arm selection, angle series, smoothing, handling of missing frames
- Features describing one exercise cycle
- Training and selection of the classifier, subject-wise cross-validation, choice of the `uncertain` threshold, evaluation report
- API contract, backend logic, upload validation
- Web and mobile interfaces, local session history, Kazakh and Russian texts
- Deployment configuration
- Instruction video for the exercise
