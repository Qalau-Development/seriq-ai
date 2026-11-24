import { describe, expect, it } from "vitest";
import { LANGS, fill, formatDateTime, num, parseLang } from "@/lib/i18n";
import { ru } from "@/lib/i18n/ru";
import { kk } from "@/lib/i18n/kk";
import { en } from "@/lib/i18n/en";
import { measureLine } from "@/lib/measureText";
import { hasVoice } from "@/lib/speech";
import { applyDocumentMeta } from "@/lib/i18n/meta";

const dicts = { ru, kk, en } as Record<string, Record<string, string>>;

describe("языки", () => {
  it("три языка: ru, kk, en; неизвестное значение — ru", () => {
    expect(LANGS).toEqual(["ru", "kk", "en"]);
    expect(parseLang("en")).toBe("en");
    expect(parseLang("kk")).toBe("kk");
    expect(parseLang("de")).toBe("ru");
    expect(parseLang(null)).toBe("ru");
  });

  it("у всех словарей один набор ключей", () => {
    const keys = Object.keys(ru).sort();
    expect(Object.keys(kk).sort()).toEqual(keys);
    expect(Object.keys(en).sort()).toEqual(keys);
  });

  it("английский словарь без кириллицы, и ни один текст не пустой (кроме result_hint_complete)", () => {
    for (const [key, text] of Object.entries(en)) {
      expect(text, key).not.toMatch(/[А-Яа-яЁёӘәІіҢңҒғҮүҰұҚқӨөҺһ]/);
      if (key !== "result_hint_complete") expect(text, key).toBeTruthy();
    }
  });

  it("подстановки {…} одни и те же во всех языках", () => {
    const slots = (s: string) => [...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();
    for (const key of Object.keys(ru)) {
      for (const lang of ["kk", "en"]) expect(slots(dicts[lang][key]), `${lang}.${key}`).toEqual(slots(dicts.ru[key]));
    }
  });

  it("в английских текстах нет медицинских обещаний", () => {
    expect(Object.values(en).join(" ").toLowerCase()).not.toMatch(/recover(y|ed)? (from|of)|cure|improvement|diagnos(e|is) (you|your)/);
  });
});

describe("числа и даты по языку", () => {
  it("десятичный разделитель: запятая в ru и kk, точка в en", () => {
    expect(num(ru, "2.5")).toBe("2,5");
    expect(num(kk, "2.5")).toBe("2,5");
    expect(num(en, "2.5")).toBe("2.5");
  });
  it("строка высоты подъёма на английском с точкой", () => {
    const m = { name: "lift_height" as const, unit: "hand_lengths" as const, value: 2.56, series: { fps: 10, values: [1] } };
    expect(measureLine(en, m)).toBe("The hand rose by 2.6 hand lengths");
    expect(measureLine(ru, m)).toBe("Кисть поднялась на 2,6 длины кисти");
  });
  it("строки результата на английском", () => {
    const op = { name: "hand_openness" as const, unit: "percent" as const, value: 178.9, series: { fps: 10, values: [1] } };
    expect(measureLine(en, op)).toBe("Hand opening increased by 79%");
    expect(measureLine(en, { ...op, value: 96.5 })).toBe("Hand opening: 97% of the starting value");
    expect(measureLine(en, { name: "wrist_lift", unit: "deg", value: 113.3, series: { fps: 10, values: [1] } })).toBe("The hand turned by 113°");
  });
  it("дата на английском содержит название месяца по-английски", () => {
    expect(formatDateTime("2026-11-25T10:00:00Z", "en")).toMatch(/November/);
    expect(formatDateTime("2026-11-25T10:00:00Z", "kk")).toMatch(/қараша/);
  });
  it("fill подставляет значения", () => {
    expect(fill(en.history_completed_count, { done: 2, total: 3 })).toBe("Done 2 of 3");
  });
  it("голос для английского ищется по en", () => {
    expect(hasVoice("en", [{ lang: "en-US" }])).toBe(true);
    expect(hasVoice("en", [{ lang: "ru-RU" }])).toBe(false);
  });
});

describe("заголовок и описание страницы по языку", () => {
  // fakeDoc — минимальный документ для проверки без браузера: tags — уже стоящие теги description
  function fakeDoc(count: number) {
    const mk = (content: string) => {
      const attrs: Record<string, string> = { content };
      return { attrs, getAttribute: (k: string) => attrs[k] ?? null, setAttribute: (k: string, v: string) => void (attrs[k] = v) };
    };
    const tags = Array.from({ length: count }, () => mk("старое"));
    const created: ReturnType<typeof mk>[] = [];
    const doc = {
      title: "",
      documentElement: { lang: "" },
      head: { appendChild: (n: unknown) => void created.push(n as ReturnType<typeof mk>) },
      querySelectorAll: () => [...tags, ...created],
      createElement: () => mk(""),
    };
    return { doc, tags, created };
  }

  it("для каждого языка меняет title, lang и description", () => {
    for (const [lang, d] of [["ru", ru], ["kk", kk], ["en", en]] as const) {
      const { doc, tags } = fakeDoc(2);
      applyDocumentMeta(doc, lang, d);
      expect(doc.title).toBe(d.meta_title);
      expect(doc.documentElement.lang).toBe(lang);
      expect(tags.map((t) => t.attrs.content)).toEqual([d.meta_description, d.meta_description]);
    }
    expect(en.meta_description).not.toBe(ru.meta_description);
    expect(ru.meta_title).toBe("SerIQ");
  });

  it("если тега description нет, он создаётся", () => {
    const { doc, created } = fakeDoc(0);
    applyDocumentMeta(doc, "en", en);
    expect(created).toHaveLength(1);
    expect(created[0].attrs.name).toBe("description");
    expect(created[0].attrs.content).toBe(en.meta_description);
  });
});
