import json

from starlette.types import ASGIApp, Message, Receive, Scope, Send

MIB = 1024 * 1024
# LIMITS — предельный размер тела по началу пути: сессия с 200 попытками и рядами по 1000 значений ≈ 1,3 МиБ, остальное мелкое
LIMITS: list[tuple[str, int]] = [
    ("/api/v1/sessions", 2 * MIB),
    ("/api/v1/auth", MIB),
    ("/api/v1/me", MIB),
    ("/api/v1/progress", MIB),
]
BODY = json.dumps({"status": "error", "error": {"code": "payload_too_large", "message": "The request body is too large"}}).encode()


# limit_for — предельный размер тела для пути или None, если путь не ограничивается здесь
def limit_for(path: str) -> int | None:
    for prefix, limit in LIMITS:
        if path == prefix or path.startswith(prefix + "/"):
            return limit
    return None


# BodyLimitMiddleware — отвечает 413 payload_too_large до разбора тела: по Content-Length сразу, без него по числу прочитанных байт
class BodyLimitMiddleware:
    # __init__ — запоминает следующее приложение
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    # __call__ — проверяет размер тела запроса к ограниченным путям
    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        limit = limit_for(scope["path"]) if scope["type"] == "http" else None
        if limit is None:
            await self.app(scope, receive, send)
            return
        headers = dict(scope["headers"])
        length = headers.get(b"content-length", b"")
        if length.isdigit() and int(length) > limit:
            await self.reject(send)
            return
        state = {"seen": 0, "rejected": False, "started": False}

        # counting_receive — считает прочитанные байты и обрывает чтение при превышении
        async def counting_receive() -> Message:
            message = await receive()
            if message["type"] == "http.request":
                state["seen"] += len(message.get("body", b""))
                if state["seen"] > limit:
                    state["rejected"] = True
                    return {"type": "http.request", "body": b"", "more_body": False}
            return message

        # guarded_send — после превышения подменяет ответ приложения на 413
        async def guarded_send(message: Message) -> None:
            if state["rejected"]:
                if not state["started"]:
                    state["started"] = True
                    await self.reject(send)
                return
            await send(message)

        await self.app(scope, counting_receive, guarded_send)
        if state["rejected"] and not state["started"]:
            await self.reject(send)

    # reject — ответ 413 в едином формате ошибок
    async def reject(self, send: Send) -> None:
        await send({"type": "http.response.start", "status": 413, "headers": [(b"content-type", b"application/json"), (b"content-length", str(len(BODY)).encode())]})
        await send({"type": "http.response.body", "body": BODY})
