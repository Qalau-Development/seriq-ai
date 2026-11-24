import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AccountError } from "@/lib/auth";
import type { LocalSession } from "@/lib/history";

const put = vi.fn();
vi.mock("@/lib/serverHistory", () => ({ putSession: (s: LocalSession) => put(s) }));
vi.mock("@/lib/auth", async (orig) => ({ ...(await orig<typeof import("@/lib/auth")>()), currentUser: () => ({ id: "u1", login: "test_u", created_at: "" }) }));

const store = new Map<string, string>();
const sessions = (): LocalSession[] => JSON.parse(store.get("seriq.sessions.v1") ?? "[]");

describe("syncNow при пределе истории", () => {
  beforeEach(() => {
    store.clear();
    put.mockReset();
    vi.stubGlobal("localStorage", { getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => void store.set(k, v), removeItem: (k: string) => void store.delete(k) });
    vi.stubGlobal("window", { dispatchEvent: () => true });
    const s: LocalSession = {
      id: "s1",
      exercise: "E04",
      started_at: "2026-11-25T08:41:03Z",
      owner: "u1",
      synced: false,
      attempts: [{ analysis_id: "a1", at: "2026-11-25T08:42:10Z", verdict: "completed", label: "complete", confidence: 0.9, source: "model" }],
    };
    store.set("seriq.sessions.v1", JSON.stringify([s]));
  });
  afterEach(() => vi.unstubAllGlobals());

  it("quota_exceeded: состояние quota, занятие не помечено отклонённым; после удаления старых занятий отправка возобновляется", async () => {
    const { syncNow, getSyncStatus } = await import("@/lib/syncRuntime");
    put.mockRejectedValueOnce(new AccountError("quota_exceeded", 413));
    await syncNow();
    expect(getSyncStatus()).toBe("quota");
    expect(sessions()[0].sync_failed).toBeUndefined();
    expect(sessions()[0].synced).toBe(false);

    put.mockResolvedValue(undefined);
    await syncNow();
    expect(getSyncStatus()).toBe("ok");
    expect(sessions()[0].synced).toBe(true);
    expect(put).toHaveBeenCalledTimes(2);

    await syncNow();
    expect(put).toHaveBeenCalledTimes(2);
  });
});

describe("syncNow и mock-повторения", () => {
  beforeEach(() => {
    store.clear();
    put.mockReset();
    put.mockResolvedValue(undefined);
    vi.stubGlobal("localStorage", { getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => void store.set(k, v), removeItem: (k: string) => void store.delete(k) });
    vi.stubGlobal("window", { dispatchEvent: () => true });
  });
  afterEach(() => vi.unstubAllGlobals());

  const at = (id: string, source: "mock" | "model") => ({ analysis_id: id, at: "2026-11-25T08:42:10Z", verdict: "completed" as const, label: "complete" as const, confidence: 0.9, source });

  it("занятие из одних mock не отправляется, смешанное уходит только с настоящими повторениями", async () => {
    const { syncNow } = await import("@/lib/syncRuntime");
    const base = { exercise: "E04" as const, started_at: "2026-11-25T08:41:03Z", owner: "u1", synced: false };
    store.set("seriq.sessions.v1", JSON.stringify([
      { ...base, id: "only-mock", attempts: [at("m1", "mock")] },
      { ...base, id: "mixed", attempts: [at("r1", "model"), at("m2", "mock")] },
    ]));
    await syncNow();
    expect(put).toHaveBeenCalledTimes(1);
    expect(put.mock.calls[0][0].id).toBe("mixed");
    const saved = sessions();
    expect(saved.find((s) => s.id === "only-mock")?.synced).toBe(false);
    expect(saved.find((s) => s.id === "mixed")?.synced).toBe(true);
    expect(saved.find((s) => s.id === "mixed")?.attempts).toHaveLength(2);
  });
});
