import type { ReactNode } from "react";

// Card — белая карточка: радиус 24 на телефоне и 28 с 640 px, тень, граница; отступ 20 → 28 → 32
export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div className={`rounded-3xl border border-line bg-surface p-5 shadow-card sm:rounded-[28px] sm:p-7 lg:p-8 ${className}`}>{children}</div>
  );
}
