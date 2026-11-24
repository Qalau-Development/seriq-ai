import argparse
import csv
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from seriq_engine.classifier import decide, load_bundle, predict_complete
from seriq_engine.features import feature_vector
from seriq_engine.hand import track_hand
from train import classification_metrics
from train_exercise import EXERCISES, MAIN, RESULTS, ROOT, cache_dir, list_videos, load_rows, load_train, models

HAND_MODEL_DEFAULT = ROOT / "data/processed/mp_models/hand_landmarker.task"


# git — вывод команды git в корне репозитория
def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, cwd=ROOT).stdout.strip()


# extract_test — точки кисти по тестовым видео упражнения в кэш (первое чтение тестовых видео)
def extract_test(exercise: str) -> None:
    out = cache_dir(exercise, "test")
    out.mkdir(parents=True, exist_ok=True)
    for v in list_videos(exercise, "test"):
        target = out / f"{v['video_id']}.npz"
        if not target.exists():
            track = track_hand(v["path"], HAND_MODEL_DEFAULT)
            np.savez_compressed(target, points=track.points, times=track.times, sample_fps=track.info.sample_fps, duration_s=track.info.duration_s)


# plot_confusion — матрицы ошибок на тесте: все видео и только уверенные
def plot_confusion(exercise: str, version: str, all_cm: list, confident_cm: list, coverage: float, n: int) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(8.5, 3.8))
    for ax, cm, title in [(axes[0], all_cm, f"All {n} videos (before uncertain)"), (axes[1], confident_cm, f"Confident only (coverage {coverage:.0%})")]:
        ax.imshow(cm, cmap="Blues", vmin=0, vmax=max(10, np.max(cm)))
        for i in range(2):
            for j in range(2):
                ax.text(j, i, cm[i][j], ha="center", va="center", fontsize=14, color="white" if cm[i][j] > 5 else "black")
        ax.set_xticks([0, 1], ["complete", "incomplete"])
        ax.set_yticks([0, 1], ["complete", "incomplete"])
        ax.set_xlabel("Predicted")
        ax.set_ylabel("True")
        ax.set_title(title, fontsize=10)
    fig.suptitle(f"{exercise} test, volunteer {EXERCISES[exercise]['test']}: {version}")
    fig.tight_layout()
    fig.savefig(ROOT / f"docs/figures/{exercise.lower()}_confusion_test.png", dpi=110)


# main — один прогон зафиксированной модели упражнения на тестовом добровольце
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("exercise", choices=sorted(EXERCISES))
    parser.add_argument("--force", action="store_true", help="rerun even if test results exist (must be justified in the report)")
    args = parser.parse_args()
    ex = args.exercise
    out = RESULTS / f"{ex.lower()}_test_metrics.json"
    model_file = ROOT / f"models/{ex.lower()}_classifier.joblib"
    if out.exists() and not args.force:
        sys.exit(f"{out.relative_to(ROOT)} already exists: the test set is evaluated once")
    rel = str(model_file.relative_to(ROOT))
    if not git("ls-files", rel) or git("status", "--porcelain", "--", rel, "ml-training", "ai-engine"):
        sys.exit("model, features or thresholds are not committed: commit them before the test run")

    extract_test(ex)
    test = load_rows(ex, "test")
    assert {r["volunteer"] for r in test} == {EXERCISES[ex]["test"]} and len(test) == 20, "unexpected test volunteer or size"
    bundle = load_bundle(str(model_file))
    y = np.array([1 if r["label"] == "complete" else 0 for r in test])
    p_main = np.array([predict_complete(bundle, r["features"]) for r in test])
    labels = [decide(p, r["quality"].ok, bundle["confidence_threshold"])[0] for r, p in zip(test, p_main)]
    confident = np.array([lab != "uncertain" for lab in labels])
    pred = np.array([1 if lab == "complete" else 0 for lab in labels])

    train, y_train, groups = load_train(ex)
    baselines = {}
    for name, (names, factory, role) in models(ex).items():
        if role == "baseline":
            fit = factory(groups).fit(np.array([feature_vector(r["features"], names) for r in train]), y_train)
            baselines[name] = fit.predict_proba(np.array([feature_vector(r["features"], names) for r in test]))[:, 1]

    report = {
        "exercise": ex,
        "evaluated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "model_version": bundle["model_version"],
        "model_sha256": hashlib.sha256(model_file.read_bytes()).hexdigest(),
        "git_commit": git("rev-parse", "HEAD"),
        "n_videos": len(test),
        "hand_share": {"min": min(r["hand_share"] for r in test), "median": float(np.median([r["hand_share"] for r in test]))},
        MAIN: {
            "all": classification_metrics(y, (p_main >= 0.5).astype(int)),
            "coverage": float(confident.mean()),
            "uncertain_by_signal_quality": int(sum(not r["quality"].ok for r in test)),
            "uncertain_by_confidence": int(sum(r["quality"].ok and lab == "uncertain" for r, lab in zip(test, labels))),
            "confident_only": classification_metrics(y[confident], pred[confident]),
        },
        **{name: {"all": classification_metrics(y, (p >= 0.5).astype(int))} for name, p in baselines.items()},
    }
    out.write_text(json.dumps(report, indent=2) + "\n")
    with (RESULTS / f"{ex.lower()}_test_predictions.csv").open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["video_id", "label", "hand_share", "detected_share", "longest_gap_s", "measure", "p_complete", "decision", *[f"p_{n}" for n in baselines]])
        for i, r in enumerate(test):
            q = r["quality"]
            writer.writerow([r["video_id"], r["label"], f"{r['hand_share']:.3f}", f"{q.detected_share:.3f}", f"{q.longest_gap_s:.2f}", r["measure"],
                             f"{p_main[i]:.4f}", labels[i], *[f"{baselines[n][i]:.4f}" for n in baselines]])
    plot_confusion(ex, bundle["model_version"], report[MAIN]["all"]["confusion_matrix"]["values"], report[MAIN]["confident_only"]["confusion_matrix"]["values"], report[MAIN]["coverage"], len(test))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
