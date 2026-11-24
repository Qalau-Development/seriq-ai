"use client";

import { useLang } from "@/lib/i18n";
import { Button, ButtonLink } from "@/components/ui/Button";

// ErrorPage — страница ошибки: без технических подробностей, кнопки «Попробовать снова» и «На главную»
export default function ErrorPage({ retry }: { error: unknown; retry: () => void }) {
  const { t } = useLang();
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">{t.error_page_title}</h1>
      <p className="text-lg">{t.error_page_text}</p>
      <div className="flex flex-col gap-3 sm:flex-row">
        <Button onClick={() => retry()}>{t.try_again}</Button>
        <ButtonLink href="/" variant="secondary">
          {t.go_home}
        </ButtonLink>
      </div>
    </div>
  );
}
