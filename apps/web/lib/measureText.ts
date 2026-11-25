import type { Measure, MeasureName } from "@/types/analysis";
import { fill, num, type Dict, type TextKey } from "@/lib/i18n";
import { clampInt, type VoiceItem } from "@/lib/voice";

type TextPart = VoiceItem;

// Тексты оси и подсказки графика по измеряемому значению
export const CHART_TEXT: Record<MeasureName, { yLabelKey: TextKey; tooltipKey: TextKey }> = {
  elbow_angle: { yLabelKey: "chart_y_label", tooltipKey: "chart_tooltip_angle" },
  wrist_lift: { yLabelKey: "chart_y_label_wrist_lift", tooltipKey: "chart_tooltip_wrist_lift" },
  hand_openness: { yLabelKey: "chart_y_label_hand_openness", tooltipKey: "chart_tooltip_hand_openness" },
  lift_height: { yLabelKey: "chart_y_label_lift_height", tooltipKey: "chart_tooltip_lift_height" },
};

// decimal — число с одной цифрой после запятой, разделитель по языку
export function decimal(value: number, t: Dict): string {
  return num(t, value.toFixed(1));
}

// formatChartValue — значение ряда с единицей для подсказки графика и оси
export function formatChartValue(value: number, unit: Measure["unit"], t: Dict): string {
  if (unit === "deg") return `${Math.round(value)}°`;
  if (unit === "percent") return `${Math.round(value)}%`;
  return `${decimal(value, t)} ${t.chart_unit_hand_lengths}`;
}

// measurePart — строка с измеренным значением для упражнений кроме E02 и id её клипа («ключ__значение», число прижато к диапазону озвучки); null, если значения нет
export function measurePart(t: Dict, measure: Measure): TextPart | null {
  const value = measure.value;
  if (value === null) return null;
  switch (measure.name) {
    case "hand_openness": {
      const up = value > 100;
      const key = up ? "result_measure_hand_openness_up" : "result_measure_hand_openness_base";
      const n = up ? Math.round(value - 100) : Math.round(value);
      return { id: `${key}__${up ? clampInt(n, 1, 200) : clampInt(n, 0, 100)}`, text: fill(t[key], { n }) };
    }
    case "wrist_lift":
      return { id: `result_measure_wrist_lift__${clampInt(value, 0, 180)}`, text: fill(t.result_measure_wrist_lift, { n: Math.round(value) }) };
    case "lift_height": {
      const tenths = Math.min(9.9, Math.max(0, value)).toFixed(1);
      return { id: `result_measure_lift_height__${tenths}`, text: fill(t.result_measure_lift_height, { n: decimal(value, t) }) };
    }
    default:
      return null;
  }
}

// measureLine — строка с измеренным значением для упражнений кроме E02; null, если значения нет
export function measureLine(t: Dict, measure: Measure): string | null {
  return measurePart(t, measure)?.text ?? null;
}
