import argparse
import csv
import importlib
import json
import platform
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import sklearn
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.svm import SVC
from sklearn.calibration import CalibratedClassifierCV
from sklearn.model_selection import LeaveOneGroupOut

from seriq_engine.classifier import CONFIDENCE_THRESHOLD, MAX_GAP_S, MIN_DETECTED_SHARE, MIN_VALID_POINTS, signal_quality
from seriq_engine.features import FEATURE_NAMES, feature_vector
from seriq_engine.hand import HandTrack
from train import ThresholdRule, loso_predict, main_model, scaled, summarize, with_uncertain

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw/An upper limb stroke rehabilitation exercise video/Exercise"
PROCESSED = ROOT / "data/processed"
RESULTS = ROOT / "ml-training/results"
LABELS = {"Complete": "complete", "Incomplete": "incomplete"}
MAIN = "main_logreg_2f_calibrated"
MAIN_FEATURES = ["extension_range", "end_minus_start"]

EXERCISES = {
    "E03": {"folder": "3_Lifting the Wrist", "train": {"02", "03", "04", "05", "06"}, "test": "10", "train_videos": 101, "version": "e03-logreg2-1"},
    "E04": {"folder": "4_Opening the Hand", "train": {"01", "02", "03", "04", "05", "06"}, "test": "09", "train_videos": 100, "pooled_calibration": True, "version": "e04-logreg2-1"},
    "E01": {"folder": "1_Lifting an Object", "train": {"01", "02", "03", "04", "05"}, "test": "07", "train_videos": 103, "version": "e01-logreg2-1"},
}


# list_videos — видео упражнения из одной части (Train/Test): класс из папки, доброволец из имени файла
def list_videos(exercise: str, split: str) -> list[dict]:
    rows = []
    for folder, label in LABELS.items():
        for path in sorted((RAW / EXERCISES[exercise]["folder"] / folder / split.capitalize()).glob("*.mp4")):
            rows.append({"video_id": f"{path.stem}_{folder}", "path": path, "volunteer": path.name[:2], "label": label})
    return rows


# cache_dir — кэш точек кисти: train общий с recon.py, test отдельно
def cache_dir(exercise: str, split: str) -> Path:
    suffix = "" if split == "train" else "_test"
    return PROCESSED / f"poses_{exercise.lower()}{suffix}"


# load_rows — ряд сигнала, признаки и качество сигнала по кэшу точек
def load_rows(exercise: str, split: str) -> list[dict]:
    module = importlib.import_module(f"seriq_engine.exercises.{exercise.lower()}")
    rows = list_videos(exercise, split)
    for r in rows:
        data = np.load(cache_dir(exercise, split) / f"{r['video_id']}.npz")
        track = HandTrack(points=data["points"], times=data["times"], info=None, frame_size=(0, 0))
        fps = float(data["sample_fps"])
        series = module.signal(track)
        r["series"], r["fps"], r["hand_share"] = series, fps, float(track.detected.mean())
        r["features"], r["quality"], r["measure"] = module.features(series, fps), signal_quality(series, fps), module.measure(series)
    return rows


# load_train — только train-добровольцы упражнения, тестовый доброволец не читается
def load_train(exercise: str) -> tuple[list[dict], np.ndarray, np.ndarray]:
    rows = load_rows(exercise, "train")
    assert {r["volunteer"] for r in rows} == EXERCISES[exercise]["train"], "unexpected volunteers in train"
    assert len(rows) == EXERCISES[exercise]["train_videos"], "unexpected number of train videos"
    y = np.array([1 if r["label"] == "complete" else 0 for r in rows])
    return rows, y, np.array([r["volunteer"] for r in rows])


# pooled_main_model — основная модель с калибровкой по всем out-of-fold предсказаниям сразу; нужна, когда у добровольцев train один класс
def pooled_main_model(groups: np.ndarray) -> CalibratedClassifierCV:
    splits = list(LeaveOneGroupOut().split(np.zeros(len(groups)), groups=groups))
    return CalibratedClassifierCV(scaled(LogisticRegression(class_weight="balanced")), method="sigmoid", cv=splits, ensemble=False)


# main_factory — фабрика основной модели упражнения
def main_factory(exercise: str):
    return pooled_main_model if EXERCISES[exercise].get("pooled_calibration") else main_model


# models — baseline A и B, основная модель и кандидаты для сравнения
def models(exercise: str) -> dict:
    threshold = lambda g: Pipeline([("impute", SimpleImputer(strategy="median")), ("rule", ThresholdRule())])
    return {
        "baseline_A_majority": (["extension_range"], lambda g: DummyClassifier(strategy="most_frequent"), "baseline"),
        "baseline_B_threshold_extension": (["extension_range"], threshold, "baseline"),
        MAIN: (MAIN_FEATURES, main_factory(exercise), "main"),
        "threshold_end_minus_start": (["end_minus_start"], threshold, "comparison"),
        "logreg_extension_only": (["extension_range"], lambda g: scaled(LogisticRegression(class_weight="balanced")), "comparison"),
        "logreg_9f": (FEATURE_NAMES, lambda g: scaled(LogisticRegression(class_weight="balanced", max_iter=1000)), "comparison"),
        "random_forest_9f": (FEATURE_NAMES, lambda g: scaled(RandomForestClassifier(n_estimators=300, min_samples_leaf=2, class_weight="balanced", random_state=0)), "comparison"),
        "svm_rbf_9f": (FEATURE_NAMES, lambda g: scaled(CalibratedClassifierCV(SVC(kernel="rbf", class_weight="balanced"), ensemble=False)), "comparison"),
    }


