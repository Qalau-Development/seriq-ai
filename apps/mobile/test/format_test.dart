import 'package:flutter_test/flutter_test.dart';
import 'package:seriq_mobile/core/format.dart';
import 'package:seriq_mobile/core/strings.dart';

void main() {
  final t = DateTime(2026, 11, 25, 2, 26);

  test('дата и время на трёх языках', () {
    expect(formatDateTime(t, 'ru'), '25 ноября 2026 г. в 02:26');
    expect(formatDateTime(t, 'kk'), '2026 ж. 25 қараша, 02:26');
    expect(formatDateTime(t, 'en'), '25 November 2026 at 02:26');
  });

  test('язык берётся из интерфейса, если не задан', () {
    appLang.value = 'en';
    expect(formatDateTime(t), '25 November 2026 at 02:26');
    appLang.value = 'ru';
    expect(formatDateTime(t), '25 ноября 2026 г. в 02:26');
  });

  test('время и день календаря', () {
    expect(formatTime(DateTime(2026, 11, 25, 9, 5)), '09:05');
    expect(formatDay('2026-11-25', 'ru'), '25 ноября');
    expect(formatDay('2026-01-03', 'kk'), '3 қаңтар');
    expect(formatDay('2026-12-31', 'en'), '31 December');
  });
}
