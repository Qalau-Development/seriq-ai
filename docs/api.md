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

`message` is for developers. Clients show their own localized text, chosen by `code`.

## Privacy

- The uploaded video is saved to a temporary file, analyzed and deleted. It is never stored permanently.
- The backend has no database and stores no personal data or results.
- The session history lives only on the user's device.
