import os
from dataclasses import dataclass
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

from seriq_engine.video import VideoInfo, iter_frames, probe_video

DEFAULT_HAND_MODEL = "/srv/models/hand_landmarker.task"
MIN_CONFIDENCE = 0.3
WRIST = 0
MIDDLE_MCP = 9
RECOVER_WINDOW_HANDS = 5.0
RECOVER_MIN_SIDE = 160
RECOVER_INPUT_SIDE = 384


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


# create_landmarker — создаёт HandLandmarker MediaPipe в режиме видео (или отдельных кадров)
def create_landmarker(model_path: str | Path | None = None, mode: vision.RunningMode = vision.RunningMode.VIDEO) -> vision.HandLandmarker:
    options = vision.HandLandmarkerOptions(
        base_options=mp_python.BaseOptions(model_asset_path=str(model_path or hand_model_path())),
        running_mode=mode,
        num_hands=1,
        min_hand_detection_confidence=MIN_CONFIDENCE,
        min_hand_presence_confidence=MIN_CONFIDENCE,
        min_tracking_confidence=MIN_CONFIDENCE,
    )
    return vision.HandLandmarker.create_from_options(options)


# track_hand — находит 21 точку кисти на каждом прореженном кадре видео
def track_hand(path: str | Path, model_path: str | Path | None = None, info: VideoInfo | None = None) -> HandTrack:
    info = info or probe_video(path)
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


# recover_missing — второй проход: ищет кисть в увеличенном окне вокруг ближайшего найденного кадра, только там, где её не нашли
def recover_missing(path: str | Path, track: HandTrack, model_path: str | Path | None = None) -> HandTrack:
    found = track.detected
    if found.all() or not found.any():
        return track
    points = track.points.copy()
    known = np.flatnonzero(found)
    hand_len = float(np.nanmedian(np.linalg.norm(points[found, MIDDLE_MCP] - points[found, WRIST], axis=1)))
    side = max(RECOVER_MIN_SIDE, RECOVER_WINDOW_HANDS * hand_len)
    missing = set(np.flatnonzero(~found).tolist())
    with create_landmarker(model_path, vision.RunningMode.IMAGE) as landmarker:
        for i, (_, rgb) in enumerate(iter_frames(path, track.info)):
            if i not in missing:
                continue
            h, w = rgb.shape[:2]
            cx, cy = track.points[known[np.argmin(np.abs(known - i))]].mean(axis=0)
            half = min(side, w, h) / 2
            x0, y0 = int(np.clip(cx - half, 0, w - 2 * half)), int(np.clip(cy - half, 0, h - 2 * half))
            crop = rgb[y0 : y0 + int(2 * half), x0 : x0 + int(2 * half)]
            scale = RECOVER_INPUT_SIDE / crop.shape[0]
            crop = cv2.resize(crop, (RECOVER_INPUT_SIDE, RECOVER_INPUT_SIDE), interpolation=cv2.INTER_CUBIC)
            result = landmarker.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(crop)))
            if result.hand_landmarks:
                points[i] = [(x0 + p.x * RECOVER_INPUT_SIDE / scale, y0 + p.y * RECOVER_INPUT_SIDE / scale) for p in result.hand_landmarks[0]]
    return HandTrack(points=points, times=track.times, info=track.info, frame_size=track.frame_size)
