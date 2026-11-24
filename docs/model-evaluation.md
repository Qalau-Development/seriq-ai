# Model Evaluation

Status: **Pending.** No model has been trained. This document fixes the evaluation methodology before training starts, so that results cannot be tuned to the test set afterwards.

## Task

Binary classification of one elbow extension (E02) cycle as `complete` or `incomplete`, with a confidence estimate; low-confidence decisions become `uncertain`. Input: the elbow angle series (and, if useful, keypoint coordinates) extracted by pose estimation from one video. One video contains one cycle. See [dataset-analysis.md](dataset-analysis.md) for the data.

## Data split

The split is strictly by volunteer ID, as required by the case specification. Videos of one person never appear in two different splits.

| Split | Volunteers | Complete | Incomplete | Purpose |
|---|---|---|---|---|
| Train | 01, 02, 03, 04, 05 | 50 | 57 | Model selection with Leave-One-Subject-Out cross-validation (LOSO-CV) |
| Test | 08 | 10 | 10 | Independent final evaluation, used once |

- **LOSO-CV:** five folds; in each fold one training volunteer is held out for validation and the model is trained on the other four. This uses all five people and shows the spread of results between people. A fixed validation set would hold only one or two people.
- **The test volunteer 08 is never used** for choosing features, models, hyperparameters, the confidence threshold or calibration. The test set is evaluated once, after all choices are fixed.
- The volunteer ID is parsed from the first two digits of the file name. The class label is taken from the folder name (see the label issue in [dataset-analysis.md](dataset-analysis.md#label-issue-volunteer-04)).
- Classes are close to balanced (50 / 57). If a model needs it, class weights are used instead of resampling.

## Models

| Role | Model | Status |
|---|---|---|
| Baseline | Logistic regression on 2–3 simple elbow-angle features (for example, range of motion and final angle) | Pending |
| Candidates for the main model | Logistic regression on the full feature set, Random Forest, Gradient Boosting, SVM | Pending |

The main model is the candidate with the best LOSO-CV balanced accuracy; the spread across volunteers is taken into account. Neural networks are considered only if they clearly outperform the simpler models; with 107 training videos from five people this is unlikely. Scaling and other preprocessing are part of the model pipeline and are fitted inside each fold.

## Metrics

Reported for the baseline and the main model, on LOSO-CV (per held-out volunteer, mean and spread) and on the test set:

| Metric | Notes |
|---|---|
| **Balanced accuracy** | Required by the case. Mean of recall for `complete` and recall for `incomplete` |
| **Precision** | Per class |
| **Recall** | Per class |
| **F1 score** | Required by the case. Per class and macro average |
| **Confusion matrix** | Required by the case. Rows = true class, columns = predicted class |
| Coverage | Share of cycles not marked `uncertain` |

Classification metrics are computed on the two classes `complete` / `incomplete` before the `uncertain` rule is applied, and also on the confident cycles only, together with coverage. Both are reported, so that the threshold cannot hide errors.

## Confidence and the `uncertain` threshold

1. The model outputs the probability `p` that the cycle is complete; `confidence = max(p, 1 - p)`.
2. **Calibration, if needed.** If out-of-fold probabilities are poorly calibrated (checked with a reliability plot on LOSO-CV), the model is calibrated with `CalibratedClassifierCV` inside the training folds.
3. **Threshold choice.** Out-of-fold predictions from LOSO-CV on the five training volunteers are used to trade coverage against balanced accuracy of confident predictions. The threshold is fixed before the test evaluation.
4. If `confidence < threshold`, the label is `uncertain`. The exact rules and the user-facing verdict are in [api.md](api.md#label-and-verdict-rules).

## Results

| Model | Evaluation | Balanced accuracy | Precision | Recall | F1 (macro) | Confusion matrix | Coverage |
|---|---|---|---|---|---|---|---|
| Baseline | LOSO-CV | Pending | Pending | Pending | Pending | Pending | Pending |
| Main model | LOSO-CV | Pending | Pending | Pending | Pending | Pending | Pending |
| Baseline | Test (vol 08) | Pending | Pending | Pending | Pending | Pending | Pending |
| Main model | Test (vol 08) | Pending | Pending | Pending | Pending | Pending | Pending |

Selected threshold: Pending. Analysis time and memory on the server: not measured yet.

## Known limitations

- The test set is one person (20 videos), so test metrics have high variance and do not show how the model works for other people.
- Training videos are portrait phone recordings; test videos are landscape webcam recordings.
- The health status of the volunteers is not stated in the dataset description.
- The labels of volunteer 04 are inconsistent between folder and file name; the folder is used.
- In the dataset the shoulder may be outside the frame; this may limit which angle can be measured.
