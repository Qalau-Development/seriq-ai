"use client";

import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";
import type { Dict } from "@/lib/i18n";

const SLOW_AFTER_MS = 15000;

// AnalyzingNotice — экран ожидания анализа; через 15 секунд добавляет строку, что сервер занят
export function AnalyzingNotice({ t }: { t: Dict }) {
  const [slow, setSlow] = useState(false);
  useEffect(() => {
    const timer = setTimeout(() => setSlow(true), SLOW_AFTER_MS);
    return () => clearTimeout(timer);
  }, []);
  return (
    <div className="space-y-2 rounded-2xl bg-surface p-6">
      <p className="flex items-center gap-3 text-xl font-semibold">
        <Loader2 aria-hidden className="size-7 animate-spin text-brand" />
        {t.analyzing}
      </p>
      <p className="text-lg text-muted">{t.analyzing_hint}</p>
      {slow && <p className="text-lg font-semibold">{t.analyzing_slow}</p>}
    </div>
  );
}
