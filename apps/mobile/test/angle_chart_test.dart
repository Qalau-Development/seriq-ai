import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/models/analysis_result.dart';
import 'package:seriq_mobile/widgets/angle_chart.dart';

void main() {
  setUp(() => appLang.value = 'ru');

  testWidgets('короткое видео: подписи времени не повторяются', (tester) async {
    final series = AngleSeries.fromJson({
      'fps': 10,
      'values': List<double>.generate(25, (i) => 90 + i.toDouble()),
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, child: AngleChart(series: series))),
    ));
    await tester.pump();
    for (final s in ['0', '1', '2']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
  });
}
