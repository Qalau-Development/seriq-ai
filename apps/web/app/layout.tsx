import type { Metadata, Viewport } from "next";
import { SiteHeader } from "@/components/ui/SiteHeader";
import { SiteFooter } from "@/components/ui/SiteFooter";
import { MigratePrompt } from "@/components/account/MigratePrompt";
import "./globals.css";

export const metadata: Metadata = {
  title: "SerIQ",
  description: "Помощник для домашних упражнений: проверяет по видео, выполнено ли упражнение",
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
        <SiteHeader />
        <MigratePrompt />
        <main className="mx-auto w-full max-w-3xl flex-1 px-5 py-8">{children}</main>
        <SiteFooter />
      </body>
    </html>
  );
}
