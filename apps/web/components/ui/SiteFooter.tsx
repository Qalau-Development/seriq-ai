"use client";

import Link from "next/link";
import { useLang } from "@/lib/i18n";
import { FOOTER_LINKS } from "@/lib/privacy";

// SiteFooter — подвал: ссылки на приватность, инструкции и историю, предупреждение, что SerIQ не медицинское изделие
export function SiteFooter() {
  const { t } = useLang();
  return (
    <footer className="border-t border-line bg-surface">
      <div className="page-shell flex flex-col gap-3 py-5 md:min-h-[107px] md:flex-row md:flex-wrap md:items-center md:justify-between md:gap-x-10 md:gap-y-4 md:py-6">
        <nav aria-label={t.privacy_link} className="flex flex-col md:flex-row md:flex-wrap md:gap-x-9 md:gap-y-1">
          {FOOTER_LINKS.map((l) => (
            <Link key={l.href} href={l.href} className="flex min-h-12 items-center text-lg leading-[1.3] font-semibold text-brand underline underline-offset-4 hover:text-brand-hover">
              {t[l.labelKey]}
            </Link>
          ))}
        </nav>
        <p className="text-base leading-snug text-muted">{t.disclaimer}</p>
      </div>
    </footer>
  );
}
