"use client";

import { Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { History, Play, Trash2 } from "lucide-react";
import { deleteSession, summarize, useSessions } from "@/lib/history";
import { formatDateTime, useLang } from "@/lib/i18n";
import { exerciseDef } from "@/lib/exercises";
import { Card } from "@/components/ui/Card";
import { ButtonLink } from "@/components/ui/Button";
import { MockBadge } from "@/components/analysis/MockBadge";
import { SummaryBars } from "@/components/analysis/SummaryBars";
import { ConfirmAction } from "@/components/analysis/ConfirmAction";
import { MeasureBars, attemptPoints } from "@/components/analysis/MeasureBars";
import { AttemptList } from "@/components/analysis/AttemptList";

// SummaryPage — страница итогов; id занятия читается из адреса
export default function SummaryPage() {
  return (
    <Suspense>
      <SessionSummaryView />
    </Suspense>
  );
}

// SessionSummaryView — итоги завершённого занятия по id из адреса
function SessionSummaryView() {
  const { t, lang } = useLang();
  const sessions = useSessions();
  const id = useSearchParams().get("id");
  const router = useRouter();

  if (sessions === null) return <p className="text-lg">{t.loading}</p>;

  const session = sessions.find((s) => s.id === id);
  if (!session) {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold">{t.summary_title}</h1>
        <p className="text-lg">{t.summary_not_found}</p>
        <ButtonLink href="/history" variant="secondary" className="w-full sm:w-auto">
          <History aria-hidden className="size-6" />
          {t.nav_history}
        </ButtonLink>
      </div>
    );
  }

  const summary = summarize(session.attempts);
  const date = formatDateTime(session.started_at, lang);
  const hasMock = session.attempts.some((a) => a.source === "mock");

  return (
    <div className="space-y-8">
      <section className="space-y-1">
        <h1 className="text-3xl font-bold">{t.summary_title}</h1>
        <p className="text-xl font-semibold">{t[exerciseDef(session.exercise).titleKey]}</p>
        <p className="text-lg text-muted">{date}</p>
      </section>
      {hasMock && <MockBadge t={t} text={t.summary_has_mock} />}
      <Card className="flex items-baseline justify-between gap-4">
        <span className="text-xl font-semibold">{t.summary_total}</span>
        <span className="text-5xl font-bold">{summary.total}</span>
      </Card>
      <SummaryBars summary={summary} exercise={session.exercise} t={t} />
      <MeasureBars {...attemptPoints(session.attempts)} xLabel={t.attempt_n} t={t} />
      <section className="space-y-4">
        <h2 className="text-2xl font-bold">{t.summary_attempts}</h2>
        <AttemptList attempts={session.attempts} exercise={session.exercise} t={t} />
      </section>
      <div className="flex flex-col gap-3 sm:flex-row">
        <ButtonLink href={`/session?e=${session.exercise}`}>
          <Play aria-hidden className="size-6" />
          {t.new_session}
        </ButtonLink>
        <ButtonLink href="/history" variant="secondary">
          <History aria-hidden className="size-6" />
          {t.nav_history}
        </ButtonLink>
      </div>
      <ConfirmAction
        label={t.delete_session}
        question={t.delete_session_confirm}
        yes={t.clear_history_yes}
        icon={<Trash2 aria-hidden className="size-6" />}
        onConfirm={() => {
          deleteSession(session.id);
          router.push("/history");
        }}
        t={t}
        className="w-full sm:w-auto"
      />
    </div>
  );
}
