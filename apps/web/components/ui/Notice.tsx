import { CircleAlert, Info, TriangleAlert } from "lucide-react";
import type { ReactNode } from "react";

type Kind = "info" | "warn" | "error";

const styles: Record<Kind, string> = {
  info: "border border-brand-soft-2 bg-neutral-soft text-neutral-ink font-medium",
  warn: "border-2 border-warn-line bg-warn-soft text-warn-ink font-bold",
  error: "border-2 border-error-line bg-error-soft text-error-ink font-bold",
};
const icons = { info: Info, warn: TriangleAlert, error: CircleAlert };

// Notice — плашка: нейтральная (info), предупреждение (warn) или ошибка (error); у каждой своя иконка, рамка и текст, цвет не единственный признак
export function Notice({ kind = "info", children, className = "", live }: { kind?: Kind; children: ReactNode; className?: string; live?: boolean }) {
  const Icon = icons[kind];
  return (
    <div
      role={kind === "error" ? "alert" : undefined}
      aria-live={live ? "polite" : undefined}
      className={`flex items-start gap-3 rounded-[20px] px-[18px] py-4 text-lg leading-[27px] sm:gap-3.5 sm:px-6 sm:py-[18px] ${styles[kind]} ${className}`}
    >
      <Icon aria-hidden className="mt-0.5 size-7 shrink-0" strokeWidth={2.2} />
      <div className="min-w-0 text-pretty">{children}</div>
    </div>
  );
}
