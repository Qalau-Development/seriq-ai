"use client";

import { useEffect } from "react";
import Image from "next/image";
import Link from "next/link";
import { ChartColumn, House, LogIn, LogOut, UserRound } from "lucide-react";
import { setLang, useLang, type Lang } from "@/lib/i18n";
import { watchDocumentMeta } from "@/lib/i18n/meta";
import { useAccountsAvailable } from "@/lib/accounts";
import { restoreSession, useAuth } from "@/lib/auth";
import { logout } from "@/lib/syncRuntime";

const OPTIONS: { lang: Lang; label: string }[] = [
  { lang: "kk", label: "ҚАЗ" },
  { lang: "ru", label: "РУС" },
  { lang: "en", label: "ENG" },
];

// navClass — вид кнопки-ссылки в шапке
const navClass = "flex min-h-12 min-w-9 items-center justify-center gap-2 rounded-xl px-1 text-lg sm:min-w-10 sm:px-2 font-semibold text-brand hover:bg-brand-soft";

// SiteHeader — шапка в одну строку: логотип и «SerIQ» (ссылка на главную), переключатель языка, ссылки и вход
export function SiteHeader() {
  const { lang, t } = useLang();
  const available = useAccountsAvailable();
  const auth = useAuth();

  useEffect(() => watchDocumentMeta(document, lang, t), [lang, t]);

  useEffect(() => {
    if (available) void restoreSession();
  }, [available]);

  return (
    <header className="border-b border-line">
      <div className="mx-auto flex w-full max-w-3xl items-center justify-between gap-2 px-2 py-3 sm:px-5">
        <Link href="/" className="flex shrink-0 items-center gap-2 text-xl font-bold text-brand sm:text-2xl">
          <Image src="/logo.png" alt="" aria-hidden width={640} height={369} unoptimized className="h-[40px] w-auto shrink-0" />
          SerIQ
        </Link>
        <div className="flex min-w-0 items-center gap-0.5 sm:gap-2">
          <div role="group" aria-label={t.lang_label} className="flex rounded-xl border-2 border-brand p-0.5">
            {OPTIONS.map((o) => (
              <button
                key={o.lang}
                type="button"
                lang={o.lang}
                aria-pressed={lang === o.lang}
                onClick={() => setLang(o.lang)}
                className={`min-h-11 min-w-9 rounded-lg px-1 text-sm font-bold sm:min-w-14 sm:px-3 sm:text-lg ${
                  lang === o.lang ? "bg-brand text-white" : "text-brand hover:bg-brand-soft"
                }`}
              >
                {o.label}
              </button>
            ))}
          </div>
          <Link href="/" title={t.nav_home} className={`${navClass} max-sm:hidden`}>
            <House aria-hidden className="size-6" />
            <span className="sr-only">{t.nav_home}</span>
          </Link>
          <Link href="/progress" title={t.nav_progress} className={`${navClass} max-sm:hidden`}>
            <ChartColumn aria-hidden className="size-6" />
            <span className="sr-only">{t.nav_progress}</span>
          </Link>
          {available && auth.kind !== "in" && auth.kind !== "restoring" && (
            <Link href="/login" title={t.nav_login} className={navClass}>
              <LogIn aria-hidden className="size-6" />
              <span className="max-sm:sr-only">{t.nav_login}</span>
            </Link>
          )}
          {available && auth.kind === "in" && (
            <Link href="/profile" title={auth.user.login} className={`${navClass} sm:max-w-28`}>
              <UserRound aria-hidden className="size-6 shrink-0" />
              <span className="truncate max-sm:sr-only">{auth.user.login}</span>
            </Link>
          )}
          {available && auth.kind === "in" && (
            <button type="button" title={t.nav_logout} onClick={() => void logout()} className={`${navClass} max-sm:hidden`}>
              <LogOut aria-hidden className="size-6" />
              <span className="sr-only">{t.nav_logout}</span>
            </button>
          )}
        </div>
      </div>
      {available && auth.kind === "expired" && (
        <div className="bg-warn-soft px-5 py-3 text-lg font-semibold text-warn-ink">
          <div className="mx-auto flex w-full max-w-3xl flex-wrap items-center gap-3">
            <p>{t.session_expired}</p>
            <Link href="/login" className="underline underline-offset-4">
              {t.nav_login}
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}
