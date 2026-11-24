import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/features/history/history_screen.dart';
import 'package:seriq_mobile/features/summary/summary_screen.dart';
import 'package:seriq_mobile/models/session.dart';
import 'package:seriq_mobile/services/history_storage.dart';

// session — занятие из двух попыток для теста
Session session() => Session(
      id: 's1',
      startedAt: DateTime.utc(2026, 11, 24, 10),
      attempts: [
        Attempt(
            analysisId: 'a1',
            at: DateTime.utc(2026, 11, 24, 10, 1),
            verdict: 'completed',
            label: 'complete',
            confidence: 0.9,
            source: 'mock'),
        Attempt(
            analysisId: 'a2',
            at: DateTime.utc(2026, 11, 24, 10, 2),
            verdict: 'check_instructions',
            label: 'uncertain',
            confidence: 0.55,
            source: 'mock'),
      ],
    );

void main() {
  setUp(() => appLang.value = 'ru');

  testWidgets('история показывает занятие и удаляется', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => HistoryStorage().saveSession(session()));
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Выполнено 1 из 2'), findsOneWidget);

    await tester.tap(find.text('Очистить всю историю'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Да, удалить'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text(Strings.ru['history_empty']!), findsOneWidget);
  });

  testWidgets('сводка: всего, метки и плашка мока', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SummaryScreen(session: session())));
    expect(find.text('Всего повторений: 2'), findsOneWidget);
    expect(find.text(Strings.ru['summary_has_mock']!), findsOneWidget);
    expect(find.text(
        'Повторение 1 · ${DateFormat('HH:mm').format(DateTime.utc(2026, 11, 24, 10, 1).toLocal())}'), findsOneWidget);
    expect(find.text('Проверьте инструкцию'), findsOneWidget);
  });
}
