import { useSyncExternalStore } from "react";

export const HEALTH_URL = "/api/v1/health";
export const CHECK_INTERVAL_MS = 5 * 60 * 1000;

// hasDatabase — аккаунты доступны, если в ответе /health есть поле database (значение не важно)
export function hasDatabase(body: unknown): boolean {
  return typeof body === "object" && body !== null && "database" in body;
}

// checkAccounts — читает /health: есть поле database — аккаунты есть; нет поля или сервер недоступен — аккаунтов нет
export async function checkAccounts(): Promise<boolean> {
  try {
    const res = await fetch(HEALTH_URL, { signal: AbortSignal.timeout(8000), cache: "no-store" });
    if (!res.ok) return false;
    return hasDatabase(await res.json());
  } catch {
    return false;
  }
}

// createAccountsStore — состояние «аккаунты доступны»: проверка при первой подписке и затем раз в интервал; null, пока ответа нет
export function createAccountsStore(check: () => Promise<boolean>, intervalMs: number = CHECK_INTERVAL_MS) {
  let available: boolean | null = null;
  let timer: ReturnType<typeof setInterval> | null = null;
  const listeners = new Set<() => void>();

  // refresh — запрашивает /health и сообщает подписчикам об изменении
  async function refresh() {
    const next = await check();
    if (next !== available) {
      available = next;
      listeners.forEach((l) => l());
    }
  }

  // subscribe — подписка; первая подписка запускает проверки, последняя отписка их останавливает
  function subscribe(listener: () => void) {
    listeners.add(listener);
    if (listeners.size === 1) {
      void refresh();
      timer = setInterval(() => void refresh(), intervalMs);
    }
    return () => {
      listeners.delete(listener);
      if (listeners.size === 0 && timer !== null) {
        clearInterval(timer);
        timer = null;
      }
    };
  }

  return { subscribe, get: () => available, refresh };
}

const store = createAccountsStore(checkAccounts);

// useAccountsAvailable — true, только если сервер подтвердил аккаунты; пока ответа нет, false
export function useAccountsAvailable(): boolean {
  return useSyncExternalStore(store.subscribe, () => store.get() === true, () => false);
}

// refreshAccounts — внеочередная проверка /health, например после ошибки запроса к аккаунтам
export function refreshAccounts(): Promise<void> {
  return store.refresh();
}
