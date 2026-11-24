import type { AnalysisResult, Measure } from "@/types/analysis";

// maxKnown — наибольшее значение ряда без пропусков или null, если значений нет
function maxKnown(values: (number | null)[]): number | null {
  const known = values.filter((v): v is number => v !== null);
  return known.length > 0 ? Math.max(...known) : null;
}

// resultMeasure — измеряемое значение ответа: measure, а без него откат на angle_series (старый ответ E02)
export function resultMeasure(result: AnalysisResult): Measure | null {
  if (result.measure) return result.measure;
  const angles = result.angle_series;
  if (!angles) return null;
  return {
    name: "elbow_angle",
    unit: "deg",
    value: maxKnown(angles.values),
    series: { fps: angles.fps, values: angles.values },
  };
}
