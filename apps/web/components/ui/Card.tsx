import type { ReactNode } from "react";

// Card — светло-серая карточка с отступами
export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`rounded-2xl bg-surface p-6 ${className}`}>{children}</div>;
}
