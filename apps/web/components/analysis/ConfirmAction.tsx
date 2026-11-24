"use client";

import { useState, type ReactNode } from "react";
import { Button } from "@/components/ui/Button";
import type { Dict } from "@/lib/i18n";

// ConfirmAction — кнопка действия с крупным подтверждением; если действие не удалось, показывает ошибку и оставляет подтверждение открытым
export function ConfirmAction({
  label,
  question,
  yes,
  icon,
  onConfirm,
  t,
  className = "",
}: {
  label: string;
  question: string;
  yes: string;
  icon?: ReactNode;
  onConfirm: () => Promise<void> | void;
  t: Dict;
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);

  // confirm — выполняет действие и закрывает подтверждение
  async function confirm() {
    setBusy(true);
    setFailed(false);
    try {
      await onConfirm();
      setOpen(false);
    } catch {
      setFailed(true);
    } finally {
      setBusy(false);
    }
  }

  if (!open) {
    return (
      <Button variant="secondary" onClick={() => setOpen(true)} className={className}>
        {icon}
        {label}
      </Button>
    );
  }
  return (
    <div className="space-y-4 rounded-2xl border-2 border-error-ink bg-error-soft p-5" role="alertdialog" aria-label={label}>
      <p className="text-lg font-semibold text-error-ink">{question}</p>
      {failed && <p className="text-lg font-semibold text-error-ink">{t.delete_failed}</p>}
      <div className="flex flex-col gap-3 sm:flex-row">
        <Button variant="danger" onClick={confirm} disabled={busy}>
          {yes}
        </Button>
        <Button variant="secondary" onClick={() => setOpen(false)} disabled={busy} autoFocus>
          {t.clear_history_no}
        </Button>
      </div>
    </div>
  );
}
