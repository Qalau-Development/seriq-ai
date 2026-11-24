"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChartColumn, History, House, LogIn, UserRound } from "lucide-react";
import { useLang } from "@/lib/i18n";
import { isActive } from "@/lib/navigation";
import { useAccountsAvailable } from "@/lib/accounts";
import { useAuth } from "@/lib/auth";

// BottomNav — нижняя панель телефона (до 640 px): Главная, История, Мой прогресс, Войти или Профиль; выбранный раздел залит, подпись жирная, иконка толще
export function BottomNav() {
  const { t } = useLang();
  const pathname = usePathname();
  const available = useAccountsAvailable();
  const auth = useAuth();

  const items = [
    { href: "/", label: t.nav_home, Icon: House },
    { href: "/history", label: t.nav_history, Icon: History },
    { href: "/progress", label: t.nav_progress, Icon: ChartColumn },
    ...(available && auth.kind === "in"
      ? [{ href: "/profile", label: t.profile_title, Icon: UserRound }]
      : available && auth.kind !== "restoring"
        ? [{ href: "/login", label: t.nav_login, Icon: LogIn }]
        : []),
  ];

  return (
    <nav
      aria-label="SerIQ"
      className="fixed inset-x-0 bottom-0 z-40 flex h-24 gap-0.5 rounded-t-[28px] border-t border-line bg-surface px-1.5 pt-1.5 pb-2.5 shadow-[0_-6px_24px_rgb(17_74_125/0.10)] sm:hidden"
    >
      {items.map(({ href, label, Icon }) => {
        const active = isActive(pathname, href === "/profile" ? "/profile" : href);
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? "page" : undefined}
            className={`flex min-w-0 flex-1 flex-col items-center justify-center gap-1 rounded-[22px] px-1 py-1.5 text-center text-base leading-[19px] ${
              active ? "bg-brand-soft font-bold text-brand" : "font-semibold text-ink"
            }`}
          >
            <Icon aria-hidden className="size-6 shrink-0" strokeWidth={active ? 2.4 : 2} />
            <span>{label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
