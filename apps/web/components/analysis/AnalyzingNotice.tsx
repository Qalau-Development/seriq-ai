"use client";

import { useEffect, useState } from "react";
import { LoaderCircle } from "lucide-react";
import type { Dict } from "@/lib/i18n";
import { Card } from "@/components/ui/Card";
import { Notice } from "@/components/ui/Notice";

const SLOW_AFTER_MS = 15000;

// AnalyzingNotice — экран ожидания анализа; через 15 секунд добавляет плашку, что сервер занят
export function AnalyzingNotice({ t }: { t: Dict }) {
  const [slow, setSlow] = useState(false);
  useEffect(() => {
    const timer = setTimeout(() => setSlow(true), SLOW_AFTER_MS);
    return () => clearTimeout(timer);
  }, []);
  return (
    <Card className="mx-auto flex w-full max-w-[720px] flex-col gap-5 sm:p-9! lg:p-9!">
      <div className="flex items-center gap-4 sm:gap-5">
        <LoaderCircle aria-hidden className="size-9 shrink-0 animate-spin text-brand sm:size-10" strokeWidth={2.6} />
        <h2 className="text-[26px] leading-8 font-extrabold sm:text-[30px] sm:leading-[38px]">{t.analyzing}</h2>
      </div>
      <p className="text-lg leading-[27px] text-pretty text-muted sm:text-xl sm:leading-[30px]">{t.analyzing_hint}</p>
      {slow && <Notice kind="info" live>{t.analyzing_slow}</Notice>}
    </Card>
  );
}
