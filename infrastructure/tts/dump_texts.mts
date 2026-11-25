// dump_texts — выгружает фразы сайта для прогрева сервера синтеза в texts.json
import { writeFileSync } from "node:fs";
import { ru } from "../../apps/web/lib/i18n/ru.ts";
import { kk } from "../../apps/web/lib/i18n/kk.ts";

const steps = ["e01", "e03", "e04"].flatMap((e) => [1, 2, 3, 4].map((i) => `${e}_step_${i}`));
const keys = [
  "exercise_e01_title", "exercise_e02_title", "exercise_e03_title", "exercise_e04_title",
  "instruction_step_1", "instruction_step_2", "instruction_step_3", "instruction_step_4", ...steps,
  "tips_title", "tip_1", "tip_2", "tip_3", "tip_4", "e01_tip_1", "e01_tip_2", "e01_tip_3",
  "e03_tip_1", "e03_tip_2", "e04_tip_1", "e04_tip_2",
  "result_title_complete", "result_title_incomplete", "result_title_uncertain",
  "verdict_completed", "verdict_check_instructions",
  "result_hint_incomplete", "result_hint_uncertain", "result_hint_uncertain_other",
  "live_show_hand", "live_show_arm", "live_start", "live_more", "live_hold", "live_slower", "live_lost", "live_back",
];
const dicts: Record<string, Record<string, string>> = { ru, kk };
const out = Object.fromEntries(Object.entries(dicts).map(([lang, d]) => [lang, Object.fromEntries(keys.filter((k) => k in d).map((k) => [k, d[k]]))]));
writeFileSync(new URL("./texts.json", import.meta.url), JSON.stringify(out, null, 1));
console.log("texts.json:", Object.keys(out.ru).length, "phrases per language");
