import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // experimental.proxyClientMaxBodySize — прокси next dev пропускает видео до 100 МБ (по умолчанию 10 МБ)
  experimental: { proxyClientMaxBodySize: "100mb" },
  // allowedDevOrigins — next dev отдаёт страницу телефону в той же сети по IP из SERIQ_DEV_ORIGIN
  allowedDevOrigins: process.env.SERIQ_DEV_ORIGIN ? [process.env.SERIQ_DEV_ORIGIN] : [],
  cacheComponents: true,
  partialPrefetching: true,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
  // rewrites — в разработке проксирует /api на бэкенд, на сервере /api перехватывает Caddy
  async rewrites() {
    if (process.env.NODE_ENV !== "development") return [];
    return [
      {
        source: "/api/:path*",
        destination: `${process.env.SERIQ_API_PROXY ?? "http://localhost:8000"}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
