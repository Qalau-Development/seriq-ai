"use client";

import { useLang } from "@/lib/i18n";

// SiteFooter — подвал с предупреждением, что SerIQ не медицинское изделие
export function SiteFooter() {
  const { t } = useLang();
  return (
    <footer className="border-t border-line">
      <p className="mx-auto w-full max-w-3xl px-5 py-4 text-base text-muted">{t.disclaimer}</p>
    </footer>
  );
}
