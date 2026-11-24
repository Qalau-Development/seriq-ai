import { FlaskConical } from "lucide-react";
import type { Dict } from "@/lib/i18n";

// MockBadge — плашка «Тестовые данные» для ответа с source: "mock"
export function MockBadge({ t, text }: { t: Dict; text?: string }) {
  return (
    <div className="flex items-center gap-3 rounded-xl border-2 border-warn-ink bg-warn-soft px-4 py-3 font-semibold text-warn-ink">
      <FlaskConical aria-hidden className="size-6 shrink-0" />
      <span>{text ?? t.mock_badge}</span>
    </div>
  );
}
