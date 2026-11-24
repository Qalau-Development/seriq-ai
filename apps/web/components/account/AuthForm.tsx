"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AlertCircle, Eye, EyeOff, TriangleAlert } from "lucide-react";
import { AccountError, signIn, validLogin, validPassword, waitText } from "@/lib/auth";
import { useAccountsAvailable } from "@/lib/accounts";
import { fill, textOr, useLang } from "@/lib/i18n";
import { Button, ButtonLink } from "@/components/ui/Button";

const inputClass = "min-h-14 w-full rounded-xl border-2 border-line bg-page px-4 text-lg text-ink focus:border-brand";

// AuthForm — вход или регистрация по логину и паролю; показывается, только если сервер включил аккаунты
export function AuthForm({ mode }: { mode: "login" | "register" }) {
  const { t } = useLang();
  const router = useRouter();
  const available = useAccountsAvailable();
  const [login, setLogin] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const register = mode === "register";

  if (!available) {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold">{register ? t.auth_register_title : t.auth_login_title}</h1>
        <p className="rounded-2xl bg-neutral-soft p-5 text-lg font-semibold text-neutral-ink">{t.auth_unavailable}</p>
        <ButtonLink href="/" variant="secondary" className="w-full sm:w-auto">
          {t.nav_home}
        </ButtonLink>
      </div>
    );
  }

  // submit — проверяет поля, отправляет запрос и при успехе открывает главную
  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (register && !validLogin(login)) return setError(t.error_invalid_login);
    if (register && !validPassword(password, login)) return setError(t.error_weak_password);
    setBusy(true);
    try {
      await signIn(mode, login.trim(), password);
      router.push("/");
    } catch (err) {
      const code = err instanceof AccountError ? err.code : "internal_error";
      const retry = err instanceof AccountError ? err.retryAfter : undefined;
      setError(fill(textOr(t, `error_${code}`, "error_internal_error"), { time: waitText(retry, t) }));
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="space-y-6" noValidate>
      <h1 className="text-3xl font-bold">{register ? t.auth_register_title : t.auth_login_title}</h1>
      {register && (
        <div className="flex gap-3 rounded-2xl border-2 border-warn-ink bg-warn-soft p-5 text-xl font-bold text-warn-ink">
          <TriangleAlert aria-hidden className="mt-1 size-7 shrink-0" />
          <p>{t.auth_remember_warning}</p>
        </div>
      )}
      <div className="space-y-2">
        <label htmlFor="login" className="text-lg font-semibold">
          {t.auth_login_label}
        </label>
        <input
          id="login"
          name="login"
          type="text"
          autoComplete="username"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          value={login}
          onChange={(e) => setLogin(e.target.value)}
          className={inputClass}
        />
        {register && <p className="text-base text-muted">{t.auth_login_rules}</p>}
      </div>
      <div className="space-y-2">
        <label htmlFor="password" className="text-lg font-semibold">
          {t.auth_password_label}
        </label>
        <input
          id="password"
          name="password"
          type={show ? "text" : "password"}
          autoComplete={register ? "new-password" : "current-password"}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className={inputClass}
        />
        {register && <p className="text-base text-muted">{t.auth_password_rules}</p>}
        <button
          type="button"
          onClick={() => setShow((v) => !v)}
          aria-pressed={show}
          className="flex min-h-12 items-center gap-2 text-lg font-semibold text-brand underline underline-offset-4"
        >
          {show ? <EyeOff aria-hidden className="size-6" /> : <Eye aria-hidden className="size-6" />}
          {show ? t.auth_hide_password : t.auth_show_password}
        </button>
      </div>
      <div aria-live="polite">
        {error && (
          <div className="flex gap-3 rounded-2xl bg-error-soft p-5 text-lg font-semibold text-error-ink">
            <AlertCircle aria-hidden className="mt-1 size-6 shrink-0" />
            <p>{error}</p>
          </div>
        )}
      </div>
      <Button type="submit" disabled={busy || login === "" || password === ""} className="w-full sm:w-auto">
        {busy ? t.auth_working : register ? t.auth_register_submit : t.auth_login_submit}
      </Button>
      <p className="text-lg">
        {register ? t.auth_have_account : t.auth_no_account}{" "}
        <Link href={register ? "/login" : "/register"} className="font-semibold text-brand underline underline-offset-4">
          {register ? t.nav_login : t.nav_register}
        </Link>
      </p>
      <p className="text-base text-muted">{t.auth_guest_note}</p>
    </form>
  );
}
