"use client";

import { LANGS, setLang, useLang, type Lang } from "@/lib/i18n";

const LABELS: Record<Lang, string> = { kk: "ҚАЗ", ru: "РУС", en: "ENG" };
const ORDER: Lang[] = ["kk", ...LANGS.filter((l) => l !== "kk")];

// LanguageSwitch — переключатель языка таблеткой: ҚАЗ, РУС, ENG
export function LanguageSwitch() {
  const { lang, t } = useLang();
  return (
    <div role="group" aria-label={t.lang_label} className="inline-flex items-center gap-0.5 rounded-full border-2 border-brand bg-surface p-0.5">
      {ORDER.map((l) => (
        <button
          key={l}
          type="button"
          lang={l}
          aria-pressed={lang === l}
          onClick={() => setLang(l)}
          className={`min-h-12 min-w-10 rounded-full px-1.5 text-sm font-bold min-[360px]:min-w-12 min-[360px]:px-2.5 min-[360px]:text-base min-[400px]:min-w-14 min-[400px]:px-3.5 min-[400px]:text-[17px] sm:min-h-11 sm:min-w-[52px] sm:px-3 lg:min-w-16 lg:px-4 ${
            lang === l ? "bg-brand text-white" : "text-brand hover:bg-brand-soft"
          }`}
        >
          {LABELS[l]}
        </button>
      ))}
    </div>
  );
}
