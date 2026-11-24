import type { ComponentProps, ReactNode } from "react";

export const fieldClass =
  "block h-14 w-full rounded-2xl border-2 border-line-strong bg-surface px-4 text-lg leading-none font-medium text-ink sm:px-[18px] focus:border-brand";

// Field — подпись, поле ввода высотой 56 px и подсказка под ним
export function Field({ id, label, hint, ...props }: { label: string; hint?: ReactNode } & ComponentProps<"input"> & { id: string }) {
  return (
    <div className="flex flex-col gap-2">
      <label htmlFor={id} className="text-lg leading-[26px] font-bold text-ink">
        {label}
      </label>
      <input id={id} className={fieldClass} {...props} />
      {hint && <p className="text-base leading-6 text-muted">{hint}</p>}
    </div>
  );
}
