import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // experimental.proxyClientMaxBodySize — прокси next dev пропускает видео до 100 МБ (по умолчанию 10 МБ)
  experimental: { proxyClientMaxBodySize: "100mb" },
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
  // rewrites — в разработке проксирует /api на бэкенд и /tts на сервер синтеза речи, на сервере /api перехватывает Caddy
  async rewrites() {
    if (process.env.NODE_ENV !== "development") return [];
    return [
      { source: "/tts", destination: `${process.env.SERIQ_TTS_PROXY ?? "http://127.0.0.1:8100"}/tts` },
      {
        source: "/api/:path*",
        destination: `${process.env.SERIQ_API_PROXY ?? "http://localhost:8000"}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
