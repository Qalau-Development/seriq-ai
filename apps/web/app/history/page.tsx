"use client";

import { useState } from "react";
import Link from "next/link";
import { ChevronRight, Play, Trash2 } from "lucide-react";
import { clearHistory, deleteSession } from "@/lib/history";
import { useHistoryList } from "@/lib/historyView";
import { fill, formatDateTime, useLang } from "@/lib/i18n";
import { exerciseDef } from "@/lib/exercises";
import { ButtonLink } from "@/components/ui/Button";
import { ExerciseFilter, type ExerciseFilterValue } from "@/components/analysis/ExerciseFilter";
import { ConfirmAction } from "@/components/analysis/ConfirmAction";

// HistoryPage — прошлые занятия с упражнением, датой и сводкой, фильтр, удаление занятия и очистка истории
export default function HistoryPage() {
  const { t, lang } = useLang();
  const list = useHistoryList();
  const [filter, setFilter] = useState<ExerciseFilterValue>("all");

  if (list === null) return <p className="text-lg">{t.loading}</p>;

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
          <ExerciseFilter value={filter} onChange={setFilter} t={t} />
          {shown.length === 0 && <p className="text-lg">{t.history_filter_empty}</p>}
          <ul className="space-y-4">
            {shown.map((s) => (
              <li key={s.id} className="space-y-2">
                <Link href={`/summary?id=${s.id}`} className="flex min-h-14 items-center gap-4 rounded-2xl bg-surface p-5 hover:bg-accent-soft">
                  <div className="min-w-0 flex-1">
                    <p className="text-base font-semibold text-accent">{t[exerciseDef(s.exercise).titleKey]}</p>
                    <p className="text-lg font-semibold">{formatDateTime(s.started_at, lang)}</p>
                    <p className="text-lg">{fill(t.history_completed_count, { done: s.summary.complete, total: s.summary.total })}</p>
                  </div>
                  <span className="sr-only">{t.open_summary}</span>
                  <ChevronRight aria-hidden className="size-7 shrink-0 text-accent" />
                </Link>
                <ConfirmAction
                  label={t.delete_session}
                  question={t.delete_session_confirm}
                  yes={t.clear_history_yes}
                  icon={<Trash2 aria-hidden className="size-6" />}
                  onConfirm={() => deleteSession(s.id)}
                  t={t}
                  className="w-full sm:w-auto"
                />
              </li>
            ))}
          </ul>

          <ConfirmAction
            label={t.clear_history}
            question={t.clear_history_confirm}
            yes={t.clear_history_yes}
            icon={<Trash2 aria-hidden className="size-6" />}
            onConfirm={() => clearHistory()}
            t={t}
            className="w-full sm:w-auto"
          />
        </>
      )}
    </div>
  );
}
