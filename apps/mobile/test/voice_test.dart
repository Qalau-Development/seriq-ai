import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:seriq_mobile/core/exercises.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/core/voice_items.dart';
import 'package:seriq_mobile/models/analysis_result.dart';
import 'package:seriq_mobile/services/speech.dart';
import 'package:seriq_mobile/services/voice.dart';
import 'package:seriq_mobile/widgets/speak_button.dart';

// fakeResult — ответ для упражнения с заданными measure и меткой цикла
AnalysisResult fakeResult(
  String exercise,
  String name,
  String unit,
  double? value, {
  String label = 'complete',
}) {
  final json =
      jsonDecode(File('../../docs/api-examples/analysis-complete.json').readAsStringSync())
          as Map<String, dynamic>;
  json['exercise'] = exercise;
  json['measure'] = {
    'name': name,
    'unit': unit,
    'value': value,
    'series': {'fps': 10, 'values': [value]},
  };
  (json['cycles'] as List).first['label'] = label;
  return AnalysisResult.fromJson(json);
}

// FakeSpeech — подставной запасной голос: какие языки есть и что прочитано
class FakeSpeech implements SpeechEngine {
  final Set<String> langs;
  final spoken = <(String, String)>[];
  int stops = 0;
  VoidCallback? _end;

  FakeSpeech(this.langs);

  @override
  Future<bool> isAvailable(String lang) async => langs.contains(lang);

  @override
  Future<void> speak(String text, String lang, VoidCallback onEnd) async {
    spoken.add((lang, text));
    _end = onEnd;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  // finish — синтезатор дочитал
  void finish() => _end?.call();
}

// FakeVoiceEnv — подставное окружение плеера: без сети и без настоящего звука
class FakeVoiceEnv implements VoiceEnv {
  Manifest? manifest;
  final Map<String, String> files = {};
  final List<String> fetchClipCalls = [];
  final List<String> playFileCalls = [];
  final List<(String, String)> spoken = [];
  final List<String> order = [];
  final List<Duration> waits = [];
  int stopPlaybackCalls = 0;
  int stopSpeakCalls = 0;
  Future<bool> Function(String path)? onPlay;

  @override
  Future<Manifest?> fetchManifest() async => manifest;

  @override
  Future<String?> fetchClip(String relativePath) async {
    fetchClipCalls.add(relativePath);
    return files[relativePath];
  }

  @override
  Future<bool> playFile(String path) async {
    playFileCalls.add(path);
    order.add('play:$path');
    return onPlay != null ? await onPlay!(path) : true;
  }

  @override
  Future<void> stopPlayback() async => stopPlaybackCalls++;

  @override
  Future<void> speak(String text, String lang) async {
    spoken.add((lang, text));
    order.add('speak:$text');
  }

  @override
  Future<void> stopSpeak() async => stopSpeakCalls++;

