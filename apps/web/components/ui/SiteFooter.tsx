"use client";

import Link from "next/link";
import { useLang } from "@/lib/i18n";
import { FOOTER_LINKS } from "@/lib/privacy";

// SiteFooter — подвал: ссылки на приватность, инструкции и историю, предупреждение, что SerIQ не медицинское изделие
export function SiteFooter() {
  const { t } = useLang();
  return (
    <footer className="border-t border-line">
      <div className="mx-auto w-full max-w-3xl space-y-3 px-5 py-4">
        <nav aria-label={t.footer_instructions} className="flex flex-wrap gap-x-6 gap-y-1">
          {FOOTER_LINKS.map((l) => (
            <Link key={l.href} href={l.href} className="flex min-h-12 items-center text-lg font-semibold text-accent underline underline-offset-4">
              {t[l.labelKey]}
            </Link>
          ))}
        </nav>
        <p className="text-base text-muted">{t.disclaimer}</p>
      </div>
    </footer>
  );
}
