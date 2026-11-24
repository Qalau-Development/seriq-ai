from dataclasses import dataclass


# ExerciseInfo — код упражнения и что по нему измеряется
@dataclass(frozen=True)
class ExerciseInfo:
    id: str
    measure_name: str
    measure_unit: str


EXERCISES: dict[str, ExerciseInfo] = {
    "E01": ExerciseInfo("E01", "lift_height", "hand_lengths"),
    "E02": ExerciseInfo("E02", "elbow_angle", "deg"),
    "E03": ExerciseInfo("E03", "wrist_lift", "deg"),
    "E04": ExerciseInfo("E04", "hand_openness", "percent"),
}


# measure_meta — имя и единицы измерения для упражнения в форме ответа API
def measure_meta(exercise_id: str) -> dict[str, str]:
    info = EXERCISES[exercise_id]
    return {"name": info.measure_name, "unit": info.measure_unit}
