import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/app.dart';
import 'package:seriq_mobile/core/privacy.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/features/system/system_screens.dart';

// tall — высокий экран, чтобы всё было построено
void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    appLang.value = 'ru';
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('приватность: все разделы сайта и ссылка в подвале', (tester) async {
    tall(tester);
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    await tester.tap(find.text('Данные и приватность'));
    await tester.pumpAndSettle();
    expect(find.text('Данные и приватность'), findsNWidgets(2));
    expect(privacySections.length, 7);
    for (final s in privacySections) {
      expect(find.text(Strings.ru[s.titleKey]!), findsOneWidget, reason: s.titleKey);
      for (final k in s.textKeys) {
        expect(find.text(Strings.ru[k]!), findsOneWidget, reason: k);
      }
    }
    expect(find.text('На главную'), findsOneWidget);
    await tester.tap(find.text('На главную'));
    await tester.pumpAndSettle();
    expect(find.text('Упражнения'), findsOneWidget);
  });

  testWidgets('приватность на английском: тексты из словаря сайта', (tester) async {
    tall(tester);
    appLang.value = 'en';
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    await tester.tap(find.text(Strings.en['privacy_link']!));
    await tester.pumpAndSettle();
    expect(find.text(Strings.en['privacy_video_1']!), findsOneWidget);
    expect(find.text(Strings.en['privacy_medical_1']!), findsOneWidget);
  });

  testWidgets('неизвестный маршрут: «Страница не найдена» и возврат на главную', (tester) async {
    tall(tester);
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    appNavigator.currentState!.pushNamed('/нет-такой');
    await tester.pumpAndSettle();
    expect(find.text(Strings.ru['not_found_title']!), findsOneWidget);
    expect(find.text(Strings.ru['not_found_text']!), findsOneWidget);
    await tester.tap(find.text('На главную').last);
    await tester.pumpAndSettle();
    expect(find.text('Упражнения'), findsOneWidget);
  });

  testWidgets('экран ошибки: текст без подробностей и две кнопки', (tester) async {
    tall(tester);
    var retried = 0;
    var home = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorScreen(onRetry: () => retried++, onHome: () => home++),
      ),
    );
    expect(find.text('Что-то пошло не так'), findsOneWidget);
    expect(find.text('Попробуйте ещё раз или вернитесь на главную.'), findsOneWidget);
    await tester.tap(find.text('Попробовать снова'));
    await tester.tap(find.text('На главную'));
    expect((retried, home), (1, 1));
  });

  testWidgets('«Попробовать снова» собирает приложение заново', (tester) async {
    tall(tester);
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    await tester.tap(find.text('История').last);
    await tester.pumpAndSettle();
    expect(find.text('История занятий'), findsOneWidget);
    restartApp();
    await tester.pumpAndSettle();
    expect(find.text('Упражнения'), findsOneWidget);
    expect(find.text('История занятий'), findsNothing);
  });
}
