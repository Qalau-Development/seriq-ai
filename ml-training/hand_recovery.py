import json
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

from seriq_engine.classifier import signal_quality
from seriq_engine.hand import MIDDLE_MCP, WRIST, HandTrack, recover_missing, track_hand
from seriq_engine.video import probe_video
from train_exercise import EXERCISES, ROOT, cache_dir, list_videos

HAND_MODEL = ROOT / "data/processed/mp_models/hand_landmarker.task"
OUT = ROOT / "ml-training/results/hand_recovery.json"


# load_track — точки кисти из кэша (если нет — считает и сохраняет), с параметрами видео для второго прохода
def load_track(exercise: str, split: str, video: dict) -> HandTrack:
    target = cache_dir(exercise, split) / f"{video['video_id']}.npz"
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        t = track_hand(video["path"], HAND_MODEL)
        np.savez_compressed(target, points=t.points, times=t.times, sample_fps=t.info.sample_fps, duration_s=t.info.duration_s)
    data = np.load(target)
    return HandTrack(points=data["points"], times=data["times"], info=probe_video(video["path"]), frame_size=(0, 0))


# hand_length_ratio — длина кисти в восстановленных кадрах к медиане по найденным изначально (проверка правдоподобия)
def hand_length_ratio(before: np.ndarray, after: np.ndarray) -> list[float]:
    new = np.isnan(before[:, WRIST, 0]) & ~np.isnan(after[:, WRIST, 0])
    old = ~np.isnan(before[:, WRIST, 0])
    if not new.any() or not old.any():
        return []
    ref = np.median(np.linalg.norm(before[old, MIDDLE_MCP] - before[old, WRIST], axis=1))
    return (np.linalg.norm(after[new, MIDDLE_MCP] - after[new, WRIST], axis=1) / ref).tolist()


# main — доля кадров с кистью и число видео, проходящих правило качества сигнала, до и после второго прохода; модели и метки не используются
def main() -> None:
    report = {}
    for exercise in sys.argv[1:] or ["E01", "E03", "E04"]:
        for split in ("train", "test"):
            per = defaultdict(lambda: {"videos": 0, "frames": 0, "before": 0, "after": 0, "min_before": 1.0, "min_after": 1.0, "quality_ok_before": 0, "quality_ok_after": 0})
            ratios = []
            for video in list_videos(exercise, split):
                track = load_track(exercise, split, video)
                fixed = recover_missing(video["path"], track, HAND_MODEL)
                b, a = track.detected, fixed.detected
                v = per[video["volunteer"]]
                v["videos"] += 1
                v["frames"] += len(b)
                v["before"] += int(b.sum())
                v["after"] += int(a.sum())
                v["min_before"] = min(v["min_before"], float(b.mean()))
                v["min_after"] = min(v["min_after"], float(a.mean()))
                fps = track.info.sample_fps
                v["quality_ok_before"] += int(signal_quality(np.where(b, 0.0, np.nan), fps).ok)
                v["quality_ok_after"] += int(signal_quality(np.where(a, 0.0, np.nan), fps).ok)
                ratios += hand_length_ratio(track.points, fixed.points)
            rows = {vol: {"videos": v["videos"], "share_before": round(v["before"] / v["frames"], 3), "share_after": round(v["after"] / v["frames"], 3),
                          "min_video_before": round(v["min_before"], 3), "min_video_after": round(v["min_after"], 3),
                          "signal_quality_ok_before": v["quality_ok_before"], "signal_quality_ok_after": v["quality_ok_after"]} for vol, v in sorted(per.items())}
            report[f"{exercise}_{split}"] = {"volunteers": rows, "recovered_hand_length_ratio": {
                "n": len(ratios), "median": round(float(np.median(ratios)), 3) if ratios else None,
                "p05": round(float(np.percentile(ratios, 5)), 3) if ratios else None, "p95": round(float(np.percentile(ratios, 95)), 3) if ratios else None}}
            print(exercise, split, json.dumps(report[f"{exercise}_{split}"], ensure_ascii=False), flush=True)
    OUT.write_text(json.dumps(report, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
