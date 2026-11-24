"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { LogOut, Trash2 } from "lucide-react";
import { AccountError, useAuth } from "@/lib/auth";
import { logout as signOutAndClean, removeAccount } from "@/lib/syncRuntime";
import { useAccountsAvailable } from "@/lib/accounts";
import { textOr, useLang } from "@/lib/i18n";
import { Button, ButtonLink } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import Link from "next/link";

// ProfilePage — профиль: логин, выход, удаление аккаунта и данных с подтверждением паролем
export default function ProfilePage() {
  const { t } = useLang();
  const router = useRouter();
  const auth = useAuth();
  const available = useAccountsAvailable();
  const [deleting, setDeleting] = useState(false);
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (auth.kind === "restoring") return <p className="text-lg">{t.loading}</p>;
  if (!available || auth.kind !== "in") {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold">{t.profile_title}</h1>
        <p className="text-lg">{available ? t.profile_not_logged : t.auth_unavailable}</p>
        <ButtonLink href={available ? "/login" : "/"} className="w-full sm:w-auto">
          {available ? t.nav_login : t.nav_home}
        </ButtonLink>
      </div>
    );
  }

  // logout — выходит из аккаунта и открывает главную
  async function logout() {
    await signOutAndClean();
    router.push("/");
  }

  // remove — удаляет аккаунт; при неверном пароле показывает ошибку
  async function remove(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await removeAccount(password);
      router.push("/");
    } catch (err) {
      const code = err instanceof AccountError ? err.code : "internal_error";
      setError(textOr(t, `error_${code}`, "error_internal_error").replace("{time}", ""));
      setBusy(false);
    }
  }

  return (
    <div className="space-y-8">
      <h1 className="text-3xl font-bold">{t.profile_title}</h1>
      <Card className="space-y-1">
        <p className="text-lg text-muted">{t.profile_login}</p>
        <p className="text-3xl font-bold break-all">{auth.user.login}</p>
      </Card>
      <p className="text-lg">{t.profile_stored_note}</p>
      <Link href="/privacy" className="inline-flex min-h-12 items-center text-lg font-semibold text-accent underline underline-offset-4">
        {t.privacy_link}
      </Link>
      <Button variant="secondary" onClick={logout} className="w-full sm:w-auto">
        <LogOut aria-hidden className="size-6" />
        {t.profile_logout}
      </Button>

      {deleting ? (
        <form onSubmit={remove} className="space-y-4 rounded-2xl border-2 border-error-ink bg-error-soft p-5" role="alertdialog" aria-labelledby="del-q">
          <p id="del-q" className="text-lg font-semibold text-error-ink">
            {t.profile_delete_warning}
          </p>
          <label htmlFor="del-password" className="block text-lg font-semibold">
            {t.auth_password_label}
          </label>
          <input
            id="del-password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="min-h-14 w-full rounded-xl border-2 border-line bg-page px-4 text-lg text-ink focus:border-accent"
          />
          {error && <p className="text-lg font-semibold text-error-ink">{error}</p>}
          <div className="flex flex-col gap-3 sm:flex-row">
            <Button type="submit" variant="danger" disabled={busy || password === ""}>
              {t.profile_delete_yes}
            </Button>
            <Button variant="secondary" onClick={() => setDeleting(false)} disabled={busy} autoFocus>
              {t.clear_history_no}
            </Button>
          </div>
        </form>
      ) : (
        <Button variant="secondary" onClick={() => setDeleting(true)} className="w-full sm:w-auto">
          <Trash2 aria-hidden className="size-6" />
          {t.profile_delete}
        </Button>
      )}
    </div>
  );
}
