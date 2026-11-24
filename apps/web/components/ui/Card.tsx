import type { ReactNode } from "react";

// cardClass — вид карточки: белая, граница, тень; радиус 24 на телефоне и 28 с 640 px
export const cardClass = "rounded-3xl border border-line bg-surface shadow-card sm:rounded-[28px]";

// panelClass — карточка результата с отступом 20 → 28 (график, видео)
export const panelClass = `${cardClass} p-5 sm:p-7`;

// Card — белая карточка: отступ 20 → 28 → 32
export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`${cardClass} p-5 sm:p-7 lg:p-8 ${className}`}>{children}</div>;
}
