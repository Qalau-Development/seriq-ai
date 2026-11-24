import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/app.dart';
import 'package:seriq_mobile/core/strings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'ru';
  });

  testWidgets('главный экран и переключение языка', (tester) async {
    await tester.pumpWidget(const SeriqApp());
    expect(find.text('SerIQ'), findsOneWidget);
    expect(find.text('Начать занятие'), findsOneWidget);
    expect(find.text(Strings.ru['disclaimer']!), findsOneWidget);

    await tester.tap(find.text('ҚАЗ'));
    await tester.pumpAndSettle();
    expect(find.text('Сабақты бастау'), findsOneWidget);
    expect(appLang.value, 'kk');
  });

  testWidgets('кнопка «История» открывает историю', (tester) async {
    await tester.pumpWidget(const SeriqApp());
    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();
    expect(find.text('История занятий'), findsOneWidget);
  });
}
