import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import { SiteHeader } from "@/components/ui/SiteHeader";
import { SiteFooter } from "@/components/ui/SiteFooter";
import { BottomNav } from "@/components/ui/BottomNav";
import { MigratePrompt } from "@/components/account/MigratePrompt";
import "./globals.css";

// Montserrat лежит в репозитории (OFL), по трём наборам знаков: латиница, кириллица и расширенная кириллица (ә ғ қ ң ө ұ ү һ і); внешних запросов нет
const montserratLatin = localFont({
  src: "./fonts/montserrat-latin.woff2",
  weight: "500 800",
  display: "swap",
  adjustFontFallback: false,
  variable: "--font-montserrat-latin",
  declarations: [
    {
      prop: "unicode-range",
      value:
        "U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD",
    },
  ],
});
const montserratCyrillic = localFont({
  src: "./fonts/montserrat-cyrillic.woff2",
  weight: "500 800",
  display: "swap",
  adjustFontFallback: false,
  variable: "--font-montserrat-cyrillic",
  declarations: [{ prop: "unicode-range", value: "U+0301, U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116" }],
});
const montserratCyrillicExt = localFont({
  src: "./fonts/montserrat-cyrillic-ext.woff2",
  weight: "500 800",
  display: "swap",
  adjustFontFallback: false,
  variable: "--font-montserrat-cyrillic-ext",
  declarations: [{ prop: "unicode-range", value: "U+0460-052F, U+1C80-1C8A, U+20B4, U+2DE0-2DFF, U+A640-A69F, U+FE2E-FE2F" }],
});

export const metadata: Metadata = {
  title: "SerIQ",
  description: "ИИ-помощник для домашней реабилитации. По видео с камеры или загруженной записи оценивает цикл разгибания локтя и показывает нейтральный результат.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

// RootLayout — общая разметка: шапка, содержимое страницы, предупреждение внизу
export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="ru" className={`${montserratLatin.variable} ${montserratCyrillic.variable} ${montserratCyrillicExt.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col max-sm:pb-24">
        <SiteHeader />
        <MigratePrompt />
        <div className="flex-1 overflow-x-clip">
          <main className="page-shell py-8 md:py-12">{children}</main>
        </div>
        <SiteFooter />
        <BottomNav />
      </body>
    </html>
  );
}
