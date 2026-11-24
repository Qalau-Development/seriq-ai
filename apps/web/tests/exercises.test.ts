import { describe, expect, it } from "vitest";
import { EXERCISES, fallbackCatalog, parseCatalog, parseExercise, exerciseAvailability } from "@/lib/exercises";

const SERVER = [
  { id: "E01", measure: { name: "lift_height", unit: "hand_lengths" }, ready: false },
  { id: "E02", measure: { name: "elbow_angle", unit: "deg" }, ready: true },
  { id: "E03", measure: { name: "wrist_lift", unit: "deg" }, ready: true },
  { id: "E04", measure: { name: "hand_openness", unit: "percent" }, ready: true },
];

describe("parseCatalog", () => {
  it("читает ответ сервера: готовность и measure по каждому упражнению", () => {
    const catalog = parseCatalog(SERVER)!;
    expect(catalog.map((e) => [e.id, e.ready])).toEqual([["E01", false], ["E02", true], ["E03", true], ["E04", true]]);
    expect(catalog[3].measure).toEqual({ name: "hand_openness", unit: "percent" });
  });
  it("упражнение, которого нет в ответе, не готово; неизвестные упражнения и поля игнорируются", () => {
    const catalog = parseCatalog([{ id: "E02", measure: { name: "elbow_angle", unit: "deg" }, ready: true, extra: 1 }, { id: "E99", ready: true }])!;
    expect(catalog.map((e) => e.id)).toEqual(["E01", "E02", "E03", "E04"]);
    expect(catalog.filter((e) => e.ready).map((e) => e.id)).toEqual(["E02"]);
  });
  it("неверные name и unit заменяются значениями справочника", () => {
    const catalog = parseCatalog([{ id: "E04", measure: { name: "x", unit: "y" }, ready: true }])!;
    expect(catalog[3].measure).toEqual({ name: "hand_openness", unit: "percent" });
  });
  it("не каталог — null", () => {
    expect(parseCatalog(null)).toBeNull();
    expect(parseCatalog({ id: "E02" })).toBeNull();
    expect(parseCatalog([])).toBeNull();
    expect(parseCatalog([{ id: "E77" }])).toBeNull();
  });
});

describe("fallbackCatalog", () => {
  it("четыре упражнения из справочника, запись доступна только для E02", () => {
    const catalog = fallbackCatalog();
    expect(catalog).toHaveLength(4);
    expect(catalog.map((e) => e.id)).toEqual(EXERCISES.map((e) => e.id));
    expect(catalog.filter((e) => e.ready).map((e) => e.id)).toEqual(["E02"]);
    expect(catalog.find((e) => e.id === "E01")?.measure).toEqual({ name: "lift_height", unit: "hand_lengths" });
  });
});

describe("parseExercise и exerciseAvailability", () => {
  it("без параметра и с неизвестным кодом — E02", () => {
    expect(parseExercise(null)).toBe("E02");
    expect(parseExercise("E99")).toBe("E02");
    expect(parseExercise("E04")).toBe("E04");
  });
  it("пока каталога нет, доступно только E02, остальные загружаются", () => {
    expect(exerciseAvailability(null, "E02")).toBe("ready");
    expect(exerciseAvailability(null, "E04")).toBe("loading");
    expect(exerciseAvailability(fallbackCatalog(), "E04")).toBe("soon");
    expect(exerciseAvailability(parseCatalog(SERVER), "E04")).toBe("ready");
  });
  it("у E01 пометка «менее надёжно», у остальных нет", () => {
    expect(EXERCISES.filter((e) => e.lowConfidence).map((e) => e.id)).toEqual(["E01"]);
  });
});
