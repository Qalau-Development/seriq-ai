# Model Evaluation

Status: **done for model `e02-logreg2-1`.** The methodology below was fixed before training; every change made after the first results is listed in [Changes to the methodology](#changes-to-the-methodology), with the time it was made. The test volunteer 08 was evaluated **once**, after the model and all thresholds were committed. The model runs on the server since 24.11.2026, 15:38; time and memory are in [On the server](#on-the-server).

All times are Kazakhstan time (UTC+5), 24.11.2026.

## Task

Binary classification of one elbow extension (E02) cycle as `complete` or `incomplete`, with a confidence estimate; low-confidence decisions become `uncertain`. Input: the elbow angle series derived from MediaPipe hand landmarks in one video (see [Elbow angle](#elbow-angle)). One video contains one cycle. See [dataset-analysis.md](dataset-analysis.md) for the data.

## Data split

The split is strictly by volunteer ID, as required by the case specification. Videos of one person never appear in two different splits.

| Split | Volunteers | Complete | Incomplete | Purpose |
|---|---|---|---|---|
| Train | 01, 02, 03, 04, 05 | 50 | 57 | Model selection with Leave-One-Subject-Out cross-validation (LOSO-CV) |
| Test | 08 | 10 | 10 | Independent final evaluation, used once |

- **LOSO-CV:** five folds; in each fold one training volunteer is held out for validation and the model is trained on the other four. This uses all five people and shows the spread of results between people.
- **The test volunteer 08 was not used** for choosing the angle method, features, models, hyperparameters, thresholds or calibration. Its videos were first read at 15:00, after the model (commit `3acdd62`, 14:58) and the evaluation script (commit `f1b492f`, 15:00) were committed.
- The volunteer ID is parsed from the first two digits of the file name. The class label is taken from the folder name (see the label issue in [dataset-analysis.md](dataset-analysis.md#label-issue-volunteer-04)).
- Classes are close to balanced (50 / 57). Models that support it use class weights; there is no resampling.

## Elbow angle

The shoulder is outside the frame in the training videos, so the shoulder–elbow–wrist angle cannot be measured. The angle is derived from MediaPipe Hand Landmarker (`seriq_engine/hand.py`, `angles.py`):

1. Wrist (landmark 0) and the base of the middle finger (landmark 9) in pixels of each sampled frame (about 10 per second).
2. The elbow is the centre of the circle the wrist moves on. The radius is fixed to `K_FOREARM × hand length` with `K_FOREARM = 3.56`, fitted by least squares.
3. Elbow angle = 180° − forearm tilt to the horizontal of the frame. Gaps of up to 3 samples are interpolated; then a 3-sample moving average.

`K_FOREARM` was estimated on the training volunteers (median ratio of the free-circle radius to hand length on the 56 videos with an arc of at least 60°; interquartile range 3.36–3.77; 3.47–3.61 when one volunteer is left out). It is a model parameter, fixed before the test run like the `uncertain` threshold.

How the angle was checked: on those 56 videos the fixed-radius method differs from a free circle fit by 1.5° (median), 5.6° (90th percentile) per frame. **This is agreement with another computation, not with manual annotation**; no manual angle annotation exists. The elbow position was also checked visually on frames of the worst-fitting videos and of the four videos where the free circle failed.

Share of sampled frames with a detected hand, per volunteer (important for fairness: volunteer 01 has dark skin, and the rejected colour-based method failed on exactly this volunteer):

| Volunteer | Videos | Minimum | Median | Mean |
|---|---|---|---|---|
| 01 | 21 | 1.000 | 1.000 | 1.000 |
| 02 | 24 | 1.000 | 1.000 | 1.000 |
| 03 | 22 | 1.000 | 1.000 | 1.000 |
| 04 | 20 | 0.887 | 1.000 | 0.994 |
| 05 | 20 | 0.886 | 0.969 | 0.955 |
| 08 (test) | 20 | 0.976 | 1.000 | 0.998 |

## Features

Nine features per cycle (`seriq_engine/features.py`), all **relative**: differences of angles, shares of time, speeds in degrees per second. A constant shift of the whole angle series, which is what a tilted camera causes, does not change them (covered by a test). Resolution, orientation and frame rate are not used.

The main model uses two of them: `extension_range` (95th percentile of the angle minus the mean of the first 10% of samples) and `end_minus_start` (mean of the last 10% minus the mean of the first 10%).

## Models

| Role | Model | Features |
|---|---|---|
| Baseline A | Majority class (`DummyClassifier`); lower bound, BA = 0.5 | — |
| Baseline B | One threshold on `end_minus_start` (> T means complete); T is chosen inside each LOSO fold to maximise balanced accuracy | 1 |
| **Main** | Logistic regression (`class_weight="balanced"`) with sigmoid calibration (`CalibratedClassifierCV`, calibration folds = leave-one-volunteer-out inside the training data) | 2 |
| Comparison | Logistic regression, Random Forest, Gradient Boosting, SVM (RBF) | 9 |

Imputation and scaling are part of each `Pipeline` and are fitted inside every fold.

## Confidence and `uncertain`

A cycle is `uncertain` if **either** rule fires (`seriq_engine/classifier.py`). Both rules were fixed before the test run.

1. **Signal quality.** It catches changed recording conditions (another camera, light, person). The thresholds lie outside everything seen on the training data:

   | Rule | On train | `uncertain` if |
   |---|---|---|
   | Share of frames with an elbow angle | minimum 0.886 | < 0.80 |
   | Longest gap without the hand | maximum 1.41 s | > 2.0 s |
   | Number of angle points | minimum 49 | < 20 (about 2 s) |

2. **Confidence.** `confidence = max(p, 1 − p)` with calibrated `p`; `uncertain` if `confidence < 0.75`. 0.75 is a margin for the change of camera, set in advance, not tuned on out-of-fold predictions.

When the share of frames with an angle is below 0.80, the API also returns the warning `arm_not_visible`.

## Results

### LOSO-CV on train (volunteers 01–05, 107 videos)

Before the `uncertain` rule. BA = balanced accuracy. Precision, recall and F1 are given as complete / incomplete. Confusion matrix: rows = true, columns = predicted, order complete, incomplete.

| Model | BA (all folds pooled) | BA per volunteer, mean ± SD | F1 macro | Precision | Recall | F1 | Confusion matrix |
|---|---|---|---|---|---|---|---|
| Baseline A: majority | 0.500 | 0.500 ± 0.000 | 0.348 | 0.00 / 0.53 | 0.00 / 1.00 | 0.00 / 0.70 | [[0, 50], [0, 57]] |
| Baseline B: one threshold | 1.000 | 1.000 ± 0.000 | 1.000 | 1.00 / 1.00 | 1.00 / 1.00 | 1.00 / 1.00 | [[50, 0], [0, 57]] |
| **Main: logistic regression, 2 features, calibrated** | **1.000** | **1.000 ± 0.000** | **1.000** | 1.00 / 1.00 | 1.00 / 1.00 | 1.00 / 1.00 | [[50, 0], [0, 57]] |
| Logistic regression, 9 features | 0.991 | 0.991 ± 0.018 | 0.991 | 0.98 / 1.00 | 1.00 / 0.98 | 0.99 / 0.99 | [[50, 0], [1, 56]] |
| Random Forest, 9 features | 0.991 | 0.991 ± 0.018 | 0.991 | 0.98 / 1.00 | 1.00 / 0.98 | 0.99 / 0.99 | [[50, 0], [1, 56]] |
| Gradient Boosting, 9 features | 0.956 | 0.951 ± 0.077 | 0.953 | 0.91 / 1.00 | 1.00 / 0.91 | 0.95 / 0.95 | [[50, 0], [5, 52]] |
| SVM (RBF), 9 features | 0.902 | 0.901 ± 0.152 | 0.905 | 0.95 / 0.87 | 0.84 / 0.96 | 0.89 / 0.92 | [[42, 8], [2, 55]] |

Per-volunteer BA of the comparison models: the 9-feature logistic regression and Random Forest miss one video of volunteer 03 (`03_02_00_08`, incomplete: the arm rose to about 123° and stayed there). Gradient Boosting has 0.80 on volunteer 05; SVM has 0.60 on volunteer 05.

Baseline B threshold per fold: 40.4° (33.1° in the fold without volunteer 03). On the training data `end_minus_start` is at least 55.0° for complete and at most 25.7° for incomplete cycles.

Main model with the `uncertain` rule (LOSO-CV): **coverage 0.953**. 5 videos are `uncertain`, all by confidence (calibrated `p` 0.62–0.73), none by signal quality; all 5 are complete and would have been classified correctly. On the 102 confident videos: BA 1.000, F1 macro 1.000, confusion [[45, 0], [0, 57]].

### Test (volunteer 08, 20 videos, webcam, landscape), one run

Model `e02-logreg2-1`, SHA-256 `522388485921c323b687afed063ec7bd680a61abd4deff9fd45937c0f8dc9fc9`. Run at 15:00:42, code at commit `f1b492f`. Raw results: [test_vol08_metrics.json](../ml-training/results/test_vol08_metrics.json), [test_vol08_predictions.csv](../ml-training/results/test_vol08_predictions.csv).

| Model | Evaluation | BA | Precision | Recall | F1 | F1 macro | Confusion matrix | Coverage |
|---|---|---|---|---|---|---|---|---|
| Baseline A: majority | all 20 | 0.500 | 0.00 / 0.50 | 0.00 / 1.00 | 0.00 / 0.67 | 0.333 | [[0, 10], [0, 10]] | — |
| Baseline B: one threshold | all 20 | 1.000 | 1.00 / 1.00 | 1.00 / 1.00 | 1.00 / 1.00 | 1.000 | [[10, 0], [0, 10]] | — |
| **Main** | all 20, before `uncertain` | **1.000** | 1.00 / 1.00 | 1.00 / 1.00 | 1.00 / 1.00 | **1.000** | [[10, 0], [0, 10]] | — |
| **Main** | confident only | **1.000** | 1.00 / 1.00 | 1.00 / 1.00 | 1.00 / 1.00 | **1.000** | [[10, 0], [0, 10]] | **1.000** |

![Confusion matrices on volunteer 08](figures/e02_confusion_vol08.png)

- No test video is `uncertain`: confidence is at least 0.903 (median 0.938); the hand is found in at least 97.6% of frames; the longest gap is 0.3 s.
- On the test videos `end_minus_start` is 81.7°–94.0° for complete and −8.6°–−0.3° for incomplete cycles: the classes are even further apart than in training.
- **20 of 20 correct is not 100% accuracy in general.** The 95% Clopper–Pearson interval for the share of correct answers is 0.832–1.000, and all 20 videos come from one person.

Angle curves of the training data: [e02_angle_curves_train.png](figures/e02_angle_curves_train.png).

## On the server

`SERIQ_MODE=model` since 24.11.2026, 15:38 (commit `25d5d46`). Before switching, `warmup()` was run inside the running container: it loads the model and creates the MediaPipe Hand Landmarker. It first failed (`libEGL.so.1` missing in the image); the image was fixed (`libegl1`, `libgles2`), and the build now runs `warmup()`, so CI catches this.

Server: VPS with 2 vCPU and 3.8 GB RAM; the backend container is limited to 2 GiB. One analysis at a time.

Measured on 24.11.2026 through the public API (`https://seriq-ai.qalau.com/api/v1/analysis`):

| Video | Size | `processing_ms` | Upload + analysis from a laptop |
|---|---|---|---|
| Portrait phone video, HEVC 1620×2880, 11.5 s (heaviest format in the dataset), two runs | 8.1 MB | 7 003 / 6 919 | 13.6 s (first run) |
| Landscape webcam video, 960×540, 14.9 s | 1.1 MB | 2 955 | 4.8 s |
| Landscape webcam video, 960×540, 13.1 s | 1.0 MB | 2 808 | not measured |

`processing_ms` is the server time from receiving the file to the response: decoding, hand landmarks on about 10 frames per second, angle, features, classifier. Upload time depends on the user's connection.

`docker stats --no-stream` of the backend, sampled about every 2 s during both analyses:

| | Memory | CPU (200% = both cores) |
|---|---|---|
| Idle | 245 MiB | 0.2% |
| During analysis, peak | 346 MiB | 167% |

The two videos used for the measurement are from the dataset (volunteers 01 and 08); they were only sent for timing, not shown anywhere, and the server deleted them after the analysis.

## End-to-end checks

Run after the switch to `model` (24.11.2026). The model, features and thresholds were not changed because of these checks.

### Own recordings

Three recordings by a team member on an iPhone (4K HEVC, rotation −90° in the metadata, read correctly), sent through the public API. The recordings show the team member's face; they are not in the repository and were not stored on the server.

| Recording | What was done | Elbow angle: start → maximum → end | Result | Expected |
|---|---|---|---|---|
| 1 | Arm lowered halfway, then raised back | 83° → 147° → 74° | `incomplete`, confidence 0.81 | `incomplete` ✓ |
| 2 | Arm lowered **to the table** (about 180°), then **raised back** | — | `uncertain`, confidence 0.55 | see below |
| 3 | No arm in the frame | — | 422 `no_pose_detected` | `no_pose_detected` ✓ |

`processing_ms` was 6.4–10.9 s: 4K HEVC is the heaviest format we have seen.

**Recording 2 is a limitation, not an error.** In the dataset a complete repetition ends with the arm lying on the table; the arm comes back up only in incomplete repetitions. A full extension followed by a return therefore looks partly like an incomplete one, and the model was not confident, so it answered `uncertain` instead of guessing. This is the behaviour the `uncertain` rule was designed for. **The recording protocol must match the dataset: lower the arm to the table and stop the recording there.** The instructions on the site and in the app are being updated to ask for this.

### Team recordings by scenario

Seven recordings by team members on an iPhone (4K HEVC, 3840×2160 with rotation metadata), one per scenario, sent through the public API with `ml-training/e2e_check.py` on 24.11.2026. Numbers only: the videos are not in the repository and were not stored on the server.

| Scenario | What was done | Expected | Result | Confidence | Elbow angle: start → max → end | `processing_ms` |
|---|---|---|---|---|---|---|
| `full` (1) | Lowered to the table and stopped | `complete` | `complete` ✓ | 0.93 | 93° → 176° → 175° | 5 948 |
| `full` (2) | Lowered to the table and stopped | `complete` | `complete` ✓ | 0.87 | 94° → 167° → 167° | 8 259 |
| `other_arm` | Other arm, from the other side | `complete` | `complete` ✓ | 0.97 | 75° → 171° → 170° | 7 122 |
| `half_back` | Lowered halfway and raised back | `incomplete` | `incomplete` ✓ | 0.90 | 93° → 141° → 80° | 9 646 |
| `full_back` | Lowered to the table and raised back | `uncertain` | `uncertain` ✓ | 0.62 | 87° → 163° → 86° | 10 409 |
| `bad_frame` | Arm partly out of the frame | `uncertain` or `no_pose_detected` | `uncertain` ✓, warning `arm_not_visible` | 0.73 | 76° → 141° → 74° | 7 660 |
| `half_hold` | Lowered halfway and **held** | not defined | `uncertain` | 0.74 | 75° → 137° → 137° | 6 294 |

6 of 6 recordings with a defined expectation matched.

- `bad_frame` is `uncertain` because of signal quality: the hand was found in 55% of the frames (rule: below 80%). Without that rule the model would have said `incomplete` with confidence 0.74, also below the threshold.
- **`half_hold` confirms the limitation found on synthetic series** (see [Known limitations](#known-limitations)). The extension from the start is 60.1°; the model gives `p_complete = 0.735` (computed locally from the same video), i.e. on the **complete** side, 0.015 below the threshold 0.75. An extension of about 3–4° more would have been classified as `complete`. The model is not changed for the reasons given there.
- `processing_ms` is 6–10 s for 4K HEVC; upload time comes on top (about 0.5 MB/s on the connection used, 12–24 MB per recording).

### Edge cases on the server

Synthetic files made with ffmpeg from a test pattern (no people, no dataset videos), sent through the public API:

| File | Response | Time |
|---|---|---|
| 61 s video | 422 `video_too_long` | 0.9 s |
| Random bytes after a valid mp4 signature | 422 `video_unreadable` | 1.0 s |
| mp4 cut to a third of its size | 422 `video_unreadable` | 0.5 s |
| 5 s video without a hand | 422 `no_pose_detected` | 1.5 s |
| 5 s webm without duration in the metadata (as browsers record), no hand | 422 `no_pose_detected` | 5.7 s |
| 1 s video | 422 `video_too_short` | 0.5 s |

A webm without duration takes longer: the server first decodes the whole file to count the frames.

### Mirrored video

Arm on the other side of the frame: two training videos (one complete, one incomplete) flipped horizontally, analysed locally and compared with the same videos re-encoded without flipping:

| Video | Original | Mirrored | Angle difference per frame |
|---|---|---|---|
| Complete | `complete`, 0.945 | `complete`, 0.935 | median 0.8°, max 2.2° |
| Incomplete | `incomplete`, 0.940 | `incomplete`, 0.942 | median 0.3°, max 0.7° |

The side of the arm is detected automatically. These two videos are from the training set, so this checks the mirroring, not the accuracy.

## Changes to the methodology

Made after results were seen, all **before any access to volunteer 08**:

| Time | Change | Reason |
|---|---|---|
| about 14:00–14:30 | Pose Landmarker replaced by Hand Landmarker; elbow from a fixed-radius circle; `K_FOREARM = 3.56` | The shoulder is outside the frame; Pose found a pose in 0–60% of frames. A colour skin mask was rejected: it lost up to 79% of frames for volunteer 01 (dark skin) |
| 14:37 | First LOSO-CV results (commit `84ccc16`): the planned baseline (logistic regression on 2 features) reached BA 1.000, all candidates were not better | — |
| 14:58 | Baseline redefined: A = majority class, B = one threshold on one feature. Main model = the former baseline (logistic regression on 2 features), now calibrated (commit `fe97478`) | The 2-feature model was not worse than the complex ones and is simpler and less likely to depend on the camera; a baseline must be simpler than the main model for the comparison to mean something |
| 14:58 | `uncertain` threshold fixed at 0.75 in advance, plus signal-quality rules, instead of a trade-off chosen on out-of-fold predictions; sigmoid calibration always applied | On LOSO-CV the out-of-fold predictions had no borderline cases, so a threshold chosen on them would be arbitrary |

**LOSO-CV is not fully clean:** the angle method and `K_FOREARM` were chosen while looking at all five training volunteers, including the one held out in each fold. The LOSO numbers are therefore somewhat optimistic; the test on volunteer 08 is not affected.

## Known limitations

- **One test person, 20 videos.** The test does not show how the model works for other people, especially for patients after a stroke. The health status of the volunteers is not stated in the dataset.
- **The task is easy on this dataset.** A single threshold (baseline B) is as good as the main model on both LOSO-CV and the test. In the incomplete videos the arm comes back without extending; real partial extensions (for example, stopping at 140°) are rare. One such video (`03_02_00_08`) exists in train.
- **The angle is an estimate**: 180° − forearm tilt, assuming the upper arm lies on the table. The absolute angle depends on camera tilt (up to about 190° in training), which is why the features are relative. The API clips `angle_series` to 0–180° for the chart only.
- **Recording protocol:** the model expects the dataset protocol: one repetition that ends with the arm on the table. A repetition "down and back up" gives `uncertain` (own recording 2). A feature based on the maximum angle and cycle segmentation could handle it, but a new model could not be evaluated honestly any more: the test volunteer has already been used.
- **Partial extension with a hold** (synthetic check, not a metric). The saved model was run on synthetic angle series "start at 90°, smooth rise, hold 1–2 s at the peak": extension from the start of up to about 33° → `incomplete`; about 36–60° → `uncertain` (confidence 0.53–0.73); from about 63° → `complete` (with a start at 90° that is a peak of about 153°). The hold time does not change the result; only the difference from the start angle does. So with the new protocol "lower the arm and stop", a partial extension that stops at about 153–170° can be classified as `complete`. The reason: the dataset has no incomplete repetitions with a hold (in its incomplete videos the arm comes back). The model is not retrained, because the test volunteer has already been used and a new model could not be evaluated honestly. The chart always shows the measured angle, so the user sees, for example, "up to 150°". Confirmed on a live recording (`half_hold`, see [Team recordings](#team-recordings-by-scenario)): extension 60.1°, `p_complete = 0.735`, `uncertain` by a margin of 0.015.
- **Camera:** training videos are portrait phone recordings, the test videos landscape webcam recordings. The model passed this one change of camera; other setups (arm not starting from the left edge, the elbow not resting, other angles of view) were not tested.
- **Hand detection and skin tone:** checked on six volunteers only. The detection rate was ≥ 0.886 for every video of every volunteer, including volunteer 01 with dark skin, but six people is not a fairness evaluation.
- **Missing frames:** in two training videos the hand disappears at the end (`04_02_00_03`: the last 13 samples, `05_02_00_06`: 1 sample). They are kept; gaps are handled in `angles.py`.
- **Labels of volunteer 04** are inconsistent between folder and file name; the folder is used.
- **Calibration is conservative:** in LOSO-CV 5 correctly classified complete videos were `uncertain` (confidence 0.62–0.73). Users will sometimes see "check the instructions" after a correct repetition.