# quality_ranges — крайние значения качества сигнала и признаков по классам на train
def quality_ranges(rows: list[dict]) -> dict:
    out = {
        "detected_share_min": min(r["quality"].detected_share for r in rows),
        "longest_gap_s_max": max(r["quality"].longest_gap_s for r in rows),
        "valid_points_min": min(r["quality"].valid_points for r in rows),
    }
    for lab in ("complete", "incomplete"):
        for name in ("extension_range", "end_minus_start"):
            vals = [r["features"][name] for r in rows if r["label"] == lab]
            out[f"{name}_{lab}"] = [round(min(vals), 2), round(max(vals), 2)]
    return out


# print_table — краткая таблица LOSO-CV в консоль
def print_table(exercise: str, report: dict, y: np.ndarray) -> None:
    print(f"{exercise} LOSO-CV: {len(y)} videos ({y.sum()} complete, {len(y) - y.sum()} incomplete)\n")
    print(f"{'model':<32} {'BA all':>7} {'BA mean±std':>13} {'F1m all':>8}  confusion [[c→c, c→i], [i→c, i→i]]")
    for name, r in report["models"].items():
        a = r["all"]
        print(f"{name:<32} {a['balanced_accuracy']:>7.3f} {r['balanced_accuracy_mean']:>6.3f}±{r['balanced_accuracy_std']:.3f} {a['f1_macro']:>8.3f}  {a['confusion_matrix']['values']}")
    u = report["models"][MAIN]["uncertain"]
    c = u["confident_only"]
    print(f"\n{MAIN} with uncertain: coverage {u['coverage']:.3f} (signal {u['uncertain_by_signal_quality']}, confidence {u['uncertain_by_confidence']}), "
          f"confident BA {c['balanced_accuracy']}, F1m {c['f1_macro']:.3f}, confusion {c['confusion_matrix']['values']}")
    print("ranges on train:", json.dumps(report["train_ranges"]))


# save_model — обучает основную модель на всех train и сохраняет её с параметрами в models/
def save_model(exercise: str, rows: list[dict], y: np.ndarray, groups: np.ndarray, report: dict) -> Path:
    cfg = EXERCISES[exercise]
    X = np.array([feature_vector(r["features"], MAIN_FEATURES) for r in rows])
    bundle = {
        "model": main_factory(exercise)(groups).fit(X, y),
        "exercise": exercise,
        "features": MAIN_FEATURES,
        "confidence_threshold": CONFIDENCE_THRESHOLD,
        "signal_quality": {"min_detected_share": MIN_DETECTED_SHARE, "max_gap_s": MAX_GAP_S, "min_valid_points": MIN_VALID_POINTS},
        "model_version": cfg["version"],
        "trained_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "train_volunteers": sorted(cfg["train"]),
        "train_videos": int(len(y)),
        "sklearn_version": sklearn.__version__,
        "numpy_version": np.__version__,
        "python_version": platform.python_version(),
        "loso": {k: report["models"][MAIN][k] for k in ("balanced_accuracy_mean", "balanced_accuracy_std")},
    }
    path = ROOT / f"models/{exercise.lower()}_classifier.joblib"
    joblib.dump(bundle, path)
    print(f"\nsaved {path.relative_to(ROOT)}: {cfg['version']}, sklearn {sklearn.__version__}")
    return path


# main — LOSO-CV всех моделей по train упражнения, правило uncertain, сохранение результатов и модели
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("exercise", choices=sorted(EXERCISES))
    parser.add_argument("--no-save", action="store_true", help="only print LOSO-CV, do not write the model")
    args = parser.parse_args()
    ex = args.exercise.lower()

    rows, y, groups = load_train(args.exercise)
    report = {"exercise": args.exercise, "models": {}, "train_ranges": quality_ranges(rows)}
    oof = {}
    for name, (names, factory, role) in models(args.exercise).items():
        X = np.array([feature_vector(r["features"], names) for r in rows])
        oof[name] = loso_predict(factory, X, y, groups)
        report["models"][name] = summarize(y, oof[name], groups) | {"role": role, "features": names}
    report["models"][MAIN]["uncertain"], main_labels = with_uncertain(rows, y, oof[MAIN])
    print_table(args.exercise, report, y)
    if args.no_save:
        return

    RESULTS.mkdir(parents=True, exist_ok=True)
    (RESULTS / f"{ex}_loso_metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    with (RESULTS / f"{ex}_loso_oof_predictions.csv").open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["video_id", "volunteer", "label", "detected_share", "longest_gap_s", "measure", *MAIN_FEATURES, *[f"p_complete_{n}" for n in oof], "main_decision"])
        for i, r in enumerate(rows):
            q = r["quality"]
            writer.writerow([r["video_id"], r["volunteer"], r["label"], f"{q.detected_share:.3f}", f"{q.longest_gap_s:.2f}", r["measure"],
                             *[f"{r['features'][n]:.2f}" for n in MAIN_FEATURES], *[f"{oof[n][i]:.4f}" for n in oof], main_labels[i]])
    save_model(args.exercise, rows, y, groups, report)


if __name__ == "__main__":
    main()
