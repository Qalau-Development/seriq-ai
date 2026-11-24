import { describe, expect, it } from "vitest";
import { isActive } from "@/lib/navigation";

describe("isActive", () => {
  it("выбран только сам раздел: главная, история, прогресс, профиль", () => {
    expect(isActive("/", "/")).toBe(true);
    expect(isActive("/history", "/history")).toBe(true);
    expect(isActive("/progress/", "/progress")).toBe(true);
    expect(isActive("/profile", "/profile")).toBe(true);
  });
  it("у упражнений, занятия и итогов выбранного пункта нет", () => {
    for (const p of ["/exercise", "/session", "/summary", "/privacy"]) for (const h of ["/", "/history", "/progress"]) expect(isActive(p, h)).toBe(false);
  });
  it("вход выбран и на регистрации", () => {
    expect(isActive("/login", "/login")).toBe(true);
    expect(isActive("/register", "/login")).toBe(true);
    expect(isActive("/", "/login")).toBe(false);
  });
});
