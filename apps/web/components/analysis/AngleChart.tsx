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
import type { Dict } from "@/lib/i18n";

const INK = "#111827";
const MUTED = "#4b5563";
const GRID = "#e5e7eb";
const LINE = "#166534";
const CYCLE = "#e5e7eb";

// formatSeconds — секунды с запятой, как принято в русском и казахском
function formatSeconds(s: number) {
  return String(Math.round(s * 10) / 10).replace(".", ",");
}

// AngleChart — график угла локтя по времени с выделенным интервалом повторения
export function AngleChart({ result, t }: { result: AnalysisResult; t: Dict }) {
  const { fps, values } = result.angle_series;
  if (!fps || values.length === 0) return null;

  const data = values.map((angle, i) => ({ s: Math.round((i / fps) * 100) / 100, angle }));
  const duration = data[data.length - 1].s;
  const cycle = result.cycles[0];
  const hasGaps = values.some((v) => v === null);

  return (
    <figure className="space-y-3">
      <figcaption className="text-xl font-bold">{t.chart_title}</figcaption>
      <div className="h-72 w-full sm:h-80" role="img" aria-label={`${t.chart_title}. ${t.chart_hint}`}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 8, right: 16, bottom: 24, left: 8 }}>
            <CartesianGrid stroke={GRID} vertical={false} />
            {cycle && (
              <ReferenceArea x1={cycle.start_s} x2={Math.min(cycle.end_s, duration)} fill={CYCLE} fillOpacity={0.8} />
            )}
            <XAxis
              dataKey="s"
              type="number"
              domain={[0, duration]}
              tickCount={6}
              tickFormatter={(s: number) => formatSeconds(s)}
              tick={{ fill: MUTED, fontSize: 14 }}
              stroke={GRID}
              label={{ value: t.chart_x_label, position: "insideBottom", offset: -16, fill: MUTED, fontSize: 14 }}
            />
            <YAxis
              domain={[0, 180]}
              ticks={[0, 45, 90, 135, 180]}
              tick={{ fill: MUTED, fontSize: 14 }}
              stroke={GRID}
              width={48}
              label={{ value: t.chart_y_label, angle: -90, position: "insideLeft", fill: MUTED, fontSize: 14, style: { textAnchor: "middle" } }}
            />
            <Tooltip
              cursor={{ stroke: MUTED, strokeWidth: 1 }}
              formatter={(v) => [`${Math.round(Number(v))}°`, t.chart_tooltip_angle]}
              labelFormatter={(s) => `${formatSeconds(Number(s))} ${t.chart_seconds}`}
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
      <p className="text-base text-muted">
        {t.chart_hint}
        {hasGaps && ` ${t.chart_gap_hint}`}
      </p>
    </figure>
  );
}
