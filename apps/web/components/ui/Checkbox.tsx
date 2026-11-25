import { Check } from "lucide-react";
import type { ComponentProps } from "react";

// Checkbox — квадратный переключатель: контур brand, отмеченный залит brand с белой галочкой
export function Checkbox({ checked, className = "", ...props }: ComponentProps<"button"> & { checked: boolean }) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={checked}
      className={`flex size-7 shrink-0 items-center justify-center rounded-lg border-2 border-brand ${checked ? "bg-brand" : "bg-surface"} ${className}`}
      {...props}
    >
      {checked && <Check aria-hidden className="size-5 text-white" strokeWidth={3} />}
    </button>
  );
}
