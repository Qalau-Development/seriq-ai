import argparse
import csv
import sys
import time
from pathlib import Path

import numpy as np

from seriq_engine.hand import track_hand

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw/An upper limb stroke rehabilitation exercise video/Exercise/2_Extending the Elbow"
OUT = ROOT / "data/processed"
POSES = OUT / "poses"
LOCAL_HAND_MODEL = OUT / "mp_models" / "hand_landmarker.task"
LABELS = {"Complete": "complete", "Incomplete": "incomplete"}


# list_videos — все видео E02: метка из имени папки, ID — первые две цифры имени файла
def list_videos() -> list[dict]:
    rows = []
    for folder, label in LABELS.items():
        for split in ("Train", "Test"):
            for path in sorted((RAW / folder / split).glob("*.mp4")):
                rows.append({
                    "video_id": f"{path.stem}_{folder}_{split}",
                    "path": str(path.relative_to(RAW)),
                    "volunteer": path.name[:2],
                    "label": label,
                    "split": split.lower(),
                })
    return rows


# main — извлекает точки кисти и сохраняет кэш и таблицу метаданных
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--split", choices=["train", "test", "all"], default="train")
    parser.add_argument("--model", default=str(LOCAL_HAND_MODEL))
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    POSES.mkdir(parents=True, exist_ok=True)
    videos = list_videos()
    if len(videos) != 127:
        sys.exit(f"Expected 127 E02 videos, found {len(videos)}")
    if len({v["video_id"] for v in videos}) != len(videos):
        sys.exit("video_id is not unique")

    for v in videos:
        if args.split != "all" and v["split"] != args.split:
            continue
        target = POSES / f"{v['video_id']}.npz"
        if target.exists() and not args.force:
            continue
        started = time.time()
        track = track_hand(RAW / v["path"], args.model)
        np.savez_compressed(
            target,
            points=track.points,
            times=track.times,
            fps=track.info.fps,
            sample_fps=track.info.sample_fps,
            duration_s=track.info.duration_s,
            frame_size=np.array(track.frame_size),
        )
        print(f"{v['video_id']}: hand {track.detected.mean():.0%}, {time.time() - started:.1f}s", flush=True)

    with (OUT / "metadata.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(videos[0]))
        writer.writeheader()
        writer.writerows(videos)


if __name__ == "__main__":
    main()
