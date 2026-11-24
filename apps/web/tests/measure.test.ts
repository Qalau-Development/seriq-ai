import { describe, expect, it } from "vitest";
import { resultMeasure } from "@/lib/measure";
import { measureLine } from "@/lib/measureText";
import { ru } from "@/lib/i18n/ru";
import { kk } from "@/lib/i18n/kk";
import type { AnalysisResult, Measure } from "@/types/analysis";

const BASE = {
  status: "ok",
  analysis_id: "id",
  source: "model",
  model_version: "v",
  exercise: "E02",
  verdict: "completed",
  summary: { total: 1, complete: 1, incomplete: 0, uncertain: 0 },
  cycles: [],
  warnings: [],
  processing_ms: 1,
};

// res — ответ анализа для теста: общая основа плюс нужные поля
const res = (extra: object) => ({ ...BASE, ...extra }) as unknown as AnalysisResult;
const m = (name: Measure["name"], unit: Measure["unit"], value: number | null): Measure => ({ name, unit, value, series: { fps: 10, values: [1] } });

describe("resultMeasure", () => {
  it("берёт measure, если он есть", () => {
    const measure = m("hand_openness", "percent", 150);
    expect(resultMeasure(res({ exercise: "E04", measure }))).toBe(measure);
  });
  it("без measure откат на angle_series: elbow_angle, максимум без пропусков", () => {
    const r = resultMeasure(res({ angle_series: { fps: 10, unit: "deg", values: [62.5, null, 166.2, 150] } }))!;
    expect(r.name).toBe("elbow_angle");
    expect(r.unit).toBe("deg");
    expect(r.value).toBe(166.2);
    expect(r.series).toEqual({ fps: 10, values: [62.5, null, 166.2, 150] });
  });
  it("angle_series только из null — значение null", () => {
    expect(resultMeasure(res({ angle_series: { fps: 10, unit: "deg", values: [null, null] } }))!.value).toBeNull();
  });
  it("нет ни measure, ни angle_series — null", () => {
    expect(resultMeasure(res({}))).toBeNull();
  });
});

describe("measureLine", () => {
  it("hand_openness: выросло на (value − 100)%", () => {
    expect(measureLine(ru, m("hand_openness", "percent", 178.9))).toBe("Раскрытие кисти выросло на 79%");
  });
  it("hand_openness: не больше 100 — процент от начального", () => {
    expect(measureLine(ru, m("hand_openness", "percent", 96.5))).toBe("Раскрытие кисти: 97% от начального");
    expect(measureLine(ru, m("hand_openness", "percent", 100))).toBe("Раскрытие кисти: 100% от начального");
  });
  it("wrist_lift: градусы, округление до целого", () => {
    expect(measureLine(ru, m("wrist_lift", "deg", 113.3))).toBe("Кисть повернулась на 113°");
  });
  it("lift_height: одна цифра после запятой, запятая как разделитель", () => {
    expect(measureLine(ru, m("lift_height", "hand_lengths", 2.56))).toBe("Кисть поднялась на 2,6 длины кисти");
    expect(measureLine(ru, m("lift_height", "hand_lengths", 3))).toBe("Кисть поднялась на 3,0 длины кисти");
  });
  it("value = null — строки нет", () => {
    for (const [n, u] of [["hand_openness", "percent"], ["wrist_lift", "deg"], ["lift_height", "hand_lengths"], ["elbow_angle", "deg"]] as const) {
      expect(measureLine(ru, m(n, u, null))).toBeNull();
    }
  });
  it("казахский текст подставляет те же числа", () => {
    expect(measureLine(kk, m("wrist_lift", "deg", 40))).toContain("40");
    expect(measureLine(kk, m("lift_height", "hand_lengths", 1.25))).toContain("1,3");
  });
});
