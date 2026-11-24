import { useSyncExternalStore } from "react";

const API = "/api/v1";
const FLAG_KEY = "seriq.account";
const EARLY_REFRESH_MS = 30000;
const RACE_RETRY_MS = 1500;

export interface AuthUser {
  id: string;
  login: string;
  created_at: string;
}

export type AuthState =
  | { kind: "guest" }
  | { kind: "restoring" }
  | { kind: "in"; user: AuthUser }
  | { kind: "expired" };

// AccountError — ошибка запроса к аккаунтам с кодом из контракта; retryAfter — секунды из Retry-After при rate_limited
export class AccountError extends Error {
  constructor(
    public code: string,
    public httpStatus?: number,
    public retryAfter?: number,
  ) {
    super(code);
  }
}

const GUEST: AuthState = { kind: "guest" };
let state: AuthState = GUEST;
let accessToken: { value: string; expiresAt: number } | null = null;
let refreshing: Promise<void> | null = null;
const listeners = new Set<() => void>();

// setState — меняет состояние входа и сообщает подписчикам
function setState(next: AuthState) {
  state = next;
  listeners.forEach((l) => l());
}

// getAuthState — текущее состояние входа
export function getAuthState(): AuthState {
  return state;
}

// useAuth — состояние входа для компонентов; на сервере всегда гость
export function useAuth(): AuthState {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => state,
    () => GUEST,
  );
}

// currentUser — вошедший пользователь или null
export function currentUser(): AuthUser | null {
  return state.kind === "in" ? state.user : null;
}

// hasAccountFlag — на устройстве уже входили: только тогда при загрузке пробуем обновить вход
export function hasAccountFlag(): boolean {
  try {
    return localStorage.getItem(FLAG_KEY) === "1";
  } catch {
    return false;
  }
}

// setAccountFlag — запоминает или забывает, что на устройстве входили
function setAccountFlag(on: boolean) {
  try {
    if (on) localStorage.setItem(FLAG_KEY, "1");
    else localStorage.removeItem(FLAG_KEY);
  } catch {
    // хранилище недоступно — вход будет только до перезагрузки страницы
  }
}

// readError — разбирает ответ с ошибкой в AccountError
async function readError(res: Response): Promise<AccountError> {
  const body = await res.json().catch(() => null);
  const code = body?.status === "error" && typeof body.error?.code === "string" ? body.error.code : "internal_error";
  const retry = Number(res.headers.get("Retry-After"));
  return new AccountError(code, res.status, Number.isFinite(retry) && retry > 0 ? retry : undefined);
}

// authRequest — запрос к /auth/*: заголовок X-SerIQ-Client: web, refresh-токен только в httpOnly cookie
async function authRequest(path: string, body: unknown): Promise<Response> {
  let res: Response;
  try {
    res = await fetch(`${API}/auth/${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-SerIQ-Client": "web" },
      body: JSON.stringify(body),
    });
  } catch {
    throw new AccountError("network_error");
  }
  if (!res.ok) throw await readError(res);
  return res;
}

// takeTokens — запоминает access-токен в памяти (в хранилище не пишется)
function takeTokens(body: { access_token: string; expires_in: number }) {
  accessToken = { value: body.access_token, expiresAt: Date.now() + body.expires_in * 1000 - EARLY_REFRESH_MS };
}

// signIn — регистрация или вход по логину и паролю
export async function signIn(mode: "login" | "register", login: string, password: string): Promise<AuthUser> {
  const res = await authRequest(mode, { login, password });
  const body = await res.json();
  takeTokens(body);
  setAccountFlag(true);
  setState({ kind: "in", user: body.user });
  return body.user;
}

// refreshOnce — обновляет access-токен по cookie; при гонке вкладок (invalid_token) повторяет один раз
async function refreshOnce(): Promise<void> {
  try {
    takeTokens(await (await authRequest("refresh", {})).json());
  } catch (e) {
    if (e instanceof AccountError && e.code === "invalid_token") {
      await new Promise((r) => setTimeout(r, RACE_RETRY_MS));
      takeTokens(await (await authRequest("refresh", {})).json());
      return;
    }
    throw e;
  }
}

// refreshToken — обновление входа, один запрос на всех; неудача с invalid_token или refresh_reused означает «войдите снова»
export function refreshToken(): Promise<void> {
  refreshing ??= refreshOnce()
    .catch((e) => {
      if (e instanceof AccountError && (e.code === "invalid_token" || e.code === "refresh_reused" || e.code === "token_expired")) {
        accessToken = null;
        setAccountFlag(false);
        setState({ kind: "expired" });
      }
      throw e;
    })
    .finally(() => {
      refreshing = null;
    });
  return refreshing;
}

// restoreSession — при загрузке страницы восстанавливает вход по cookie, если на устройстве уже входили
export async function restoreSession(): Promise<void> {
  if (state.kind !== "guest" || !hasAccountFlag()) return;
  setState({ kind: "restoring" });
  try {
    await refreshToken();
    const res = await accountFetch("/me");
    setState({ kind: "in", user: await res.json() });
  } catch {
    if (getAuthState().kind === "restoring") setState({ kind: "guest" });
  }
}

// accountFetch — запрос с Bearer-токеном: обновляет токен заранее и один раз повторяет запрос при token_expired
export async function accountFetch(path: string, init: RequestInit = {}): Promise<Response> {
  if (!accessToken || accessToken.expiresAt <= Date.now()) await refreshToken();
  for (let attempt = 0; ; attempt++) {
    let res: Response;
    try {
      res = await fetch(`${API}${path}`, {
        ...init,
        headers: { ...(init.headers as Record<string, string>), Authorization: `Bearer ${accessToken?.value ?? ""}` },
      });
    } catch {
      throw new AccountError("network_error");
    }
    if (res.ok) return res;
    const err = await readError(res);
    if (attempt === 0 && (err.code === "token_expired" || err.code === "invalid_token")) {
      await refreshToken();
      continue;
    }
    throw err;
  }
}

// signOut — выход: сервер отзывает цепочку, токен и вход на устройстве забываются
export async function signOut(): Promise<void> {
  try {
    await authRequest("logout", {});
  } catch {
    // выход на устройстве выполняется всегда
  }
  accessToken = null;
  setAccountFlag(false);
  setState({ kind: "guest" });
}

// deleteAccount — удаляет аккаунт и все данные на сервере после подтверждения паролем
export async function deleteAccount(password: string): Promise<void> {
  await accountFetch("/me", {
    method: "DELETE",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ password }),
  });
  accessToken = null;
  setAccountFlag(false);
  setState({ kind: "guest" });
}

// waitText — время ожидания из Retry-After словами: секунды или минуты
export function waitText(seconds: number | undefined, t: { wait_seconds: string; wait_minutes: string }): string {
  const s = Math.max(1, Math.round(seconds ?? 60));
  return s < 60 ? t.wait_seconds.replace("{n}", String(s)) : t.wait_minutes.replace("{n}", String(Math.ceil(s / 60)));
}

// validLogin — логин 3–32 символа: латиница, цифры, точка, подчёркивание, дефис
export function validLogin(login: string): boolean {
  return /^[A-Za-z0-9._-]{3,32}$/.test(login);
}

// validPassword — пароль 10–128 символов и без логина внутри (регистр не важен)
export function validPassword(password: string, login: string): boolean {
  return password.length >= 10 && password.length <= 128 && !password.toLowerCase().includes(login.toLowerCase());
}
