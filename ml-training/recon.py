import argparse
import json
import sys
from pathlib import Path

import numpy as np

from seriq_engine.hand import track_hand

ROOT = Path(__file__).resolve().parents[1]
EXERCISES_ROOT = ROOT / "data/raw/An upper limb stroke rehabilitation exercise video/Exercise"
FOLDERS = {"E01": "1_Lifting an Object", "E02": "2_Extending the Elbow", "E03": "3_Lifting the Wrist", "E04": "4_Opening the Hand"}
TRAIN_VOLUNTEERS = {"E01": "01-05", "E03": "02-06", "E04": "01-06"}
HAND_MODEL = ROOT / "data/processed/mp_models/hand_landmarker.task"
LABELS = {"Complete": "complete", "Incomplete": "incomplete"}
TIPS = [4, 8, 12, 16, 20]


# list_train_videos — train-видео упражнения: класс из папки, доброволец из имени файла, test не читается
def list_train_videos(exercise: str) -> list[dict]:
    rows = []
    for folder, label in LABELS.items():
        for path in sorted((EXERCISES_ROOT / FOLDERS[exercise] / folder / "Train").glob("*.mp4")):
            rows.append({"video_id": f"{path.stem}_{folder}", "path": path, "volunteer": path.name[:2], "label": label})
    return rows


# extract — точки кисти по train-видео в кэш data/processed/poses_<exercise>/
def extract(exercise: str) -> None:
    out = ROOT / f"data/processed/poses_{exercise.lower()}"
    out.mkdir(parents=True, exist_ok=True)
    for v in list_train_videos(exercise):
        target = out / f"{v['video_id']}.npz"
        if target.exists():
            continue
        track = track_hand(v["path"], HAND_MODEL)
        np.savez_compressed(target, points=track.points, times=track.times, sample_fps=track.info.sample_fps, duration_s=track.info.duration_s)
        print(f"{exercise} {v['video_id']}: hand {track.detected.mean():.0%}", flush=True)


# fill — линейная интерполяция пропусков для разведочных графиков
def fill(values: np.ndarray) -> np.ndarray:
    ok = ~np.isnan(values)
    if ok.sum() < 2:
        return values
    return np.interp(np.arange(len(values)), np.flatnonzero(ok), values[ok])


# openness_signal — E04: среднее расстояние кончиков пальцев до запястья / размер ладони, в процентах от начала
def openness_signal(points: np.ndarray) -> np.ndarray:
    wrist, palm = points[:, 0], np.linalg.norm(points[:, 9] - points[:, 0], axis=1)
    reach = np.mean([np.linalg.norm(points[:, t] - wrist, axis=1) for t in TIPS], axis=0) / palm
    start = np.nanmean(reach[: max(1, len(reach) // 10)])
    return 100.0 * reach / start


# wrist_lift_signal — E03: поворот вектора запястье → середина ладони от начального направления, градусы
def wrist_lift_signal(points: np.ndarray) -> np.ndarray:
    vec = points[:, 9] - points[:, 0]
    angle = np.unwrap(np.arctan2(-vec[:, 1], vec[:, 0]))
    angle = np.degrees(angle)
    return angle - np.nanmean(angle[: max(1, len(angle) // 10)])


# lift_height_signal — E01: подъём запястья вверх от начала в длинах кисти
def lift_height_signal(points: np.ndarray) -> np.ndarray:
    hand_len = np.nanmedian(np.linalg.norm(points[:, 9] - points[:, 0], axis=1))
    y = points[:, 0, 1]
    return (np.nanmean(y[: max(1, len(y) // 10)]) - y) / hand_len


SIGNALS = {"E01": lift_height_signal, "E03": wrist_lift_signal, "E04": openness_signal}


# report — доля кадров с кистью по добровольцам, максимум сигнала по классам и график кривых
def report(exercise: str) -> dict:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    videos = list_train_videos(exercise)
    cache = ROOT / f"data/processed/poses_{exercise.lower()}"
    rows = []
    for v in videos:
        d = np.load(cache / f"{v['video_id']}.npz")
        points = d["points"]
        found = ~np.isnan(points[:, 0, 0])
        series = SIGNALS[exercise](points)
        rows.append({**v, "share": float(found.mean()), "times": d["times"], "series": series, "dur": float(d["duration_s"]), "peak": float(np.nanmax(series)), "trough": float(np.nanmin(series))})

    volunteers = sorted({r["volunteer"] for r in rows})
    summary = {"detected_share": {}, "peak_by_class": {}}
    for vol in volunteers:
        shares = [r["share"] for r in rows if r["volunteer"] == vol]
        summary["detected_share"][vol] = {"videos": len(shares), "min": round(min(shares), 3), "median": round(float(np.median(shares)), 3), "mean": round(float(np.mean(shares)), 3)}
        summary["peak_by_class"][vol] = {
            lab: [round(r["peak"], 2) for r in rows if r["volunteer"] == vol and r["label"] == lab] for lab in ("complete", "incomplete")
        }

    fig, axes = plt.subplots(2, len(volunteers), figsize=(3.2 * len(volunteers), 6), sharey=True, squeeze=False)
    for col, vol in enumerate(volunteers):
        for row, lab in enumerate(("complete", "incomplete")):
            ax = axes[row, col]
            for r in rows:
                if r["volunteer"] == vol and r["label"] == lab:
                    ax.plot(r["times"], r["series"], lw=0.8, alpha=0.7)
            ax.set_title(f"vol{vol} {lab}", fontsize=9)
    fig.supxlabel("time, s")
    fig.supylabel(exercise + " signal")
    fig.tight_layout()
    figures = ROOT / "docs/figures"
    figures.mkdir(exist_ok=True)
    fig.savefig(figures / f"{exercise.lower()}_signal_train.png", dpi=110)
    return summary


# main — извлечение и отчёт по одному упражнению, только train
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("exercise", choices=sorted(SIGNALS))
    parser.add_argument("--report-only", action="store_true")
    args = parser.parse_args()
    if not args.report_only:
        extract(args.exercise)
    result = report(args.exercise)
    out = ROOT / f"data/processed/recon_{args.exercise.lower()}.json"
    out.write_text(json.dumps(result, indent=1))
    print(json.dumps(result, indent=1))


if __name__ == "__main__":
    sys.exit(main())
