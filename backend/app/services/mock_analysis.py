import math
from typing import Any

from app.core.errors import AppError
from app.core.exercises import measure_meta

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

# Кривые мока для E01/E03/E04: допустимый диапазон, знаки после запятой и (начало, конец) по меткам сценариев
EXERCISE_CURVES: dict[str, dict[str, Any]] = {
    "E01": {"range": (0.0, 3.0), "digits": 2, "complete": (0.0, 2.5), "incomplete": (0.0, 0.6), "uncertain": (0.0, 1.4)},
    "E03": {"range": (0.0, 90.0), "digits": 1, "complete": (0.0, 35.0), "incomplete": (0.0, 10.0), "uncertain": (0.0, 20.0)},
    "E04": {"range": (0.0, 100.0), "digits": 1, "complete": (20.0, 95.0), "incomplete": (20.0, 50.0), "uncertain": (20.0, 70.0)},
}
POSE_TRACK_PX = {"x": (150.0, 390.0), "y": (760.0, 420.0)}


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


# hand_landmarks — 21 точка кисти по запястью (wx, wy) и направлению пальцев (dx, dy)
def hand_landmarks(wx: float, wy: float, dx: float, dy: float) -> list[list[float]]:
    hand = [share(wx, wy)]
    for j in range(20):
        finger, joint = j // 4, j % 4
        along = POSE_HAND_PX * (0.35 + 0.15 * joint)
        across = POSE_HAND_PX * 0.18 * (finger - 2)
        hand.append(share(wx + along * dx - across * dy, wy + along * dy + across * dx))
    return hand


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
        hand = hand_landmarks(wx, wy, dx, dy)
        frames.append({"t": round(i / FPS, 4), "wrist": hand[0], "hand": hand})
    return {"fps": FPS, "elbow": share(*POSE_ELBOW_PX), "frames": frames}


# build_curve — детерминированная кривая величины от start до end в своих единицах, без выхода за диапазон
def build_curve(start: float, end: float, gaps: Any, bounds: tuple[float, float], digits: int) -> list[float | None]:
    values: list[float | None] = []
    for i in range(FRAMES):
        t = min(1.0, i / (FRAMES * 0.75))
        smooth = t * t * (3 - 2 * t)
        value = start + (end - start) * smooth + 0.02 * (end - start) * math.sin(i * 1.3)
        values.append(None if i in gaps else round(min(max(value, bounds[0]), bounds[1]), digits))
    return values


# build_hand_pose — синтетическая кисть, которая движется по прямой пропорционально величине, без локтя
def build_hand_pose(values: list[float | None], bounds: tuple[float, float]) -> dict[str, Any]:
    frames: list[dict[str, Any] | None] = []
    for i, value in enumerate(values):
        if value is None:
            frames.append(None)
            continue
        k = (value - bounds[0]) / (bounds[1] - bounds[0])
        wx = POSE_TRACK_PX["x"][0] + (POSE_TRACK_PX["x"][1] - POSE_TRACK_PX["x"][0]) * k
        wy = POSE_TRACK_PX["y"][0] + (POSE_TRACK_PX["y"][1] - POSE_TRACK_PX["y"][0]) * k
        hand = hand_landmarks(wx, wy, 0.0, -1.0)
        frames.append({"t": round(i / FPS, 4), "wrist": hand[0], "hand": hand})
    return {"fps": FPS, "frames": frames}


# build_measure — поле measure: имя и единицы упражнения, максимум без пропусков и ряд по кадрам
def build_measure(exercise: str, values: list[float | None]) -> dict[str, Any]:
    known = [v for v in values if v is not None]
    return {
        **measure_meta(exercise),
        "value": max(known) if known else None,
        "series": {"fps": FPS, "values": list(values)},
    }


# run_mock — фиксированный ответ по сценарию и упражнению в форме результата analyze_video
def run_mock(scenario: str, exercise: str = "E02") -> dict[str, Any]:
    if scenario == "no_pose":
        raise AppError("no_pose_detected", 422, "The arm was not found in the video")
    spec = SCENARIOS.get(scenario, SCENARIOS["complete"])
    label = spec["label"]
    verdict = cycle_verdict(label)
    if exercise == "E02":
        values = build_series(spec["start"], spec["end"], spec["gaps"])
        angle_series: dict[str, Any] | None = {"fps": FPS, "unit": "deg", "values": values}
        pose = build_pose(values)
    else:
        curve = EXERCISE_CURVES[exercise]
        start, end = curve[label]
        values = build_curve(start, end, spec["gaps"], curve["range"], curve["digits"])
        angle_series = None
        pose = build_hand_pose(values, curve["range"])
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
        "measure": build_measure(exercise, values),
        "angle_series": angle_series,
        "warnings": list(spec["warnings"]),
        "pose": pose,
    }
