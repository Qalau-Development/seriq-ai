import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:seriq_mobile/app.dart';
import 'package:seriq_mobile/core/exercises.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/features/exercise/exercise_screen.dart';
import 'package:seriq_mobile/services/catalog.dart';

// entries — каталог сервера с заданными готовыми упражнениями
List<CatalogEntry> entries(Set<String> ready) => [
  for (final e in exercises)
    CatalogEntry(
      id: e.id,
      measureName: e.measureName,
      measureUnit: e.measureUnit,
      ready: ready.contains(e.id),
    ),
];

// tall — высокий экран, чтобы все карточки были построены
void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    appLang.value = 'ru';
    catalog.value = null;
  });

  testWidgets('библиотека: четыре карточки, «Скоро» у неготовых', (tester) async {
    tall(tester);
    catalog.value = entries({'E01', 'E02', 'E04'});
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    catalog.value = entries({'E01', 'E02', 'E04'});
    await tester.pump();
    for (final e in exercises) {
      expect(find.text(Strings.ru[e.titleKey]!), findsOneWidget, reason: e.id);
      expect(find.text(Strings.ru[e.measuresKey]!), findsOneWidget);
    }
    expect(find.text('Начать занятие'), findsNWidgets(3));
    expect(find.text('Скоро'), findsOneWidget);
  });

  testWidgets('пока каталога нет, кнопка только у E02', (tester) async {
    tall(tester);
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    catalog.value = null;
    await tester.pump();
    expect(find.text('Начать занятие'), findsOneWidget);
    expect(find.text('Загрузка…'), findsNWidgets(3));
  });

  testWidgets('метка «Менее надёжно» не выдумывается: без ключа в словаре сайта её нет', (tester) async {
    tall(tester);
    catalog.value = entries({'E01', 'E02', 'E03', 'E04'});
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    catalog.value = entries({'E01', 'E02', 'E03', 'E04'});
    await tester.pump();
    expect(Strings.ru.containsKey('exercise_less_reliable'), isFalse);
    expect(find.textContaining('надёжно'), findsNothing);
  });

  testWidgets('инструкция E04: шаги и советы текстом, без видео', (tester) async {
    tall(tester);
    catalog.value = entries({'E01', 'E02', 'E03', 'E04'});
    await tester.pumpWidget(const MaterialApp(home: ExerciseScreen(id: 'E04')));
    await tester.pump();
    final def = exerciseDef('E04');
    expect(
      find.text('Раскрытие кисти: ${Strings.ru['instruction_title']!.toLowerCase()}'),
      findsOneWidget,
    );
    for (final k in [...def.stepKeys, ...def.tipKeys]) {
      expect(find.text(Strings.ru[k]!), findsWidgets, reason: k);
    }
    expect(find.text(Strings.ru['instruction_video_missing']!), findsNothing);
    expect(find.text('Я готов'), findsOneWidget);
  });

  testWidgets('инструкция неготового упражнения: пояснение и возврат к списку', (tester) async {
    tall(tester);
    catalog.value = entries({'E02'});
    await tester.pumpWidget(const MaterialApp(home: ExerciseScreen(id: 'E03')));
    await tester.pump();
    expect(find.text(Strings.ru['exercise_soon_hint']!), findsOneWidget);
    expect(find.text('Ко всем упражнениям'), findsOneWidget);
    expect(find.text('Я готов'), findsNothing);
  });

  testWidgets('кнопка запуска ведёт на инструкцию выбранного упражнения', (tester) async {
    tall(tester);
    catalog.value = entries({'E01', 'E02', 'E03', 'E04'});
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    catalog.value = entries({'E01', 'E02', 'E03', 'E04'});
    await tester.pump();
    await tester.tap(find.text('Начать занятие').at(3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Раскрытие кисти:'), findsOneWidget);
    expect(find.text(Strings.ru['e04_step_1']!), findsOneWidget);
  });
}
