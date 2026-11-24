import { describe, expect, it } from "vitest";
import { AccountError } from "@/lib/auth";
import type { LocalSession } from "@/lib/history";
import { cleanupOnLogout, flushPending, migratableCount, pendingSessions, planMigration, toServerAttempt, toServerBody, type ServerSessionBody } from "@/lib/sync";

const attempt = (id: string, extra = {}) => ({
  analysis_id: id,
  at: "2026-11-25T08:42:10Z",
  verdict: "completed" as const,
  label: "complete" as const,
  confidence: 0.87,
  source: "model" as const,
  ...extra,
});
const session = (id: string, extra: Partial<LocalSession> = {}): LocalSession => ({
  id,
  exercise: "E04",
  started_at: "2026-11-25T08:41:03Z",
  attempts: [attempt(id + "-a")],
  owner: "u1",
  ...extra,
});

describe("pendingSessions", () => {
  it("только занятия этого пользователя, ещё не отправленные и не отклонённые сервером", () => {
    const list = [
      session("a"),
      session("b", { synced: true }),
      session("c", { owner: "u2" }),
      session("d", { owner: undefined }),
      session("e", { sync_failed: "invalid_request" }),
      session("f", { attempts: [] }),
      session("g", { synced: false }),
    ];
    expect(pendingSessions(list, "u1").map((s) => s.id)).toEqual(["a", "g"]);
  });
});

describe("toServerBody", () => {
  it("формат контракта: exercise, started_at и повторения с model_version и measure", () => {
    const measure = { name: "hand_openness" as const, unit: "percent" as const, value: 150, series: { fps: 10, values: [100, 150] } };
    const body = toServerBody(session("a", { attempts: [attempt("x1", { model_version: "e04-logreg2-1", measure })] }));
    expect(body).toEqual({
      exercise: "E04",
      started_at: "2026-11-25T08:41:03Z",
      attempts: [{ analysis_id: "x1", at: "2026-11-25T08:42:10Z", source: "model", model_version: "e04-logreg2-1", verdict: "completed", label: "complete", confidence: 0.87, measure }],
    });
  });
  it("у старых повторений без версии модели: unknown; без measure поля нет", () => {
    const body = toServerBody(session("a", { attempts: [attempt("m2")] }));
    expect(body.attempts.map((a) => a.model_version)).toEqual(["unknown"]);
    expect("measure" in body.attempts[0]).toBe(false);
    expect(toServerAttempt(attempt("m3", { model_version: "e02-logreg2-1" })).model_version).toBe("e02-logreg2-1");
  });
});

describe("flushPending", () => {
  it("отправляет всё по очереди и сообщает, что ушло", async () => {
    const sent: [string, ServerSessionBody][] = [];
    const r = await flushPending([session("a"), session("b")], async (id, body) => void sent.push([id, body]));
    expect(r).toEqual({ sent: ["a", "b"], dropped: [], stopped: null });
    expect(sent.map(([id]) => id)).toEqual(["a", "b"]);
  });

  it("повтор: после обрыва сети отправка останавливается, следующая попытка досылает оставшееся", async () => {
    const calls: string[] = [];
    let online = false;
    const put = async (id: string) => {
      calls.push(id);
      if (!online) throw new AccountError("network_error");
    };
    const all = [session("a"), session("b")];
    expect(await flushPending(all, put)).toEqual({ sent: [], dropped: [], stopped: "network" });
    expect(calls).toEqual(["a"]);
    online = true;
    expect((await flushPending(all, put)).sent).toEqual(["a", "b"]);
  });

  it("идемпотентность: пока занятие не отмечено отправленным, повтор шлёт то же тело; после отметки очередь пуста", async () => {
    const bodies: ServerSessionBody[] = [];
    const put = async (_id: string, body: ServerSessionBody) => void bodies.push(body);
    const s = session("a");
    await flushPending([s], put);
    await flushPending([s], put);
    expect(bodies[0]).toEqual(bodies[1]);
    expect(pendingSessions([{ ...s, synced: true }], "u1")).toEqual([]);
  });

  it("истёкший вход останавливает отправку с причиной auth", async () => {
    for (const code of ["invalid_token", "token_expired", "refresh_reused"]) {
      const r = await flushPending([session("a"), session("b")], async () => {
        throw new AccountError(code, 401);
      });
      expect(r).toEqual({ sent: [], dropped: [], stopped: "auth" });
    }
  });

  it("ошибка сервера и rate_limited останавливают отправку, занятия остаются в очереди", async () => {
    for (const code of ["internal_error", "rate_limited", "busy"]) {
      const r = await flushPending([session("a")], async () => {
        throw new AccountError(code, 500);
      });
      expect(r).toEqual({ sent: [], dropped: [], stopped: "server" });
    }
  });

  it("занятие, которое сервер отклонил (400, 409, 413), отмечается и не мешает остальным", async () => {
    const put = async (id: string) => {
      if (id === "bad") throw new AccountError("id_conflict", 409);
    };
    const r = await flushPending([session("bad"), session("good")], put);
    expect(r).toEqual({ sent: ["good"], dropped: [{ id: "bad", code: "id_conflict" }], stopped: null });
  });

  it("quota_exceeded: отправка останавливается, занятие не отклоняется и остаётся в очереди", async () => {
    const list = [session("a"), session("b")];
    const r = await flushPending(list, async () => {
      throw new AccountError("quota_exceeded", 413);
    });
    expect(r).toEqual({ sent: [], dropped: [], stopped: "quota" });
    expect(pendingSessions(list, "u1").map((s) => s.id)).toEqual(["a", "b"]);
  });

  it("после освобождения места тот же flush досылает занятия", async () => {
    let full = true;
    const put = async () => {
      if (full) throw new AccountError("quota_exceeded", 413);
    };
    const list = [session("a"), session("b")];
    expect((await flushPending(list, put)).stopped).toBe("quota");
    full = false;
    expect(await flushPending(list, put)).toEqual({ sent: ["a", "b"], dropped: [], stopped: null });
  });

  it("payload_too_large, в отличие от quota_exceeded, отклоняет только это занятие", async () => {
    const r = await flushPending([session("big"), session("ok")], async (id) => {
      if (id === "big") throw new AccountError("payload_too_large", 413);
    });
    expect(r).toEqual({ sent: ["ok"], dropped: [{ id: "big", code: "payload_too_large" }], stopped: null });
  });

  it("пустая очередь ничего не шлёт", async () => {
    let calls = 0;
    expect(await flushPending([], async () => void calls++)).toEqual({ sent: [], dropped: [], stopped: null });
    expect(calls).toBe(0);
  });
});

