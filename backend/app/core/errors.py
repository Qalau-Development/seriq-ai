# AppError — ожидаемая ошибка API с кодом из api.md
class AppError(Exception):
    # __init__ — сохраняет код, HTTP-статус, сообщение и необязательные заголовки ответа
    def __init__(self, code: str, http_status: int, message: str, headers: dict[str, str] | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.http_status = http_status
        self.message = message
        self.headers = headers
