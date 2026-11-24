"use client";

import { useEffect, useState } from "react";
import { fill, useLang } from "@/lib/i18n";
import { currentUser } from "@/lib/auth";
import { useAccountMode } from "@/lib/historyView";
import { declineMigration, guestSessions, isMigrationDeclined, migrateGuestSessions, syncNow } from "@/lib/syncRuntime";
import { useSessions } from "@/lib/history";
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
  const hasGuest = sessions.some((s) => !s.owner && s.attempts.length > 0);

  if (state.kind === "done") {
    return (
      <Banner>
        <p className="text-lg font-semibold">{fill(t.migrate_done, { n: state.moved })}</p>
        {state.left > 0 && <p className="text-lg">{fill(t.migrate_left, { n: state.left })}</p>}
        <Button variant="secondary" onClick={() => setState({ kind: "idle" })}>
          OK
        </Button>
      </Banner>
    );
  }
  if (!hasGuest || isMigrationDeclined(userId)) return null;

  // accept — переносит гостевые занятия в аккаунт и показывает итог
  async function accept() {
    setState({ kind: "working" });
    const user = currentUser();
    if (!user || guestSessions().length === 0) return setState({ kind: "idle" });
    setState({ kind: "done", ...(await migrateGuestSessions()) });
  }

  return (
    <Banner>
      <p className="text-xl font-bold">{t.migrate_question}</p>
      <p className="text-lg">{t.migrate_note}</p>
      <div className="flex flex-col gap-3 sm:flex-row">
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
      </div>
    </Banner>
  );
}

// Banner — заметный блок над содержимым страницы
function Banner({ children }: { children: React.ReactNode }) {
  return (
    <div className="border-b border-line bg-accent-soft px-5 py-4">
      <div className="mx-auto w-full max-w-3xl space-y-3">{children}</div>
    </div>
  );
}
