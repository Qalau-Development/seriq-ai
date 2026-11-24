import type { Metadata, Viewport } from "next";
import Link from "next/link";
import { House } from "lucide-react";
import "./globals.css";

export const metadata: Metadata = {
  title: "SerIQ",
  description: "Помощник для домашних упражнений: проверяет по видео, выполнено ли разгибание локтя",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

// RootLayout — общая разметка: шапка, содержимое страницы, предупреждение внизу
export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="ru" className="h-full antialiased">
      <body className="flex min-h-full flex-col">
        <header className="border-b border-line">
          <div className="mx-auto flex w-full max-w-3xl items-center justify-between px-5 py-4">
            <Link href="/" className="text-2xl font-bold text-accent">
              SerIQ
            </Link>
            <Link
              href="/"
              className="flex min-h-12 items-center gap-2 rounded-xl px-3 text-lg font-semibold text-accent hover:bg-accent-soft"
            >
              <House aria-hidden className="size-6" />
              Главная
            </Link>
          </div>
        </header>
        <main className="mx-auto w-full max-w-3xl flex-1 px-5 py-8">{children}</main>
        <footer className="border-t border-line">
          <p className="mx-auto w-full max-w-3xl px-5 py-4 text-base text-muted">
            SerIQ не является медицинским изделием и не ставит диагнозов
          </p>
        </footer>
      </body>
    </html>
  );
}
