"use client";

import { useState } from "react";
import { Play } from "lucide-react";
import { fill, useLang } from "@/lib/i18n";
import { useProgress } from "@/lib/progressView";
import { localUtcOffsetMinutes } from "@/lib/progress";
import { Card } from "@/components/ui/Card";
import { ButtonLink } from "@/components/ui/Button";
import { SyncNotice } from "@/components/account/SyncNotice";
import { ExerciseFilter, type ExerciseFilterValue } from "@/components/analysis/ExerciseFilter";
import { SummaryBars } from "@/components/analysis/SummaryBars";
import { ActivityCalendar } from "@/components/analysis/ActivityCalendar";
import { MeasureBars } from "@/components/analysis/MeasureBars";

// ProgressPage — «Мой прогресс»: счёт повторений, доли исходов, дни с занятиями и измеренные значения; только факты, без оценок
export default function ProgressPage() {
  const { t, lang } = useLang();
  const [filter, setFilter] = useState<ExerciseFilterValue>("all");
  const exercise = filter === "all" ? null : filter;
  const { summary, failed } = useProgress(exercise);

  if (summary === null) return <p className="text-lg">{t.loading}</p>;

  const counts = { total: summary.repetitions, ...summary.labels };
  const points = summary.points.map((p, i) => ({ n: i + 1, value: p.value }));

  return (
    <div className="space-y-8">
      <h1 className="text-3xl font-bold">{t.progress_title}</h1>
      <SyncNotice />
      <ExerciseFilter value={filter} onChange={setFilter} t={t} />
      {failed && <p className="rounded-xl bg-neutral-soft p-4 text-lg text-neutral-ink">{t.progress_load_failed}</p>}

      {summary.repetitions === 0 ? (
        <div className="space-y-4">
          <p className="text-lg">{t.progress_empty}</p>
          <ButtonLink href="/" className="w-full sm:w-auto">
            <Play aria-hidden className="size-6" />
            {t.start_session}
          </ButtonLink>
        </div>
      ) : (
        <>
          <p className="text-2xl font-bold">{fill(t.progress_done_line, { n: summary.repetitions })}</p>
          <div className="grid grid-cols-2 gap-4">
            <Card className="space-y-1">
              <p className="text-lg font-semibold">{t.progress_sessions}</p>
              <p className="text-5xl font-bold">{summary.sessions}</p>
            </Card>
            <Card className="space-y-1">
              <p className="text-lg font-semibold">{t.progress_repetitions}</p>
              <p className="text-5xl font-bold">{summary.repetitions}</p>
            </Card>
          </div>
          <SummaryBars summary={counts} exercise={exercise === "E02" ? "E02" : null} showShare title={t.progress_shares_title} t={t} />
          <ActivityCalendar activity={summary.activity} utcOffsetMinutes={localUtcOffsetMinutes()} lang={lang} t={t} />
          {exercise === null ? (
            <p className="text-lg text-muted">{t.progress_choose_exercise}</p>
          ) : (
            <MeasureBars points={points} measure={summary.measure} xLabel={t.attempt_n} t={t} />
          )}
        </>
      )}
      <p className="border-t border-line pt-6 text-lg font-semibold">{t.progress_disclaimer}</p>
    </div>
  );
}
