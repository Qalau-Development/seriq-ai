"use client";

import { useEffect, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";
import { LANGS, setLang, useLang, type Lang } from "@/lib/i18n";

const LABELS: Record<Lang, string> = { kk: "ҚАЗ", ru: "РУС", en: "ENG" };
const ORDER: Lang[] = ["kk", ...LANGS.filter((l) => l !== "kk")];

// LanguageSwitch — кнопка с активным языком, список остальных выпадает вниз
export function LanguageSwitch() {
  const { lang, t } = useLang();
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (e: PointerEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={t.lang_label}
        onClick={() => setOpen((v) => !v)}
        className="inline-flex h-10 min-w-[72px] items-center justify-center gap-1 rounded-full border-2 border-brand bg-surface px-3 text-sm font-bold text-brand"
      >
        {LABELS[lang]}
        <ChevronDown aria-hidden className={`size-4 shrink-0 transition-transform ${open ? "rotate-180" : ""}`} />
      </button>
      {open && (
        <div role="listbox" aria-label={t.lang_label} className="absolute left-0 top-[calc(100%+6px)] z-20 min-w-[72px] overflow-hidden rounded-2xl border-2 border-brand bg-surface shadow-lg">
          {ORDER.map((l) => (
            <button
              key={l}
              type="button"
              lang={l}
              role="option"
              aria-selected={lang === l}
              onClick={() => {
                setLang(l);
                setOpen(false);
              }}
              className={`block w-full px-3 py-2.5 text-left text-sm font-bold whitespace-nowrap ${
                lang === l ? "bg-brand text-white" : "text-brand hover:bg-brand-soft"
              }`}
            >
              {LABELS[l]}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
