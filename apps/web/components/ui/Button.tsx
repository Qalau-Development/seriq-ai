import Link from "next/link";
import type { ComponentProps, ReactNode } from "react";

type Variant = "primary" | "secondary" | "danger";
type Size = "md" | "sm";

const base =
  "inline-flex items-center justify-center gap-3 [&_svg]:shrink-0 rounded-full border-2 text-center leading-[1.2] font-bold transition-colors active:translate-y-px max-sm:w-full sm:whitespace-nowrap disabled:cursor-not-allowed disabled:border-disabled disabled:bg-disabled disabled:text-disabled-ink disabled:shadow-none disabled:active:translate-y-0";
const sizes: Record<Size, string> = {
  md: "min-h-14 px-6 py-2 text-lg sm:px-7",
  sm: "min-h-12 px-5 py-1.5 text-base sm:px-[22px]",
};
const variants: Record<Variant, string> = {
  primary: "border-accent bg-accent text-on-accent shadow-accent hover:border-accent-hover hover:bg-accent-hover active:shadow-none",
  secondary: "border-brand bg-surface text-brand hover:bg-brand-soft",
  danger: "border-error-ink bg-error-ink text-white hover:border-error-hover hover:bg-error-hover",
};

// buttonClass — классы кнопки нужного вида и размера
export function buttonClass(variant: Variant = "primary", extra = "", size: Size = "md") {
  return `${base} ${sizes[size]} ${variants[variant]} ${extra}`;
}

// Button — кнопка-таблетка: primary оранжевая заливка, secondary контур brand, danger красная; на телефоне на всю ширину
export function Button({
  variant = "primary",
  size = "md",
  className = "",
  ...props
}: ComponentProps<"button"> & { variant?: Variant; size?: Size }) {
  return <button type="button" className={buttonClass(variant, className, size)} {...props} />;
}

// ButtonLink — кнопка-ссылка на другую страницу
export function ButtonLink({
  href,
  variant = "primary",
  size = "md",
  className = "",
  children,
}: {
  href: string;
  variant?: Variant;
  size?: Size;
  className?: string;
  children: ReactNode;
}) {
  return (
    <Link href={href} className={buttonClass(variant, className, size)}>
      {children}
    </Link>
  );
}
