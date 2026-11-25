"use client";

import { useEffect } from "react";
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChartColumn, House, LogIn, LogOut, UserRound } from "lucide-react";
import { useLang } from "@/lib/i18n";
import { watchDocumentMeta } from "@/lib/i18n/meta";
import { isActive } from "@/lib/navigation";
import { useAccountsAvailable } from "@/lib/accounts";
import { restoreSession, useAuth } from "@/lib/auth";
import { logout } from "@/lib/syncRuntime";
import { LanguageSwitch } from "@/components/ui/LanguageSwitch";

const itemBase = "inline-flex min-h-12 items-center gap-2.5 rounded-full px-3 text-lg whitespace-nowrap hover:bg-brand-soft lg:px-[18px]";
const itemOutline =
  "inline-flex min-h-12 items-center gap-2.5 rounded-full border-2 border-brand bg-surface px-4 text-lg font-bold whitespace-nowrap text-brand hover:bg-brand-soft lg:px-5";

// NavItem — пункт верхней навигации: иконка и подпись (подпись до 1024 px только для скринридера), выбранный пункт залит
function NavItem({ href, label, icon, pathname }: { href: string; label: string; icon: React.ReactNode; pathname: string }) {
  const active = isActive(pathname, href);
  return (
    <Link
      href={href}
      title={label}
      aria-current={active ? "page" : undefined}
      className={`${itemBase} ${active ? "bg-brand-soft font-bold text-brand" : "font-semibold text-ink"}`}
    >
      {icon}
      <span className="max-lg:sr-only">{label}</span>
    </Link>
  );
}

// SiteHeader — шапка: логотип, переключатель языка, навигация (с 640 px), вход или профиль
export function SiteHeader() {
  const { lang, t } = useLang();
  const available = useAccountsAvailable();
  const auth = useAuth();
  const pathname = usePathname();

  useEffect(() => watchDocumentMeta(document, lang, t), [lang, t]);

  useEffect(() => {
    if (available) void restoreSession();
  }, [available]);

  return (
    <header className="relative z-10 border-b border-line bg-surface">
      <div className="page-shell flex h-[72px] items-center justify-between gap-3 sm:gap-4 md:h-[88px] md:gap-6">
        <div className="flex min-w-0 items-center gap-3 sm:gap-5 md:gap-7">
          <Link href="/" className="inline-flex shrink-0 items-center gap-2 md:gap-3">
            <Image src="/logo.png" alt="SerIQ" width={640} height={369} unoptimized className="h-10 w-auto shrink-0" />
          </Link>
          <LanguageSwitch />
        </div>
        <nav aria-label="SerIQ" className="hidden items-center gap-1 sm:flex">
          <NavItem href="/" label={t.nav_home} icon={<House aria-hidden className="size-6 shrink-0" />} pathname={pathname} />
          <NavItem href="/progress" label={t.nav_progress} icon={<ChartColumn aria-hidden className="size-6 shrink-0" />} pathname={pathname} />
          {available && auth.kind !== "in" && auth.kind !== "restoring" && (
            <Link href="/login" aria-current={isActive(pathname, "/login") ? "page" : undefined} className={`${itemOutline} ml-1 lg:ml-2`}>
              <LogIn aria-hidden className="size-6 shrink-0 max-md:hidden" />
              {t.nav_login}
            </Link>
          )}
          {available && auth.kind === "in" && (
            <>
              <Link
                href="/profile"
                title={auth.user.login}
                aria-current={isActive(pathname, "/profile") ? "page" : undefined}
                className={`${itemBase} max-w-[220px] ${isActive(pathname, "/profile") ? "bg-brand-soft font-bold text-brand" : "font-semibold text-ink"}`}
              >
                <UserRound aria-hidden className="size-6 shrink-0" />
                <span className="truncate max-lg:sr-only">{auth.user.login}</span>
              </Link>
              <button type="button" onClick={() => void logout()} className={`${itemOutline} ml-1 lg:ml-2`}>
                <LogOut aria-hidden className="size-6 shrink-0 max-md:hidden" />
                {t.nav_logout}
              </button>
            </>
          )}
        </nav>
      </div>
      {available && auth.kind === "expired" && (
        <div className="border-b-2 border-warn-line bg-warn-soft text-warn-ink">
          <div className="page-shell flex min-h-16 flex-wrap items-center gap-x-3.5 gap-y-1 py-2 text-lg leading-snug font-bold">
            <p>{t.session_expired}</p>
            <Link href="/login" className="underline underline-offset-4">
              {t.nav_login}
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}