  @override
  Future<void> wait(Duration d) async => waits.add(d);
}

void main() {
  setUp(() => appLang.value = 'ru');

  group('сборка id клипов: инструкция', () {
    test('по порядку: название, шаги, «Как снимать», советы; id равен ключу словаря', () {
      for (final def in exercises) {
        final items = instructionItems(def);
        expect(items.map((i) => i.id), [
          def.titleKey,
          ...def.stepKeys,
          'tips_title',
          ...def.tipKeys,
        ]);
        expect(items.every((i) => i.text.isNotEmpty), isTrue);
      }
      expect(instructionItems(exerciseDef('E04')).map((i) => i.id), [
        'exercise_e04_title',
        'e04_step_1',
        'e04_step_2',
        'e04_step_3',
        'e04_step_4',
        'tips_title',
        'e04_tip_1',
        'e04_tip_2',
        'tip_3',
        'tip_4',
      ]);
    });

    test('текст запасного голоса берётся на языке интерфейса', () {
      appLang.value = 'en';
      expect(instructionItems(exerciseDef('E02'))[0].text, Strings.en['exercise_e02_title']);
      appLang.value = 'kk';
      expect(instructionItems(exerciseDef('E02'))[0].text, Strings.kk['exercise_e02_title']);
    });
  });

  group('сборка id клипов: заголовок результата', () {
    test('E02: result_title_{метка}, остальные: verdict_completed или verdict_check_instructions', () {
      for (final label in ['complete', 'incomplete', 'uncertain']) {
        expect(
          resultVoiceParts(fakeResult('E02', 'elbow_angle', 'deg', 1, label: label), label).title.id,
          'result_title_$label',
        );
        for (final ex in ['E01', 'E03', 'E04']) {
          expect(
            resultVoiceParts(fakeResult(ex, 'elbow_angle', 'deg', 1, label: label), label).title.id,
            label == 'complete' ? 'verdict_completed' : 'verdict_check_instructions',
          );
        }
      }
    });
  });

  group('сборка id клипов: строки с числом', () {
    test('E02: result_line_{метка}__{максимум угла}, текст как на экране', () {
      for (final label in ['complete', 'incomplete', 'uncertain']) {
        final r = fakeResult('E02', 'elbow_angle', 'deg', 123.4, label: label);
        final lines = resultVoiceParts(r, label).lines;
        expect(lines, hasLength(1));
        expect(lines[0].id, 'result_line_${label}__123');
        expect(lines[0].text, contains('123'));
      }
    });

    test('E02: значение вне 0–180 прижимается, текст остаётся показанным', () {
      expect(
        resultVoiceParts(fakeResult('E02', 'elbow_angle', 'deg', 191), 'complete').lines[0].id,
        'result_line_complete__180',
      );
      expect(
        resultVoiceParts(fakeResult('E02', 'elbow_angle', 'deg', -3), 'complete').lines[0].id,
        'result_line_complete__0',
      );
    });

    test('E02 без значения: подсказка result_hint_{метка}; у «выполнено» строки нет', () {
      expect(
        resultVoiceParts(fakeResult('E02', 'elbow_angle', 'deg', null), 'uncertain').lines.map((l) => l.id),
        ['result_hint_uncertain'],
      );
      expect(
        resultVoiceParts(fakeResult('E02', 'elbow_angle', 'deg', null), 'incomplete').lines.map((l) => l.id),
        ['result_hint_incomplete'],
      );
      expect(resultVoiceParts(fakeResult('E02', 'elbow_angle', 'deg', null), 'complete').lines, isEmpty);
    });

    test('E04: выросло — value−100 от 1 до 200, иначе значение от 0 до 100', () {
      expect(
        resultVoiceParts(fakeResult('E04', 'hand_openness', 'percent', 178.9), 'complete').lines[0].id,
        'result_measure_hand_openness_up__79',
      );
      expect(
        resultVoiceParts(fakeResult('E04', 'hand_openness', 'percent', 100), 'complete').lines[0].id,
        'result_measure_hand_openness_base__100',
      );
      expect(
        resultVoiceParts(fakeResult('E04', 'hand_openness', 'percent', 100.6), 'complete').lines[0].id,
        'result_measure_hand_openness_up__1',
      );
      expect(
        resultVoiceParts(fakeResult('E04', 'hand_openness', 'percent', 96.5), 'complete').lines[0].id,
        'result_measure_hand_openness_base__97',
      );
      expect(
        resultVoiceParts(fakeResult('E04', 'hand_openness', 'percent', 450), 'complete').lines[0].id,
        'result_measure_hand_openness_up__200',
      );
      expect(
        resultVoiceParts(fakeResult('E04', 'hand_openness', 'percent', -4), 'complete').lines[0].id,
        'result_measure_hand_openness_base__0',
      );
    });

    test('E03: result_measure_wrist_lift__n от 0 до 180', () {
      expect(
        resultVoiceParts(fakeResult('E03', 'wrist_lift', 'deg', 113.3), 'complete').lines[0].id,
        'result_measure_wrist_lift__113',
      );
      expect(
        resultVoiceParts(fakeResult('E03', 'wrist_lift', 'deg', 400), 'complete').lines[0].id,
        'result_measure_wrist_lift__180',
      );
      expect(
        resultVoiceParts(fakeResult('E03', 'wrist_lift', 'deg', -1), 'complete').lines[0].id,
        'result_measure_wrist_lift__0',
      );
    });

    test('E01: одна цифра после точки, от 0.0 до 9.9, на экране запятая языка', () {
      final line = resultVoiceParts(fakeResult('E01', 'lift_height', 'hand_lengths', 3.46), 'complete').lines[0];
      expect(line.id, 'result_measure_lift_height__3.5');
      expect(line.text, 'Кисть поднялась на 3,5 длины кисти');
      expect(
        resultVoiceParts(fakeResult('E01', 'lift_height', 'hand_lengths', 0), 'complete').lines[0].id,
        'result_measure_lift_height__0.0',
      );
      expect(
        resultVoiceParts(fakeResult('E01', 'lift_height', 'hand_lengths', 12.7), 'complete').lines[0].id,
        'result_measure_lift_height__9.9',
      );
      expect(
        resultVoiceParts(fakeResult('E01', 'lift_height', 'hand_lengths', 9.96), 'complete').lines[0].id,
        'result_measure_lift_height__9.9',
      );
      expect(
        resultVoiceParts(fakeResult('E01', 'lift_height', 'hand_lengths', -2), 'complete').lines[0].id,
        'result_measure_lift_height__0.0',
      );
    });

    test('без числа строки нет; подсказка для не-E02 с вариантом _other', () {
      for (final (ex, name, unit) in [
        ('E01', 'lift_height', 'hand_lengths'),
        ('E03', 'wrist_lift', 'deg'),
        ('E04', 'hand_openness', 'percent'),
      ]) {
        expect(resultVoiceParts(fakeResult(ex, name, unit, null), 'complete').lines, isEmpty);
        expect(
          resultVoiceParts(fakeResult(ex, name, unit, null), 'uncertain').lines.map((l) => l.id),
          ['result_hint_uncertain_other'],
        );
        expect(
          resultVoiceParts(fakeResult(ex, name, unit, null), 'incomplete').lines.map((l) => l.id),
          ['result_hint_incomplete'],
        );
      }
    });
  });

  test('clampInt: округляет и прижимает к краям', () {
    expect(clampInt(179.6, 0, 180), 180);
    expect(clampInt(-5, 0, 180), 0);
    expect(clampInt(300, 1, 200), 200);
    expect(clampInt(0, 1, 200), 1);
  });

  group('манифест', () {
    test('parseManifest: проверяет форму, лишнее — отсутствие манифеста', () {
      final ok = parseManifest({
        'v': 1,
        'clips': {
          'a': {'ru': 'ru/a.mp3', 'en': 'en/a.mp3'},
        },
      });
      expect(ok!.clips['a'], {'ru': 'ru/a.mp3', 'en': 'en/a.mp3'});
      expect(parseManifest({'v': 2, 'clips': {}}), isNull);
      expect(parseManifest({'v': 1}), isNull);
      expect(parseManifest('не манифест'), isNull);
      expect(parseManifest(null), isNull);
    });

    test('clipAvailable: есть ли хотя бы один клип из списка на языке', () {
      final m = parseManifest({
        'v': 1,
        'clips': {
          'a': {'ru': 'ru/a.mp3'},
          'b': {'en': 'en/b.mp3'},
        },
      });
      const items = [VoiceItem('a', 'A'), VoiceItem('b', 'B')];
      expect(clipAvailable(m, items, 'ru'), isTrue);
      expect(clipAvailable(m, items, 'kk'), isFalse);
      expect(clipAvailable(null, items, 'ru'), isFalse);
      expect(clipAvailable(m, const [], 'ru'), isFalse);
    });
  });

  group('VoiceCache: клипы с кэшем на устройстве', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('voice_cache_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('скачивает один раз, второй запрос отдаёт файл из кэша', () async {
      var calls = 0;
      final cache = VoiceCache(
        dirProvider: () async => dir,
        client: MockClient((req) async {
          calls++;
          expect(req.url.toString(), 'https://seriq-ai.qalau.com/voice/ru/a.mp3');
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      final path1 = await cache.fetch('ru/a.mp3');
      expect(path1, isNotNull);
      expect(File(path1!).readAsBytesSync(), [1, 2, 3]);
      expect(calls, 1);

      final path2 = await cache.fetch('ru/a.mp3');
      expect(path2, path1);
      expect(calls, 1, reason: 'второй запрос не обращается к серверу');
    });

    test('ошибка сервера или сети — null, файл не создаётся', () async {
      final cache404 = VoiceCache(
        dirProvider: () async => dir,
        client: MockClient((_) async => http.Response('', 404)),
      );
      expect(await cache404.fetch('ru/missing.mp3'), isNull);

      final cacheOffline = VoiceCache(
        dirProvider: () async => dir,
        client: MockClient((_) async => throw Exception('offline')),
      );
      expect(await cacheOffline.fetch('ru/x.mp3'), isNull);
    });

    test('подпапки языка превращаются в безопасное имя файла', () async {
      final cache = VoiceCache(
        dirProvider: () async => dir,
        client: MockClient((_) async => http.Response.bytes([9], 200)),
      );
      final path = await cache.fetch('kk/sub/dir/clip.mp3');
      expect(path, '${dir.path}/kk__sub__dir__clip.mp3');
    });
  });

  group('VoicePlayer: воспроизведение по очереди', () {
    test('играет клипы по порядку с паузой; известный манифест не грузится заново', () async {
      final env = FakeVoiceEnv()
        ..manifest = parseManifest({
          'v': 1,
          'clips': {
            'a': {'ru': 'ru/a.mp3'},
            'b': {'ru': 'ru/b.mp3'},
          },
        })
        ..files['ru/a.mp3'] = '/cache/a.mp3'
        ..files['ru/b.mp3'] = '/cache/b.mp3';
      final player = VoicePlayer(env);
      var ended = false;
      await player.playClips(
        const [VoiceItem('a', 'A'), VoiceItem('b', 'B')],
        'ru',
        onEnd: () => ended = true,
      );
      expect(env.order, ['play:/cache/a.mp3', 'play:/cache/b.mp3']);
      expect(env.waits, [pauseBetweenClips]);
      expect(ended, isTrue);
      expect(player.isPlaying, isFalse);
    });

    test('нет клипа в манифесте — читает запасным голосом', () async {
      final env = FakeVoiceEnv()..manifest = parseManifest({'v': 1, 'clips': {}});
      final player = VoicePlayer(env);
      await player.playClips(const [VoiceItem('a', 'Текст A')], 'ru');
      expect(env.fetchClipCalls, isEmpty);
      expect(env.spoken, [('ru', 'Текст A')]);
      expect(env.playFileCalls, isEmpty);
    });

    test('файл не скачался — читает запасным голосом', () async {
      final env = FakeVoiceEnv()
        ..manifest = parseManifest({
          'v': 1,
          'clips': {
            'a': {'ru': 'ru/a.mp3'},
          },
        });
      final player = VoicePlayer(env);
      await player.playClips(const [VoiceItem('a', 'Текст A')], 'ru');
      expect(env.fetchClipCalls, ['ru/a.mp3']);
      expect(env.spoken, [('ru', 'Текст A')]);
    });

    test('ошибка воспроизведения — читает запасным голосом для этого фрагмента', () async {
      final env = FakeVoiceEnv()
        ..manifest = parseManifest({
          'v': 1,
          'clips': {
            'a': {'ru': 'ru/a.mp3'},
            'b': {'ru': 'ru/b.mp3'},
          },
        })
        ..files['ru/a.mp3'] = '/cache/a.mp3'
        ..files['ru/b.mp3'] = '/cache/b.mp3'
        ..onPlay = (path) async => path != '/cache/a.mp3';
      final player = VoicePlayer(env);
      await player.playClips(
        const [VoiceItem('a', 'Текст A'), VoiceItem('b', 'Текст B')],
        'ru',
      );
      expect(env.order, ['play:/cache/a.mp3', 'speak:Текст A', 'play:/cache/b.mp3']);
    });

    test('без манифеста (сеть недоступна) всегда запасной голос', () async {
      final env = FakeVoiceEnv()..manifest = null;
      final player = VoicePlayer(env);
      await player.playClips(const [VoiceItem('a', 'Текст A')], 'ru');
      expect(env.spoken, [('ru', 'Текст A')]);
    });

    test('пустой список фрагментов завершается сразу', () async {
      final env = FakeVoiceEnv();
      final player = VoicePlayer(env);
      var ended = false;
      await player.playClips(const [], 'ru', onEnd: () => ended = true);
      expect(ended, isTrue);
      expect(env.order, isEmpty);
    });

    test('новый запуск прерывает старый: прежняя очередь дальше не играет', () async {
      final env = FakeVoiceEnv()
        ..manifest = parseManifest({
          'v': 1,
          'clips': {
            'a': {'ru': 'ru/a.mp3'},
            'b': {'ru': 'ru/b.mp3'},
            'c': {'ru': 'ru/c.mp3'},
          },
        })
        ..files['ru/a.mp3'] = '/cache/a.mp3'
        ..files['ru/b.mp3'] = '/cache/b.mp3'
        ..files['ru/c.mp3'] = '/cache/c.mp3';
      final player = VoicePlayer(env);
      final gate = Completer<bool>();
      env.onPlay = (path) => path == '/cache/a.mp3' ? gate.future : Future.value(true);

      var firstEnded = false;
      final first = player.playClips(
        const [VoiceItem('a', 'A'), VoiceItem('b', 'B')],
        'ru',
        onEnd: () => firstEnded = true,
      );
      // даём первому запуску дойти до проигрывания клипа a и застрять там на gate
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(env.order, ['play:/cache/a.mp3']);

      var secondEnded = false;
      final second = player.playClips(
        const [VoiceItem('c', 'C')],
        'ru',
        onEnd: () => secondEnded = true,
      );
      gate.complete(true); // клип a наконец «доигрался», но его очередь уже не актуальна
      await Future.wait([first, second]);

      expect(secondEnded, isTrue);
      expect(env.order, contains('play:/cache/c.mp3'));
      expect(env.order, isNot(contains('play:/cache/b.mp3')));
      expect(firstEnded, isFalse);
      expect(env.stopPlaybackCalls, greaterThanOrEqualTo(1));
    });

    test('stop() останавливает воспроизведение и запасной голос', () async {
      final env = FakeVoiceEnv();
      final player = VoicePlayer(env);
      await player.stop();
      expect(env.stopPlaybackCalls, 1);
      expect(env.stopSpeakCalls, 1);
    });

    test('hasClip: по манифесту для списка и языка, после load()', () async {
      final env = FakeVoiceEnv()
        ..manifest = parseManifest({
          'v': 1,
          'clips': {
            'a': {'ru': 'ru/a.mp3'},
          },
        });
      final player = VoicePlayer(env);
      expect(player.hasClip(const [VoiceItem('a', 'A')], 'ru'), isFalse,
          reason: 'манифест ещё не загружен');
      await player.load();
      expect(player.hasClip(const [VoiceItem('a', 'A')], 'ru'), isTrue);
      expect(player.hasClip(const [VoiceItem('a', 'A')], 'en'), isFalse);
      expect(player.manifest, isNotNull);
    });
  });

  group('SpeakButton с записанными клипами', () {
    late VoicePlayer savedPlayer;
    late SpeechEngine savedSpeech;

    setUp(() {
      savedPlayer = voicePlayer;
      savedSpeech = speechEngine;
    });

    tearDown(() {
      voicePlayer = savedPlayer;
      speechEngine = savedSpeech;
    });

    testWidgets('есть клип, но нет системного голоса — кнопка всё равно показана', (tester) async {
      final env = FakeVoiceEnv()
        ..manifest = parseManifest({
          'v': 1,
          'clips': {
            'a': {'ru': 'ru/a.mp3'},
          },
        })
        ..files['ru/a.mp3'] = '/cache/a.mp3';
      voicePlayer = VoicePlayer(env);
      speechEngine = FakeSpeech({});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SpeakButton(items: [VoiceItem('a', 'Текст A')]))),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Озвучить'), findsOneWidget);

      await tester.tap(find.text('Озвучить'));
      await tester.pumpAndSettle();
      expect(env.order, ['play:/cache/a.mp3']);
      expect(find.text('Озвучить'), findsOneWidget);
    });

    testWidgets('нет клипов и нет системного голоса — кнопки нет', (tester) async {
      voicePlayer = VoicePlayer(FakeVoiceEnv()..manifest = parseManifest({'v': 1, 'clips': {}}));
      speechEngine = FakeSpeech({});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SpeakButton(items: [VoiceItem('a', 'Текст A')]))),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Озвучить'), findsNothing);
    });

