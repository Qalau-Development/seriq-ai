import csv
import json
from pathlib import Path

import numpy as np
from sklearn.base import clone
from sklearn.calibration import CalibratedClassifierCV
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import balanced_accuracy_score, confusion_matrix, f1_score, precision_recall_fscore_support
from sklearn.model_selection import LeaveOneGroupOut
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC

from seriq_engine.angles import elbow_angle_series
from seriq_engine.features import BASELINE_FEATURES, FEATURE_NAMES, compute_features, feature_vector

ROOT = Path(__file__).resolve().parents[1]
PROCESSED = ROOT / "data/processed"
RESULTS = ROOT / "ml-training/results"
TRAIN_VOLUNTEERS = {"01", "02", "03", "04", "05"}


# load_train_features — признаки и метки только по train (vol01–05), vol08 не читается
def load_train_features() -> tuple[list[dict], np.ndarray]:
    rows = [r for r in csv.DictReader((PROCESSED / "metadata.csv").open()) if r["split"] == "train"]
    assert {r["volunteer"] for r in rows} == TRAIN_VOLUNTEERS, "train must be volunteers 01–05 only"
    for r in rows:
        data = np.load(PROCESSED / "poses" / f"{r['video_id']}.npz")
        r["features"] = compute_features(elbow_angle_series(data["points"]), float(data["sample_fps"]))
    y = np.array([1 if r["label"] == "complete" else 0 for r in rows])
    return rows, y


# make_pipeline — заполнение пропусков, масштабирование и классификатор внутри одного Pipeline
def make_pipeline(classifier) -> Pipeline:
    return Pipeline([("impute", SimpleImputer(strategy="median")), ("scale", StandardScaler()), ("model", classifier)])


# candidates — базовая модель и кандидаты из docs/model-evaluation.md
def candidates() -> dict[str, tuple[list[str], Pipeline]]:
    return {
        "baseline_logreg_2f": (BASELINE_FEATURES, make_pipeline(LogisticRegression(class_weight="balanced"))),
        "logreg": (FEATURE_NAMES, make_pipeline(LogisticRegression(class_weight="balanced", max_iter=1000))),
        "random_forest": (FEATURE_NAMES, make_pipeline(RandomForestClassifier(n_estimators=300, min_samples_leaf=2, class_weight="balanced", random_state=0))),
        "gradient_boosting": (FEATURE_NAMES, make_pipeline(GradientBoostingClassifier(random_state=0))),
        "svm_rbf": (FEATURE_NAMES, make_pipeline(CalibratedClassifierCV(SVC(kernel="rbf", class_weight="balanced"), ensemble=False))),
    }


# loso_predict — out-of-fold вероятности complete по схеме LeaveOneGroupOut (группа = доброволец)
def loso_predict(pipeline: Pipeline, X: np.ndarray, y: np.ndarray, groups: np.ndarray) -> np.ndarray:
    proba = np.zeros(len(y))
    for train_idx, test_idx in LeaveOneGroupOut().split(X, y, groups):
        fitted = clone(pipeline).fit(X[train_idx], y[train_idx])
        proba[test_idx] = fitted.predict_proba(X[test_idx])[:, 1]
    return proba


# summarize — метрики out-of-fold: по каждому добровольцу и по всем вместе
def summarize(y: np.ndarray, proba: np.ndarray, groups: np.ndarray) -> dict:
    pred = (proba >= 0.5).astype(int)
    per_volunteer = {}
    for g in sorted(set(groups)):
        m = groups == g
        per_volunteer[g] = {
            "balanced_accuracy": balanced_accuracy_score(y[m], pred[m]),
            "f1_macro": f1_score(y[m], pred[m], average="macro"),
            "n": int(m.sum()),
        }
    bacc = [v["balanced_accuracy"] for v in per_volunteer.values()]
    f1s = [v["f1_macro"] for v in per_volunteer.values()]
    precision, recall, f1, _ = precision_recall_fscore_support(y, pred, labels=[1, 0], zero_division=0)
    return {
        "pooled": {
            "balanced_accuracy": balanced_accuracy_score(y, pred),
            "f1_macro": f1_score(y, pred, average="macro"),
            "precision": {"complete": precision[0], "incomplete": precision[1]},
            "recall": {"complete": recall[0], "incomplete": recall[1]},
            "f1": {"complete": f1[0], "incomplete": f1[1]},
            "confusion_matrix_rows_true_cols_pred_[complete,incomplete]": confusion_matrix(y, pred, labels=[1, 0]).tolist(),
        },
        "per_volunteer": per_volunteer,
        "balanced_accuracy_mean": float(np.mean(bacc)),
        "balanced_accuracy_std": float(np.std(bacc)),
        "f1_macro_mean": float(np.mean(f1s)),
        "f1_macro_std": float(np.std(f1s)),
    }


# main — LOSO-CV для всех моделей, таблица метрик и out-of-fold предсказания
def main() -> None:
    RESULTS.mkdir(parents=True, exist_ok=True)
    rows, y = load_train_features()
    groups = np.array([r["volunteer"] for r in rows])
    report, oof = {}, {}
    for name, (feature_names, pipeline) in candidates().items():
        X = np.array([feature_vector(r["features"], feature_names) for r in rows])
        oof[name] = loso_predict(pipeline, X, y, groups)
        report[name] = summarize(y, oof[name], groups)

    print(f"LOSO-CV, train vol01–05: {len(y)} videos ({y.sum()} complete, {len(y) - y.sum()} incomplete)\n")
    print(f"{'model':<20} {'BA pooled':>9} {'BA mean±std':>14} {'F1m pooled':>10} {'F1m mean±std':>14}  per-volunteer BA")
    for name, r in report.items():
        pv = " ".join(f"{g}:{v['balanced_accuracy']:.2f}" for g, v in r["per_volunteer"].items())
        print(f"{name:<20} {r['pooled']['balanced_accuracy']:>9.3f} {r['balanced_accuracy_mean']:>7.3f}±{r['balanced_accuracy_std']:.3f} "
              f"{r['pooled']['f1_macro']:>10.3f} {r['f1_macro_mean']:>7.3f}±{r['f1_macro_std']:.3f}  {pv}")
    for name, r in report.items():
        print(f"\n{name}: confusion matrix (rows true, cols pred) [complete, incomplete]: {r['pooled']['confusion_matrix_rows_true_cols_pred_[complete,incomplete]']}")

    (RESULTS / "loso_metrics.json").write_text(json.dumps(report, indent=2, default=float) + "\n")
    with (RESULTS / "loso_oof_predictions.csv").open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["video_id", "volunteer", "label", *[f"p_complete_{n}" for n in oof]])
        for i, r in enumerate(rows):
            writer.writerow([r["video_id"], r["volunteer"], r["label"], *[f"{oof[n][i]:.4f}" for n in oof]])


if __name__ == "__main__":
    main()
