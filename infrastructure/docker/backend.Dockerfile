FROM python:3.12-slim

LABEL project=seriq-ai

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# системные библиотеки для OpenCV и MediaPipe
RUN apt-get update \
 && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv
COPY backend/requirements.txt backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

# ai-engine ставится сам, как только в нём появляется pyproject.toml
COPY ai-engine ai-engine
RUN if [ -f ai-engine/pyproject.toml ]; then pip install --no-cache-dir ./ai-engine; fi
COPY models models

COPY backend backend
WORKDIR /srv/backend
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
