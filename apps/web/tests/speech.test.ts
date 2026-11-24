import { describe, expect, it } from "vitest";
import { cleanText, hasVoice } from "@/lib/speech";

describe("hasVoice", () => {
  it("находит голос по языку, регистр и разделитель не важны", () => {
    expect(hasVoice("ru", [{ lang: "en-US" }, { lang: "ru-RU" }])).toBe(true);
    expect(hasVoice("ru", [{ lang: "ru_RU" }])).toBe(true);
    expect(hasVoice("kk", [{ lang: "KK-kz" }])).toBe(true);
  });
  it("нет голоса для языка — кнопку не показываем", () => {
    expect(hasVoice("kk", [{ lang: "ru-RU" }, { lang: "en-US" }])).toBe(false);
    expect(hasVoice("ru", [])).toBe(false);
  });
});

describe("cleanText", () => {
  it("убирает двойные точки на стыках", () => {
    expect(cleanText("Один шаг.. Второй шаг. Третий")).toBe("Один шаг. Второй шаг. Третий");
  });
});
