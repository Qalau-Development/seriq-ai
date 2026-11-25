import { describe, expect, it } from "vitest";
import { ru, type Dict } from "@/lib/i18n/ru";
import { en } from "@/lib/i18n/en";
import { kk } from "@/lib/i18n/kk";
import { EXERCISES } from "@/lib/exercises";
import { resultParts } from "@/lib/resultText";
import { cueItem, instructionItems } from "@/lib/voiceClips";
import { clampInt, clipAvailable, createVoice, parseManifest, PAUSE_MS, type AudioLike, type Manifest, type VoiceEnv } from "@/lib/voice";
import type { CycleLabel, Measure } from "@/types/analysis";

const LABELS: CycleLabel[] = ["complete", "incomplete", "uncertain"];
const m = (name: Measure["name"], unit: Measure["unit"], value: number | null): Measure => ({ name, unit, value, series: { fps: 10, values: [1] } });
const MANIFEST: Manifest = {
  v: 1,
  clips: {
    a: { ru: "ru/a.mp3", kk: "kk/a.mp3", en: "en/a.mp3" },
    b: { ru: "ru/b.mp3" },
    c: { ru: "ru/c.mp3" },
  },
};

class FakeAudio implements AudioLike {
  onended: ((ev: Event) => unknown) | null = null;
  onerror: ((ev: Event | string) => unknown) | null = null;
  currentTime = 0;
  played = 0;
  paused = false;
  constructor(public url: string) {}
  play() {
    this.played++;
  }
  pause() {
    this.paused = true;
  }
}

// setup — окружение с заглушками: аудио, запасной голос и таймеры, которыми управляет тест
function setup(manifest: Manifest | null = MANIFEST) {
  const audios: FakeAudio[] = [];
  const spoken: string[] = [];
  const speakEnds: (() => void)[] = [];
  const timers: { fn: () => void; ms: number; live: boolean }[] = [];
  let now = 1000;
  let stopped = 0;
  const env: VoiceEnv = {
    fetchManifest: async () => manifest,
    createAudio: (url) => {
      const a = new FakeAudio(url);
      audios.push(a);
      return a;
    },
    speak: (text, _lang, onEnd) => {
      spoken.push(text);
      speakEnds.push(onEnd);
    },
    stopSpeak: () => void stopped++,
    later: (fn, ms) => {
      const timer = { fn, ms, live: true };
      timers.push(timer);
      return () => void (timer.live = false);
    },
    now: () => now,
  };
  const voice = createVoice(env);
  const tick = () => timers.filter((x) => x.live).forEach((x) => ((x.live = false), x.fn()));
  return { voice, audios, spoken, speakEnds, timers, tick, advance: (ms: number) => void (now += ms), stopped: () => stopped };
}

describe("clampInt", () => {
  it("округляет и прижимает к краям", () => {
    expect(clampInt(179.6, 0, 180)).toBe(180);
    expect(clampInt(-5, 0, 180)).toBe(0);
    expect(clampInt(300, 1, 200)).toBe(200);
    expect(clampInt(0, 1, 200)).toBe(1);
  });
});

describe("id клипов инструкции", () => {
  it("по порядку: название, шаги, «Как снимать», советы; id равен ключу словаря", () => {
    for (const def of EXERCISES) {
      const items = instructionItems(ru, def);
      expect(items.map((i) => i.id)).toEqual([def.titleKey, ...def.stepKeys, "tips_title", ...def.tipKeys]);
      expect(items.every((i) => i.text.length > 0)).toBe(true);
    }
    expect(instructionItems(ru, EXERCISES[3]).map((i) => i.id)).toEqual([
      "exercise_e04_title", "e04_step_1", "e04_step_2", "e04_step_3", "e04_step_4", "tips_title", "e04_tip_1", "e04_tip_2", "tip_3", "tip_4",
    ]);
  });
  it("текст запасного голоса берётся на языке интерфейса", () => {
    expect(instructionItems(en, EXERCISES[1])[0].text).toBe(en.exercise_e02_title);
    expect(instructionItems(kk, EXERCISES[1])[0].text).toBe(kk.exercise_e02_title);
  });
});

describe("id клипов результата: заголовок", () => {
  it("E02: result_title_{метка}, остальные: verdict_completed или verdict_check_instructions", () => {
    for (const label of LABELS) {
      expect(resultParts(ru, label, "E02", null).title.id).toBe(`result_title_${label}`);
      for (const ex of ["E01", "E03", "E04"] as const) {
        expect(resultParts(ru, label, ex, null).title.id).toBe(label === "complete" ? "verdict_completed" : "verdict_check_instructions");
      }
    }
  });
});

