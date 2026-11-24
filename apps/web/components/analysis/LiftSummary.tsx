"use client";

import { Timer, TrendingUp } from "lucide-react";
import type { AnalysisResult } from "@/types/analysis";
import { fill, type Dict } from "@/lib/i18n";
import { useSessions } from "@/lib/history";
import { decimal } from "@/lib/measureText";
import { compareWithHistory, riseTime, type LiftAttempt } from "@/lib/liftStats";

// signed — число со знаком и разделителем языка: +0,4 или −0,2
function signed(value: number, t: Dict): string {
  if (value === 0) return decimal(0, t);
  return `${value > 0 ? "+" : "−"}${decimal(Math.abs(value), t)}`;
}

// LiftSummary — E01: время подъёма, разница с прошлой попыткой и лучший результат по истории на устройстве
export function LiftSummary({ result, t }: { result: AnalysisResult; t: Dict }) {
  const sessions = useSessions();
  const measure = result.measure;
  if (result.exercise !== "E01" || !measure || measure.name !== "lift_height" || measure.value === null) return null;

  const riseS = riseTime(measure.series);
  const attempts = (sessions ?? []).filter((s) => s.exercise === "E01").flatMap((s) => s.attempts);
  const own = attempts.find((a) => a.analysis_id === result.analysis_id);
  const current: LiftAttempt = { at: own?.at ?? new Date().toISOString(), value: measure.value, riseS };
  const history: LiftAttempt[] = attempts
    .filter((a) => a.analysis_id !== result.analysis_id && a.source === result.source)
    .map((a) => ({ at: a.at, value: a.measure?.value ?? null, riseS: riseTime(a.measure?.series) }));
  const cmp = compareWithHistory(current, history);
  const unit = t.chart_unit_hand_lengths;

  return (
    <section className="space-y-3 rounded-[20px] border border-brand-soft-2 bg-neutral-soft p-5 text-lg text-neutral-ink sm:px-6">
      <h2 className="text-2xl font-bold">{t.lift_title}</h2>
      {riseS !== null && (
        <p className="flex items-center gap-3">
          <Timer aria-hidden className="size-6 shrink-0" />
          {fill(t.lift_rise_time, { s: decimal(riseS, t) })}
        </p>
      )}
      <p className="flex items-start gap-3">
        <TrendingUp aria-hidden className="mt-1 size-6 shrink-0" />
        <span>
          {cmp.previous
            ? [
                cmp.previous.valueDelta !== null ? fill(t.lift_vs_previous_value, { d: signed(cmp.previous.valueDelta, t), unit }) : null,
                cmp.previous.riseDelta !== null ? fill(t.lift_vs_previous_time, { d: signed(cmp.previous.riseDelta, t) }) : null,
              ]
                .filter(Boolean)
                .join(" ")
            : t.lift_first}
        </span>
      </p>
      {cmp.best !== null && cmp.previous && (
        <p className="font-semibold">{cmp.isBest ? t.lift_is_best : fill(t.lift_best, { n: decimal(cmp.best, t), unit })}</p>
      )}
      {result.pose && <p className="text-base">{t.lift_line_hint}</p>}
      <p className="text-base text-muted">{t.lift_note}</p>
    </section>
  );
}
