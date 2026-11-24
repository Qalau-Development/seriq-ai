"use client";

import { useLang } from "@/lib/i18n";
import { ButtonLink } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { PageBlobs } from "@/components/ui/PageBlobs";

// NotFound — страница 404: понятная фраза и кнопка «На главную»
export default function NotFound() {
  const { t } = useLang();
  return (
    <PageBlobs>
      <div className="mx-auto w-full max-w-[720px]">
        <Card className="flex flex-col gap-6 sm:p-10!">
          <h1 className="text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[38px] sm:leading-[46px] lg:text-[44px] lg:leading-[53px]">{t.not_found_title}</h1>
          <p className="text-xl leading-[30px] text-pretty text-muted sm:text-[22px] sm:leading-[33px]">{t.not_found_text}</p>
          <div>
            <ButtonLink href="/">{t.go_home}</ButtonLink>
          </div>
        </Card>
      </div>
    </PageBlobs>
  );
}
