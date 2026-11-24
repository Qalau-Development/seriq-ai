import ipaddress
import math
import threading
import time
from collections import deque

from fastapi import Request

from app.core.errors import AppError

clock = time.monotonic
LOGIN_PER_IP = (20, 600)
REGISTER_PER_IP = (5, 3600)


# SlidingWindowLimiter — счётчик обращений за скользящее окно по ключу, в памяти процесса
class SlidingWindowLimiter:
    # __init__ — создаёт пустой счётчик
    def __init__(self) -> None:
        self.hits: dict[str, deque[float]] = {}
        self.lock = threading.Lock()
        self.calls = 0

    # hit — записывает обращение; если лимит исчерпан, не записывает и возвращает секунды ожидания
    def hit(self, key: str, limit: int, window: float) -> int:
        now = clock()
        with self.lock:
            self.calls += 1
            if self.calls % 500 == 0:
                self.purge(now, window)
            queue = self.hits.setdefault(key, deque())
            while queue and now - queue[0] >= window:
                queue.popleft()
            if len(queue) >= limit:
                return max(1, math.ceil(window - (now - queue[0])))
            queue.append(now)
            return 0

    # purge — удаляет ключи, у которых не осталось обращений в окне
    def purge(self, now: float, window: float) -> None:
        for key in [k for k, q in self.hits.items() if not q or now - q[-1] >= window]:
            del self.hits[key]

    # reset — очищает всё (для тестов)
    def reset(self) -> None:
        with self.lock:
            self.hits.clear()


login_limiter = SlidingWindowLimiter()
register_limiter = SlidingWindowLimiter()


# is_private — адрес из частной сети (наши Traefik и Caddy в Docker)
def is_private(value: str) -> bool:
    try:
        return ipaddress.ip_address(value).is_private
    except ValueError:
        return False


# is_ip — строка является IP-адресом
def is_ip(value: str) -> bool:
    try:
        ipaddress.ip_address(value)
        return True
    except ValueError:
        return False


# client_ip — адрес клиента: X-Forwarded-For берётся только если запрос пришёл от нашего прокси (частная сеть); справа налево пропускаются адреса прокси, первый публичный и есть клиент
def client_ip(request: Request) -> str:
    peer = request.client.host if request.client else "unknown"
    forwarded = request.headers.get("x-forwarded-for")
    if not forwarded or not is_private(peer):
        return peer
    for hop in reversed([part.strip() for part in forwarded.split(",")]):
        if not is_ip(hop):
            return peer
        if not is_private(hop):
            return hop
    return peer


# limit_ip — пропускает запрос или отвечает 429 rate_limited с Retry-After
def limit_ip(limiter: SlidingWindowLimiter, request: Request, rule: tuple[int, int]) -> None:
    wait = limiter.hit(client_ip(request), rule[0], rule[1])
    if wait:
        raise rate_limited(wait)


# rate_limited — ошибка 429 с заголовком Retry-After
def rate_limited(seconds: int) -> AppError:
    return AppError("rate_limited", 429, "Too many attempts, retry later", {"Retry-After": str(seconds)})
