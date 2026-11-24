"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Eye, EyeOff } from "lucide-react";
import { AccountError, signIn, validLogin, validPassword, waitText } from "@/lib/auth";
import { useAccountsAvailable } from "@/lib/accounts";
import { fill, textOr, useLang } from "@/lib/i18n";
import { Button, ButtonLink } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Field } from "@/components/ui/Field";
import { Notice } from "@/components/ui/Notice";
import { PageBlobs } from "@/components/ui/PageBlobs";

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

  const heading = (
    <h1 className="text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[38px] sm:leading-[46px] lg:text-[44px] lg:leading-[53px]">
      {register ? t.auth_register_title : t.auth_login_title}
    </h1>
  );

  if (!available) {
    return (
      <PageBlobs>
        <div className="mx-auto flex w-full max-w-[600px] flex-col gap-7">
          {heading}
          <Notice kind="info">{t.auth_unavailable}</Notice>
          <div>
            <ButtonLink href="/" variant="secondary">
              {t.nav_home}
            </ButtonLink>
          </div>
        </div>
      </PageBlobs>
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
    <PageBlobs>
      <div className="mx-auto flex w-full max-w-[600px] flex-col gap-7">
        {heading}
        <Card className="sm:p-10!">
          <form onSubmit={submit} className="flex flex-col gap-5 sm:gap-[22px]" noValidate>
            {register && (
              <Notice kind="warn">
                <span className="text-xl leading-[30px]">{t.auth_remember_warning}</span>
              </Notice>
            )}
            <Field
              id="login"
              name="login"
              type="text"
              label={t.auth_login_label}
              hint={register ? t.auth_login_rules : undefined}
              autoComplete="username"
              autoCapitalize="none"
              autoCorrect="off"
              spellCheck={false}
              value={login}
              onChange={(e) => setLogin(e.target.value)}
            />
            <div className="flex flex-col gap-2">
              <Field
                id="password"
                name="password"
                type={show ? "text" : "password"}
                label={t.auth_password_label}
                hint={register ? t.auth_password_rules : undefined}
                autoComplete={register ? "new-password" : "current-password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <button
                type="button"
                onClick={() => setShow((v) => !v)}
                aria-pressed={show}
                className="inline-flex min-h-12 items-center gap-2.5 self-start px-1 text-lg leading-[1.2] font-bold text-link underline underline-offset-4 hover:text-brand"
              >
                {show ? <EyeOff aria-hidden className="size-6" /> : <Eye aria-hidden className="size-6" />}
                {show ? t.auth_hide_password : t.auth_show_password}
              </button>
            </div>
            <div aria-live="polite">{error && <Notice kind="error">{error}</Notice>}</div>
            <Button type="submit" disabled={busy || login === "" || password === ""}>
              {busy ? t.auth_working : register ? t.auth_register_submit : t.auth_login_submit}
            </Button>
            <p className="text-lg leading-7 text-ink">
              {register ? t.auth_have_account : t.auth_no_account}{" "}
              <Link href={register ? "/login" : "/register"} className="font-bold text-link underline underline-offset-4 hover:text-brand">
                {register ? t.nav_login : t.nav_register}
              </Link>
            </p>
            <p className="text-base leading-6 text-pretty text-muted">{t.auth_guest_note}</p>
          </form>
        </Card>
      </div>
    </PageBlobs>
  );
}
