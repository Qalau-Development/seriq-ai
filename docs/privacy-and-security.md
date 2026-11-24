# Privacy and security

This page lists what SerIQ does today and how each point was checked. It is updated when something new is built and checked. It is not a legal document.

Last checked: 25 November 2026.

## What the server does with your data

| Fact | How it was checked |
|---|---|
| The uploaded video is written to a temporary file, analyzed and deleted. The server does not keep it. | Backend tests `test_temp_file_removed` and `test_model_result`: the temporary folder is empty after the request. Code: `backend/app/services/upload.py` (`finally` block). |
| The video is deleted also when the request fails: unsupported format, empty file, file too large, unreadable video, no hand found, server busy. | Same tests, one case per error. |
| The video analysis stores no result. The result goes back to the device that sent the video. The request contains only the video and the exercise code; the response contains no personal data. | Backend tests of `POST /analysis` (nothing is written to the database) and `docs/api.md`, request and response fields. |
| Analysis needs no account and does not depend on the database: it works the same for a guest and when the database is off or unavailable. | Test `test_analysis_does_not_need_database`. |
| A guest (not logged in) keeps the session history only on the device (web: browser local storage, mobile: app storage). | Code: `apps/web/lib/history.ts`, `apps/mobile/lib/services/history_storage.dart`. |
| Accounts and the saved history of logged-in users are described in [Accounts and history](#accounts-and-history). | |
| The analysis runs on the SerIQ server itself. The video is not sent to any other service: the backend and the AI engine code import no HTTP client. | Search of `backend/app` and `ai-engine/seriq_engine`. The hand model file is downloaded once when the server image is built, with a checksum (`infrastructure/docker/backend.Dockerfile`). |

## Accounts and history

Accounts are switched on on the server since 25 November 2026 (`GET /api/v1/health` shows `"database":"ok"`, checked on 25 November 2026 with `curl`). Login is by login name and password only. The password cannot be changed or recovered.

| Fact | How it was checked |
|---|---|
| The password is stored only as an argon2id hash (64 MiB, 3 passes, a random salt inside the hash), never as text, and is not written to the log or returned in any answer. | Tests `test_register` (the stored value starts with `$argon2id$`), `test_real_argon2_parameters`, `test_secrets_not_in_logs`. |
| Refresh tokens are stored only as a SHA-256 hash, so a copy of the database cannot be used to sign in. Access tokens live 15 minutes, refresh tokens 30 days and are replaced on every use; a token that is used again is treated as stolen and the whole chain is revoked. | Tests `test_register`, `test_access_token_lifetime`, `test_refresh_rotation`, `test_refresh_reuse_is_theft`. |
| The answer to a wrong login and to a wrong password is the same, and the server does the same hashing work in both cases, so the time of the answer does not show whether the login exists. | Tests `test_same_answer_for_unknown_login_and_wrong_password`, `test_unknown_login_still_hashes`. |
| Guessing is limited: after 5 failed logins for one login the waiting time grows from 1 up to 15 minutes; one IP address may log in 20 times per 10 minutes and register 5 times per hour. The address is the real address of the client behind the proxies. | Tests `test_login_delay`, `test_login_ip_limit`, `test_register_ip_limit`, `test_client_ip`; the IP limit was also checked on the live server by the team on 25 November 2026, after the proxy (Caddy) was restarted. |
| What is stored for an account: the login name, the password hash, the hashes of refresh tokens, and for each saved attempt the label, confidence, the measured value and its series for the chart, with the dates. **Not stored in the database: the video, frames, hand points (`pose`), e-mail, IP address, device data.** | Tables in `backend/app/db/models.py` and the migrations in `backend/alembic/versions`; test `test_migrations_match_models`. |
| Deleting the account (`DELETE /me`, confirmed with the password) erases the account, its tokens, sessions and attempts at once. Deleting a session or the whole history erases those records at once. Other users' data is not touched. | Tests `test_delete_account`, `test_account_deletion_erases_history`, `test_delete_session_and_reuse_ids`, `test_delete_all_sessions`; the whole scenario (register, sign in, save a session, delete the session and the account) was also run on the live server by the team on 25 November 2026. |
| A user sees only their own sessions and results. | Test `test_users_do_not_see_each_other`. |
| Size limits: the body of account and history requests is at most 1 MiB (sessions 2 MiB) and is rejected before it is read; one account keeps at most 1000 sessions and 10 000 attempts. | Tests in `tests/test_body_limit.py` and `test_quota_*`. |

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
| TLS 1.2 and TLS 1.3 are accepted. (Older versions were not tested.) | `openssl s_client -tls1_2` and `-tls1_3` against the public domain on 25 November 2026. |
| The backend, the web app and the proxy publish no ports of their own; requests come only through the HTTPS entry point. | `docker-compose.yml` has no `ports` entries. |

## Browsers and other sites

| Fact | How it was checked |
|---|---|
| The API sends no CORS headers (`Access-Control-Allow-*`), so a page from another website cannot read its responses in a browser. A cross-origin preflight request (`OPTIONS` with a foreign `Origin`) is answered `405`. | `curl` with `Origin: https://evil.example` against `/api/v1/health` and `/api/v1/analysis` on 25 November 2026. |
| The site pages and the API endpoints that were checked set no cookies (no `Set-Cookie` header). | `curl -D -` on `/`, `/exercise`, `/api/v1/health`, `/api/v1/exercises` on 25 November 2026. |
| The HTML of the five site pages (`/`, `/exercise`, `/history`, `/summary`, `/session`) has no `src`, `href` or `content` link to another host. | `curl` of the pages on 25 November 2026 and a search for `http(s)://` links in the HTML. Scripts loaded by the pages were not inspected. |
| The API documentation at `/api/docs` is public. When a visitor opens it, the browser loads the Swagger UI script from `cdn.jsdelivr.net` and an icon from `fastapi.tiangolo.com`. The video analysis and the site itself do not use that page. | `curl https://<domain>/api/docs` and a search for `http(s)://` links on 25 November 2026. |

## What the results are, and are not

- SerIQ is a demonstration tool, not a medical device. It does not diagnose, prescribe treatment or give corrective medical advice.
- The result contains only a label (complete, incomplete, uncertain), a confidence value and the measured value. See `docs/api.md`.

## Secrets and the repository

- The repository contains no videos, server addresses, passwords or keys. `.env.example` holds only the public domain and non-secret settings. The server `.env` and the access keys are not in the repository.
- Checked on 24 November 2026: the tracked files contain no `.env` file other than `.env.example`, no key files, no IP addresses and no key or password patterns. No `.env` or key file was ever added in the git history.
- The dataset used for training is not in the repository (see `.gitignore`).
