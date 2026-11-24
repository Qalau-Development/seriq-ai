import type { CycleLabel, ExerciseId } from "@/types/analysis";
import { textForExercise, type Dict } from "@/lib/i18n";

// resultTitle — заголовок результата: для E02 как раньше, для остальных упражнений «Выполнено» или «Проверьте инструкцию»
export function resultTitle(t: Dict, label: CycleLabel, exercise: ExerciseId): string {
  if (exercise === "E02") return t[`result_title_${label}`];
  return label === "complete" ? t.verdict_completed : t.verdict_check_instructions;
}

// resultHint — подсказка под заголовком, когда измеренного значения нет
export function resultHint(t: Dict, label: CycleLabel, exercise: ExerciseId): string {
  return textForExercise(t, `result_hint_${label}`, exercise, "result_hint_incomplete");
}
