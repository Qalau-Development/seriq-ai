# Third-Party Notices

SerIQ is built with open-source libraries, a pretrained hand landmark model and a public dataset. This document lists every third-party component, its license and what it is used for, and separates it from the team's own work.

Status: every component in the tables below is *in use* in the code, the CI or on the server. A new component gets a row in the same pull request that adds it.

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
| MediaPipe Hand Landmarker model bundle (`hand_landmarker.task`, float16, version 1) | [MediaPipe Hand Landmarker](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker), model card on [Hugging Face](https://huggingface.co/litert-community/MediaPipe-HandLandmarker-Full) (includes the PDF *Model Card Hand Tracking (Lite_Full) with Fairness Oct 2021*) | Apache-2.0 (Hugging Face model card metadata) | Hand and wrist keypoints on video frames; the elbow and the forearm angle are derived from the wrist trajectory (in use) | None; downloaded at image build time from the pinned version-1 URL and verified by SHA-256 |
| MediaPipe Pose Landmarker model bundle (`pose_landmarker_full.task`, float16, version 1) | [MediaPipe Pose Landmarker](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker) | To verify (model card) | Live mode for E02, "without a table": shoulder, elbow and wrist in the browser, so the elbow angle is measured at the real elbow; only for prompts on the screen, the verdict still comes from the server (in use) | None; loaded by the browser from the pinned version-1 URL |

## Libraries — AI core and backend (Python)

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| MediaPipe | [github.com/google-ai-edge/mediapipe](https://github.com/google-ai-edge/mediapipe) | Apache-2.0 | Running the hand landmark model (in use) | None |
| OpenCV (`opencv-contrib-python`, required by MediaPipe) | [github.com/opencv/opencv](https://github.com/opencv/opencv) | Apache-2.0 | Reading and resizing video frames (in use) | None |
| NumPy | [numpy.org](https://numpy.org/) | BSD-3-Clause AND 0BSD AND MIT AND Zlib AND CC0-1.0 (as declared on PyPI) | Angle and feature computations (in use) | None |
| SciPy | [github.com/scipy/scipy](https://github.com/scipy/scipy) | BSD-3-Clause (LICENSE.txt in the repository) | Fitting the elbow position to the wrist trajectory (`scipy.optimize.least_squares`) (in use) | None |
| scikit-learn | [scikit-learn.org](https://scikit-learn.org/) | BSD-3-Clause | Classifier, calibration, cross-validation, metrics (in use) | None |
| joblib | [joblib.readthedocs.io](https://joblib.readthedocs.io/) | BSD-3-Clause | Saving and loading the trained model (in use) | None |
| Matplotlib | [matplotlib.org](https://matplotlib.org/) | Matplotlib License, PSF-based (as declared on PyPI) | Elbow angle plots for the data analysis and the report, training scripts only (in use) | None |
| FastAPI | [fastapi.tiangolo.com](https://fastapi.tiangolo.com/) | MIT | Backend API (in use) | None |
| Pydantic | [docs.pydantic.dev](https://docs.pydantic.dev/) | MIT | API request and response schemas (in use) | None |
| Uvicorn | [uvicorn.dev](https://uvicorn.dev/) | BSD-3-Clause | ASGI server for the backend (in use) | None |
| python-multipart | [github.com/Kludex/python-multipart](https://github.com/Kludex/python-multipart) | Apache-2.0 | Parsing video uploads (in use) | None |
| SQLAlchemy | [sqlalchemy.org](https://www.sqlalchemy.org/) | MIT | Database access for accounts and saved sessions (in use when the database is on) | None |
| Alembic | [alembic.sqlalchemy.org](https://alembic.sqlalchemy.org/) | MIT | Database migrations (in use when the database is on) | None |
| argon2-cffi | [github.com/hynek/argon2-cffi](https://github.com/hynek/argon2-cffi) | MIT | Password hashing with argon2id (in use when the database is on) | None |
| PyJWT | [github.com/jpadilla/pyjwt](https://github.com/jpadilla/pyjwt) | MIT | Signed access tokens (in use when the database is on) | None |
| pytest | [pytest.org](https://pytest.org/) | MIT | Backend tests, development only (in use) | None |
| HTTPX | [python-httpx.org](https://www.python-httpx.org/) | BSD-3-Clause | HTTP client behind FastAPI `TestClient` in backend tests, development only (in use) | None |

## Libraries — web app

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| Next.js | [nextjs.org](https://nextjs.org/) | MIT | Web application framework (in use) | None |
| React | [react.dev](https://react.dev/) | MIT | UI components (in use) | None |
| Tailwind CSS | [tailwindcss.com](https://tailwindcss.com/) | MIT | Styling (in use) | None |
| Recharts | [recharts.org](https://recharts.org/) | MIT | Elbow angle chart (in use) | None |
| Lucide React | [lucide.dev](https://lucide.dev/) | ISC | Icons (in use) | None |
| MediaPipe Tasks Vision (`@mediapipe/tasks-vision` 1.2.3, npm) | [npmjs.com/package/@mediapipe/tasks-vision](https://www.npmjs.com/package/@mediapipe/tasks-vision) | Apache-2.0 (npm registry) | Live mode for E02: runs the same Hand Landmarker model (`hand_landmarker.task`, float16, version 1) in the browser, so the video is not sent anywhere until the repetition is finished; the WASM files are loaded from jsDelivr and the model from the MediaPipe storage at pinned versions (in use) | None |
| Vitest | [vitest.dev](https://vitest.dev/) | MIT | Unit tests of the web app, dev dependency only (in use) | None |

## Libraries — mobile app

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| Flutter | [github.com/flutter/flutter](https://github.com/flutter/flutter) | BSD-3-Clause | Mobile application framework (in use) | None |
| material_ui | [pub.dev/packages/material_ui](https://pub.dev/packages/material_ui) | BSD-3-Clause | Material widgets, added by the `flutter create` template (in use) | None |
| http | [pub.dev/packages/http](https://pub.dev/packages/http) | BSD-3-Clause | Uploading video to the API (in use) | None |
| image_picker | [pub.dev/packages/image_picker](https://pub.dev/packages/image_picker) | BSD-3-Clause; the package's LICENSE also includes the aFileChooser component under Apache-2.0 | Recording video with the system camera, picking from gallery (in use) | None |
| shared_preferences | [pub.dev/packages/shared_preferences](https://pub.dev/packages/shared_preferences) | BSD-3-Clause | Local session history (in use) | None |
| fl_chart | [pub.dev/packages/fl_chart](https://pub.dev/packages/fl_chart) | MIT | Elbow angle chart (in use) | None |
| video_player | [pub.dev/packages/video_player](https://pub.dev/packages/video_player) | BSD-3-Clause | Instruction video; playback of the user's recording under the arm line on the result screen (in use) | None |
| uuid | [pub.dev/packages/uuid](https://pub.dev/packages/uuid) | MIT | Local session IDs (in use) | None |
| intl | [pub.dev/packages/intl](https://pub.dev/packages/intl) | BSD-3-Clause | Date formatting (in use) | None |
| flutter_lints | [pub.dev/packages/flutter_lints](https://pub.dev/packages/flutter_lints) | BSD-3-Clause | Lint rules for `flutter analyze`; development only, not shipped in the app (in use) | None |

## Infrastructure and runtimes

| Component | Source | License | Usage in SerIQ | Modifications |
|---|---|---|---|---|
| Traefik | [github.com/traefik/traefik](https://github.com/traefik/traefik) | MIT | Edge proxy on the server: ports 80/443, HTTPS certificates (in use, shared with other projects on the server) | None; SerIQ only adds Docker labels |
| Dokploy | [github.com/Dokploy/dokploy](https://github.com/Dokploy/dokploy) | Apache-2.0 (content under a `/proprietary` directory, if present, is under a separate license; SerIQ does not use it) | Runs Traefik on the server (in use) | None |
| Caddy | [github.com/caddyserver/caddy](https://github.com/caddyserver/caddy) | Apache-2.0 | Internal routing of `/api/*` and `/*` behind Traefik; placeholder page (in use) | Configuration only |
| Docker Engine / Docker Compose | [github.com/moby/moby](https://github.com/moby/moby), [github.com/docker/compose](https://github.com/docker/compose) | Apache-2.0 | Running the services on the server (in use) | Configuration only |
| GitHub Actions | [github.com/features/actions](https://github.com/features/actions) | Service, not a library | CI/CD: configuration checks and deployment (in use) | Workflow configuration only |
| actions/checkout | [github.com/actions/checkout](https://github.com/actions/checkout) | MIT | Checking out the repository in CI workflows (in use) | None |
| subosito/flutter-action | [github.com/subosito/flutter-action](https://github.com/subosito/flutter-action) | MIT | Installing Flutter in CI: analysis, tests, APK and iOS builds (in use) | None |
| actions/setup-java | [github.com/actions/setup-java](https://github.com/actions/setup-java) | MIT | Installing the JDK for the Android build in CI (in use) | None |
| actions/upload-artifact | [github.com/actions/upload-artifact](https://github.com/actions/upload-artifact) | MIT | Publishing the built APK as a CI artifact (in use) | None |
| OpenJDK (Eclipse Temurin in CI) | [adoptium.net](https://adoptium.net/), [openjdk.org](https://openjdk.org/) | GPL-2.0 with Classpath Exception | Build tool for the Android app (Gradle); not shipped inside the app (in use) | None |
| Python (`python:3.12-slim` image) | [python.org](https://www.python.org/), [github.com/python/cpython](https://github.com/python/cpython) | Python Software Foundation License Version 2 | Backend runtime (in use) | None |
| Node.js (`node:22-alpine` image) | [nodejs.org](https://nodejs.org/), [github.com/nodejs/node](https://github.com/nodejs/node) | MIT (bundled dependencies under their own licenses) | Web app runtime (in use) | None |

Base container images also contain operating system packages (Debian in `python:3.12-slim`, Alpine in `node:22-alpine`) under their own licenses. SerIQ images are built and run only on the project server and are not published to a registry, so they are not redistributed.

## Adapted code and ideas

Add code snippets, algorithms or approaches taken from open projects, papers or articles here, with a link.

| Idea | Source | Where in SerIQ | Changes |
|---|---|---|---|
| 1€ (One Euro) filter for smoothing noisy points in real time | G. Casiez, N. Roussel, D. Vogel, *1€ Filter: A Simple Speed-based Low-pass Filter for Noisy Input in Interactive Systems*, CHI 2012, [gery.casiez.net/1euro](https://gery.casiez.net/1euro/) | `apps/web/lib/liveCoach.ts` (`OneEuro`), smoothing of hand points in the E02 live mode | Own implementation from the paper's formulas; no code copied |

## AI assistants used in development

These tools helped the team write code and documentation. They are not part of the product.

| Tool | Provider | Used for |
|---|---|---|
| Claude Code | Anthropic | Repository setup, dataset inspection scripts, documentation drafts |
| ChatGPT | OpenAI | Initial analysis of the case, planning |
| Claude Code (developer 3, AI / ML / backend) | Anthropic | Writing and testing the backend, the AI core (`seriq_engine`), the training and evaluation scripts; drafts of `docs/model-evaluation.md`, `models/README.md`, `ml-training/README.md` and the defense notes; checks on the server. Method choices were discussed and approved by the developer; all metrics come from running the scripts on the data, not from generated text |
| Claude Code (developer 1, web) | Anthropic | Writing and testing the web app in `apps/web` (pages, API client, camera recording, angle chart, local history, i18n), browser checks with Playwright on test clips and the live API, drafts of PR descriptions. The Kazakh texts in `apps/web/lib/i18n/kk.ts` are a machine-assisted draft that must be checked by a native speaker. Design and wording decisions were made and approved by the developer |
| Claude Code (developer 2, mobile + DevOps) | Anthropic | Writing and testing the Flutter app in `apps/mobile` (screens, API client, local history, i18n, result screen, arm line over the video), the GitHub Actions workflow `mobile.yml`, checks on an Android phone over USB and on the live API, the run instructions in `README.md` / `README.ru.md`, license checks for this file, drafts of PR descriptions. The Kazakh texts in `apps/mobile/lib/core/strings.dart` follow the web texts and are a machine-assisted draft that must be checked by a native speaker. Tasks and decisions were set and approved by the team lead and the developer |

Each developer adds the tools they used. All AI-assisted output is reviewed by the team.

## The team's own work

Built by the team on top of the components above:

- Elbow angle and motion analysis for the E02 exercise: elbow position from the wrist trajectory (circle with a forearm length tied to hand size), angle series, smoothing, handling of missing frames
- Features describing one exercise cycle
- Training and selection of the classifier, subject-wise cross-validation, choice of the `uncertain` threshold, evaluation report
- API contract, backend logic, upload validation
- Web and mobile interfaces, local session history, Kazakh and Russian texts
- Deployment configuration
- Instruction video for the exercise
