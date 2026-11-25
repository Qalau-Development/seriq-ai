import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/voice_items.dart';
import 'speech.dart';

// voiceBase — единственный источник записанных клипов озвучки; других внешних адресов нет
const voiceBase = 'https://seriq-ai.qalau.com/voice';

// pauseBetweenClips — пауза между фрагментами озвучки, как на сайте
const pauseBetweenClips = Duration(milliseconds: 250);

// Manifest — список клипов озвучки: id → язык → относительный путь файла
class Manifest {
  final int v;
  final Map<String, Map<String, String>> clips;

  const Manifest(this.v, this.clips);
}

// parseManifest — проверяет форму манифеста; всё лишнее считается его отсутствием
Manifest? parseManifest(Object? data) {
  if (data is! Map) return null;
  final v = data['v'];
  final clips = data['clips'];
  if (v != 1 || clips is! Map) return null;
  final out = <String, Map<String, String>>{};
  clips.forEach((id, langs) {
    if (id is String && langs is Map) {
      out[id] = {
        for (final e in langs.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      };
    }
  });
  return Manifest(1, out);
}

// clipAvailable — есть ли в манифесте хотя бы один клип из списка на языке
bool clipAvailable(Manifest? manifest, List<VoiceItem> items, String lang) {
  if (manifest == null) return false;
  return items.any((i) => manifest.clips[i.id]?[lang] != null);
}

// VoiceCache — клипы по требованию с кэшем на устройстве: скачивает один раз, дальше отдаёт локальный файл
class VoiceCache {
  final http.Client client;
  final Future<Directory> Function() _dirProvider;

  VoiceCache({http.Client? client, Future<Directory> Function()? dirProvider})
    : client = client ?? http.Client(),
      _dirProvider = dirProvider ?? _defaultDir;

  // _defaultDir — папка кэша в постоянном хранилище приложения
  static Future<Directory> _defaultDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/voice_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // _fileFor — локальный файл для относительного пути клипа
  Future<File> _fileFor(String relativePath) async {
    final dir = await _dirProvider();
    final safe = relativePath.replaceAll('/', '__');
    return File('${dir.path}/$safe');
  }

  // fetch — путь к файлу клипа на устройстве; из кэша, а если его там нет — скачивает и сохраняет; null при любой ошибке
  Future<String?> fetch(String relativePath) async {
    final file = await _fileFor(relativePath);
    if (await file.exists()) return file.path;
    try {
      final res = await client
          .get(Uri.parse('$voiceBase/$relativePath'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      await file.writeAsBytes(res.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

// VoiceEnv — что нужно плееру: манифест, файл клипа, воспроизведение, запасной голос
abstract class VoiceEnv {
  Future<Manifest?> fetchManifest();
  Future<String?> fetchClip(String relativePath);
  Future<bool> playFile(String path);
  Future<void> stopPlayback();
  Future<void> speak(String text, String lang);
  Future<void> stopSpeak();
  Future<void> wait(Duration d);
}

// RealVoiceEnv — настоящее окружение: HTTP-манифест, just_audio, flutter_tts
class RealVoiceEnv implements VoiceEnv {
  final VoiceCache cache;
  final http.Client _client;
  final AudioPlayer _player = AudioPlayer();

  RealVoiceEnv({VoiceCache? cache, http.Client? client})
    : cache = cache ?? VoiceCache(),
      _client = client ?? http.Client();

  @override
  Future<Manifest?> fetchManifest() async {
    try {
      final res = await _client
          .get(Uri.parse('$voiceBase/manifest.json'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return parseManifest(jsonDecode(utf8.decode(res.bodyBytes)));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> fetchClip(String relativePath) => cache.fetch(relativePath);

  @override
  Future<bool> playFile(String path) async {
    try {
      await _player.setFilePath(path);
      final done = _player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.completed || s == ProcessingState.idle,
      );
      await _player.play();
      final state = await done;
      return state == ProcessingState.completed;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
    } catch (_) {
      // плеер уже остановлен или недоступен
    }
  }

  @override
  Future<void> speak(String text, String lang) async {
    if (!await speechEngine.isAvailable(lang)) return;
    final completer = Completer<void>();
    await speechEngine.speak(text, lang, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  @override
  Future<void> stopSpeak() => speechEngine.stop();

  @override
  Future<void> wait(Duration d) => Future<void>.delayed(d);
}

// VoicePlayer — играет заранее записанные клипы по очереди; для фрагмента без клипа или с ошибкой читает текст голосом устройства
class VoicePlayer extends ChangeNotifier {
  final VoiceEnv env;
  Manifest? _manifest;
  Future<Manifest?>? _loading;
  int _gen = 0;
  bool _playing = false;

  VoicePlayer(this.env);

  Manifest? get manifest => _manifest;
  bool get isPlaying => _playing;

  // load — загружает манифест один раз; при ошибке дальше работает только запасной голос
  Future<Manifest?> load() {
    _loading ??= env
        .fetchManifest()
        .then((m) {
          _manifest = m;
          notifyListeners();
          return m;
        })
        .catchError((_) {
          _manifest = null;
          notifyListeners();
          return null;
        });
    return _loading!;
  }

  // clipAvailable — есть ли в манифесте хотя бы один клип из списка на языке
  bool hasClip(List<VoiceItem> items, String lang) =>
      clipAvailable(_manifest, items, lang);

  // stop — останавливает клипы и запасной голос; продолжение прежнего playClips не происходит
  Future<void> stop() async {
    _gen++;
    _playing = false;
    await env.stopPlayback();
    await env.stopSpeak();
  }

  // playClips — играет фрагменты по очереди с паузой; новый вызов прерывает предыдущий. gen захватывается сразу, до ожиданий: иначе более поздний параллельный вызов успеет сам себя сделать «текущим» раньше, чем этот дочитает своё gen
  Future<void> playClips(
    List<VoiceItem> items,
    String lang, {
    VoidCallback? onEnd,
  }) async {
    final gen = ++_gen;
    _playing = false;
    await env.stopPlayback();
    await env.stopSpeak();
    if (gen != _gen) return;
    if (items.isEmpty) {
      onEnd?.call();
      return;
    }
    _playing = true;
    await load();
    if (gen != _gen) return;
    await _step(items, 0, lang, gen, onEnd);
  }

  // _step — один фрагмент: клип из манифеста, а без него или при ошибке — запасной голос; затем пауза и следующий
  Future<void> _step(
    List<VoiceItem> items,
    int i,
    String lang,
    int gen,
    VoidCallback? onEnd,
  ) async {
    if (gen != _gen) return;
    final item = items[i];
    final rel = _manifest?.clips[item.id]?[lang];
    var played = false;
    if (rel != null) {
      final local = await env.fetchClip(rel);
      if (gen != _gen) return;
      if (local != null) played = await env.playFile(local);
    }
    if (gen != _gen) return;
    if (!played) {
      await env.speak(item.text, lang);
      if (gen != _gen) return;
    }
    if (i + 1 >= items.length) {
      _playing = false;
      onEnd?.call();
      return;
    }
    await env.wait(pauseBetweenClips);
    if (gen != _gen) return;
    await _step(items, i + 1, lang, gen, onEnd);
  }
}

// voicePlayer — озвучка приложения записанными клипами с запасным голосом устройства
VoicePlayer voicePlayer = VoicePlayer(RealVoiceEnv());
