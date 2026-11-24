import csv
import json
import platform
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import sklearn
from sklearn.base import BaseEstimator, ClassifierMixin
from sklearn.calibration import CalibratedClassifierCV
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import balanced_accuracy_score, confusion_matrix, f1_score, precision_recall_fscore_support
from sklearn.model_selection import LeaveOneGroupOut
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC

from seriq_engine.angles import K_FOREARM, elbow_angle_series
from seriq_engine.classifier import CONFIDENCE_THRESHOLD, MAX_GAP_S, MIN_DETECTED_SHARE, MIN_VALID_POINTS, decide, signal_quality
from seriq_engine.features import FEATURE_NAMES, MODEL_FEATURES, compute_features, feature_vector

ROOT = Path(__file__).resolve().parents[1]
PROCESSED = ROOT / "data/processed"
RESULTS = ROOT / "ml-training/results"
MODEL_PATH = ROOT / "models/e02_classifier.joblib"
MODEL_VERSION = "e02-logreg2-1"
MAIN = "main_logreg_2f_calibrated"
TRAIN_VOLUNTEERS = {"01", "02", "03", "04", "05"}


# ThresholdRule — baseline B: complete, если признак больше порога; порог подбирается на обучающих данных
class ThresholdRule(ClassifierMixin, BaseEstimator):
    # fit — выбирает порог с лучшей balanced accuracy
    def fit(self, X, y):
        x = np.asarray(X, dtype=float)[:, 0]
        values = np.unique(x)
        cuts = (values[:-1] + values[1:]) / 2 if len(values) > 1 else values
        scores = [balanced_accuracy_score(y, (x > t).astype(int)) for t in cuts]
        self.threshold_ = float(cuts[int(np.argmax(scores))])
        self.classes_ = np.array([0, 1])
        return self

    # predict_proba — 1 для complete выше порога, иначе 0
    def predict_proba(self, X):
        p = (np.asarray(X, dtype=float)[:, 0] > self.threshold_).astype(float)
        return np.c_[1 - p, p]

    # predict — класс по порогу
    def predict(self, X):
        return (self.predict_proba(X)[:, 1] >= 0.5).astype(int)


# load_train — признаки, качество сигнала и метки только по train (vol01–05), vol08 не читается
def load_train() -> tuple[list[dict], np.ndarray, np.ndarray]:
    rows = [r for r in csv.DictReader((PROCESSED / "metadata.csv").open()) if r["split"] == "train"]
    assert {r["volunteer"] for r in rows} == TRAIN_VOLUNTEERS, "train must be volunteers 01–05 only"
    for r in rows:
        data = np.load(PROCESSED / "poses" / f"{r['video_id']}.npz")
        angles, fps = elbow_angle_series(data["points"]), float(data["sample_fps"])
        r["features"], r["quality"] = compute_features(angles, fps), signal_quality(angles, fps)
    y = np.array([1 if r["label"] == "complete" else 0 for r in rows])
    return rows, y, np.array([r["volunteer"] for r in rows])


# scaled — заполнение пропусков, масштабирование и классификатор в одном Pipeline
def scaled(classifier) -> Pipeline:
    return Pipeline([("impute", SimpleImputer(strategy="median")), ("scale", StandardScaler()), ("model", classifier)])


# main_model — логрегрессия на 2 признаках с калибровкой sigmoid на вложенном LOSO
def main_model(groups: np.ndarray) -> CalibratedClassifierCV:
    splits = list(LeaveOneGroupOut().split(np.zeros(len(groups)), groups=groups))
    return CalibratedClassifierCV(scaled(LogisticRegression(class_weight="balanced")), method="sigmoid", cv=splits)


