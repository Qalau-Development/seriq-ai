"use client";

import Link from "next/link";
import { CircleCheck, CloudOff, Info, LoaderCircle } from "lucide-react";
import { useLang } from "@/lib/i18n";
import { useAccountMode } from "@/lib/historyView";
import { useSyncStatus } from "@/lib/syncRuntime";

// SyncNotice — состояние сохранения занятий в аккаунте: сохраняем, сохранено, нет связи, вход истёк, предел истории, сервер не принял; гостю ничего не показывает
export function SyncNotice() {
  const { t } = useLang();
  const mode = useAccountMode();
  const status = useSyncStatus();
  if (mode.kind !== "account" || status === "idle") return null;
  const text = { syncing: t.sync_syncing, ok: t.sync_ok, offline: t.sync_offline, auth: t.sync_auth, quota: t.sync_quota, error: t.sync_error }[status];
  const problem = status === "offline" || status === "auth" || status === "quota" || status === "error";
  const Icon = status === "syncing" ? LoaderCircle : status === "ok" ? CircleCheck : status === "offline" ? CloudOff : Info;
  return (
    <div
      aria-live="polite"
      className={`flex max-w-[720px] items-center gap-3 rounded-2xl px-5 py-3 text-base leading-6 font-semibold ${
        problem ? "border-2 border-warn-line bg-warn-soft text-warn-ink" : "border border-brand-soft-2 bg-neutral-soft text-neutral-ink"
      }`}
    >
      <Icon aria-hidden className={`size-[26px] shrink-0 ${status === "syncing" ? "animate-spin" : ""}`} strokeWidth={2.2} />
      <p>
        {text}{" "}
        {status === "auth" && (
          <Link href="/login" className="underline underline-offset-4">
            {t.nav_login}
          </Link>
        )}
      </p>
    </div>
  );
}
