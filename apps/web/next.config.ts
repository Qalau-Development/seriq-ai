import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
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
