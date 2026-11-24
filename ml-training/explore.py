import csv
from pathlib import Path

import cv2
import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from seriq_engine.angles import elbow_angle_series, elbow_center
from seriq_engine.hand import WRIST

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw/An upper limb stroke rehabilitation exercise video/Exercise/2_Extending the Elbow"
PROCESSED = ROOT / "data/processed"
FIGURES = ROOT / "docs/figures"
QC_DIR = PROCESSED / "qc"
COLORS = {"complete": "#1a9850", "incomplete": "#d73027"}


# load_train — метаданные и кэш точек только для train (vol01–05)
def load_train() -> list[dict]:
    rows = [r for r in csv.DictReader((PROCESSED / "metadata.csv").open()) if r["split"] == "train"]
    for r in rows:
        data = np.load(PROCESSED / "poses" / f"{r['video_id']}.npz")
        r["points"], r["sample_fps"] = data["points"], float(data["sample_fps"])
    return rows


# fit_quality — относительная невязка окружности: RMS(|запястье − центр| − r) / r
def fit_quality(points: np.ndarray) -> float:
    center, radius = elbow_center(points)
    wrist = points[~np.isnan(points[:, WRIST, 0]), WRIST]
    return float(np.sqrt(np.mean((np.linalg.norm(wrist - center, axis=1) - radius) ** 2)) / radius)


# draw_qc — кадры видео с локтем и запястьем для ручной проверки (только локально)
def draw_qc(row: dict) -> None:
    center, radius = elbow_center(row["points"])
    cap = cv2.VideoCapture(str(RAW / row["path"]))
    step = max(1, round(cap.get(cv2.CAP_PROP_FPS) / row["sample_fps"]))
    tiles = []
    for k in np.linspace(0, len(row["points"]) - 1, 4).astype(int):
        cap.set(cv2.CAP_PROP_POS_FRAMES, int(k * step))
        ok, frame = cap.read()
        if not ok:
            continue
        frame = cv2.resize(frame, None, fx=min(1, 960 / max(frame.shape[:2])), fy=min(1, 960 / max(frame.shape[:2])))
        c = tuple(int(v) for v in center)
        cv2.circle(frame, c, int(radius), (0, 255, 0), 2)
        cv2.circle(frame, c, 10, (0, 255, 0), -1)
        wrist = row["points"][k, WRIST]
        if not np.isnan(wrist[0]):
            cv2.line(frame, c, tuple(int(v) for v in wrist), (0, 255, 0), 3)
        tiles.append(cv2.resize(frame, (240, int(240 * frame.shape[0] / frame.shape[1]))))
    cap.release()
    cv2.imwrite(str(QC_DIR / f"{row['video_id']}.jpg"), np.hstack(tiles))


# plot_curves — угол локтя complete против incomplete по каждому добровольцу
def plot_curves(rows: list[dict]) -> None:
    volunteers = sorted({r["volunteer"] for r in rows})
    fig, axes = plt.subplots(1, len(volunteers), figsize=(4 * len(volunteers), 3.6), sharey=True)
    for ax, vol in zip(axes, volunteers):
        for r in [r for r in rows if r["volunteer"] == vol]:
            t = np.linspace(0, 1, len(r["angle"]))
            ax.plot(t, r["angle"], color=COLORS[r["label"]], alpha=0.55, linewidth=1.2)
        ax.set_title(f"Volunteer {vol}")
        ax.set_xlabel("Time, share of video")
        ax.grid(alpha=0.3)
    axes[0].set_ylabel("Elbow angle estimate, deg")
    for label, color in COLORS.items():
        axes[0].plot([], [], color=color, label=label)
    axes[0].legend(loc="lower left")
    fig.suptitle("E02 train (volunteers 01–05): elbow angle = 180° − forearm tilt, from MediaPipe hand landmarks")
    fig.tight_layout()
    fig.savefig(FIGURES / "e02_angle_curves_train.png", dpi=110)


# main — кривые, контроль качества центра и сводка по train
def main() -> None:
    FIGURES.mkdir(parents=True, exist_ok=True)
    QC_DIR.mkdir(parents=True, exist_ok=True)
    rows = load_train()
    for r in rows:
        r["angle"] = elbow_angle_series(r["points"])
        r["detected"] = float((~np.isnan(r["points"][:, WRIST, 0])).mean())
        r["residual"] = fit_quality(r["points"])
    plot_curves(rows)

    print("vol  videos  hand_min  hand_median  residual_median  residual_max")
    for vol in sorted({r["volunteer"] for r in rows}):
        rs = [r for r in rows if r["volunteer"] == vol]
        det, res = [r["detected"] for r in rs], [r["residual"] for r in rs]
        print(f"{vol}   {len(rs):>3}     {min(det):.2f}      {np.median(det):.2f}         {np.median(res):.3f}           {max(res):.3f}")
    worst = sorted(rows, key=lambda r: -r["residual"])[:8]
    print("worst fits:", [(r["video_id"], round(r["residual"], 3)) for r in worst])
    for r in worst:
        draw_qc(r)

    print("\nlabel       n   end_angle(median)  max_angle(median)  return_from_peak(median)")
    for label in COLORS:
        rs = [r for r in rows if r["label"] == label]
        valid = [r["angle"][~np.isnan(r["angle"])] for r in rs]
        end = [v[-max(1, len(v) // 10):].mean() for v in valid]
        peak = [np.nanmax(r["angle"]) for r in rs]
        print(f"{label:<11} {len(rs):>3}  {np.median(end):>10.1f}  {np.median(peak):>17.1f}  {np.median(np.subtract(peak, end)):>17.1f}")


if __name__ == "__main__":
    main()
