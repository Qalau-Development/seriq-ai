"use client";

import Link from "next/link";
import { ChevronRight, Play } from "lucide-react";
import { exerciseAvailability, exerciseDef, type CatalogEntry } from "@/lib/exercises";
import { fill, formatDateTime, useLang } from "@/lib/i18n";
import { useHistoryList } from "@/lib/historyView";
import { ButtonLink } from "@/components/ui/Button";

// RecentSessions — на главной: до трёх последних занятий, кнопка «Начать занятие» и ссылка на всю историю; без истории блока нет
export function RecentSessions({ catalog }: { catalog: CatalogEntry[] | null }) {
  const { t, lang } = useLang();
  const items = useHistoryList();
  if (!items || items.length === 0) return null;
  const last = items[0].exercise;
  const startHref = exerciseAvailability(catalog, last) === "ready" ? `/exercise?e=${last}` : "#exercises";

  return (
    <section className="space-y-4">
      <h2 className="text-2xl font-bold">{t.recent_title}</h2>
      <ul className="space-y-3">
        {items.slice(0, 3).map((s) => (
          <li key={s.id}>
            <Link href={`/summary?id=${s.id}`} className="flex min-h-14 items-center gap-4 rounded-2xl bg-surface p-5 hover:bg-accent-soft">
              <div className="min-w-0 flex-1">
                <p className="text-base font-semibold text-accent">{t[exerciseDef(s.exercise).titleKey]}</p>
                <p className="text-lg font-semibold">{formatDateTime(s.started_at, lang)}</p>
                <p className="text-lg">{fill(t.history_completed_count, { done: s.summary.complete, total: s.summary.total })}</p>
              </div>
              <span className="sr-only">{t.open_summary}</span>
              <ChevronRight aria-hidden className="size-7 shrink-0 text-accent" />
            </Link>
          </li>
        ))}
      </ul>
      <div className="flex flex-col gap-3 sm:flex-row">
        <ButtonLink href={startHref}>
          <Play aria-hidden className="size-6" />
          {t.start_session}
        </ButtonLink>
        <ButtonLink href="/history" variant="secondary">
          {t.recent_all}
        </ButtonLink>
      </div>
    </section>
  );
}
