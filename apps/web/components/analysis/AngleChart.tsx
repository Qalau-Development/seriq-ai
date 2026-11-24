"use client";

import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceArea,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { AnalysisResult } from "@/types/analysis";
import { num, type Dict } from "@/lib/i18n";
import { resultMeasure } from "@/lib/measure";
import { CHART_TEXT, formatChartValue } from "@/lib/measureText";

const INK = "#111827";
const MUTED = "#4b5563";
const GRID = "#e5e7eb";
const LINE = "#166534";
const CYCLE = "#e5e7eb";

// formatSeconds — секунды с десятичным разделителем языка
function formatSeconds(s: number, t: Dict) {
  return num(t, String(Math.round(s * 10) / 10));
}

// AngleChart — «Как двигалась рука»: измеряемое значение по времени; у E02 шкала 0–180°; интервал повторения выделен, только если он короче записи
export function AngleChart({ result, t }: { result: AnalysisResult; t: Dict }) {
  const measure = resultMeasure(result);
  const series = measure?.series;
  if (!measure || !series || !series.fps || series.values.length === 0) return null;
  const { fps, values } = series;
  const text = CHART_TEXT[measure.name];
  const fixedScale = measure.name === "elbow_angle";
  const yLabel = t[text.yLabelKey];

  const data = values.map((angle, i) => ({ s: Math.round((i / fps) * 100) / 100, angle }));
  const duration = data[data.length - 1].s;
  const cycle = result.cycles[0];
  const hasGaps = values.some((v) => v === null);
  const cycleEnd = cycle ? Math.min(cycle.end_s, duration) : 0;
  const showCycle = !!cycle && (cycle.start_s > 0.5 || cycleEnd < duration - 0.5);

  return (
    <figure className="space-y-3">
      <figcaption className="text-xl font-bold">{t.chart_title}</figcaption>
      <div className="h-72 w-full sm:h-80" role="img" aria-label={`${t.chart_title}. ${yLabel}`}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 8, right: 16, bottom: 24, left: 8 }}>
            <CartesianGrid stroke={GRID} vertical={false} />
            {showCycle && <ReferenceArea x1={cycle.start_s} x2={cycleEnd} fill={CYCLE} fillOpacity={0.8} />}
            <XAxis
              dataKey="s"
              type="number"
              domain={[0, duration]}
              tickCount={6}
              tickFormatter={(s: number) => formatSeconds(s, t)}
              tick={{ fill: MUTED, fontSize: 14 }}
              stroke={GRID}
              label={{ value: t.chart_x_label, position: "insideBottom", offset: -16, fill: MUTED, fontSize: 14 }}
            />
            <YAxis
              domain={fixedScale ? [0, 180] : [(min: number) => Math.min(0, Math.floor(min)), "auto"]}
              ticks={fixedScale ? [0, 45, 90, 135, 180] : undefined}
              tickFormatter={fixedScale ? undefined : (v: number) => num(t, String(Math.round(v * 10) / 10))}
              tick={{ fill: MUTED, fontSize: 14 }}
              stroke={GRID}
              width={fixedScale ? 48 : 56}
              label={{ value: yLabel, angle: -90, position: "insideLeft", fill: MUTED, fontSize: 13, style: { textAnchor: "middle" } }}
            />
            <Tooltip
              cursor={{ stroke: MUTED, strokeWidth: 1 }}
              formatter={(v) => [formatChartValue(Number(v), measure.unit, t), t[text.tooltipKey]]}
              labelFormatter={(s) => `${formatSeconds(Number(s), t)} ${t.chart_seconds}`}
              separator=": "
              contentStyle={{ borderRadius: 12, borderColor: GRID, fontSize: 16 }}
              itemStyle={{ color: INK }}
              labelStyle={{ color: MUTED }}
            />
            <Line
              type="monotone"
              dataKey="angle"
              stroke={LINE}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 5 }}
              connectNulls={false}
              isAnimationActive={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
      {(showCycle || hasGaps) && (
        <p className="text-base text-muted">
          {[showCycle && t.chart_cycle_hint, hasGaps && t.chart_gap_hint].filter(Boolean).join(" ")}
        </p>
      )}
    </figure>
  );
}
