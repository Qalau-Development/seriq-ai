import math
from typing import Any

from app.core.errors import AppError

FPS = 10
FRAMES = 100
START_S = 0.4
END_S = 9.8

SCENARIOS: dict[str, dict[str, Any]] = {
    "complete": {"start": 62.0, "end": 166.0, "label": "complete", "confidence": 0.87, "gaps": (), "warnings": []},
    "incomplete": {"start": 64.0, "end": 108.0, "label": "incomplete", "confidence": 0.81, "gaps": (), "warnings": []},
    "uncertain": {
        "start": 63.0,
        "end": 138.0,
        "label": "uncertain",
        "confidence": 0.55,
        "gaps": range(40, 47),
        "warnings": ["arm_not_visible"],
    },
}

POSE_FRAME_PX = (540.0, 960.0)
POSE_ELBOW_PX = (70.0, 640.0)
POSE_FOREARM_PX = 330.0
POSE_HAND_PX = 90.0


# cycle_verdict — вердикт цикла по правилам api.md
def cycle_verdict(label: str) -> str:
    return "completed" if label == "complete" else "check_instructions"


# build_series — детерминированная кривая угла от start до end с пропусками
def build_series(start: float, end: float, gaps: Any) -> list[float | None]:
    values: list[float | None] = []
    for i in range(FRAMES):
        t = min(1.0, i / (FRAMES * 0.75))
        smooth = t * t * (3 - 2 * t)
        angle = start + (end - start) * smooth + 1.5 * math.sin(i * 1.3)
        values.append(None if i in gaps else round(angle, 1))
    return values


# share — точка в пикселях условного вертикального кадра → доли кадра с 4 знаками
def share(x: float, y: float) -> list[float]:
    return [round(x / POSE_FRAME_PX[0], 4), round(y / POSE_FRAME_PX[1], 4)]


# build_pose — синтетическая дуга запястья вокруг локтя по ряду угла мока, null там же, где у угла
def build_pose(values: list[float | None]) -> dict[str, Any]:
    frames: list[dict[str, Any] | None] = []
    for i, angle in enumerate(values):
        if angle is None:
            frames.append(None)
            continue
        tilt = math.radians(180.0 - angle)
        dx, dy = math.cos(tilt), -math.sin(tilt)
        wx, wy = POSE_ELBOW_PX[0] + POSE_FOREARM_PX * dx, POSE_ELBOW_PX[1] + POSE_FOREARM_PX * dy
        hand = [share(wx, wy)]
        for j in range(20):
            finger, joint = j // 4, j % 4
            along = POSE_HAND_PX * (0.35 + 0.15 * joint)
            across = POSE_HAND_PX * 0.18 * (finger - 2)
            hand.append(share(wx + along * dx - across * dy, wy + along * dy + across * dx))
        frames.append({"t": round(i / FPS, 4), "wrist": hand[0], "hand": hand})
    return {"fps": FPS, "elbow": share(*POSE_ELBOW_PX), "frames": frames}


# run_mock — фиксированный ответ по сценарию в форме результата analyze_video
def run_mock(scenario: str) -> dict[str, Any]:
    if scenario == "no_pose":
        raise AppError("no_pose_detected", 422, "The arm was not found in the video")
    spec = SCENARIOS.get(scenario, SCENARIOS["complete"])
    label = spec["label"]
    verdict = cycle_verdict(label)
    values = build_series(spec["start"], spec["end"], spec["gaps"])
    return {
        "model_version": "mock",
        "verdict": verdict,
        "summary": {
            "total": 1,
            "complete": int(label == "complete"),
            "incomplete": int(label == "incomplete"),
            "uncertain": int(label == "uncertain"),
        },
        "cycles": [
            {
                "index": 1,
                "start_s": START_S,
                "end_s": END_S,
                "label": label,
                "confidence": spec["confidence"],
                "verdict": verdict,
            }
        ],
        "angle_series": {"fps": FPS, "unit": "deg", "values": values},
        "warnings": list(spec["warnings"]),
        "pose": build_pose(values),
    }
