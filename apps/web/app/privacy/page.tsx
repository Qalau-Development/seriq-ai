"use client";

import { useLang } from "@/lib/i18n";
import { PRIVACY_SECTIONS } from "@/lib/privacy";
import { ButtonLink } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";

// PrivacyPage — «Данные и приватность»: что хранится у гостя и у вошедшего, что не хранится, как удалить данные; карточки по два в ряд
export default function PrivacyPage() {
  const { t } = useLang();
  return (
    <div className="flex flex-col gap-8">
      <h1 className="text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[38px] sm:leading-[46px] lg:text-[44px] lg:leading-[53px]">{t.privacy_title}</h1>
      <div className="grid gap-5 sm:grid-cols-2 lg:gap-6">
        {PRIVACY_SECTIONS.map((s) => (
          <Card key={s.titleKey} className="flex flex-col gap-2.5 lg:p-7!">
            <h2 className="text-2xl leading-[29px] font-extrabold tracking-[-0.01em] text-balance lg:text-[26px] lg:leading-[31px]">{t[s.titleKey]}</h2>
            {s.textKeys.map((k) => (
              <p key={k} className="text-lg leading-[29px] font-medium text-pretty text-ink">
                {t[k]}
              </p>
            ))}
          </Card>
        ))}
      </div>
      <div>
        <ButtonLink href="/" variant="secondary">
          {t.go_home}
        </ButtonLink>
      </div>
    </div>
  );
}
