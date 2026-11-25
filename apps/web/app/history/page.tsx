"use client";

import { useState } from "react";
import { Play, Trash2 } from "lucide-react";
import { removeSessions } from "@/lib/history";
import { useAccountMode, useHistoryList } from "@/lib/historyView";
import { clearRemoteHistory, deleteRemoteSession } from "@/lib/serverHistory";
import { fill, formatDateTime, useLang } from "@/lib/i18n";
import { exerciseDef } from "@/lib/exercises";
import { ButtonLink } from "@/components/ui/Button";
import { Checkbox } from "@/components/ui/Checkbox";
import { Notice } from "@/components/ui/Notice";
import { TileLink, TileTexts } from "@/components/ui/Tile";
import { ExerciseFilter, type ExerciseFilterValue } from "@/components/analysis/ExerciseFilter";
import { SyncNotice } from "@/components/account/SyncNotice";
import { ConfirmAction } from "@/components/analysis/ConfirmAction";

// HistoryPage — прошлые занятия с упражнением, датой и сводкой, фильтр, выбор нескольких и удаление
export default function HistoryPage() {
  const { t, lang } = useLang();
  const { items: list, offline } = useHistoryList();
  const mode = useAccountMode();
  const account = mode.kind === "account";
  const userId = mode.kind === "account" ? mode.userId : null;
  const [filter, setFilter] = useState<ExerciseFilterValue>("all");
  const [selected, setSelected] = useState<Set<string>>(new Set());

  // removeMany — удаляет выбранные занятия: у вошедшего сначала на сервере, затем на устройстве
  async function removeMany(ids: string[]) {
    if (account) await Promise.all(ids.map((id) => deleteRemoteSession(id)));
    removeSessions((s) => ids.includes(s.id));
    setSelected(new Set());
  }

  // removeAll — очищает историю: у вошедшего на сервере и копии на устройстве, у гостя гостевые занятия
  async function removeAll() {
    if (account) await clearRemoteHistory();
    removeSessions((s) => (userId ? s.owner === userId : !s.owner));
    setSelected(new Set());
  }

  if (list === null) return <p className="text-lg">{t.loading}</p>;

  const shown = list.filter((s) => filter === "all" || s.exercise === filter);
  const allSelected = shown.length > 0 && shown.every((s) => selected.has(s.id));

  // toggleAll — выбирает все показанные занятия или снимает выбор со всех
  function toggleAll() {
    setSelected(allSelected ? new Set() : new Set(shown.map((s) => s.id)));
  }

  // toggleOne — добавляет или убирает одно занятие из выбранных
  function toggleOne(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

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
          <ExerciseFilter
            value={filter}
            onChange={(v) => {
              setFilter(v);
              setSelected(new Set());
            }}
            t={t}
          />
          {shown.length === 0 && <p className="text-lg leading-[27px] text-muted">{t.history_filter_empty}</p>}
          {shown.length > 0 && (
            <div className="flex flex-col gap-3 rounded-[22px] border-2 border-line bg-surface p-4 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between sm:gap-4 sm:p-5">
              <label className="flex items-center gap-3 text-lg leading-[1.2] font-bold text-ink">
                <Checkbox checked={allSelected} onClick={toggleAll} />
                {t.history_select_all}
              </label>
              <div className="flex flex-wrap items-center gap-3 sm:gap-4">
                {selected.size > 0 && <span className="text-base font-bold text-muted">{fill(t.history_selected_count, { count: selected.size })}</span>}
                <ConfirmAction
                  label={t.delete_selected}
                  question={account ? t.delete_selected_confirm_account : t.delete_selected_confirm}
                  yes={t.clear_history_yes}
                  icon={<Trash2 aria-hidden className="size-6" />}
                  onConfirm={() => removeMany([...selected])}
                  t={t}
                  variant="danger-soft"
                  disabled={selected.size === 0}
                />
                <ConfirmAction
                  label={t.clear_history}
                  question={account ? t.clear_history_confirm_account : t.clear_history_confirm}
                  yes={t.clear_history_yes}
                  icon={<Trash2 aria-hidden className="size-6" />}
                  onConfirm={removeAll}
                  t={t}
                />
              </div>
            </div>
          )}
          <ul className="flex flex-col gap-3">
            {shown.map((s) => (
              <li key={s.id} className="flex items-center gap-3">
                <Checkbox checked={selected.has(s.id)} onClick={() => toggleOne(s.id)} aria-label={`${t[exerciseDef(s.exercise).titleKey]}, ${formatDateTime(s.started_at, lang)}`} />
                <div className="min-w-0 flex-1">
                  <TileLink href={`/summary?id=${s.id}`} variant="white" srLabel={t.open_summary}>
                    <TileTexts
                      exercise={t[exerciseDef(s.exercise).titleKey]}
                      date={formatDateTime(s.started_at, lang)}
                      done={fill(t.history_completed_count, { done: s.summary.complete, total: s.summary.total })}
                    />
                  </TileLink>
                </div>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}
