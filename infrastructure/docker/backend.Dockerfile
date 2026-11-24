FROM python:3.12-slim

LABEL project=seriq-ai

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# системные библиотеки для OpenCV и MediaPipe (libEGL и libGLESv2 нужны HandLandmarker даже на CPU)
RUN apt-get update \
 && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 libegl1 libgles2 \
 && rm -rf /var/lib/apt/lists/*

# веса MediaPipe Hand Landmarker версии 1, сборка падает при несовпадении контрольной суммы
ARG HAND_MODEL_URL=https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task
ARG HAND_MODEL_SHA256=fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1
RUN mkdir -p /srv/models \
 && python -c "import sys, urllib.request; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])" "$HAND_MODEL_URL" /srv/models/hand_landmarker.task \
 && echo "$HAND_MODEL_SHA256  /srv/models/hand_landmarker.task" | sha256sum -c -
ENV SERIQ_HAND_MODEL_PATH=/srv/models/hand_landmarker.task

WORKDIR /srv
COPY backend/requirements.txt backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

# ai-engine ставится сам, как только в нём появляется pyproject.toml
COPY ai-engine ai-engine
RUN if [ -f ai-engine/pyproject.toml ]; then pip install --no-cache-dir ./ai-engine; fi
COPY models models

# MediaPipe и модель должны запускаться в образе, иначе сборка падает
RUN if [ -f ai-engine/pyproject.toml ] && [ -f models/e02_classifier.joblib ]; then python -c "from seriq_engine.pipeline import warmup; print(warmup())"; fi

COPY backend backend
WORKDIR /srv/backend
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