describe("перенос гостевой истории без тестовых данных", () => {
  const guest = (id: string, sources: ("mock" | "model")[]): LocalSession =>
    session(id, { owner: undefined, attempts: sources.map((src, i) => attempt(`${id}-${i}`, { source: src })) });

  it("считаются только занятия, где есть настоящее повторение", () => {
    expect(migratableCount([guest("a", ["model"]), guest("b", ["mock"]), guest("c", ["mock", "model"]), guest("d", ["mock", "mock"])])).toBe(2);
    expect(migratableCount([])).toBe(0);
  });

  it("занятие только из mock остаётся на устройстве и в аккаунт не уходит", () => {
    const only = guest("m", ["mock", "mock"]);
    const plan = planMigration([only], () => "new");
    expect(plan.migrate).toEqual([]);
    expect(plan.keepGuest).toEqual([only]);
  });

  it("смешанное занятие: настоящие повторения уходят, mock остаётся гостевым занятием с новым id", () => {
    const mixed = guest("x", ["model", "mock", "model"]);
    const plan = planMigration([mixed], () => "new-id");
    expect(plan.migrate).toHaveLength(1);
    expect(plan.migrate[0].id).toBe("x");
    expect(plan.migrate[0].attempts.map((a) => a.source)).toEqual(["model", "model"]);
    expect(plan.keepGuest).toHaveLength(1);
    expect(plan.keepGuest[0].id).toBe("new-id");
    expect(plan.keepGuest[0].attempts.map((a) => a.source)).toEqual(["mock"]);
  });

  it("в тело PUT попадают только настоящие повторения", () => {
    const plan = planMigration([guest("x", ["mock", "model"])], () => "n");
    expect(toServerBody(plan.migrate[0]).attempts.map((a) => a.source)).toEqual(["model"]);
  });
});

describe("mock-повторения никогда не уходят на сервер", () => {
  const mixed = (id: string, extra: Partial<LocalSession> = {}) =>
    session(id, { attempts: [attempt(id + "-r1"), attempt(id + "-m1", { source: "mock" }), attempt(id + "-r2")], ...extra });
  const mockOnly = (id: string, extra: Partial<LocalSession> = {}) =>
    session(id, { attempts: [attempt(id + "-m1", { source: "mock" }), attempt(id + "-m2", { source: "mock" })], ...extra });

  it("в теле PUT только настоящие повторения", () => {
    expect(toServerBody(mixed("a")).attempts.map((a) => a.analysis_id)).toEqual(["a-r1", "a-r2"]);
    expect(toServerBody(mixed("a")).attempts.every((a) => a.source === "model")).toBe(true);
  });

  it("занятие из одних mock-повторений не попадает в очередь отправки вовсе", () => {
    expect(pendingSessions([mockOnly("m"), mixed("x"), session("r")], "u1").map((s) => s.id)).toEqual(["x", "r"]);
  });

  it("flushPending по очереди без настоящих занятий ничего не шлёт", async () => {
    let calls = 0;
    const pending = pendingSessions([mockOnly("m1"), mockOnly("m2")], "u1");
    expect(await flushPending(pending, async () => void calls++)).toEqual({ sent: [], dropped: [], stopped: null });
    expect(calls).toBe(0);
  });

  it("при выходе: mock-занятие становится гостевым, сохранённое на сервере убирается, его mock-повторения остаются гостевым занятием", () => {
    const out = cleanupOnLogout(
      [mockOnly("m"), mixed("x", { synced: true }), session("done", { synced: true }), session("pending"), session("other", { owner: "u2" })],
      "u1",
      () => "new-id",
    );
    expect(out.find((s) => s.id === "m")).toMatchObject({ owner: undefined, synced: undefined });
    expect(out.find((s) => s.id === "x")).toBeUndefined();
    expect(out.find((s) => s.id === "new-id")?.attempts.map((a) => a.source)).toEqual(["mock"]);
    expect(out.find((s) => s.id === "new-id")?.owner).toBeUndefined();
    expect(out.find((s) => s.id === "done")).toBeUndefined();
    expect(out.map((s) => s.id)).toContain("pending");
    expect(out.map((s) => s.id)).toContain("other");
  });
});