describe("id клипов результата: строки с числом", () => {
  it("E02: result_line_{метка}__{максимум угла}, текст как на экране", () => {
    for (const label of LABELS) {
      const { lines } = resultParts(ru, label, "E02", m("elbow_angle", "deg", 123.4));
      expect(lines).toHaveLength(1);
      expect(lines[0].id).toBe(`result_line_${label}__123`);
      expect(lines[0].text).toContain("123");
    }
  });
  it("E02: значение вне 0–180 прижимается, текст остаётся показанным", () => {
    expect(resultParts(ru, "complete", "E02", m("elbow_angle", "deg", 191)).lines[0].id).toBe("result_line_complete__180");
    expect(resultParts(ru, "complete", "E02", m("elbow_angle", "deg", -3)).lines[0].id).toBe("result_line_complete__0");
  });
  it("E02 без значения: подсказка result_hint_{метка}; у «выполнено» строки нет", () => {
    expect(resultParts(ru, "uncertain", "E02", null).lines.map((l) => l.id)).toEqual(["result_hint_uncertain"]);
    expect(resultParts(ru, "incomplete", "E02", null).lines.map((l) => l.id)).toEqual(["result_hint_incomplete"]);
    expect(resultParts(ru, "complete", "E02", null).lines).toEqual([]);
  });
  it("E04: выросло — value−100 от 1 до 200, иначе значение от 0 до 100", () => {
    expect(resultParts(ru, "complete", "E04", m("hand_openness", "percent", 178.9)).lines[0].id).toBe("result_measure_hand_openness_up__79");
    expect(resultParts(ru, "complete", "E04", m("hand_openness", "percent", 100)).lines[0].id).toBe("result_measure_hand_openness_base__100");
    expect(resultParts(ru, "complete", "E04", m("hand_openness", "percent", 100.6)).lines[0].id).toBe("result_measure_hand_openness_up__1");
    expect(resultParts(ru, "complete", "E04", m("hand_openness", "percent", 96.5)).lines[0].id).toBe("result_measure_hand_openness_base__97");
    expect(resultParts(ru, "complete", "E04", m("hand_openness", "percent", 450)).lines[0].id).toBe("result_measure_hand_openness_up__200");
    expect(resultParts(ru, "complete", "E04", m("hand_openness", "percent", -4)).lines[0].id).toBe("result_measure_hand_openness_base__0");
  });
  it("E03: result_measure_wrist_lift__n от 0 до 180", () => {
    expect(resultParts(ru, "complete", "E03", m("wrist_lift", "deg", 113.3)).lines[0].id).toBe("result_measure_wrist_lift__113");
    expect(resultParts(ru, "complete", "E03", m("wrist_lift", "deg", 400)).lines[0].id).toBe("result_measure_wrist_lift__180");
    expect(resultParts(ru, "complete", "E03", m("wrist_lift", "deg", -1)).lines[0].id).toBe("result_measure_wrist_lift__0");
  });
  it("E01: одна цифра после точки, от 0.0 до 9.9, на экране запятая языка", () => {
    const line = resultParts(ru, "complete", "E01", m("lift_height", "hand_lengths", 3.46)).lines[0];
    expect(line.id).toBe("result_measure_lift_height__3.5");
    expect(line.text).toBe("Кисть поднялась на 3,5 длины кисти");
    expect(resultParts(ru, "complete", "E01", m("lift_height", "hand_lengths", 0)).lines[0].id).toBe("result_measure_lift_height__0.0");
    expect(resultParts(ru, "complete", "E01", m("lift_height", "hand_lengths", 12.7)).lines[0].id).toBe("result_measure_lift_height__9.9");
    expect(resultParts(ru, "complete", "E01", m("lift_height", "hand_lengths", 9.96)).lines[0].id).toBe("result_measure_lift_height__9.9");
    expect(resultParts(ru, "complete", "E01", m("lift_height", "hand_lengths", -2)).lines[0].id).toBe("result_measure_lift_height__0.0");
  });
  it("без числа строки нет; подсказка для не-E02 с вариантом _other", () => {
    for (const [ex, name, unit] of [["E01", "lift_height", "hand_lengths"], ["E03", "wrist_lift", "deg"], ["E04", "hand_openness", "percent"]] as const) {
      expect(resultParts(ru, "complete", ex, m(name, unit, null)).lines).toEqual([]);
      expect(resultParts(ru, "uncertain", ex, m(name, unit, null)).lines.map((l) => l.id)).toEqual(["result_hint_uncertain_other"]);
      expect(resultParts(ru, "incomplete", ex, m(name, unit, null)).lines.map((l) => l.id)).toEqual(["result_hint_incomplete"]);
    }
  });
  it("не выполнено: после числа идёт подсказка", () => {
    const { lines } = resultParts(ru, "incomplete", "E03", m("wrist_lift", "deg", 20));
    expect(lines.map((l) => l.id)).toEqual(["result_measure_wrist_lift__20", "result_hint_incomplete"]);
  });
  it("все id чисел из набора, для которого записаны клипы, укладываются в диапазоны", () => {
    for (let v = -20; v <= 520; v += 7) {
      const id = (ex: "E03" | "E04", name: Measure["name"], unit: Measure["unit"]) => resultParts(ru, "complete", ex, m(name, unit, v)).lines[0].id;
      const n3 = Number(id("E03", "wrist_lift", "deg").split("__")[1]);
      expect(n3).toBeGreaterThanOrEqual(0);
      expect(n3).toBeLessThanOrEqual(180);
      const [key, n4] = id("E04", "hand_openness", "percent").split("__");
      expect(Number(n4)).toBeGreaterThanOrEqual(key.endsWith("up") ? 1 : 0);
      expect(Number(n4)).toBeLessThanOrEqual(key.endsWith("up") ? 200 : 100);
    }
  });
});

