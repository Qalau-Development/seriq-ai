import { Check } from "lucide-react";
import type { ComponentProps } from "react";

// Chip — кнопка-фильтр: контур brand; выбранная залита brand, с галочкой и жирным шрифтом
export function Chip({ selected, children, className = "", ...props }: ComponentProps<"button"> & { selected: boolean }) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      className={`inline-flex min-h-12 items-center gap-2 rounded-full border-2 border-brand px-5 text-lg leading-[1.2] ${
        selected ? "bg-brand font-bold text-white" : "bg-surface font-semibold text-brand hover:bg-brand-soft"
      } ${className}`}
      {...props}
    >
      {selected && <Check aria-hidden className="size-5 shrink-0" strokeWidth={3} />}
      <span>{children}</span>
    </button>
  );
}
