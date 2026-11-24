# AppError — ожидаемая ошибка API с кодом из api.md
class AppError(Exception):
    # __init__ — сохраняет код, HTTP-статус и сообщение
    def __init__(self, code: str, http_status: int, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.http_status = http_status
        self.message = message