# models — baseline A и B, основная модель и кандидаты для сравнения: (признаки, фабрика по группам обучения, роль)
def models() -> dict:
    return {
        "baseline_A_majority": (["end_minus_start"], lambda g: DummyClassifier(strategy="most_frequent"), "baseline"),
        "baseline_B_threshold": (["end_minus_start"], lambda g: Pipeline([("impute", SimpleImputer(strategy="median")), ("rule", ThresholdRule())]), "baseline"),
        MAIN: (MODEL_FEATURES, main_model, "main"),
        "logreg_9f": (FEATURE_NAMES, lambda g: scaled(LogisticRegression(class_weight="balanced", max_iter=1000)), "comparison"),
        "random_forest_9f": (FEATURE_NAMES, lambda g: scaled(RandomForestClassifier(n_estimators=300, min_samples_leaf=2, class_weight="balanced", random_state=0)), "comparison"),
        "gradient_boosting_9f": (FEATURE_NAMES, lambda g: scaled(GradientBoostingClassifier(random_state=0)), "comparison"),
        "svm_rbf_9f": (FEATURE_NAMES, lambda g: scaled(CalibratedClassifierCV(SVC(kernel="rbf", class_weight="balanced"), ensemble=False)), "comparison"),
    }


# loso_predict — out-of-fold вероятности complete по LeaveOneGroupOut (группа = доброволец)
def loso_predict(factory, X: np.ndarray, y: np.ndarray, groups: np.ndarray) -> np.ndarray:
    proba = np.zeros(len(y))
    for train_idx, test_idx in LeaveOneGroupOut().split(X, y, groups):
        model = factory(groups[train_idx]).fit(X[train_idx], y[train_idx])
        proba[test_idx] = model.predict_proba(X[test_idx])[:, 1]
    return proba


# classification_metrics — balanced accuracy, precision, recall, F1 и матрица ошибок для complete/incomplete
def classification_metrics(y: np.ndarray, pred: np.ndarray) -> dict:
    precision, recall, f1, _ = precision_recall_fscore_support(y, pred, labels=[1, 0], zero_division=0)
    return {
        "n": int(len(y)),
        "balanced_accuracy": float(balanced_accuracy_score(y, pred)) if len(set(y)) > 1 else None,
        "f1_macro": float(f1_score(y, pred, average="macro", labels=[1, 0], zero_division=0)),
        "precision": {"complete": float(precision[0]), "incomplete": float(precision[1])},
        "recall": {"complete": float(recall[0]), "incomplete": float(recall[1])},
        "f1": {"complete": float(f1[0]), "incomplete": float(f1[1])},
        "confusion_matrix": {"rows_true_cols_pred": ["complete", "incomplete"], "values": confusion_matrix(y, pred, labels=[1, 0]).tolist()},
    }


# summarize — метрики по всем видео, по каждому добровольцу (среднее и разброс)
def summarize(y: np.ndarray, proba: np.ndarray, groups: np.ndarray) -> dict:
    pred = (proba >= 0.5).astype(int)
    per = {g: classification_metrics(y[groups == g], pred[groups == g]) for g in sorted(set(groups))}
    bacc = [p["balanced_accuracy"] for p in per.values() if p["balanced_accuracy"] is not None]
    f1m = [p["f1_macro"] for p in per.values()]
    return {
        "all": classification_metrics(y, pred),
        "per_volunteer": {g: {"balanced_accuracy": p["balanced_accuracy"], "f1_macro": p["f1_macro"], "n": p["n"]} for g, p in per.items()},
        "balanced_accuracy_mean": float(np.mean(bacc)),
        "balanced_accuracy_std": float(np.std(bacc)),
        "f1_macro_mean": float(np.mean(f1m)),
        "f1_macro_std": float(np.std(f1m)),
    }


# with_uncertain — правило uncertain (качество сигнала и confidence < порога): coverage и метрики на уверенных
def with_uncertain(rows: list[dict], y: np.ndarray, proba: np.ndarray) -> tuple[dict, list[str]]:
    labels = [decide(p, r["quality"].ok)[0] for r, p in zip(rows, proba)]
    confident = np.array([lab != "uncertain" for lab in labels])
    pred = np.array([1 if lab == "complete" else 0 for lab in labels])
    return {
        "coverage": float(confident.mean()),
        "uncertain_by_signal_quality": int(sum(not r["quality"].ok for r in rows)),
        "uncertain_by_confidence": int(sum(r["quality"].ok and lab == "uncertain" for r, lab in zip(rows, labels))),
        "confident_only": classification_metrics(y[confident], pred[confident]),
    }, labels


