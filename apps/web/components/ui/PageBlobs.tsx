import type { ReactNode } from "react";

// PageBlobs — фон страниц входа и профиля: три мягких круга за карточкой; лишнее за краем экрана обрезается, прокрутки нет
export function PageBlobs({ children }: { children: ReactNode }) {
  return (
    <div className="relative">
      <div aria-hidden className="pointer-events-none absolute top-[230px] -left-[110px] size-[260px] rounded-full bg-brand-soft sm:top-[120px] sm:-left-[120px] sm:size-[340px]" />
      <div aria-hidden className="pointer-events-none absolute -right-[90px] bottom-[60px] size-[220px] rounded-full bg-accent-soft sm:bottom-20 sm:size-[300px]" />
      <div aria-hidden className="pointer-events-none absolute top-[70px] right-10 size-14 rounded-full bg-accent sm:top-[90px] sm:right-40 sm:size-[84px]" />
      <div className="relative">{children}</div>
    </div>
  );
}
