import os
from dataclasses import dataclass

API_VERSION = "0.1.0"
MODES = ("mock", "model")


# Settings — настройки бэкенда из переменных SERIQ_*
@dataclass(frozen=True)
class Settings:
    mode: str
    max_upload_mb: int
    model_path: str

    # max_upload_bytes — лимит загрузки в байтах
    @property
    def max_upload_bytes(self) -> int:
        return self.max_upload_mb * 1024 * 1024


# get_settings — читает настройки из окружения и проверяет их
def get_settings() -> Settings:
    mode = os.environ.get("SERIQ_MODE", "mock")
    if mode not in MODES:
        raise ValueError(f"SERIQ_MODE must be one of {MODES}, got {mode!r}")
    return Settings(
        mode=mode,
        max_upload_mb=int(os.environ.get("SERIQ_MAX_UPLOAD_MB", "100")),
        model_path=os.environ.get("SERIQ_MODEL_PATH", "/srv/models/e02_classifier.joblib"),
    )
