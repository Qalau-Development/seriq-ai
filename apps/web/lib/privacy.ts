import type { TextKey } from "@/lib/i18n";

export interface PrivacySection {
  titleKey: TextKey;
  textKeys: TextKey[];
}

// Разделы страницы «Данные и приватность»: только то, что реально так и есть
export const PRIVACY_SECTIONS: PrivacySection[] = [
  { titleKey: "privacy_video_title", textKeys: ["privacy_video_1"] },
  { titleKey: "privacy_guest_title", textKeys: ["privacy_guest_1"] },
  { titleKey: "privacy_account_title", textKeys: ["privacy_account_1"] },
  { titleKey: "privacy_not_stored_title", textKeys: ["privacy_not_stored_1"] },
  { titleKey: "privacy_delete_title", textKeys: ["privacy_delete_1"] },
  { titleKey: "privacy_password_title", textKeys: ["privacy_password_1"] },
  { titleKey: "privacy_medical_title", textKeys: ["privacy_medical_1"] },
];

// FOOTER_LINKS — ссылки подвала: приватность, инструкции (выбор упражнения на главной), история, мой прогресс
export const FOOTER_LINKS: { href: string; labelKey: TextKey }[] = [
  { href: "/privacy", labelKey: "privacy_link" },
  { href: "/#exercises", labelKey: "footer_instructions" },
  { href: "/history", labelKey: "nav_history" },
  { href: "/progress", labelKey: "nav_progress" },
];
