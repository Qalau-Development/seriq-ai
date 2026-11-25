import type { CycleLabel, ExerciseId, Measure } from "@/types/analysis";
import { fill, textForExercise, type Dict, type TextKey } from "@/lib/i18n";
import { measurePart } from "@/lib/measureText";
import { clampInt, type VoiceItem } from "@/lib/voice";

// titleKey — ключ заголовка результата: для E02 как раньше, для остальных упражнений «Выполнено» или «Проверьте инструкцию»
function titleKey(label: CycleLabel, exercise: ExerciseId): TextKey {
  if (exercise === "E02") return `result_title_${label}`;
  return label === "complete" ? "verdict_completed" : "verdict_check_instructions";
}

// resultTitle — заголовок результата
export function resultTitle(t: Dict, label: CycleLabel, exercise: ExerciseId): string {
  return t[titleKey(label, exercise)];
}

// hintKey — ключ подсказки под заголовком: для упражнений кроме E02 вариант _other, если он есть; для неизвестной метки — result_hint_incomplete
function hintKey(t: Dict, label: CycleLabel, exercise: ExerciseId): TextKey {
  const key = `result_hint_${label}`;
  const other = `${key}_other`;
  if (exercise !== "E02" && other in t) return other as TextKey;
  return key in t ? (key as TextKey) : "result_hint_incomplete";
}

// resultHint — подсказка под заголовком, когда измеренного значения нет
export function resultHint(t: Dict, label: CycleLabel, exercise: ExerciseId): string {
  return textForExercise(t, `result_hint_${label}`, exercise, "result_hint_incomplete");
}

// resultParts — заголовок и строки результата с id клипов озвучки; те же тексты показываются на экране
export function resultParts(
  t: Dict,
  label: CycleLabel,
  exercise: ExerciseId,
  measure: Measure | null,
): { title: VoiceItem; lines: VoiceItem[] } {
  const title = { id: titleKey(label, exercise), text: resultTitle(t, label, exercise) };
  const hint = () => {
    const id = hintKey(t, label, exercise);
    return { id, text: t[id] };
  };
  const elbow = measure?.name === "elbow_angle" || exercise === "E02";
  if (elbow) {
    const max = measure?.name === "elbow_angle" && measure.value !== null ? Math.round(measure.value) : null;
    if (max === null) return { title, lines: [hint()].filter((l) => l.text !== "") };
    const key = `result_line_${label}` as TextKey;
    return { title, lines: [{ id: `${key}__${clampInt(max, 0, 180)}`, text: fill(t[key], { max }) }] };
  }
  const line = measure ? measurePart(t, measure) : null;
  return { title, lines: [line, label === "complete" ? null : hint()].filter((l): l is VoiceItem => l !== null) };
}
