# ml-training

Scripts that turn the E02 videos into the model `models/e02_classifier.joblib` and the numbers in [docs/model-evaluation.md](../docs/model-evaluation.md). They run on a developer laptop; the server only runs inference.

The feature code is not here: the scripts import `seriq_engine` from [ai-engine/](../ai-engine/), the same code the backend uses.

## Setup

From the repository root, Python 3.12:

```bash
uv venv --python 3.12 .venv
source .venv/bin/activate
uv pip install -e ai-engine -r ml-training/requirements.txt
```

**Dataset:** E02 extracted into `data/raw/` as described in [data/README.md](../data/README.md). It is never committed.

**Hand Landmarker weights:** version 1, the same file the backend image downloads and checks:

```bash
mkdir -p data/processed/mp_models
curl -L -o data/processed/mp_models/hand_landmarker.task \
  https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task
echo "fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1  data/processed/mp_models/hand_landmarker.task" | shasum -a 256 -c -
```

## Steps

| Step | Command | Reads | Writes |
|---|---|---|---|
| 1. Hand landmarks of the training videos | `python ml-training/extract_poses.py --split train` | `data/raw/` | `data/processed/poses/*.npz`, `data/processed/metadata.csv` |
| 2. Angle curves and a check of the elbow position | `python ml-training/explore.py` | cache of step 1, train only | `docs/figures/e02_angle_curves_train.png`; frames with the elbow drawn in `data/processed/qc/` (local only) |
| 3. LOSO-CV, final model | `python ml-training/train.py` | cache of step 1, train only | `ml-training/results/loso_*`, `models/e02_classifier.joblib` |
| 4. Hand landmarks of the test volunteer | `python ml-training/extract_poses.py --split test` | `data/raw/` | `data/processed/poses/*_Test.npz` |
| 5. **One** evaluation on volunteer 08 | `python ml-training/evaluate.py` | model, cache of step 4 | `ml-training/results/test_vol08_*`, `docs/figures/e02_confusion_vol08.png` |

Times on an Apple-silicon laptop: step 1 about 3 minutes for 107 videos, step 4 under a minute, the others a few seconds.

## End-to-end check on own recordings

```bash
python ml-training/e2e_check.py /path/to/recordings            # through https://seriq-ai.qalau.com/api/v1/analysis
python ml-training/e2e_check.py /path/to/recordings --local    # same code on this computer (needs SERIQ_HAND_MODEL_PATH and SERIQ_MODEL_PATH)
```

The scenario comes from the file name (`d_full_1.mp4`, `z_half_hold.mov`):

| Scenario | Expected |
|---|---|
| `full`, `other_arm` | `complete` |
| `half_back` | `incomplete` |
| `full_back` | `uncertain` |
| `bad_frame` | `uncertain` or `no_pose_detected` |
| `half_hold` | not defined: no such case in the dataset |

The script prints a table: label, confidence, warnings, start / maximum / end angle, `processing_ms`, match. It prints numbers only; it does not save videos or frames. Keep the recordings outside the repository.

## Rules

- **The class label comes from the folder name** (`Complete` / `Incomplete`), not from the file name: they disagree for volunteer 04. `video_id` includes the class and the split, because file names are not unique.
- **Volunteer 08 is the test set.** `train.py` and `explore.py` read only the training split; `train.py` also stops if it sees any volunteer other than 01–05. `evaluate.py` refuses to run again once `results/test_vol08_metrics.json` exists; `--force` exists only for a documented reason.
- **The committed model and results are final.** Running `train.py` again rewrites `models/e02_classifier.joblib` (with a new `trained_at`). Do not commit a retrained model: the test volunteer has already been used, so a new model cannot be evaluated honestly.
- scikit-learn must stay 1.9.1 in `ai-engine/pyproject.toml`, `backend/requirements.txt` and here.
- Nothing from `data/` goes into the repository: no videos, no frames, no landmark caches. Plots in `docs/figures/` contain curves and numbers only.
