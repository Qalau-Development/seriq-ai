# API Contract

Status: **agreed, not implemented yet.** This contract is shared by the web app (`apps/web`), the mobile app (`apps/mobile`) and the backend (`backend`). Changing it requires agreement of all three developers.

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

Analyzes one recording of the elbow extension exercise (E02).

**MVP rule: one recording = one repetition (one cycle).** The training data contain exactly one cycle per video. A session summary is built on the client from several analyses. The response still uses a `cycles` array, so that automatic cycle segmentation can be added later without changing clients.

### Request

`Content-Type: multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `video` | file | yes | `.mp4`, `.mov` or `.webm` |
| `exercise` | string | no | Only `E02` is supported. Default `E02` |

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
| `exercise` | string | Always `"E02"` for now |
| `verdict` | `"completed"` / `"check_instructions"` | What the user is told. See rules below |
| `summary` | object | Counts of cycles by label in this recording |
| `cycles[]` | array | One element per detected cycle; in the MVP exactly one |
| `cycles[].index` | integer | Cycle number, starting from 1 |
| `cycles[].start_s`, `end_s` | number | Cycle start and end in seconds from the start of the video |
| `cycles[].label` | `"complete"` / `"incomplete"` / `"uncertain"` | Model decision for this cycle |
| `cycles[].confidence` | number 0–1 | Confidence of the decision |
| `cycles[].verdict` | `"completed"` / `"check_instructions"` | What the user is told for this cycle |
| `angle_series` | object | Elbow angle over time, for the chart |
| `angle_series.fps` | number | Samples per second in `values` |
| `angle_series.unit` | `"deg"` | Degrees; 180 means a fully straight arm |
| `angle_series.values` | array of number or `null` | `null` = arm not detected in that frame |
| `warnings` | array of string | Non-fatal problems, see the table below |
| `processing_ms` | integer | Server processing time |
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
| 400 | `unsupported_exercise` | `exercise` is not `E02` |
| 413 | `file_too_large` | File is larger than 100 MB |
| 415 | `unsupported_format` | Not `.mp4`, `.mov` or `.webm` |
| 422 | `video_unreadable` | The file cannot be decoded as video |
| 422 | `video_too_short` | Shorter than 2 seconds |
| 422 | `video_too_long` | Longer than 60 seconds |
| 422 | `no_pose_detected` | The arm was not found in the video |
| 503 | `busy` | Another analysis is running; retry in a few seconds |
| 500 | `internal_error` | Unexpected server error |

`message` is for developers. Clients show their own localized text, chosen by `code`.

## Privacy

- The uploaded video is saved to a temporary file, analyzed and deleted. It is never stored permanently.
- The backend has no database and stores no personal data or results.
- The session history lives only on the user's device.
