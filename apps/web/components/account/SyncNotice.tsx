"use client";

import Link from "next/link";
import { CloudOff, CloudUpload, Info } from "lucide-react";
import { useLang } from "@/lib/i18n";
import { useAccountMode } from "@/lib/historyView";
import { useSyncStatus } from "@/lib/syncRuntime";

// SyncNotice — состояние сохранения занятий в аккаунте: сохраняем, сохранено, нет связи, вход истёк, сервер не принял; гостю ничего не показывает
export function SyncNotice() {
  const { t } = useLang();
  const mode = useAccountMode();
  const status = useSyncStatus();
  if (mode.kind !== "account" || status === "idle") return null;
  const text = { syncing: t.sync_syncing, ok: t.sync_ok, offline: t.sync_offline, auth: t.sync_auth, error: t.sync_error }[status];
  const problem = status === "offline" || status === "auth" || status === "error";
  return (
    <div
      aria-live="polite"
      className={`flex items-start gap-3 rounded-xl p-4 text-lg ${problem ? "bg-neutral-soft text-neutral-ink" : "bg-surface text-ink"}`}
    >
      {status === "offline" ? <CloudOff aria-hidden className="mt-1 size-6 shrink-0" /> : problem ? <Info aria-hidden className="mt-1 size-6 shrink-0" /> : <CloudUpload aria-hidden className="mt-1 size-6 shrink-0" />}
      <p>
        {text}{" "}
        {status === "auth" && (
          <Link href="/login" className="font-semibold underline underline-offset-4">
            {t.nav_login}
          </Link>
        )}
      </p>
    </div>
  );
}
