import argparse
import hashlib
import json
import os
from pathlib import Path

from seriq_engine.exercises import analyze_video

ROOT = Path(__file__).resolve().parents[1]
EXERCISE_DIR = ROOT / "data/raw/An upper limb stroke rehabilitation exercise video/Exercise"
FOLDERS = {"E01": "1_Lifting an Object", "E02": "2_Extending the Elbow", "E03": "3_Lifting the Wrist", "E04": "4_Opening the Hand"}
OUT = ROOT / "ai-engine/tests/data/regression_answers.json"
PER_CLASS = 3


# field_hash — sha256 поля ответа в каноническом JSON
def field_hash(value) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


# pick_videos — по одному train-видео от разных добровольцев на класс, детерминированно
def pick_videos(exercise: str) -> list[Path]:
    picked = []
    for folder in ("Complete", "Incomplete"):
        seen = set()
        for path in sorted((EXERCISE_DIR / FOLDERS[exercise] / folder / "Train").glob("*.mp4")):
            if path.name[:2] not in seen and len(seen) < PER_CLASS:
                seen.add(path.name[:2])
                picked.append(path)
    return picked


# main — снимает эталонные ответы текущего кода по train-видео всех упражнений
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="overwrite existing answers")
    args = parser.parse_args()
    if OUT.exists() and not args.force:
        raise SystemExit(f"{OUT.relative_to(ROOT)} exists: regenerate only on purpose, with --force")
    os.environ.setdefault("SERIQ_MODEL_PATH", str(ROOT / "models/e02_classifier.joblib"))
    os.environ.setdefault("SERIQ_HAND_MODEL_PATH", str(ROOT / "data/processed/mp_models/hand_landmarker.task"))
    answers = []
    for exercise in FOLDERS:
        for path in pick_videos(exercise):
            result = analyze_video(path, exercise)
            cycle = result["cycles"][0]
            answers.append({
                "exercise": exercise,
                "video": str(path.relative_to(EXERCISE_DIR)),
                "label": cycle["label"],
                "confidence": cycle["confidence"],
                "measure_value": result["measure"]["value"],
                "field_sha256": {key: field_hash(value) for key, value in sorted(result.items())},
            })
            print(exercise, path.name, cycle["label"], cycle["confidence"], result["measure"]["value"], flush=True)
    OUT.write_text(json.dumps(answers, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
