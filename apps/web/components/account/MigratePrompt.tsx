"use client";

import { useEffect, useState } from "react";
import { CloudUpload } from "lucide-react";
import { fill, useLang } from "@/lib/i18n";
import { currentUser } from "@/lib/auth";
import { useAccountMode } from "@/lib/historyView";
import { declineMigration, guestMigratableCount, isMigrationDeclined, migrateGuestSessions, syncNow } from "@/lib/syncRuntime";
import { useSessions } from "@/lib/history";
import { migratableCount } from "@/lib/sync";
import { Button } from "@/components/ui/Button";

// MigratePrompt — после входа: если на устройстве есть гостевая история, спрашивает, перенести ли её в аккаунт; заодно отправляет неотправленное
export function MigratePrompt() {
  const { t } = useLang();
  const mode = useAccountMode();
  const sessions = useSessions();
  const [state, setState] = useState<{ kind: "idle" } | { kind: "working" } | { kind: "done"; moved: number; left: number }>({ kind: "idle" });
  const userId = mode.kind === "account" ? mode.userId : null;

  useEffect(() => {
    if (!userId) return;
    void syncNow();
    const retry = () => void syncNow();
    window.addEventListener("online", retry);
    return () => window.removeEventListener("online", retry);
  }, [userId]);

  if (!userId || sessions === null) return null;
  const migratable = migratableCount(sessions.filter((s) => !s.owner && s.attempts.length > 0));

  if (state.kind === "done") {
    return (
      <Banner
        text={
          <div className="flex flex-col gap-1.5">
            <p className="text-[22px] leading-[29px] font-extrabold text-pretty sm:text-2xl sm:leading-[31px]">{fill(t.migrate_done, { n: state.moved })}</p>
            {state.left > 0 && <p className="text-lg leading-[27px] text-pretty">{fill(t.migrate_left, { n: state.left })}</p>}
          </div>
        }
        actions={
          <Button variant="secondary" onClick={() => setState({ kind: "idle" })}>
            OK
          </Button>
        }
      />
    );
  }
  if (migratable === 0 || isMigrationDeclined(userId)) return null;

  // accept — переносит гостевые занятия в аккаунт и показывает итог
  async function accept() {
    setState({ kind: "working" });
    const user = currentUser();
    if (!user || guestMigratableCount() === 0) return setState({ kind: "idle" });
    setState({ kind: "done", ...(await migrateGuestSessions()) });
  }

  return (
    <Banner
      text={
        <div className="flex flex-col gap-1.5">
          <p className="text-[22px] leading-[29px] font-extrabold text-pretty sm:text-2xl sm:leading-[31px]">{t.migrate_question}</p>
          <p className="text-lg leading-[27px] text-pretty">{t.migrate_note}</p>
          <p className="text-lg leading-[27px] font-bold">{fill(t.migrate_count, { n: migratable })}</p>
        </div>
      }
      actions={
        <>
          <Button onClick={accept} disabled={state.kind === "working"}>
            {state.kind === "working" ? t.migrate_working : t.migrate_yes}
          </Button>
          <Button
            variant="secondary"
            onClick={() => {
              declineMigration(userId);
              setState({ kind: "idle" });
            }}
            disabled={state.kind === "working"}
          >
            {t.migrate_no}
          </Button>
        </>
      }
    />
  );
}

// Banner — заметный блок над содержимым страницы: иконка и тексты слева, кнопки справа; на телефоне всё в столбик
function Banner({ text, actions }: { text: React.ReactNode; actions: React.ReactNode }) {
  return (
    <div className="page-shell pt-8">
      <section className="flex flex-col gap-4 rounded-[28px] border-2 border-brand-soft-2 bg-neutral-soft p-6 lg:flex-row lg:items-center lg:justify-between lg:gap-8 lg:px-9 lg:py-7">
        <div className="flex flex-col gap-3.5 lg:flex-row lg:items-center lg:gap-5">
          <span aria-hidden className="flex size-12 shrink-0 items-center justify-center rounded-full bg-brand text-white lg:size-14">
            <CloudUpload className="size-6" strokeWidth={2.4} />
          </span>
          {text}
        </div>
        <div className="flex flex-col gap-3 sm:flex-row sm:gap-4 lg:shrink-0">{actions}</div>
      </section>
    </div>
  );
}
