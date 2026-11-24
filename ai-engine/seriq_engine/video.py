from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

TARGET_FPS = 10.0
MAX_SIDE = 960


# VideoUnreadable — видео не удалось открыть или прочитать
class VideoUnreadable(Exception):
    pass


# VideoInfo — параметры видео и прореживания
@dataclass(frozen=True)
class VideoInfo:
    fps: float
    frame_count: int
    duration_s: float
    step: int
    sample_fps: float


# probe_video — читает fps, число кадров и длительность
def probe_video(path: str | Path, target_fps: float = TARGET_FPS) -> VideoInfo:
    cap = cv2.VideoCapture(str(path))
    try:
        if not cap.isOpened():
            raise VideoUnreadable(f"Cannot open {path}")
        fps = cap.get(cv2.CAP_PROP_FPS)
        count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    finally:
        cap.release()
    if not fps or fps <= 0 or count <= 0:
        raise VideoUnreadable(f"No frame rate or frames in {path}")
    step = max(1, round(fps / target_fps))
    return VideoInfo(fps=fps, frame_count=count, duration_s=count / fps, step=step, sample_fps=fps / step)


# iter_frames — прореженные кадры RGB, уменьшенные до max_side, с временем в секундах
def iter_frames(path: str | Path, info: VideoInfo, max_side: int = MAX_SIDE) -> Iterator[tuple[float, np.ndarray]]:
    cap = cv2.VideoCapture(str(path))
    try:
        index = 0
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            if index % info.step == 0:
                scale = min(1.0, max_side / max(frame.shape[:2]))
                if scale < 1.0:
                    frame = cv2.resize(frame, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
                yield index / info.fps, cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            index += 1
    finally:
        cap.release()
