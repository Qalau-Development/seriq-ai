import type { ExerciseId, MeasureName, MeasureUnit } from "@/types/analysis";
import type { TextKey } from "@/lib/i18n/ru";

export interface ExerciseDef {
  id: ExerciseId;
  titleKey: TextKey;
  measureName: MeasureName;
  measureUnit: MeasureUnit;
}

export interface CatalogEntry {
  id: ExerciseId;
  measure: { name: MeasureName; unit: MeasureUnit };
  ready: boolean;
}

export const DEFAULT_EXERCISE: ExerciseId = "E02";

// Единственный справочник упражнений: код, ключ названия, что измеряем (имена и единицы как в контракте API)
export const EXERCISES: ExerciseDef[] = [
  { id: "E01", titleKey: "exercise_e01_title", measureName: "lift_height", measureUnit: "hand_lengths" },
  { id: "E02", titleKey: "exercise_e02_title", measureName: "elbow_angle", measureUnit: "deg" },
  { id: "E03", titleKey: "exercise_e03_title", measureName: "wrist_lift", measureUnit: "deg" },
  { id: "E04", titleKey: "exercise_e04_title", measureName: "hand_openness", measureUnit: "percent" },
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
