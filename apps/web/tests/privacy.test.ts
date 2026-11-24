import { describe, expect, it } from "vitest";
import { ru } from "@/lib/i18n/ru";
import { kk } from "@/lib/i18n/kk";
import { FOOTER_LINKS, PRIVACY_SECTIONS } from "@/lib/privacy";

const dicts = { ru, kk } as Record<string, Record<string, string>>;
const KEYS = [...PRIVACY_SECTIONS.flatMap((s) => [s.titleKey, ...s.textKeys]), ...FOOTER_LINKS.map((l) => l.labelKey), "go_home", "not_found_title", "not_found_text", "error_page_title", "error_page_text"];

describe("страница приватности, подвал, 404 и ошибка", () => {
  it("все тексты есть на русском и казахском и не пустые", () => {
    for (const [lang, d] of Object.entries(dicts)) {
      for (const key of KEYS) expect(d[key], `${lang}.${key}`).toBeTruthy();
    }
  });

  it("в подвале три ссылки: приватность, инструкции, история", () => {
    expect(FOOTER_LINKS.map((l) => l.href)).toEqual(["/privacy", "/#exercises", "/history"]);
  });

  it("на странице приватности есть всё обязательное и нет обещаний", () => {
    for (const [lang, d] of Object.entries(dicts)) {
      const text = PRIVACY_SECTIONS.flatMap((s) => [d[s.titleKey], ...s.textKeys.map((k) => d[k])]).join(" ").toLowerCase();
      expect(text, lang).toContain("ip");
      expect(text, lang).toContain("e-mail");
      expect(text, lang).not.toMatch(/шифр|гаранти|100\s?%|облак|google|яндекс|amazon|cloud|encrypt|гарант/);
    }
    const ruText = PRIVACY_SECTIONS.flatMap((s) => s.textKeys.map((k) => ru[k])).join(" ");
    expect(ruText).toContain("хэш пароля");
    expect(ruText).toContain("Пароль восстановить нельзя");
    expect(ruText).toContain("не является медицинским изделием");
    expect(ruText).toContain("только на этом устройстве");
  });

  it("сообщение об ошибке не содержит технических подробностей", () => {
    for (const d of Object.values(dicts)) {
      expect(`${d.error_page_title} ${d.error_page_text} ${d.not_found_text}`).not.toMatch(/error|exception|stack|500|404|undefined/i);
    }
  });
});
