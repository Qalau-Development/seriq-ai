import os
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import BinaryIO

from fastapi import UploadFile

from app.core.errors import AppError

ALLOWED_EXTENSIONS = (".mp4", ".mov", ".webm")
WEBM_SIGNATURE = bytes.fromhex("1A45DFA3")
CHUNK_SIZE = 1024 * 1024


# write_limited — копирует поток в файл и прерывается при превышении лимита
def write_limited(fd: int, source: BinaryIO, max_bytes: int) -> int:
    size = 0
    with os.fdopen(fd, "wb") as out:
        while chunk := source.read(CHUNK_SIZE):
            size += len(chunk)
            if size > max_bytes:
                raise AppError("file_too_large", 413, f"File exceeds {max_bytes // (1024 * 1024)} MB")
            out.write(chunk)
    return size


# check_signature — сверяет первые байты файла с его расширением
def check_signature(path: Path, ext: str) -> None:
    with path.open("rb") as f:
        head = f.read(12)
    if ext == ".webm":
        valid = head[:4] == WEBM_SIGNATURE
    else:
        valid = head[4:8] == b"ftyp"
    if not valid:
        raise AppError("unsupported_format", 415, "File content does not match the video format")


# temp_upload — сохраняет загрузку во временный файл и удаляет его в finally
@contextmanager
def temp_upload(upload: UploadFile, max_bytes: int) -> Iterator[Path]:
    ext = Path(upload.filename or "").suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise AppError("unsupported_format", 415, "Only .mp4, .mov and .webm are supported")
    fd, name = tempfile.mkstemp(prefix="seriq-", suffix=ext)
    path = Path(name)
    try:
        size = write_limited(fd, upload.file, max_bytes)
        if size == 0:
            raise AppError("empty_file", 400, "The file is empty")
        check_signature(path, ext)
        yield path
    finally:
        path.unlink(missing_ok=True)
