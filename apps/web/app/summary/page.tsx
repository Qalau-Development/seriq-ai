"use client";

import { Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { History, Play, Trash2 } from "lucide-react";
import { removeSessions, summarize } from "@/lib/history";
import { useAccountMode, useSessionDetail } from "@/lib/historyView";
import { deleteRemoteSession } from "@/lib/serverHistory";
import { formatDateTime, useLang } from "@/lib/i18n";
import { exerciseDef } from "@/lib/exercises";
import { Card } from "@/components/ui/Card";
import { ButtonLink } from "@/components/ui/Button";
import { Notice } from "@/components/ui/Notice";
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
  const id = useSearchParams().get("id");
  const router = useRouter();
  const { session, offline } = useSessionDetail(id);
  const account = useAccountMode().kind === "account";

  if (session === undefined) return <p className="text-lg">{t.loading}</p>;

  if (!session) {
    return (
      <div className="mx-auto w-full max-w-[720px]">
        <Card className="flex flex-col gap-6 sm:p-10!">
          <p className="text-[22px] leading-[31px] font-bold text-pretty sm:text-[28px] sm:leading-[39px]">{t.summary_not_found}</p>
          <div>
            <ButtonLink href="/history" variant="secondary">
              <History aria-hidden className="size-6" />
              {t.nav_history}
            </ButtonLink>
          </div>
        </Card>
      </div>
    );
  }

  const summary = summarize(session.attempts);
  const date = formatDateTime(session.started_at, lang);
  const hasMock = session.attempts.some((a) => a.source === "mock");

  return (
    <div className="flex flex-col gap-8 lg:gap-9">
      <section className="flex flex-col gap-5 lg:flex-row lg:items-center lg:justify-between lg:gap-8">
        <div className="flex flex-col gap-1.5">
          <h1 className="text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[38px] sm:leading-[46px] lg:text-[44px] lg:leading-[53px]">{t.summary_title}</h1>
          <p className="text-[22px] leading-[30px] font-bold text-link sm:text-[28px] sm:leading-9">{t[exerciseDef(session.exercise).titleKey]}</p>
          <p className="text-lg leading-[27px] text-muted">{date}</p>
        </div>
        <div className="flex w-full items-center justify-between gap-4 rounded-[28px] bg-brand px-6 py-5 text-white sm:px-8 sm:py-6 lg:w-[380px] lg:shrink-0">
          <span className="text-xl leading-[1.3] font-bold">{t.summary_total}</span>
          <span className="text-[56px] leading-none font-extrabold sm:text-[76px]">{summary.total}</span>
        </div>
      </section>
      {offline && <Notice kind="info">{t.history_offline_note}</Notice>}
      {hasMock && <MockBadge t={t} text={t.summary_has_mock} />}
      <div className="grid items-stretch gap-6 lg:grid-cols-2">
        <SummaryBars summary={summary} exercise={session.exercise} t={t} />
        <MeasureBars {...attemptPoints(session.attempts)} xLabel={t.attempt_n} t={t} />
      </div>
      <section className="flex flex-col gap-5 lg:gap-6">
        <h2 className="text-[26px] leading-[31px] font-extrabold tracking-[-0.01em] text-balance sm:text-[32px] sm:leading-[38px]">{t.summary_attempts}</h2>
        <AttemptList attempts={session.attempts} exercise={session.exercise} t={t} />
      </section>
      <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:gap-4">
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
        question={account ? t.delete_session_confirm_account : t.delete_session_confirm}
        yes={t.clear_history_yes}
        icon={<Trash2 aria-hidden className="size-6" />}
        onConfirm={async () => {
          if (account) await deleteRemoteSession(session.id);
          removeSessions((s) => s.id === session.id);
          router.push("/history");
        }}
        t={t}
        className="sm:self-start"
      />
    </div>
  );
}
