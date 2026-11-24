"use client";

import { useLang } from "@/lib/i18n";
import { Button, ButtonLink } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { PageBlobs } from "@/components/ui/PageBlobs";

// ErrorPage — страница ошибки: без технических подробностей, кнопки «Попробовать снова» и «На главную»
export default function ErrorPage({ retry }: { error: unknown; retry: () => void }) {
  const { t } = useLang();
  return (
    <PageBlobs>
      <div className="mx-auto w-full max-w-[720px]">
        <Card className="flex flex-col gap-6 sm:p-10!">
          <h1 className="text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[38px] sm:leading-[46px] lg:text-[44px] lg:leading-[53px]">{t.error_page_title}</h1>
          <p className="text-xl leading-[30px] text-pretty text-muted sm:text-[22px] sm:leading-[33px]">{t.error_page_text}</p>
          <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:gap-4">
            <Button onClick={() => retry()}>{t.try_again}</Button>
            <ButtonLink href="/" variant="secondary">
              {t.go_home}
            </ButtonLink>
          </div>
        </Card>
      </div>
    </PageBlobs>
  );
}
