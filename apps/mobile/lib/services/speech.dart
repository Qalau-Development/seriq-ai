import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// speechLocales — языки голоса для языков интерфейса
const speechLocales = {'ru': 'ru-RU', 'kk': 'kk-KZ', 'en': 'en-US'};

// cleanText — убирает двойные точки на стыках предложений
String cleanText(String text) =>
    text.replaceAllMapped(RegExp(r'([.!?…])\s*\.+'), (m) => m[1]!);

// SpeechEngine — озвучивание текста системным голосом
abstract class SpeechEngine {
  Future<bool> isAvailable(String lang);
  Future<void> speak(String text, String lang, VoidCallback onEnd);
  Future<void> stop();
}

// FlutterTtsEngine — системный синтезатор речи iOS и Android
class FlutterTtsEngine implements SpeechEngine {
  final _tts = FlutterTts();
  VoidCallback? _onEnd;

  FlutterTtsEngine() {
    void end() {
      final cb = _onEnd;
      _onEnd = null;
      cb?.call();
    }

    _tts.setCompletionHandler(end);
    _tts.setCancelHandler(end);
    _tts.setErrorHandler((_) => end());
  }

  @override
  Future<bool> isAvailable(String lang) async {
    try {
      final r = await _tts.isLanguageAvailable(speechLocales[lang] ?? 'ru-RU');
      return r == true || r == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> speak(String text, String lang, VoidCallback onEnd) async {
    await _tts.stop();
    _onEnd = onEnd;
    await _tts.setLanguage(speechLocales[lang] ?? 'ru-RU');
    await _tts.speak(cleanText(text));
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // синтезатор недоступен — останавливать нечего
    }
  }
}

// speechEngine — озвучивание приложения
SpeechEngine speechEngine = FlutterTtsEngine();