    testWidgets('нет клипов, но есть системный голос — играет запасным голосом', (tester) async {
      final env = FakeVoiceEnv()..manifest = parseManifest({'v': 1, 'clips': {}});
      voicePlayer = VoicePlayer(env);
      speechEngine = FakeSpeech({'ru'});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SpeakButton(items: [VoiceItem('a', 'Текст A')]))),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Озвучить'), findsOneWidget);
      await tester.tap(find.text('Озвучить'));
      await tester.pumpAndSettle();
      expect(env.spoken, [('ru', 'Текст A')]);
    });

    testWidgets('пустой список фрагментов — кнопки нет', (tester) async {
      voicePlayer = VoicePlayer(FakeVoiceEnv());
      speechEngine = FakeSpeech({'ru'});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SpeakButton(items: []))),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Озвучить'), findsNothing);
    });

    testWidgets('повторное нажатие останавливает озвучивание', (tester) async {
      final gate = Completer<bool>();
      final env = FakeVoiceEnv()
        ..manifest = parseManifest({
          'v': 1,
          'clips': {
            'a': {'ru': 'ru/a.mp3'},
          },
        })
        ..files['ru/a.mp3'] = '/cache/a.mp3'
        ..onPlay = (_) => gate.future;
      voicePlayer = VoicePlayer(env);
      speechEngine = FakeSpeech({'ru'});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SpeakButton(items: [VoiceItem('a', 'A')]))),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Озвучить'));
      await tester.pump();
      expect(find.text('Остановить озвучивание'), findsOneWidget);

      await tester.tap(find.text('Остановить озвучивание'));
      await tester.pump();
      expect(env.stopPlaybackCalls, greaterThanOrEqualTo(1));
      expect(find.text('Озвучить'), findsOneWidget);
      gate.complete(true);
    });
  });
}
