"use client";

import { Bar, BarChart, CartesianGrid, LabelList, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { LocalAttempt } from "@/lib/history";
import type { Dict } from "@/lib/i18n";
import { CHART_TEXT, formatChartValue } from "@/lib/measureText";

const MUTED = "#4b5563";
const GRID = "#e5e7eb";
const BAR = "#166534";

// MeasureBars — измеренное значение по каждому повторению занятия; повторения без значения не показываются
export function MeasureBars({ attempts, t }: { attempts: LocalAttempt[]; t: Dict }) {
  const points = attempts.flatMap((a, i) =>
    a.measure && a.measure.value !== null ? [{ n: i + 1, value: a.measure.value, measure: a.measure }] : [],
  );
  if (points.length === 0) return null;
  const { name, unit } = points[0].measure;
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
              label={{ value: t.attempt_n, position: "insideBottom", offset: -16, fill: MUTED, fontSize: 14 }}
            />
            <YAxis
              domain={fixedScale ? [0, 180] : [0, "auto"]}
              ticks={fixedScale ? [0, 45, 90, 135, 180] : undefined}
              tickFormatter={(v: number) => String(Math.round(v * 10) / 10).replace(".", ",")}
              tick={{ fill: MUTED, fontSize: 14 }}
              stroke={GRID}
              width={48}
              label={{ value: t[text.yLabelKey], angle: -90, position: "insideLeft", fill: MUTED, fontSize: 13, style: { textAnchor: "middle" } }}
            />
            <Tooltip
              cursor={{ fill: GRID, fillOpacity: 0.5 }}
              formatter={(v) => [formatChartValue(Number(v), unit, t), t[text.tooltipKey]]}
              labelFormatter={(n) => `${t.attempt_n} ${n}`}
              separator=": "
              contentStyle={{ borderRadius: 12, borderColor: GRID, fontSize: 16 }}
            />
            <Bar dataKey="value" fill={BAR} radius={[6, 6, 0, 0]} isAnimationActive={false} maxBarSize={64}>
              <LabelList
                dataKey="value"
                position="top"
                formatter={(v) => (unit === "hand_lengths" ? String(Math.round(Number(v) * 10) / 10).replace(".", ",") : String(Math.round(Number(v))))}
                style={{ fill: "#111827", fontSize: 14, fontWeight: 600 }}
              />
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
      <p className="text-base text-muted">{t.summary_values_hint}</p>
    </figure>
  );
}
