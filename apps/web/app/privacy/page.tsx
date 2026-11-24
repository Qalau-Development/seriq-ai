"use client";

import { useLang } from "@/lib/i18n";
import { PRIVACY_SECTIONS } from "@/lib/privacy";
import { ButtonLink } from "@/components/ui/Button";

// PrivacyPage — «Данные и приватность»: что хранится у гостя и у вошедшего, что не хранится, как удалить данные
export default function PrivacyPage() {
  const { t } = useLang();
  return (
    <div className="space-y-8">
      <h1 className="text-3xl font-bold">{t.privacy_title}</h1>
      {PRIVACY_SECTIONS.map((s) => (
        <section key={s.titleKey} className="space-y-2">
          <h2 className="text-2xl font-bold">{t[s.titleKey]}</h2>
          {s.textKeys.map((k) => (
            <p key={k} className="text-lg">
              {t[k]}
            </p>
          ))}
        </section>
      ))}
      <ButtonLink href="/" variant="secondary" className="w-full sm:w-auto">
        {t.go_home}
      </ButtonLink>
    </div>
  );
}
