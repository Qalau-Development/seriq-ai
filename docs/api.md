# API Contract

Status: **implemented.** This contract is shared by the web app (`apps/web`), the mobile app (`apps/mobile`) and the backend (`backend`). Changing it requires agreement of all three developers.

Base URL:

| Environment | Base URL |
|---|---|
| Production | `https://seriq-ai.qalau.com/api/v1` |
| Local backend | `http://localhost:8000/api/v1` |

Interactive documentation is served by FastAPI at `/api/docs` (OpenAPI schema at `/api/openapi.json`), so that it is reachable through the same `/api/*` route in production.

## Modes

The backend runs in one of two modes, set by the environment variable `SERIQ_MODE`:

| Mode | Meaning |
|---|---|
| `mock` | Returns fixed test responses in the format below. **Not model output.** Used until the model is ready. |
| `model` | Runs the real analysis pipeline: pose estimation and the trained classifier. |

Every analysis response contains `"source": "mock"` or `"source": "model"`, so clients and the jury can always tell test data from real results.

## GET /api/v1/health

Checks that the backend is running.

```json
{ "status": "ok", "mode": "mock", "version": "0.1.0" }
```

## POST /api/v1/analysis

Analyzes one recording of one exercise. Today only the elbow extension (E02) has a trained model; E01, E03 and E04 are described in [Several exercises](#several-exercises).

**MVP rule: one recording = one repetition (one cycle).** The training data contain exactly one cycle per video. A session summary is built on the client from several analyses. The response still uses a `cycles` array, so that automatic cycle segmentation can be added later without changing clients.

### Request

`Content-Type: multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `video` | file | yes | `.mp4`, `.mov` or `.webm` |
| `exercise` | string | no | `E01`–`E04`. Default `E02`. In `model` mode an exercise without a ready model gives `400 unsupported_exercise` (see [Several exercises](#several-exercises)) |

Limits:

| Limit | Value |
|---|---|
| File size | up to 100 MB |
| Duration | 2 to 60 seconds |

The server checks the file extension and the file content, not only the MIME type sent by the client.

Mock mode only: the query parameter `mock_scenario` selects the test response. Values: `complete` (default), `incomplete`, `uncertain`, `no_pose`. Example: `POST /api/v1/analysis?mock_scenario=uncertain`. Ignored in `model` mode.

### Response 200

```json
{
  "status": "ok",
  "analysis_id": "3f2b9c1e-6a51-4c0e-9a57-1f6f0f2d8b11",
  "source": "mock",
  "model_version": "mock",
  "exercise": "E02",
  "verdict": "completed",
  "summary": { "total": 1, "complete": 1, "incomplete": 0, "uncertain": 0 },
  "cycles": [
    {
      "index": 1,
      "start_s": 0.4,
      "end_s": 9.8,
      "label": "complete",
      "confidence": 0.87,
      "verdict": "completed"
    }
  ],
  "angle_series": {
    "fps": 10,
    "unit": "deg",
    "values": [62.5, 70.1, 85.3, null, 120.4, 151.0, 166.2]
  },
  "warnings": [],
  "processing_ms": 4210
}
```

The numbers above are an example of the format, not model results.

### Fields

| Field | Type | Description |
|---|---|---|
| `status` | `"ok"` | Successful analysis |
| `analysis_id` | string (UUID) | Unique ID of this analysis |
| `source` | `"mock"` / `"model"` | Where the result comes from |
| `model_version` | string | Version of the classifier, `"mock"` in mock mode |
| `exercise` | string | The exercise that was analyzed, as sent in the request (`"E02"` by default) |
| `verdict` | `"completed"` / `"check_instructions"` | What the user is told. See rules below |
| `summary` | object | Counts of cycles by label in this recording |
| `cycles[]` | array | One element per detected cycle; in the MVP exactly one |
| `cycles[].index` | integer | Cycle number, starting from 1 |
| `cycles[].start_s`, `end_s` | number | Cycle start and end in seconds from the start of the video |
| `cycles[].label` | `"complete"` / `"incomplete"` / `"uncertain"` | Model decision for this cycle |
| `cycles[].confidence` | number 0–1 | Confidence of the decision |
| `cycles[].verdict` | `"completed"` / `"check_instructions"` | What the user is told for this cycle |
| `angle_series` | object | Elbow angle over time, for the chart. Meaningful for `E02` only; kept for older clients. Other exercises: see `measure` |
| `angle_series.fps` | number | Samples per second in `values` |
| `angle_series.unit` | `"deg"` | Degrees; 180 means a fully straight arm |
| `angle_series.values` | array of number or `null` | `null` = arm not detected in that frame |
| `warnings` | array of string | Non-fatal problems, see the table below |
| `processing_ms` | integer | Server processing time |
| `measure` | object, **optional** | What is measured and shown to the user, with the series for the chart. See [measure](#measure-optional). Always present for `E01`, `E03`, `E04`; for `E02` it repeats `angle_series` |
| `pose` | object, **optional** | Hand points and the elbow for drawing the arm line over the video. See [pose](#pose-optional). Clients that do not use it ignore it |

### pose (optional)

Added after the contract was agreed; older clients ignore it. The backend returns it in both modes; in `mock` mode it is a synthetic, deterministic arc built from the mock angle series.

```text
"pose": {
  "fps": 10,
  "elbow": [0.1806, 0.6975],
  "frames": [
    {"t": 0.0, "wrist": [0.2104, 0.4652], "hand": [[0.2104, 0.4652], [0.2251, 0.4408], "… 21 points in total"]},
    null
  ]
}
```

| Field | Type | Description |
|---|---|---|
| `pose.fps` | number | Same as `angle_series.fps` |
| `pose.elbow` | `[x, y]` | The elbow found by the analysis: centre of the arc of the wrist. May lie outside 0–1 if the elbow is outside the frame |
| `pose.frames` | array of object or `null` | **Exactly as many elements as `angle_series.values`**, same time axis. `null` = no hand found in that frame |
| `frames[].t` | number | Time in seconds from the start of the video, `index / fps` |
| `frames[].wrist` | `[x, y]` | Wrist; the same point as `hand[0]` |
| `frames[].hand` | array of 21 `[x, y]` | MediaPipe hand landmarks in their standard order (0 = wrist) |

- Coordinates are **shares of the frame width and height as the user sees the video**: rotation metadata (for example iPhone −90°) is already applied. `[0, 0]` is the top left corner. Rounded to 4 digits.
- Only real points from MediaPipe and the elbow actually used for the angle: nothing is interpolated or drawn in. Where `angle_series.values` has a short interpolated gap, `frames` still has `null`.
- Size: about 110 KB of JSON for a 30 s recording (about 32 KB with the gzip/zstd compression the server applies), about 220 KB for 60 s.

## Several exercises

Status: **implemented in the backend** (catalog, `measure`, mock answers for all four exercises, `unsupported_exercise`). In `model` mode `ready` is `true` only for an exercise whose model is loaded (today `E02`). Nothing changes for `E02`: its response, model (`e02-logreg2-1`) and thresholds stay as they are, and `angle_series` stays in the response for older clients.

| `exercise` | Exercise | `measure.name` | `measure.unit` | Value shown to the user |
|---|---|---|---|---|
| `E01` | Lifting an object | `lift_height` | `hand_lengths` | Maximum rise of the hand from its starting position, in hand lengths |
| `E02` | Elbow extension | `elbow_angle` | `deg` | Maximum elbow angle (as the chart shows today) |
| `E03` | Wrist lift | `wrist_lift` | `deg` | Maximum lift of the hand from its starting direction |
| `E04` | Hand opening | `hand_openness` | `percent` | Maximum opening of the hand relative to the start |

The formulas are fixed per exercise after the signal check on the training data and are described in [model-evaluation.md](model-evaluation.md). Until then the names and units above are the contract, the formulas are not.

### measure (optional)

```text
"measure": {
  "name": "hand_openness",
  "unit": "percent",
  "value": 138.5,
  "series": { "fps": 10, "values": [100.0, 101.3, null, 118.9, 138.5] }
}
```

| Field | Type | Description |
|---|---|---|
| `measure.name` | `"elbow_angle"` / `"wrist_lift"` / `"hand_openness"` / `"lift_height"` | What is measured |
| `measure.unit` | `"deg"` / `"percent"` / `"hand_lengths"` | Unit of `value` and `series.values` |
| `measure.value` | number | The one number the result line shows (the maximum over the cycle, see the table above). `null` if the signal is too short to measure |
| `measure.series.fps` | number | Samples per second, same as `angle_series.fps` |
| `measure.series.values` | array of number or `null` | The chart; `null` = hand not detected in that frame |

- For `E02`: `measure.name = "elbow_angle"`, `unit = "deg"`, `series` equals `angle_series` (clipped to 0–180 for the chart) and `value` is its maximum.
- The label, confidence and verdict rules below are the same for every exercise. There are no medical hints: only the label, the confidence and the measured value.

### pose for the other exercises

`pose` for `E02` is unchanged (elbow + wrist + hand). For `E01`, `E03`, `E04` it has the same shape but **without `elbow`** (the field is omitted): only the real hand points of MediaPipe in `frames`. Clients draw the elbow line only if `pose.elbow` is present.

### GET /api/v1/exercises

Which exercises can be analyzed now. Clients show "coming soon" for `ready: false` and do not offer recording.

```json
[
  { "id": "E01", "measure": { "name": "lift_height",   "unit": "hand_lengths" }, "ready": false },
  { "id": "E02", "measure": { "name": "elbow_angle",   "unit": "deg" },          "ready": true  },
  { "id": "E03", "measure": { "name": "wrist_lift",    "unit": "deg" },          "ready": false },
  { "id": "E04", "measure": { "name": "hand_openness", "unit": "percent" },      "ready": false }
]
```

- `model` mode: `ready` is `true` only if the model file of the exercise exists and is loaded. `POST /analysis` with a not ready exercise gives `400 unsupported_exercise`.
- `mock` mode: `ready` is `true` for all four, and `POST /analysis` answers for all four exercises with deterministic test responses (`source: "mock"`, the same scenarios `mock_scenario=complete|incomplete|uncertain|no_pose`), so that the site and the app can build the interface before the models are ready.

### What clients should do

1. Read `measure` if present, otherwise fall back to `angle_series` (old behaviour).
2. Show the chart from `measure.series` with the unit from `measure.unit`; show `measure.value` in the result line.
3. Ask `GET /exercises` to know which exercises to offer.
4. Ignore unknown fields.

### Label and verdict rules

The classifier outputs the probability `p` that the cycle is complete.

1. `confidence = max(p, 1 - p)`
2. If `confidence < threshold`, then `label = "uncertain"`.
3. Otherwise `label = "complete"` if `p >= 0.5`, else `"incomplete"`.
4. `cycles[].verdict = "completed"` only for `label = "complete"`. For `incomplete` and `uncertain` it is `"check_instructions"`.
5. Top-level `verdict = "completed"` only if every cycle is `completed`.

`threshold` is chosen during model training on cross-validation, not on the test set. See [model-evaluation.md](model-evaluation.md).

### Warnings

| Code | Meaning |
|---|---|
| `arm_not_visible` | The arm was not detected in a noticeable share of frames; the result may be less reliable |

Clients show warnings as neutral hints, for example "Make sure your whole arm is visible". New warning codes are added only when the backend can actually detect the condition, and only by agreement of the team.

A video that is too short is an error, not a warning (`video_too_short`): a recording under 2 seconds cannot contain a full cycle; the shortest cycle in the dataset is 4.9 s.

## Accounts and history

Status: **contract, agreed before the implementation.** The web app and the mobile app are built against this section in parallel with the backend. It changes only by agreement of all three developers.

Accounts are **optional and switched on by the server**: only when the environment variable `SERIQ_DATABASE_URL` is set. Without it the routes `/auth`, `/me`, `/sessions` and `/progress` do not exist (the server answers `404`), `GET /health` has no `database` field, and everything above this section works as before. `POST /analysis` and `GET /exercises` never need a login and never depend on the database.

When accounts are on, `GET /health` has one more field:

```json
{ "status": "ok", "mode": "model", "version": "0.1.0", "database": "ok" }
```

`database` is `"ok"` or `"unavailable"`. Clients treat the **presence** of this field as "accounts are available on this server". A guest (not logged in) works as today: the history stays on the device.

What is stored for a logged-in user: the login, a hash of the password (argon2id), hashes of refresh tokens, and the saved sessions with their attempts (result of each analysis: label, confidence, `measure`). **Never stored: video, frames, `pose`, `angle_series`, e-mail, IP address, device data.** There is no password change and no password recovery: a forgotten password cannot be restored, clients say so at registration.

### Login and password rules

| Field | Rule |
|---|---|
| `login` | 3–32 characters, ASCII letters, digits, `.`, `_`, `-`. Not an e-mail. Case is kept as typed, uniqueness ignores case (`Anna` and `anna` are the same login) |
| `password` | 10–128 characters, any characters. No required digits or symbols. Must not equal the login and must not contain it (case ignored) |

### Tokens

| Token | Lifetime | Use |
|---|---|---|
| `access_token` | 15 minutes (`expires_in: 900` seconds) | Header `Authorization: Bearer <access_token>` on `/me`, `/sessions`, `/progress`. The content is opaque: clients do not read it |
| `refresh_token` | 30 days | Only for `/auth/refresh` and `/auth/logout`. Rotated on every use: the old one stops working |

Where the refresh token lives depends on the client, which is announced by the header `X-SerIQ-Client`:

| Client | Header | Refresh token |
|---|---|---|
| Mobile app | none | In the JSON body of the response (`refresh_token`); the app stores it in secure storage and sends it in the body of `/auth/refresh` and `/auth/logout` |
| Web app | `X-SerIQ-Client: web` | **Not in the body.** The server sets the cookie `seriq_refresh=<token>; HttpOnly; Secure; SameSite=Strict; Path=/api/v1/auth; Max-Age=2592000`. The browser sends it by itself to `/auth/*`; the body of `/auth/refresh` and `/auth/logout` is empty (`{}`). The web app keeps the access token in memory only |

Rules for the cookie flow:

- The header must be sent on every `/auth/*` request of the web app. A request with the header reads the refresh token only from the cookie; a request without it reads it only from the body. This header, together with `SameSite=Strict`, is the protection against cross-site requests.
- `/auth/refresh` sets a new cookie. `/auth/logout` and `DELETE /me` clear it (`Max-Age=0`).
- The site and the API share one domain, so no CORS is needed.

Reuse of a refresh token: a token that was already rotated and is sent again **after 10 seconds** is treated as stolen: the whole chain is revoked and the answer is `401 refresh_reused` (the user logs in again). Within the first 10 seconds the answer is `401 invalid_token` and nothing is revoked (two browser tabs refreshing at the same moment): the client retries with the newest token or logs in again.

### POST /api/v1/auth/register

```json
{ "login": "anna_k", "password": "correct horse battery" }
```

Response `201` (mobile; the web response has no `refresh_token`, see above):

```json
{
  "user": { "id": "8d3f2b3a-5d1c-4a1e-9b43-6c1f0e2a7d10", "login": "anna_k", "created_at": "2026-11-25T08:30:12Z" },
  "access_token": "ACCESS_TOKEN_EXAMPLE",
  "refresh_token": "REFRESH_TOKEN_EXAMPLE",
  "expires_in": 900
}
```

Errors: `400 invalid_request` (wrong login format, missing field), `400 weak_password` (length or the password contains the login), `409 login_taken`, `429 rate_limited`.

### POST /api/v1/auth/login

The same body as register. Response `200`, the same shape as register. Errors: `401 invalid_credentials` (**the same answer, text and code for an unknown login and for a wrong password**), `400 invalid_request`, `429 rate_limited`.

### POST /api/v1/auth/refresh

Mobile: `{ "refresh_token": "…" }`. Web: empty body, the cookie is used. Response `200`: `{ "access_token", "refresh_token", "expires_in" }` (web: without `refresh_token`, a new cookie is set). Errors: `401 invalid_token` (unknown, expired or revoked token), `401 refresh_reused`, `400 invalid_request`.

### POST /api/v1/auth/logout

Mobile: `{ "refresh_token": "…" }`. Web: empty body. Revokes the whole chain of this refresh token. Response `204`, also when the token is unknown (the answer does not reveal whether it existed).

### GET /api/v1/me

Needs `Authorization`. Response `200`:

```json
{ "id": "8d3f2b3a-5d1c-4a1e-9b43-6c1f0e2a7d10", "login": "anna_k", "created_at": "2026-11-25T08:30:12Z" }
```

### DELETE /api/v1/me

Needs `Authorization`. Body: `{ "password": "…" }` (confirmation). Deletes the account and **all its data** (sessions, attempts, tokens) in one step. Response `204`; the web cookie is cleared. A wrong password gives `403 invalid_credentials` and counts as a failed login attempt. Copies of the database file made before the deletion keep the data until they are replaced (the last 7 copies are kept).

### PUT /api/v1/sessions/{session_id}

Needs `Authorization`. `session_id` is the UUID the client already uses for the session on the device. The body is the session as the device holds it:

```json
{
  "exercise": "E02",
  "started_at": "2026-11-25T08:41:03Z",
  "attempts": [
    {
      "analysis_id": "3f2b9c1e-6a51-4c0e-9a57-1f6f0f2d8b11",
      "at": "2026-11-25T08:42:10Z",
      "source": "model",
      "model_version": "e02-logreg2-1",
      "verdict": "completed",
      "label": "complete",
      "confidence": 0.87,
      "measure": {
        "name": "elbow_angle",
        "unit": "deg",
        "value": 166.2,
        "series": { "fps": 10, "values": [62.5, 70.1, null, 166.2] }
      }
    }
  ]
}
```

| Field | Rule |
|---|---|
| `exercise` | `E01`–`E04` |
| `started_at`, `attempts[].at` | ISO 8601 date and time with `Z` or an offset. Stored and returned in UTC |
| `attempts` | 1–200 items |
| `attempts[].analysis_id` | UUID from the analysis response |
| `attempts[].source` | `"mock"` or `"model"` |
| `attempts[].model_version` | string, up to 64 characters |
| `attempts[].verdict` | `"completed"` or `"check_instructions"` |
| `attempts[].label` | `"complete"`, `"incomplete"` or `"uncertain"` |
| `attempts[].confidence` | number 0–1 |
| `attempts[].measure` | optional. `name` and `unit` must be those of the exercise (see the table in *Several exercises*); `value` is a number or `null`; `series.fps` > 0; `series.values` up to **1000** numbers or `null` |

Response `200` always (also on the first save): the session **as stored**:

```json
{
  "id": "5b9e7c0a-2e61-4f6d-8c3a-0d2f6a9b1e44",
  "exercise": "E02",
  "started_at": "2026-11-25T08:41:03Z",
  "created_at": "2026-11-25T08:42:11Z",
  "attempts": [ { "analysis_id": "3f2b9c1e-…", "at": "2026-11-25T08:42:10Z", "source": "model", "…": "as in the request" } ]
}
```

Attempts come back sorted by `at`. The call is **idempotent**:

- Sending the same data again changes nothing and creates no duplicates.
- An attempt with a new `analysis_id` in an existing session is added.
- A saved attempt is **never changed**: if the same `analysis_id` arrives with different data, the stored version is kept and returned.
- The stored `exercise` and `started_at` of an existing session are not changed; a different `exercise` for an existing `session_id` gives `400 invalid_request`.
- Everything happens in one transaction: on any error nothing from this request is saved.
- `session_id` or `analysis_id` that belongs to another user, or an `analysis_id` already saved in another session, gives `409 id_conflict`.

Errors: `400 invalid_request` (validation, `session_id` is not a UUID), `401`, `409 id_conflict`, `413 payload_too_large` (more than 200 attempts, more than 1000 values in a series, or a body over 4 MiB).

### GET /api/v1/sessions

Needs `Authorization`. Newest first (by `started_at`, then `id`). Query: `exercise` (optional, `E01`–`E04`), `limit` (1–100, default 20), `cursor` (from the previous page, opaque). Response `200`:

```json
{
  "items": [
    {
      "id": "5b9e7c0a-2e61-4f6d-8c3a-0d2f6a9b1e44",
      "exercise": "E02",
      "started_at": "2026-11-25T08:41:03Z",
      "created_at": "2026-11-25T08:42:11Z",
      "summary": { "total": 3, "complete": 2, "incomplete": 1, "uncertain": 0 }
    }
  ],
  "next_cursor": null
}
```

`summary` counts the attempts of the session by label. `next_cursor` is `null` on the last page. The list has no attempts and no series; they come from the detail request.

### GET /api/v1/sessions/{session_id}

The session as in the `PUT` response, with all attempts and series. A session of another user or a missing one gives `404 not_found` (the same answer).

### DELETE /api/v1/sessions/{session_id}

Response `204`. A missing session or another user's session gives `404 not_found`. After the deletion the same `analysis_id` values can be saved again.

### DELETE /api/v1/sessions

Deletes the whole history of the user, the account stays. Response `204`, also when the history is empty.

### GET /api/v1/progress/summary

Needs `Authorization`. Counts what the user did; it is **not an assessment of recovery** and contains no conclusions. Query: `exercise` (optional), `utc_offset_minutes` (optional, −720…840, default 0: the day boundaries of `activity` are taken in this offset, for example `300` for UTC+5). Response `200`:

```json
{
  "exercise": "E02",
  "sessions": 4,
  "repetitions": 11,
  "labels": { "complete": 7, "incomplete": 3, "uncertain": 1 },
  "shares": { "complete": 0.6364, "incomplete": 0.2727, "uncertain": 0.0909 },
  "activity": [
    { "date": "2026-11-24", "sessions": 1, "repetitions": 3 },
    { "date": "2026-11-25", "sessions": 3, "repetitions": 8 }
  ],
  "measure": { "name": "elbow_angle", "unit": "deg" },
  "points": [
    { "at": "2026-11-24T16:02:10Z", "value": 141.5, "label": "incomplete" },
    { "at": "2026-11-25T08:42:10Z", "value": 166.2, "label": "complete" }
  ]
}
```

| Field | Meaning |
|---|---|
| `exercise` | The filter, or `null` for all exercises |
| `sessions`, `repetitions` | Number of saved sessions and of saved attempts (one attempt = one repetition) |
| `labels`, `shares` | Attempts by label, and their shares (0–1, 4 digits). `shares` is `null` when there are no attempts |
| `activity` | Days with activity, oldest first, the last 90 days only |
| `measure`, `points` | Measured values in time order, the last 100 attempts that have a number. Units differ between exercises, so both are `null` when `exercise` is not given |

### Errors of this section

All in the usual error shape. New codes, added to the table in [Errors](#errors):

| HTTP | `code` | When |
|---|---|---|
| 400 | `invalid_request` | The body, a parameter or an identifier has a wrong format |
| 400 | `weak_password` | The password is shorter than 10 or longer than 128 characters, or contains the login |
| 401 | `invalid_credentials` | Login: unknown login or wrong password (same answer) |
| 403 | `invalid_credentials` | `DELETE /me`: wrong confirmation password |
| 401 | `invalid_token` | No token, a wrong, revoked or unknown token |
| 401 | `token_expired` | The access token has expired: refresh it |
| 401 | `refresh_reused` | A rotated refresh token was used again: the chain is revoked, log in again |
| 404 | `not_found` | Session not found (or not yours) |
| 409 | `login_taken` | The login is already registered |
| 409 | `id_conflict` | `session_id` or `analysis_id` belongs to another user or to another session |
| 413 | `payload_too_large` | Too many attempts or values, or the body is too large |
| 429 | `rate_limited` | Too many attempts. The header `Retry-After` has the seconds to wait |

Limits against guessing: after repeated failed logins for one login the waiting time grows up to 15 minutes; one IP address may log in 20 times per 10 minutes and register 5 times per hour. The answers are the same for existing and unknown logins.

## Errors

Every error has the same shape:

```json
{
  "status": "error",
  "error": { "code": "file_too_large", "message": "File exceeds 100 MB" }
}
```

| HTTP | `code` | When |
|---|---|---|
| 400 | `missing_video` | No `video` field in the request |
| 400 | `empty_file` | The file is empty |
| 400 | `unsupported_exercise` | `exercise` is not one of `E01`–`E04`, or the exercise has no ready model (`ready: false` in `GET /exercises`) |
| 413 | `file_too_large` | File is larger than 100 MB |
| 415 | `unsupported_format` | Not `.mp4`, `.mov` or `.webm` |
| 422 | `video_unreadable` | The file cannot be decoded as video |
| 422 | `video_too_short` | Shorter than 2 seconds |
| 422 | `video_too_long` | Longer than 60 seconds |
| 422 | `no_pose_detected` | The arm was not found in the video |
| 503 | `busy` | Another analysis is running; retry in a few seconds |
| 500 | `internal_error` | Unexpected server error |

Codes of accounts and history (`invalid_request`, `invalid_credentials`, `login_taken`, `weak_password`, `invalid_token`, `token_expired`, `refresh_reused`, `not_found`, `id_conflict`, `payload_too_large`, `rate_limited`) are listed in [Accounts and history](#accounts-and-history).

`message` is for developers. Clients show their own localized text, chosen by `code`.

## Privacy

- The uploaded video is saved to a temporary file, analyzed and deleted. It is never stored permanently.
- By default (no `SERIQ_DATABASE_URL`) the backend has no database and stores no personal data or results. The session history lives only on the user's device.
- With accounts switched on, the server stores only what [Accounts and history](#accounts-and-history) lists: the login, a password hash and the saved results of a logged-in user. Never the video.
