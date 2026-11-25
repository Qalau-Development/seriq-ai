import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/app.dart';
import 'package:seriq_mobile/core/strings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'ru';
  });

  testWidgets('главный экран и переключение языка', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SeriqApp());
    expect(find.text('SerIQ'), findsWidgets);
    expect(find.text('Начать занятие'), findsOneWidget);
    expect(find.text(Strings.ru['disclaimer']!), findsOneWidget);

    await tester.tap(find.text('РУС'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ҚАЗ'));
    await tester.pumpAndSettle();
    expect(find.text('Сабақты бастау'), findsOneWidget);
    expect(appLang.value, 'kk');

    await tester.tap(find.text('ҚАЗ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENG'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.en['start_session']!), findsOneWidget);
    expect(appLang.value, 'en');
  });

  testWidgets('кнопка «История» открывает историю', (tester) async {
    await tester.pumpWidget(const SeriqApp());
    await tester.tap(find.text('История').last);
    await tester.pumpAndSettle();
    expect(find.text('История занятий'), findsOneWidget);
  });
}
