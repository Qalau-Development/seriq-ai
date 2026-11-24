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


# run_mock — фиксированный ответ по сценарию в форме результата analyze_video
def run_mock(scenario: str) -> dict[str, Any]:
    if scenario == "no_pose":
        raise AppError("no_pose_detected", 422, "The arm was not found in the video")
    spec = SCENARIOS.get(scenario, SCENARIOS["complete"])
    label = spec["label"]
    verdict = cycle_verdict(label)
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
        "angle_series": {"fps": FPS, "unit": "deg", "values": build_series(spec["start"], spec["end"], spec["gaps"])},
        "warnings": list(spec["warnings"]),
    }
