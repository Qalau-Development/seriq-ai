"use client";

import { Bar, BarChart, CartesianGrid, LabelList, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { LocalAttempt } from "@/lib/history";
import { num, type Dict } from "@/lib/i18n";
import type { MeasureName, MeasureUnit } from "@/types/analysis";
import { CHART_TEXT, formatChartValue } from "@/lib/measureText";

const MUTED = "#4b5563";
const GRID = "#e5e7eb";
const BAR = "#166534";

export interface ValuePoint {
  n: number;
  value: number;
}

// attemptPoints — значения повторений занятия; номер повторения сохраняется, повторения без значения пропускаются
export function attemptPoints(attempts: LocalAttempt[]): { points: ValuePoint[]; measure: { name: MeasureName; unit: MeasureUnit } | null } {
  const points = attempts.flatMap((a, i) => (a.measure && a.measure.value !== null ? [{ n: i + 1, value: a.measure.value }] : []));
  const first = attempts.find((a) => a.measure && a.measure.value !== null)?.measure;
  return { points, measure: first ? { name: first.name, unit: first.unit } : null };
}

// MeasureBars — измеренное значение по повторениям: столбец на каждое; подписи значений только когда столбцов немного
export function MeasureBars({
  points,
  measure,
  xLabel,
  t,
}: {
  points: ValuePoint[];
  measure: { name: MeasureName; unit: MeasureUnit } | null;
  xLabel: string;
  t: Dict;
}) {
  if (points.length === 0 || !measure) return null;
  const { name, unit } = measure;
  const text = CHART_TEXT[name];
  const fixedScale = name === "elbow_angle";

  return (
    <figure className="space-y-3">
      <figcaption className="text-xl font-bold">{t.summary_values_title}</figcaption>
      <div className="h-72 w-full" role="img" aria-label={`${t.summary_values_title}. ${t[text.yLabelKey]}`}>
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={points} margin={{ top: 24, right: 16, bottom: 24, left: 8 }}>
            <CartesianGrid stroke={GRID} vertical={false} />
            <XAxis
              dataKey="n"
              tick={{ fill: MUTED, fontSize: 14 }}
              stroke={GRID}
              label={{ value: xLabel, position: "insideBottom", offset: -16, fill: MUTED, fontSize: 14 }}
            />
            <YAxis
              domain={fixedScale ? [0, 180] : [0, "auto"]}
              ticks={fixedScale ? [0, 45, 90, 135, 180] : undefined}
              tickFormatter={(v: number) => num(t, String(Math.round(v * 10) / 10))}
              tick={{ fill: MUTED, fontSize: 14 }}
              stroke={GRID}
              width={48}
              label={{ value: t[text.yLabelKey], angle: -90, position: "insideLeft", fill: MUTED, fontSize: 13, style: { textAnchor: "middle" } }}
            />
            <Tooltip
              cursor={{ fill: GRID, fillOpacity: 0.5 }}
              formatter={(v) => [formatChartValue(Number(v), unit, t), t[text.tooltipKey]]}
              labelFormatter={(n) => `${xLabel} ${n}`}
              separator=": "
              contentStyle={{ borderRadius: 12, borderColor: GRID, fontSize: 16 }}
            />
            <Bar dataKey="value" fill={BAR} radius={[6, 6, 0, 0]} isAnimationActive={false} maxBarSize={64}>
              {points.length <= 12 && (
                <LabelList
                  dataKey="value"
                  position="top"
                  formatter={(v) => (unit === "hand_lengths" ? num(t, String(Math.round(Number(v) * 10) / 10)) : String(Math.round(Number(v))))}
                  style={{ fill: "#111827", fontSize: 14, fontWeight: 600 }}
                />
              )}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
      <p className="text-base text-muted">{t.summary_values_hint}</p>
    </figure>
  );
}
