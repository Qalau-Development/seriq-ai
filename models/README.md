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