# print_table — краткая таблица LOSO-CV в консоль
def print_table(report: dict, y: np.ndarray) -> None:
    print(f"LOSO-CV, train vol01–05: {len(y)} videos ({y.sum()} complete, {len(y) - y.sum()} incomplete)\n")
    print(f"{'model':<28} {'BA all':>7} {'BA mean±std':>13} {'F1m all':>8}  confusion [[c→c, c→i], [i→c, i→i]]")
    for name, r in report.items():
        a = r["all"]
        print(f"{name:<28} {a['balanced_accuracy']:>7.3f} {r['balanced_accuracy_mean']:>6.3f}±{r['balanced_accuracy_std']:.3f} {a['f1_macro']:>8.3f}  {a['confusion_matrix']['values']}")
    u = report[MAIN]["uncertain"]
    c = u["confident_only"]
    print(f"\n{MAIN} with uncertain: coverage {u['coverage']:.3f} (signal {u['uncertain_by_signal_quality']}, confidence {u['uncertain_by_confidence']}), "
          f"confident BA {c['balanced_accuracy']:.3f}, F1m {c['f1_macro']:.3f}, confusion {c['confusion_matrix']['values']}")


# save_model — обучает основную модель на всех train и сохраняет её с параметрами в models/
def save_model(rows: list[dict], y: np.ndarray, groups: np.ndarray, report: dict) -> None:
    X = np.array([feature_vector(r["features"], MODEL_FEATURES) for r in rows])
    bundle = {
        "model": main_model(groups).fit(X, y),
        "features": MODEL_FEATURES,
        "confidence_threshold": CONFIDENCE_THRESHOLD,
        "signal_quality": {"min_detected_share": MIN_DETECTED_SHARE, "max_gap_s": MAX_GAP_S, "min_valid_points": MIN_VALID_POINTS},
        "k_forearm": K_FOREARM,
        "model_version": MODEL_VERSION,
        "trained_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "train_volunteers": sorted(TRAIN_VOLUNTEERS),
        "train_videos": int(len(y)),
        "sklearn_version": sklearn.__version__,
        "numpy_version": np.__version__,
        "python_version": platform.python_version(),
        "loso": {k: report[MAIN][k] for k in ("balanced_accuracy_mean", "balanced_accuracy_std")},
    }
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(bundle, MODEL_PATH)
    print(f"\nsaved {MODEL_PATH.relative_to(ROOT)}: {MODEL_VERSION}, sklearn {sklearn.__version__}")


# main — LOSO-CV всех моделей, правило uncertain для основной, сохранение результатов и модели
def main() -> None:
    RESULTS.mkdir(parents=True, exist_ok=True)
    rows, y, groups = load_train()
    report, oof, roles = {}, {}, {}
    for name, (names, factory, role) in models().items():
        X = np.array([feature_vector(r["features"], names) for r in rows])
        oof[name] = loso_predict(factory, X, y, groups)
        report[name] = summarize(y, oof[name], groups) | {"role": role, "features": names}
    report[MAIN]["uncertain"], main_labels = with_uncertain(rows, y, oof[MAIN])
    print_table(report, y)

    (RESULTS / "loso_metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    with (RESULTS / "loso_oof_predictions.csv").open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["video_id", "volunteer", "label", "detected_share", "longest_gap_s", *[f"p_complete_{n}" for n in oof], "main_decision"])
        for i, r in enumerate(rows):
            q = r["quality"]
            writer.writerow([r["video_id"], r["volunteer"], r["label"], f"{q.detected_share:.3f}", f"{q.longest_gap_s:.2f}",
                             *[f"{oof[n][i]:.4f}" for n in oof], main_labels[i]])
    save_model(rows, y, groups, report)


if __name__ == "__main__":
    main()
