import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { checkAccounts, createAccountsStore, hasDatabase } from "@/lib/accounts";

describe("hasDatabase", () => {
  it("поле database есть — аккаунты доступны", () => {
    expect(hasDatabase({ status: "ok", mode: "model", version: "0.1.0", database: "ok" })).toBe(true);
    expect(hasDatabase({ status: "ok", database: "unavailable" })).toBe(true);
  });
  it("поля нет или ответ не объект — аккаунтов нет", () => {
    expect(hasDatabase({ status: "ok", mode: "model", version: "0.1.0" })).toBe(false);
    expect(hasDatabase(null)).toBe(false);
    expect(hasDatabase("ok")).toBe(false);
    expect(hasDatabase(undefined)).toBe(false);
  });
});

describe("checkAccounts", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("с database в /health — true", async () => {
    vi.stubGlobal("fetch", async () => new Response(JSON.stringify({ status: "ok", database: "ok" })));
    expect(await checkAccounts()).toBe(true);
  });
  it("без database в /health — false", async () => {
    vi.stubGlobal("fetch", async () => new Response(JSON.stringify({ status: "ok", mode: "mock", version: "0.1.0" })));
    expect(await checkAccounts()).toBe(false);
  });
  it("/health недоступен или не JSON — false", async () => {
    vi.stubGlobal("fetch", async () => {
      throw new Error("offline");
    });
    expect(await checkAccounts()).toBe(false);
    vi.stubGlobal("fetch", async () => new Response("не json", { status: 200 }));
    expect(await checkAccounts()).toBe(false);
    vi.stubGlobal("fetch", async () => new Response("{}", { status: 503 }));
    expect(await checkAccounts()).toBe(false);
  });
});

describe("createAccountsStore", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("проверяет при первой подписке и затем раз в интервал, на последней отписке останавливается", async () => {
    const check = vi.fn(async () => true);
    const store = createAccountsStore(check, 1000);
    expect(store.get()).toBeNull();
    const off = store.subscribe(() => {});
    await vi.advanceTimersByTimeAsync(0);
    expect(store.get()).toBe(true);
    expect(check).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(3000);
    expect(check).toHaveBeenCalledTimes(4);
    off();
    await vi.advanceTimersByTimeAsync(5000);
    expect(check).toHaveBeenCalledTimes(4);
  });

  it("состояние меняется, когда сервер включил или выключил аккаунты, подписчик получает уведомление", async () => {
    let answer = false;
    const store = createAccountsStore(async () => answer, 1000);
    const listener = vi.fn();
    store.subscribe(listener);
    await vi.advanceTimersByTimeAsync(0);
    expect(store.get()).toBe(false);
    answer = true;
    await vi.advanceTimersByTimeAsync(1000);
    expect(store.get()).toBe(true);
    answer = false;
    await vi.advanceTimersByTimeAsync(1000);
    expect(store.get()).toBe(false);
    expect(listener).toHaveBeenCalledTimes(3);
  });
});
