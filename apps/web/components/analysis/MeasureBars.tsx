"use client";

import { Bar, BarChart, CartesianGrid, LabelList, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { LocalAttempt } from "@/lib/history";
import { num, type Dict } from "@/lib/i18n";
import type { MeasureName, MeasureUnit } from "@/types/analysis";
import { panelClass } from "@/components/ui/Card";
import { CHART_TEXT, formatChartValue } from "@/lib/measureText";

const MUTED = "#435a72";
const GRID = "#d3dee9";
const BAR = "#114a7d";

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
    <figure className={`${panelClass} flex flex-col gap-3.5 sm:gap-4`}>
      <figcaption className="text-[22px] leading-[26px] font-bold tracking-[-0.01em] text-balance sm:text-2xl sm:leading-[29px]">{t.summary_values_title}</figcaption>
      <p className="text-base leading-snug font-semibold text-muted">{t[text.yLabelKey]}</p>
      <div className="h-72 w-full" role="img" aria-label={`${t.summary_values_title}. ${t[text.yLabelKey]}`}>
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={points} margin={{ top: 24, right: 16, bottom: 24, left: 0 }}>
            <CartesianGrid stroke={GRID} vertical={false} />
            <XAxis
              dataKey="n"
              tick={{ fill: MUTED, fontSize: 16 }}
              stroke={GRID}
              label={{ value: xLabel, position: "insideBottom", offset: -16, fill: MUTED, fontSize: 16 }}
            />
            <YAxis
              domain={fixedScale ? [0, 180] : [0, "auto"]}
              ticks={fixedScale ? [0, 45, 90, 135, 180] : undefined}
              tickFormatter={(v: number) => num(t, String(Math.round(v * 10) / 10))}
              tick={{ fill: MUTED, fontSize: 16 }}
              stroke="#5f7c99"
              width={44}
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
                  style={{ fill: "#0e2237", fontSize: 16, fontWeight: 600 }}
                />
              )}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
      <p className="text-base leading-6 text-pretty text-muted">{t.summary_values_hint}</p>
    </figure>
  );
}
