import type { Dict } from "@/lib/i18n";
import { Notice } from "@/components/ui/Notice";

// MockBadge — плашка «Тестовые данные» для ответа с source: "mock"
export function MockBadge({ t, text }: { t: Dict; text?: string }) {
  return <Notice kind="warn">{text ?? t.mock_badge}</Notice>;
}