describe("подсказки живого режима", () => {
  it("клипы есть у «положите руку / повернитесь боком» и «рука не видна»", () => {
    expect(cueItem(ru, "show_hand", false)).toEqual({ id: "live_show_hand", text: ru.live_show_hand });
    expect(cueItem(ru, "show_hand", true)).toEqual({ id: "live_show_arm", text: ru.live_show_arm });
    expect(cueItem(ru, "lost", true)).toEqual({ id: "live_lost", text: ru.live_lost });
  });
  it("пять корректирующих подсказок не озвучиваются", () => {
    for (const key of ["start", "more", "hold", "slower", "back"] as const) expect(cueItem(ru, key, false)).toBeNull();
  });
});

describe("parseManifest и clipAvailable", () => {
  it("принимает формат v1, остальное отвергает", () => {
    expect(parseManifest({ v: 1, clips: {} })).toEqual({ v: 1, clips: {} });
    expect(parseManifest({ v: 2, clips: {} })).toBeNull();
    expect(parseManifest(null)).toBeNull();
    expect(parseManifest("x")).toBeNull();
  });
  it("кнопка нужна, если в манифесте есть клип на языке", () => {
    const items = [{ id: "b", text: "" }];
    expect(clipAvailable(MANIFEST, items, "ru")).toBe(true);
    expect(clipAvailable(MANIFEST, items, "kk")).toBe(false);
    expect(clipAvailable(null, items, "ru")).toBe(false);
    expect(clipAvailable(undefined, items, "ru")).toBe(false);
  });
});

describe("playClips", () => {
  const items = [
    { id: "a", text: "А" },
    { id: "b", text: "Б" },
    { id: "c", text: "В" },
  ];

  it("играет клипы по очереди с паузой 250 мс и предзагружает следующий", async () => {
    const s = setup();
    let ended = 0;
    s.voice.playClips(items, "ru", () => ended++);
    await s.voice.load();
    expect(s.audios.map((a) => a.url)).toEqual(["/voice/ru/a.mp3", "/voice/ru/b.mp3"]);
    expect(s.audios[0].played).toBe(1);
    expect(s.audios[1].played).toBe(0);
    s.audios[0].onended!({} as Event);
    expect(s.timers.at(-1)!.ms).toBe(PAUSE_MS);
    expect(s.audios[1].played).toBe(0);
    s.tick();
    expect(s.audios[1].played).toBe(1);
    expect(s.audios.map((a) => a.url)).toContain("/voice/ru/c.mp3");
    s.audios[1].onended!({} as Event);
    s.tick();
    s.audios[2].onended!({} as Event);
    expect(ended).toBe(1);
    expect(s.spoken).toEqual([]);
  });

  it("клипа нет в манифесте — этот фрагмент читает голос браузера, остальные файлы", async () => {
    const s = setup();
    s.voice.playClips(items, "kk");
    await s.voice.load();
    expect(s.audios.map((a) => a.url)).toEqual(["/voice/kk/a.mp3"]);
    s.audios[0].onended!({} as Event);
    s.tick();
    expect(s.spoken).toEqual(["Б"]);
    s.speakEnds[0]();
    s.tick();
    expect(s.spoken).toEqual(["Б", "В"]);
  });

  it("клип не загрузился (ошибка или отказ play) — читает голос браузера, дальше идёт по очереди", async () => {
    const s = setup();
    s.voice.playClips(items, "ru");
    await s.voice.load();
    s.audios[0].onerror!("");
    expect(s.spoken).toEqual(["А"]);
    s.speakEnds[0]();
    s.tick();
    expect(s.audios.find((a) => a.url.endsWith("b.mp3"))!.played).toBe(1);
  });

  it("отказ play() тоже запасной вариант", async () => {
    const s = setup();
    const create = s.voice;
    create.playClips([items[0]], "ru");
    await create.load();
    s.audios[0].onerror!("");
    expect(s.spoken).toEqual(["А"]);
  });

  it("без манифеста всё читает голос браузера", async () => {
    const s = setup(null);
    let ended = 0;
    s.voice.playClips([items[0], items[1]], "ru", () => ended++);
    await s.voice.load();
    expect(s.audios).toEqual([]);
    expect(s.spoken).toEqual(["А"]);
    s.speakEnds[0]();
    s.tick();
    s.speakEnds[1]();
    expect(s.spoken).toEqual(["А", "Б"]);
    expect(ended).toBe(1);
  });

  it("новый вызов прерывает предыдущий, его onEnd не вызывается", async () => {
    const s = setup();
    let first = 0;
    let second = 0;
    s.voice.playClips(items, "ru", () => first++);
    await s.voice.load();
    const old = s.audios[0];
    s.voice.playClips([items[2]], "ru", () => second++);
    expect(old.paused).toBe(true);
    expect(old.onended).toBeNull();
    s.audios.find((a) => a.url.endsWith("c.mp3"))!.onended!({} as Event);
    expect(first).toBe(0);
    expect(second).toBe(1);
  });
});

