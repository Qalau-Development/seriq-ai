"use client";

import { useState } from "react";
import { Play } from "lucide-react";
import { fill, useLang } from "@/lib/i18n";
import { useProgress } from "@/lib/progressView";
import { localUtcOffsetMinutes } from "@/lib/progress";
import { ButtonLink } from "@/components/ui/Button";
import { Notice } from "@/components/ui/Notice";
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
    <div className="flex flex-col gap-7 lg:gap-8">
      <h1 className="text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[38px] sm:leading-[46px] lg:text-[44px] lg:leading-[53px]">{t.progress_title}</h1>
      <SyncNotice />
      <ExerciseFilter value={filter} onChange={setFilter} t={t} />
      {failed && <Notice kind="info">{t.progress_load_failed}</Notice>}

      {summary.repetitions === 0 ? (
        <div className="flex max-w-[880px] flex-col gap-5">
          <p className="text-[22px] leading-[33px] font-semibold text-pretty">{t.progress_empty}</p>
          <div>
            <ButtonLink href="/">
              <Play aria-hidden className="size-6" />
              {t.start_session}
            </ButtonLink>
          </div>
        </div>
      ) : (
        <>
          <h2 className="text-[30px] leading-9 font-extrabold tracking-[-0.01em] text-balance sm:text-4xl lg:text-[40px] lg:leading-[48px]">{fill(t.progress_done_line, { n: summary.repetitions })}</h2>
          <div className="grid items-stretch gap-6 lg:grid-cols-[5fr_7fr]">
            <div className="flex flex-col gap-6">
              <div className="grid grid-cols-2 gap-4">
                <div className="rounded-3xl border border-line bg-surface px-5 py-[22px] shadow-card sm:px-7">
                  <div className="text-lg leading-[26px] font-semibold text-muted">{t.progress_sessions}</div>
                  <div className="text-5xl leading-[60px] font-extrabold sm:text-[52px]">{summary.sessions}</div>
                </div>
                <div className="rounded-3xl border border-line bg-surface px-5 py-[22px] shadow-card sm:px-7">
                  <div className="text-lg leading-[26px] font-semibold text-muted">{t.progress_repetitions}</div>
                  <div className="text-5xl leading-[60px] font-extrabold sm:text-[52px]">{summary.repetitions}</div>
                </div>
              </div>
              <SummaryBars summary={counts} exercise={exercise === "E02" ? "E02" : null} showShare title={t.progress_shares_title} t={t} />
            </div>
            <ActivityCalendar activity={summary.activity} utcOffsetMinutes={localUtcOffsetMinutes()} lang={lang} t={t} />
          </div>
          {exercise === null ? (
            <p className="text-lg leading-[27px] text-muted">{t.progress_choose_exercise}</p>
          ) : (
            <MeasureBars points={points} measure={summary.measure} xLabel={t.attempt_n} t={t} />
          )}
        </>
      )}
      <p className="border-t border-line pt-6 text-lg leading-[27px] font-semibold text-pretty">{t.progress_disclaimer}</p>
    </div>
  );
}
