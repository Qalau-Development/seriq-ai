"use client";

import { useState } from "react";
import { Play, Trash2 } from "lucide-react";
import { removeSessions } from "@/lib/history";
import { useAccountMode, useHistoryList } from "@/lib/historyView";
import { clearRemoteHistory, deleteRemoteSession } from "@/lib/serverHistory";
import { fill, formatDateTime, useLang } from "@/lib/i18n";
import { exerciseDef } from "@/lib/exercises";
import { ButtonLink } from "@/components/ui/Button";
import { Notice } from "@/components/ui/Notice";
import { TileLink, TileTexts } from "@/components/ui/Tile";
import { ExerciseFilter, type ExerciseFilterValue } from "@/components/analysis/ExerciseFilter";
import { SyncNotice } from "@/components/account/SyncNotice";
import { ConfirmAction } from "@/components/analysis/ConfirmAction";

// HistoryPage — прошлые занятия с упражнением, датой и сводкой, фильтр, удаление занятия и очистка истории
export default function HistoryPage() {
  const { t, lang } = useLang();
  const { items: list, offline } = useHistoryList();
  const mode = useAccountMode();
  const account = mode.kind === "account";
  const userId = mode.kind === "account" ? mode.userId : null;

  // removeOne — удаляет занятие: у вошедшего сначала на сервере, затем на устройстве
  async function removeOne(id: string) {
    if (account) await deleteRemoteSession(id);
    removeSessions((s) => s.id === id);
  }

  // removeAll — очищает историю: у вошедшего на сервере и копии на устройстве, у гостя гостевые занятия
  async function removeAll() {
    if (account) await clearRemoteHistory();
    removeSessions((s) => (userId ? s.owner === userId : !s.owner));
  }
  const [filter, setFilter] = useState<ExerciseFilterValue>("all");

  if (list === null) return <p className="text-lg">{t.loading}</p>;

  const shown = list.filter((s) => filter === "all" || s.exercise === filter);

  return (
    <div className="flex flex-col gap-7 lg:gap-7">
      <section className="flex flex-col gap-2">
        <h1 className="text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[38px] sm:leading-[46px] lg:text-[44px] lg:leading-[53px]">{t.history_title}</h1>
        <p className="text-lg leading-[27px] text-pretty text-muted">{list.length > 0 ? (account ? t.history_account_note : t.history_local_note) : account ? t.history_empty_account : t.history_empty}</p>
      </section>
      {offline && <Notice kind="info">{t.history_offline_note}</Notice>}
      <SyncNotice />

      {list.length === 0 ? (
        <div>
          <ButtonLink href="/">
            <Play aria-hidden className="size-6" />
            {t.start_session}
          </ButtonLink>
        </div>
      ) : (
        <>
          <ExerciseFilter value={filter} onChange={setFilter} t={t} />
          {shown.length === 0 && <p className="text-lg leading-[27px] text-muted">{t.history_filter_empty}</p>}
          <ul className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 lg:gap-6">
            {shown.map((s) => (
              <li key={s.id} className="flex flex-col gap-2.5">
                <TileLink href={`/summary?id=${s.id}`} variant="white" srLabel={t.open_summary}>
                  <TileTexts
                    exercise={t[exerciseDef(s.exercise).titleKey]}
                    date={formatDateTime(s.started_at, lang)}
                    done={fill(t.history_completed_count, { done: s.summary.complete, total: s.summary.total })}
                  />
                </TileLink>
                <ConfirmAction
                  label={t.delete_session}
                  question={account ? t.delete_session_confirm_account : t.delete_session_confirm}
                  yes={t.clear_history_yes}
                  icon={<Trash2 aria-hidden className="size-6" />}
                  onConfirm={() => removeOne(s.id)}
                  t={t}
                  className="sm:self-start"
                />
              </li>
            ))}
          </ul>

          <ConfirmAction
            label={t.clear_history}
            question={account ? t.clear_history_confirm_account : t.clear_history_confirm}
            yes={t.clear_history_yes}
            icon={<Trash2 aria-hidden className="size-6" />}
            onConfirm={removeAll}
            t={t}
            className="sm:self-start"
          />
        </>
      )}
    </div>
  );
}
