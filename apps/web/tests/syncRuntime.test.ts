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
