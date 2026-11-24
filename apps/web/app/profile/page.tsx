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
import { Field } from "@/components/ui/Field";
import { Notice } from "@/components/ui/Notice";
import { PageBlobs } from "@/components/ui/PageBlobs";
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

  const heading = (
    <h1 className="text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[38px] sm:leading-[46px] lg:text-[44px] lg:leading-[53px]">{t.profile_title}</h1>
  );

  if (!available || auth.kind !== "in") {
    return (
      <PageBlobs>
        <div className="mx-auto flex w-full max-w-[800px] flex-col gap-7">
          {heading}
          <Notice kind="info">{available ? t.profile_not_logged : t.auth_unavailable}</Notice>
          <div>
            <ButtonLink href={available ? "/login" : "/"}>{available ? t.nav_login : t.nav_home}</ButtonLink>
          </div>
        </div>
      </PageBlobs>
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
    <PageBlobs>
      <div className="mx-auto flex w-full max-w-[800px] flex-col gap-7">
        {heading}
        <Card className="flex flex-col gap-6 sm:p-9!">
          <div className="rounded-[22px] bg-tile px-5 py-5 sm:px-7">
            <div className="text-lg leading-[26px] font-semibold text-muted">{t.profile_login}</div>
            <div className="text-[28px] leading-9 font-extrabold break-all sm:text-[34px] sm:leading-11">{auth.user.login}</div>
          </div>
          <p className="text-lg leading-7 text-pretty">{t.profile_stored_note}</p>
          <Link href="/privacy" className="inline-flex min-h-12 items-center self-start text-lg font-bold text-link underline underline-offset-4 hover:text-brand">
            {t.privacy_link}
          </Link>
          <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:gap-4">
            <Button variant="secondary" onClick={logout}>
              <LogOut aria-hidden className="size-6" />
              {t.profile_logout}
            </Button>
            {!deleting && (
              <Button variant="secondary" onClick={() => setDeleting(true)}>
                <Trash2 aria-hidden className="size-6" />
                {t.profile_delete}
              </Button>
            )}
          </div>
          {deleting && (
            <form onSubmit={remove} className="flex flex-col gap-4 rounded-3xl border-2 border-error-line bg-error-soft p-5 sm:p-7" role="alertdialog" aria-labelledby="del-q">
              <p id="del-q" className="text-lg leading-[27px] font-bold text-error-ink">
                {t.profile_delete_warning}
              </p>
              <Field
                id="del-password"
                type="password"
                label={t.auth_password_label}
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              {error && <Notice kind="error">{error}</Notice>}
              <div className="flex flex-col gap-3 sm:flex-row sm:gap-4">
                <Button type="submit" variant="danger" disabled={busy || password === ""}>
                  {t.profile_delete_yes}
                </Button>
                <Button variant="secondary" onClick={() => setDeleting(false)} disabled={busy} autoFocus>
                  {t.clear_history_no}
                </Button>
              </div>
            </form>
          )}
        </Card>
      </div>
    </PageBlobs>
  );
}
