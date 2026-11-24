# Privacy and security

This page lists what SerIQ does today and how each point was checked. It is updated when something new is built and checked. It is not a legal document.

Last checked: 24 November 2026.

## What the server does with your data

| Fact | How it was checked |
|---|---|
| The uploaded video is written to a temporary file, analyzed and deleted. The server does not keep it. | Backend tests `test_temp_file_removed` and `test_model_result`: the temporary folder is empty after the request. Code: `backend/app/services/upload.py` (`finally` block). |
| The video is deleted also when the request fails: unsupported format, empty file, file too large, unreadable video, no hand found, server busy. | Same tests, one case per error. |
| The server has no database and stores no analysis results. The result goes back to the device that sent the video. | There is no database in `docker-compose.yml` or in `backend/requirements.txt`. |
| There are no accounts and no login. The request contains only the video and the exercise code; the response contains no personal data. | `docs/api.md`, request and response fields. |
| The session history stays on the user's device (web: browser local storage, mobile: app storage). | Code: `apps/web/lib/history.ts`, `apps/mobile/lib/services/history_storage.dart`. |
| The analysis runs on the SerIQ server itself. The video is not sent to any other service: the backend and the AI engine code import no HTTP client. | Search of `backend/app` and `ai-engine/seriq_engine`. The hand model file is downloaded once when the server image is built, with a checksum (`infrastructure/docker/backend.Dockerfile`). |

## Limits

| Limit | Value | How it was checked |
|---|---|---|
| File size | 100 MB | Test `test_file_too_large` |
| Formats | `.mp4`, `.mov`, `.webm`; the file content is checked, not only the extension | Tests `test_unsupported_extension`, `test_wrong_signature` |
| Duration | 2 to 60 seconds | AI engine tests `test_too_short`, `test_too_long` |
| One analysis at a time | A second request waits in the queue for up to 20 seconds, then gets `503 busy` | Tests `test_busy`, `test_busy_waits_in_queue` |

## Connection

| Fact | How it was checked |
|---|---|
| The site and the API are served over HTTPS with TLS 1.3 and a Let's Encrypt certificate. | `curl -v https://seriq-ai.qalau.com/api/v1/health` on 24 November 2026. |
| Plain HTTP requests are redirected to HTTPS (status 301). | `curl http://seriq-ai.qalau.com/api/v1/health` on 24 November 2026. |
| The backend, the web app and the proxy publish no ports of their own; requests come only through the HTTPS entry point. | `docker-compose.yml` has no `ports` entries. |

## What the results are, and are not

- SerIQ is a demonstration tool, not a medical device. It does not diagnose, prescribe treatment or give corrective medical advice.
- The result contains only a label (complete, incomplete, uncertain), a confidence value and the measured value. See `docs/api.md`.

## Secrets and the repository

- The repository contains no videos, server addresses, passwords or keys. `.env.example` holds only the public domain and non-secret settings. The server `.env` and the access keys are not in the repository.
- Checked on 24 November 2026: the tracked files contain no `.env` file other than `.env.example`, no key files, no IP addresses and no key or password patterns. No `.env` or key file was ever added in the git history.
- The dataset used for training is not in the repository (see `.gitignore`).
