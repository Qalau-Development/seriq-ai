import type { ExerciseId, MeasureName, MeasureUnit } from "@/types/analysis";
import type { TextKey } from "@/lib/i18n/ru";

export interface ExerciseDef {
  id: ExerciseId;
  titleKey: TextKey;
  descKey: TextKey;
  measuresKey: TextKey;
  stepKeys: TextKey[];
  tipKeys: TextKey[];
  reminderKey: TextKey;
  hasVideo: boolean;
  lowConfidence: boolean;
  measureName: MeasureName;
  measureUnit: MeasureUnit;
}

export interface CatalogEntry {
  id: ExerciseId;
  measure: { name: MeasureName; unit: MeasureUnit };
  ready: boolean;
}

export const DEFAULT_EXERCISE: ExerciseId = "E02";

// Единственный справочник упражнений: код, ключи текстов, что измеряем (имена и единицы как в контракте API)
export const EXERCISES: ExerciseDef[] = [
  {
    id: "E01",
    titleKey: "exercise_e01_title",
    descKey: "exercise_e01_desc",
    measuresKey: "exercise_e01_measures",
    stepKeys: ["e01_step_1", "e01_step_2", "e01_step_3", "e01_step_4"],
    tipKeys: ["e01_tip_1", "e01_tip_2", "e01_tip_3", "tip_3", "tip_4"],
    reminderKey: "e01_reminder",
    hasVideo: false,
    lowConfidence: true,
    measureName: "lift_height",
    measureUnit: "hand_lengths",
  },
  {
    id: "E02",
    titleKey: "exercise_e02_title",
    descKey: "exercise_e02_desc",
    measuresKey: "exercise_e02_measures",
    stepKeys: ["instruction_step_1", "instruction_step_2", "instruction_step_3", "instruction_step_4"],
    tipKeys: ["tip_1", "tip_2", "tip_3", "tip_4"],
    reminderKey: "session_reminder",
    hasVideo: true,
    lowConfidence: false,
    measureName: "elbow_angle",
    measureUnit: "deg",
  },
  {
    id: "E03",
    titleKey: "exercise_e03_title",
    descKey: "exercise_e03_desc",
    measuresKey: "exercise_e03_measures",
    stepKeys: ["e03_step_1", "e03_step_2", "e03_step_3", "e03_step_4"],
    tipKeys: ["e03_tip_1", "e03_tip_2", "tip_3", "tip_4"],
    reminderKey: "e03_reminder",
    hasVideo: false,
    lowConfidence: false,
    measureName: "wrist_lift",
    measureUnit: "deg",
  },
  {
    id: "E04",
    titleKey: "exercise_e04_title",
    descKey: "exercise_e04_desc",
    measuresKey: "exercise_e04_measures",
    stepKeys: ["e04_step_1", "e04_step_2", "e04_step_3", "e04_step_4"],
    tipKeys: ["e04_tip_1", "e04_tip_2", "tip_3", "tip_4"],
    reminderKey: "e04_reminder",
    hasVideo: false,
    lowConfidence: false,
    measureName: "hand_openness",
    measureUnit: "percent",
  },
];

const MEASURE_NAMES: string[] = EXERCISES.map((e) => e.measureName);
const MEASURE_UNITS: string[] = EXERCISES.map((e) => e.measureUnit);

// exerciseDef — запись справочника по коду упражнения
export function exerciseDef(id: ExerciseId): ExerciseDef {
  return EXERCISES.find((e) => e.id === id) ?? exerciseDef(DEFAULT_EXERCISE);
}

// parseExercise — код упражнения из адреса или хранилища; неизвестное или пустое значение — E02
export function parseExercise(value: string | null | undefined): ExerciseId {
  return EXERCISES.find((e) => e.id === value)?.id ?? DEFAULT_EXERCISE;
}

// fallbackCatalog — запасной каталог из справочника: запись доступна только для E02
export function fallbackCatalog(): CatalogEntry[] {
  return EXERCISES.map((e) => ({
    id: e.id,
    measure: { name: e.measureName, unit: e.measureUnit },
    ready: e.id === DEFAULT_EXERCISE,
  }));
}

// parseCatalog — разбирает ответ GET /api/v1/exercises; null, если это не каталог
export function parseCatalog(body: unknown): CatalogEntry[] | null {
  if (!Array.isArray(body)) return null;
  const known = body.filter((item) => item && typeof item === "object" && EXERCISES.some((e) => e.id === item.id));
  if (known.length === 0) return null;
  return EXERCISES.map((def) => {
    const item = known.find((k) => k.id === def.id);
    const name = item?.measure?.name;
    const unit = item?.measure?.unit;
    return {
      id: def.id,
      measure: {
        name: MEASURE_NAMES.includes(name) ? name : def.measureName,
        unit: MEASURE_UNITS.includes(unit) ? unit : def.measureUnit,
      },
      ready: item?.ready === true,
    };
  });
}

// exerciseAvailability — состояние упражнения по каталогу: loading, ready или soon; пока каталога нет, доступно только E02
export function exerciseAvailability(catalog: CatalogEntry[] | null, id: ExerciseId): "loading" | "ready" | "soon" {
  if (catalog === null) return id === DEFAULT_EXERCISE ? "ready" : "loading";
  return catalog.find((e) => e.id === id)?.ready ? "ready" : "soon";
}
