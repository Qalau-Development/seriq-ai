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

from seriq_engine.angles import elbow_angle_series
from seriq_engine.classifier import decide, load_bundle, predict_complete, signal_quality
from seriq_engine.features import compute_features, feature_vector
from train import MAIN, MODEL_PATH, RESULTS, classification_metrics, load_train, models

ROOT = Path(__file__).resolve().parents[1]
PROCESSED = ROOT / "data/processed"
FIGURES = ROOT / "docs/figures"
OUT = RESULTS / "test_vol08_metrics.json"


# load_test — признаки и качество сигнала по тестовому добровольцу 08
def load_test() -> list[dict]:
    rows = [r for r in csv.DictReader((PROCESSED / "metadata.csv").open()) if r["split"] == "test"]
    assert {r["volunteer"] for r in rows} == {"08"} and len(rows) == 20, "test must be volunteer 08, 20 videos"
    for r in rows:
        data = np.load(PROCESSED / "poses" / f"{r['video_id']}.npz")
        angles, fps = elbow_angle_series(data["points"]), float(data["sample_fps"])
        r["features"], r["quality"] = compute_features(angles, fps), signal_quality(angles, fps)
        r["hand_share"] = float((~np.isnan(data["points"][:, 0, 0])).mean())
    return rows


# baseline_predictions — baseline A и B, обученные на всех train, на тесте
def baseline_predictions(test: list[dict]) -> dict[str, np.ndarray]:
    train, y, groups = load_train()
    out = {}
    for name, (names, factory, role) in models().items():
        if role != "baseline":
            continue
        model = factory(groups).fit(np.array([feature_vector(r["features"], names) for r in train]), y)
        out[name] = model.predict_proba(np.array([feature_vector(r["features"], names) for r in test]))[:, 1]
    return out


# plot_confusion — матрицы ошибок на vol08: все видео и только уверенные
def plot_confusion(all_cm: list, confident_cm: list, coverage: float) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(8.5, 3.8))
    for ax, cm, title in [(axes[0], all_cm, "All 20 videos (before uncertain)"), (axes[1], confident_cm, f"Confident only (coverage {coverage:.0%})")]:
        ax.imshow(cm, cmap="Blues", vmin=0, vmax=max(10, np.max(cm)))
        for i in range(2):
            for j in range(2):
                ax.text(j, i, cm[i][j], ha="center", va="center", fontsize=14, color="white" if cm[i][j] > 5 else "black")
        ax.set_xticks([0, 1], ["complete", "incomplete"])
        ax.set_yticks([0, 1], ["complete", "incomplete"])
        ax.set_xlabel("Predicted")
        ax.set_ylabel("True")
        ax.set_title(title, fontsize=10)
    fig.suptitle("E02 test, volunteer 08 (webcam, landscape): e02-logreg2-1")
    fig.tight_layout()
    fig.savefig(FIGURES / "e02_confusion_vol08.png", dpi=110)


# main — один прогон зафиксированной модели на vol08
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="rerun even if test results exist (must be justified in the report)")
    args = parser.parse_args()
    if OUT.exists() and not args.force:
        sys.exit(f"{OUT.relative_to(ROOT)} already exists: the test set is evaluated once")

    bundle = load_bundle(str(MODEL_PATH))
    test = load_test()
    y = np.array([1 if r["label"] == "complete" else 0 for r in test])
    p_main = np.array([predict_complete(bundle, r["features"]) for r in test])
    labels = [decide(p, r["quality"].ok, bundle["confidence_threshold"])[0] for r, p in zip(test, p_main)]
    confident = np.array([lab != "uncertain" for lab in labels])
    pred = np.array([1 if lab == "complete" else 0 for lab in labels])
    baselines = baseline_predictions(test)

    report = {
        "evaluated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "model_version": bundle["model_version"],
        "model_sha256": hashlib.sha256(MODEL_PATH.read_bytes()).hexdigest(),
        "git_commit": subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True, cwd=ROOT).stdout.strip(),
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
    OUT.write_text(json.dumps(report, indent=2) + "\n")
    with (RESULTS / "test_vol08_predictions.csv").open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["video_id", "label", "hand_share", "detected_share", "longest_gap_s", "p_complete", "decision", *[f"p_{n}" for n in baselines]])
        for i, r in enumerate(test):
            q = r["quality"]
            writer.writerow([r["video_id"], r["label"], f"{r['hand_share']:.3f}", f"{q.detected_share:.3f}", f"{q.longest_gap_s:.2f}",
                             f"{p_main[i]:.4f}", labels[i], *[f"{baselines[n][i]:.4f}" for n in baselines]])
    plot_confusion(report[MAIN]["all"]["confusion_matrix"]["values"], report[MAIN]["confident_only"]["confusion_matrix"]["values"], report[MAIN]["coverage"])
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
