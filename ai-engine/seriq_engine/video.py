from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from seriq_engine.errors import VideoUnreadable

TARGET_FPS = 10.0
MAX_SIDE = 960
MAX_FPS = 240.0
MAX_FRAMES = 10_000_000


# VideoInfo — параметры видео и прореживания
@dataclass(frozen=True)
class VideoInfo:
    fps: float
    frame_count: int
    duration_s: float
    step: int
    sample_fps: float


# decode_stats — число кадров и время последнего кадра, когда метаданных нет (webm из браузера)
def decode_stats(path: str | Path) -> tuple[int, float]:
    cap = cv2.VideoCapture(str(path))
    count, last_ms = 0, 0.0
    try:
        while cap.grab():
            count += 1
            last_ms = cap.get(cv2.CAP_PROP_POS_MSEC)
    finally:
        cap.release()
    return count, last_ms / 1000.0


# probe_video — fps, число кадров и длительность; без метаданных считает декодированием
def probe_video(path: str | Path, target_fps: float = TARGET_FPS) -> VideoInfo:
    cap = cv2.VideoCapture(str(path))
    try:
        if not cap.isOpened():
            raise VideoUnreadable("Cannot open the video")
        fps = cap.get(cv2.CAP_PROP_FPS)
        count = cap.get(cv2.CAP_PROP_FRAME_COUNT)
    finally:
        cap.release()
    fps_ok = 0 < fps <= MAX_FPS
    if not fps_ok or not 0 < count < MAX_FRAMES:
        count, last_s = decode_stats(path)
        if count == 0:
            raise VideoUnreadable("No frames could be decoded")
        if not fps_ok:
            fps = (count - 1) / last_s if count > 1 and last_s > 0 else target_fps
    count = int(count)
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
