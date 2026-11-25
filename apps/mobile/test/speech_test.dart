import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/services/speech.dart';
import 'package:seriq_mobile/widgets/speak_button.dart';

// FakeSpeech — подставной синтезатор: какие языки есть и что прочитано
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

void main() {
  late SpeechEngine saved;

  setUp(() {
    saved = speechEngine;
    appLang.value = 'ru';
  });

  tearDown(() => speechEngine = saved);

  test('двойные точки на стыках убираются, обычный текст не меняется', () {
    expect(cleanText('Выполнено. . Рука разогнулась до 166°.'), 'Выполнено. Рука разогнулась до 166°.');
    expect(cleanText('Привет… .. Пока'), 'Привет… Пока');
    expect(cleanText('Без точек'), 'Без точек');
  });

  test('языки голоса: русский, казахский и английский', () {
    expect(speechLocales, {'ru': 'ru-RU', 'kk': 'kk-KZ', 'en': 'en-US'});
  });

  testWidgets('кнопка читает переданный текст и меняется на «Остановить»', (tester) async {
    final fake = FakeSpeech({'ru', 'en'});
    speechEngine = fake;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeakButton(text: 'Выполнено. Рука разогнулась до 166°.'))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Озвучить'), findsOneWidget);

    await tester.tap(find.text('Озвучить'));
    await tester.pump();
    expect(fake.spoken, [('ru', 'Выполнено. Рука разогнулась до 166°.')]);
    expect(find.text('Остановить озвучивание'), findsOneWidget);

    await tester.tap(find.text('Остановить озвучивание'));
    await tester.pump();
    expect(fake.stops, greaterThan(0));
    expect(find.text('Озвучить'), findsOneWidget);
  });

  testWidgets('дочитал — кнопка снова «Озвучить»', (tester) async {
    final fake = FakeSpeech({'ru'});
    speechEngine = fake;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeakButton(text: 'Текст'))));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Озвучить'));
    await tester.pump();
    fake.finish();
    await tester.pump();
    expect(find.text('Озвучить'), findsOneWidget);
  });

  testWidgets('нет голоса для языка — кнопки нет; смена языка проверяет голос заново', (tester) async {
    speechEngine = FakeSpeech({'ru'});
    appLang.value = 'kk';
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeakButton(text: 'Текст'))));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text(Strings.kk['speak_start']!), findsNothing);

    appLang.value = 'ru';
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Озвучить'), findsOneWidget);
  });

  testWidgets('пустой текст — кнопки нет', (tester) async {
    speechEngine = FakeSpeech({'ru'});
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeakButton(text: ''))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Озвучить'), findsNothing);
  });
}
