# Models

## e02_classifier.joblib

Classifier for one elbow extension (E02) cycle. Created by `ml-training/train.py`, loaded by `seriq_engine.classifier.load_bundle` (path from `SERIQ_MODEL_PATH`, in the image `/srv/models/e02_classifier.joblib`).

The file is a `joblib` dump of a dictionary:

| Key | Value |
|---|---|
| `model` | `CalibratedClassifierCV` (sigmoid, calibration folds = leave-one-volunteer-out) around `SimpleImputer → StandardScaler → LogisticRegression(class_weight="balanced")` |
| `features` | `extension_range`, `end_minus_start` (see `seriq_engine/features.py`) |
| `confidence_threshold` | `0.75`: below it the cycle is `uncertain` |
| `signal_quality` | `uncertain` if the elbow angle is found in less than 80% of frames, a gap is longer than 2 s, or fewer than 20 angle points |
| `k_forearm` | `3.56`: forearm length in hand lengths, used to find the elbow |
| `model_version` | `e02-logreg2-1` |
| `trained_at`, `sklearn_version`, `numpy_version`, `python_version` | Training environment |
| `train_volunteers`, `train_videos`, `loso` | Training data (volunteers 01–05, 107 videos) and LOSO-CV balanced accuracy |

Trained only on volunteers 01–05. Volunteer 08 (test) was not used for any choice. Metrics are in [docs/model-evaluation.md](../docs/model-evaluation.md).

**scikit-learn must be the same version (1.9.1) in training, in `ai-engine/pyproject.toml` and in `backend/requirements.txt`**: a joblib file from one version may not load in another.

## e04_classifier.joblib

Classifier for one hand opening (E04) cycle, model `e04-logreg2-1`. Created by `ml-training/train_exercise.py E04`, same file layout as `e02_classifier.joblib` (the path is built next to `SERIQ_MODEL_PATH`: `/srv/models/e04_classifier.joblib`). Signal: mean distance from the fingertips to the wrist divided by the palm size, in percent of the start of the recording (`seriq_engine/exercises/e04.py`). Features `extension_range`, `end_minus_start`; calibration over all out-of-fold predictions at once (`ensemble=False`), because volunteers 01 and 03 have one class only in train. Trained on volunteers 01–06 (100 videos); volunteer 09 (test) was evaluated once after the model was committed. Metrics: [docs/model-evaluation.md](../docs/model-evaluation.md#e04-hand-opening).

## e03_classifier.joblib

Classifier for one wrist lift (E03) cycle, model `e03-logreg2-1`. Created by `ml-training/train_exercise.py E03`, same layout as the other models (`/srv/models/e03_classifier.joblib` in the image). Signal: rotation of the vector wrist → middle of the palm from its start direction, mirrored so that a lift is positive on either side of the frame (`seriq_engine/exercises/e03.py`). Features `end_minus_start`, `return_from_peak`; calibration as for E02. Trained on volunteers 02–06 (101 videos); volunteer 10 (test) was evaluated once after the model was committed. Metrics: [docs/model-evaluation.md](../docs/model-evaluation.md#e03-wrist-lift).
