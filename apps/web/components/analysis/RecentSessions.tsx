"use client";

import { Play } from "lucide-react";
import { exerciseAvailability, exerciseDef, type CatalogEntry } from "@/lib/exercises";
import { fill, formatDateTime, useLang } from "@/lib/i18n";
import { useHistoryList } from "@/lib/historyView";
import { ButtonLink } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { TileLink, TileTexts } from "@/components/ui/Tile";

// RecentSessions — на главной: до трёх последних занятий, кнопка «Начать занятие» и ссылка на всю историю; без истории блока нет
export function RecentSessions({ catalog }: { catalog: CatalogEntry[] | null }) {
  const { t, lang } = useLang();
  const { items } = useHistoryList();
  if (!items || items.length === 0) return null;
  const last = items[0].exercise;
  const startHref = exerciseAvailability(catalog, last) === "ready" ? `/exercise?e=${last}` : "#exercises";

  return (
    <Card className="flex flex-col gap-5 lg:gap-[22px]">
      <h2 className="text-[26px] leading-[31px] font-extrabold tracking-[-0.01em] text-balance lg:text-[28px] lg:leading-[34px]">{t.recent_title}</h2>
      <ul className="flex flex-col gap-3">
        {items.slice(0, 3).map((s) => (
          <li key={s.id}>
            <TileLink href={`/summary?id=${s.id}`} srLabel={t.open_summary}>
              <TileTexts
                exercise={t[exerciseDef(s.exercise).titleKey]}
                date={formatDateTime(s.started_at, lang)}
                done={fill(t.history_completed_count, { done: s.summary.complete, total: s.summary.total })}
              />
            </TileLink>
          </li>
        ))}
      </ul>
      <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:gap-4">
        <ButtonLink href={startHref}>
          <Play aria-hidden className="size-6" />
          {t.start_session}
        </ButtonLink>
        <ButtonLink href="/history" variant="secondary">
          {t.recent_all}
        </ButtonLink>
      </div>
    </Card>
  );
}
