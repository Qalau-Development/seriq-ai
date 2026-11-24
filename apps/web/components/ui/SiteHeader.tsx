"use client";

import { useEffect } from "react";
import Link from "next/link";
import { House } from "lucide-react";
import { setLang, useLang, type Lang } from "@/lib/i18n";

const OPTIONS: { lang: Lang; label: string }[] = [
  { lang: "kk", label: "ҚАЗ" },
  { lang: "ru", label: "РУС" },
];

// SiteHeader — шапка: логотип, переключатель ҚАЗ / РУС и ссылка на главную
export function SiteHeader() {
  const { lang, t } = useLang();

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  return (
    <header className="border-b border-line">
      <div className="mx-auto flex w-full max-w-3xl flex-wrap items-center justify-between gap-3 px-5 py-4">
        <Link href="/" className="text-2xl font-bold text-accent">
          SerIQ
        </Link>
        <div className="flex items-center gap-2">
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
        </div>
      </div>
    </header>
  );
}
