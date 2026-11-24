# SerIQ — сайт

Next.js (App Router), TypeScript, Tailwind CSS, npm.

```bash
npm install
npm run dev                                            # http://localhost:3000, /api → localhost:8000
SERIQ_API_PROXY=https://seriq-ai.qalau.com npm run dev # /api → боевой сервер
npm run lint
npm run build                                          # сборка в .next/standalone для Docker
```

API вызывается по относительному адресу `/api/v1/...`. Контракт — [docs/api.md](../../docs/api.md), общие имена — [docs/team/integration.md](../../docs/team/integration.md).