describe("stop", () => {
  it("останавливает клип, паузу между клипами и запасной голос; onEnd не вызывается", async () => {
    const s = setup();
    let ended = 0;
    s.voice.playClips(items3(), "ru", () => ended++);
    await s.voice.load();
    s.audios[0].onended!({} as Event);
    s.voice.stop();
    s.tick();
    expect(s.audios[1].played).toBe(0);
    expect(ended).toBe(0);
    expect(s.stopped()).toBeGreaterThan(0);
    expect(s.voice.isPlaying()).toBe(false);
  });
  it("остановка во время клипа ставит его на паузу", async () => {
    const s = setup();
    s.voice.playClips(items3(), "ru");
    await s.voice.load();
    s.voice.stop();
    expect(s.audios[0].paused).toBe(true);
    s.audios[0].onended?.({} as Event);
    expect(s.audios[1].played).toBe(0);
  });
  it("остановка до загрузки манифеста: ничего не играет", async () => {
    const s = setup();
    s.voice.playClips(items3(), "ru");
    s.voice.stop();
    await s.voice.load();
    expect(s.audios).toEqual([]);
    expect(s.spoken).toEqual([]);
  });
});

function items3() {
  return [
    { id: "a", text: "А" },
    { id: "b", text: "Б" },
  ];
}

describe("playCue", () => {
  it("одну и ту же подсказку не чаще раза в 4 секунды", async () => {
    const s = setup();
    await s.voice.load();
    const cue = { id: "a", text: "А" };
    expect(s.voice.playCue(cue, "ru")).toBe(true);
    s.audios[0].onended!({} as Event);
    s.advance(3000);
    expect(s.voice.playCue(cue, "ru")).toBe(false);
    s.advance(1100);
    expect(s.voice.playCue(cue, "ru")).toBe(true);
  });
  it("новая подсказка не накладывается на играющую", async () => {
    const s = setup();
    await s.voice.load();
    expect(s.voice.playCue({ id: "a", text: "А" }, "ru")).toBe(true);
    expect(s.voice.playCue({ id: "b", text: "Б" }, "ru")).toBe(false);
    s.audios[0].onended!({} as Event);
    expect(s.voice.playCue({ id: "b", text: "Б" }, "ru")).toBe(true);
  });
  it("force (итог повтора) прерывает играющую", async () => {
    const s = setup();
    await s.voice.load();
    s.voice.playCue({ id: "a", text: "А" }, "ru");
    expect(s.voice.playCue({ id: "b", text: "Б" }, "ru", true)).toBe(true);
    expect(s.audios[0].paused).toBe(true);
  });
  it("зависший клип не блокирует подсказки навсегда", async () => {
    const s = setup();
    await s.voice.load();
    s.voice.playCue({ id: "a", text: "А" }, "ru");
    s.advance(16000);
    expect(s.voice.playCue({ id: "b", text: "Б" }, "ru")).toBe(true);
  });
  it("предзагрузка создаёт аудио для клипов из манифеста", async () => {
    const s = setup();
    s.voice.preload(["a", "b", "нет"], "ru");
    await s.voice.load();
    await Promise.resolve();
    expect(s.audios.map((a) => a.url)).toEqual(["/voice/ru/a.mp3", "/voice/ru/b.mp3"]);
  });
});

describe("словари", () => {
  it("все ключи озвучки есть во всех языках", () => {
    const dicts: Dict[] = [ru, kk, en];
    for (const d of dicts) for (const k of ["live_show_hand", "live_show_arm", "live_lost", "live_unstable", "verdict_completed", "verdict_check_instructions", "tips_title"] as const) expect(d[k]).toBeTruthy();
  });
});
