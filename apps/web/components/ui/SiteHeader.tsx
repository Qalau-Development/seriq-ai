"use client";

import { useEffect } from "react";
import Link from "next/link";
import { ChartColumn, House, LogIn, LogOut, UserRound } from "lucide-react";
import { setLang, useLang, type Lang } from "@/lib/i18n";
import { useAccountsAvailable } from "@/lib/accounts";
import { restoreSession, useAuth } from "@/lib/auth";
import { logout } from "@/lib/syncRuntime";

const OPTIONS: { lang: Lang; label: string }[] = [
  { lang: "kk", label: "ҚАЗ" },
  { lang: "ru", label: "РУС" },
  { lang: "en", label: "ENG" },
];

// SiteHeader — шапка: логотип, переключатель ҚАЗ / РУС и ссылка на главную
export function SiteHeader() {
  const { lang, t } = useLang();
  const available = useAccountsAvailable();
  const auth = useAuth();

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  useEffect(() => {
    if (available) void restoreSession();
  }, [available]);

  return (
    <header className="border-b border-line">
      <div className="mx-auto flex w-full max-w-3xl flex-wrap items-center justify-between gap-3 px-5 py-4">
        <Link href="/" className="text-2xl font-bold text-accent">
          SerIQ
        </Link>
        <div className="flex flex-wrap items-center gap-2">
          <div role="group" aria-label={t.lang_label} className="flex rounded-xl border-2 border-accent p-0.5">
            {OPTIONS.map((o) => (
              <button
                key={o.lang}
                type="button"
                lang={o.lang}
                aria-pressed={lang === o.lang}
                onClick={() => setLang(o.lang)}
                className={`min-h-11 min-w-14 rounded-lg px-3 text-lg font-bold ${
                  lang === o.lang ? "bg-accent text-white" : "text-accent hover:bg-accent-soft"
                }`}
              >
                {o.label}
              </button>
            ))}
          </div>
          <Link
            href="/"
            className="flex min-h-12 items-center gap-2 rounded-xl px-3 text-lg font-semibold text-accent hover:bg-accent-soft"
          >
            <House aria-hidden className="size-6" />
            <span className="max-sm:sr-only">{t.nav_home}</span>
          </Link>
          <Link
            href="/progress"
            className="flex min-h-12 items-center gap-2 rounded-xl px-3 text-lg font-semibold text-accent hover:bg-accent-soft"
          >
            <ChartColumn aria-hidden className="size-6" />
            <span className="max-sm:sr-only">{t.nav_progress}</span>
          </Link>
          {available && auth.kind !== "in" && auth.kind !== "restoring" && (
            <Link
              href="/login"
              className="flex min-h-12 items-center gap-2 rounded-xl px-3 text-lg font-semibold text-accent hover:bg-accent-soft"
            >
              <LogIn aria-hidden className="size-6" />
              {t.nav_login}
            </Link>
          )}
          {available && auth.kind === "in" && (
            <Link
              href="/profile"
              className="flex min-h-12 max-w-40 items-center gap-2 rounded-xl px-3 text-lg font-semibold text-accent hover:bg-accent-soft"
            >
              <UserRound aria-hidden className="size-6 shrink-0" />
              <span className="truncate">{auth.user.login}</span>
            </Link>
          )}
          {available && auth.kind === "in" && (
            <button
              type="button"
              onClick={() => void logout()}
              className="flex min-h-12 items-center gap-2 rounded-xl px-3 text-lg font-semibold text-accent hover:bg-accent-soft"
            >
              <LogOut aria-hidden className="size-6" />
              <span className="max-sm:sr-only">{t.nav_logout}</span>
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
