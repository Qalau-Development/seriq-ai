import Link from "next/link";
import { ChevronRight } from "lucide-react";
import type { ReactNode } from "react";

// TileLink — плитка занятия со стрелкой: soft (серо-голубая, внутри карточки) или white (белая с тенью, в списках)
export function TileLink({ href, variant = "soft", srLabel, children }: { href: string; variant?: "soft" | "white"; srLabel: string; children: ReactNode }) {
  return (
    <Link
      href={href}
      className={`flex min-h-[100px] items-center justify-between gap-4 rounded-[22px] border-2 px-5 py-4 text-ink hover:border-brand ${
        variant === "soft" ? "border-transparent bg-tile" : "border-line bg-surface shadow-card sm:pl-6"
      }`}
    >
      <span className="flex min-w-0 flex-col gap-[3px]">{children}</span>
      <span className="sr-only">{srLabel}</span>
      <span aria-hidden className={`flex size-11 shrink-0 items-center justify-center rounded-full text-brand ${variant === "soft" ? "bg-surface" : "bg-brand-soft"}`}>
        <ChevronRight className="size-6" strokeWidth={2.6} />
      </span>
    </Link>
  );
}

// TileTexts — три строки плитки занятия: упражнение, дата, сколько выполнено
export function TileTexts({ exercise, date, done }: { exercise: string; date: string; done: string }) {
  return (
    <>
      <span className="text-base leading-[22px] font-bold text-link">{exercise}</span>
      <span className="text-lg leading-[26px] font-bold text-balance text-ink">{date}</span>
      <span className="text-base leading-[22px] font-medium text-muted">{done}</span>
    </>
  );
}
