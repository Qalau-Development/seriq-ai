import os
from dataclasses import dataclass
from pathlib import Path

import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

from seriq_engine.video import VideoInfo, iter_frames, probe_video

DEFAULT_HAND_MODEL = "/srv/models/hand_landmarker.task"
MIN_CONFIDENCE = 0.3
WRIST = 0
MIDDLE_MCP = 9


# HandTrack — точки кисти по кадрам в пикселях уменьшенного кадра, NaN где руки нет
@dataclass
class HandTrack:
    points: np.ndarray
    times: np.ndarray
    info: VideoInfo
    frame_size: tuple[int, int]

    # detected — маска кадров, где кисть найдена
    @property
    def detected(self) -> np.ndarray:
        return ~np.isnan(self.points[:, WRIST, 0])


# hand_model_path — путь к весам HandLandmarker из SERIQ_HAND_MODEL_PATH
def hand_model_path() -> str:
    return os.environ.get("SERIQ_HAND_MODEL_PATH", DEFAULT_HAND_MODEL)


# create_landmarker — создаёт HandLandmarker MediaPipe в режиме видео
def create_landmarker(model_path: str | Path | None = None) -> vision.HandLandmarker:
    options = vision.HandLandmarkerOptions(
        base_options=mp_python.BaseOptions(model_asset_path=str(model_path or hand_model_path())),
        running_mode=vision.RunningMode.VIDEO,
        num_hands=1,
        min_hand_detection_confidence=MIN_CONFIDENCE,
        min_hand_presence_confidence=MIN_CONFIDENCE,
        min_tracking_confidence=MIN_CONFIDENCE,
    )
    return vision.HandLandmarker.create_from_options(options)


# track_hand — находит 21 точку кисти на каждом прореженном кадре видео
def track_hand(path: str | Path, model_path: str | Path | None = None) -> HandTrack:
    info = probe_video(path)
    points, times, size = [], [], (0, 0)
    with create_landmarker(model_path) as landmarker:
        for t, rgb in iter_frames(path, info):
            h, w = rgb.shape[:2]
            size = (w, h)
            result = landmarker.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), int(t * 1000))
            if result.hand_landmarks:
                points.append([(p.x * w, p.y * h) for p in result.hand_landmarks[0]])
            else:
                points.append(np.full((21, 2), np.nan))
            times.append(t)
    return HandTrack(points=np.array(points, dtype=float).reshape(-1, 21, 2), times=np.array(times), info=info, frame_size=size)
