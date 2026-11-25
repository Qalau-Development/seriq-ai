#!/usr/bin/env bash
# fetch_models — скачивает модели синтеза речи в infrastructure/tts/models: Silero v5_ru и ISSAI KazakhTTS female1
set -euo pipefail

dir="${SERIQ_TTS_MODELS:-$(cd "$(dirname "$0")" && pwd)/models}"
issai="https://issai.nu.edu.kz/wp-content/uploads/2022/03"
mkdir -p "$dir"
cd "$dir"

[ -f v5_ru.pt ] || curl -fL -o v5_ru.pt https://models.silero.ai/models/tts/ru/v5_ru.pt
for name in kaztts_female1_tacotron2_train.loss.ave parallelwavegan_female1_checkpoint; do
  if [ ! -d "$name" ]; then
    curl -fL -o "$name.zip" "$issai/$name.zip"
    unzip -q "$name.zip" -d "$name"
    rm "$name.zip"
  fi
done
echo "models in $dir"
