"use client";

import { useState } from "react";
import Link from "next/link";
import { ChevronRight, Play, Trash2 } from "lucide-react";
import { clearHistory, summarize, useSessions } from "@/lib/history";
import { fill, formatDateTime, useLang } from "@/lib/i18n";
import { EXERCISES, exerciseDef } from "@/lib/exercises";
import type { ExerciseId } from "@/types/analysis";
import { Button, ButtonLink } from "@/components/ui/Button";

// HistoryPage — прошлые занятия с датой и сводкой, удаление истории
export default function HistoryPage() {
  const { t, lang } = useLang();
  const sessions = useSessions();
  const [confirming, setConfirming] = useState(false);
  const [filter, setFilter] = useState<ExerciseId | "all">("all");

  if (sessions === null) return <p className="text-lg">{t.loading}</p>;

  const list = sessions
    .filter((s) => s.attempts.length > 0)
    .sort((a, b) => b.started_at.localeCompare(a.started_at));

  const shown = list.filter((s) => filter === "all" || s.exercise === filter);

  return (
    <div className="space-y-8">
      <section className="space-y-2">
        <h1 className="text-3xl font-bold">{t.history_title}</h1>
        <p className="text-lg text-muted">{list.length > 0 ? t.history_local_note : t.history_empty}</p>
      </section>

      {list.length === 0 ? (
        <ButtonLink href="/" className="w-full sm:w-auto">
          <Play aria-hidden className="size-6" />
          {t.start_session}
        </ButtonLink>
      ) : (
        <>
          <div role="group" aria-label={t.history_filter_label} className="flex flex-wrap gap-2">
            {[{ id: "all" as const, text: t.history_filter_all }, ...EXERCISES.map((e) => ({ id: e.id, text: t[e.titleKey] }))].map((o) => (
              <button
                key={o.id}
                type="button"
                aria-pressed={filter === o.id}
                onClick={() => setFilter(o.id)}
                className={`min-h-12 rounded-xl border-2 border-accent px-4 text-lg font-semibold ${filter === o.id ? "bg-accent text-white" : "bg-page text-accent hover:bg-accent-soft"}`}
              >
                {o.text}
              </button>
            ))}
          </div>
          {shown.length === 0 && <p className="text-lg">{t.history_filter_empty}</p>}
          <ul className="space-y-3">
            {shown.map((s) => {
              const sum = summarize(s.attempts);
              return (
                <li key={s.id}>
                  <Link
                    href={`/summary?id=${s.id}`}
                    className="flex min-h-14 items-center gap-4 rounded-2xl bg-surface p-5 hover:bg-accent-soft"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="text-base font-semibold text-accent">{t[exerciseDef(s.exercise).titleKey]}</p>
                      <p className="text-lg font-semibold">{formatDateTime(s.started_at, lang)}</p>
                      <p className="text-lg">
                        {fill(t.history_completed_count, { done: sum.complete, total: sum.total })}
                      </p>
                    </div>
                    <span className="sr-only">{t.open_summary}</span>
                    <ChevronRight aria-hidden className="size-7 shrink-0 text-accent" />
                  </Link>
                </li>
              );
            })}
          </ul>

          {confirming ? (
            <div className="space-y-4 rounded-2xl border-2 border-error-ink bg-error-soft p-5" role="alertdialog" aria-labelledby="clear-q">
              <p id="clear-q" className="text-lg font-semibold text-error-ink">
                {t.clear_history_confirm}
              </p>
              <div className="flex flex-col gap-3 sm:flex-row">
                <Button
                  variant="danger"
                  onClick={() => {
                    clearHistory();
                    setConfirming(false);
                  }}
                >
                  {t.clear_history_yes}
                </Button>
                <Button variant="secondary" onClick={() => setConfirming(false)} autoFocus>
                  {t.clear_history_no}
                </Button>
              </div>
            </div>
          ) : (
            <Button variant="secondary" onClick={() => setConfirming(true)} className="w-full sm:w-auto">
              <Trash2 aria-hidden className="size-6" />
              {t.clear_history}
            </Button>
          )}
        </>
      )}
    </div>
  );
}
