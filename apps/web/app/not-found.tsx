"use client";

import { useLang } from "@/lib/i18n";
import { ButtonLink } from "@/components/ui/Button";

// NotFound — страница 404: понятная фраза и кнопка «На главную»
export default function NotFound() {
  const { t } = useLang();
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">{t.not_found_title}</h1>
      <p className="text-lg">{t.not_found_text}</p>
      <ButtonLink href="/" className="w-full sm:w-auto">
        {t.go_home}
      </ButtonLink>
    </div>
  );
}
