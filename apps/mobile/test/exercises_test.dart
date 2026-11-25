import 'package:flutter_test/flutter_test.dart';
import 'package:seriq_mobile/core/exercises.dart';
import 'package:seriq_mobile/core/strings.dart';

void main() {
  test('справочник: четыре упражнения, имена и единицы как в api.md', () {
    expect(exercises.map((e) => e.id), ['E01', 'E02', 'E03', 'E04']);
    final expected = {
      'E01': ('lift_height', 'hand_lengths'),
      'E02': ('elbow_angle', 'deg'),
      'E03': ('wrist_lift', 'deg'),
      'E04': ('hand_openness', 'percent'),
    };
    for (final e in exercises) {
      expect((e.measureName, e.measureUnit), expected[e.id], reason: e.id);
    }
    expect(exercises.where((e) => e.hasVideo).map((e) => e.id), ['E02']);
  });

  test('все ключи текстов справочника есть в словаре сайта', () {
    for (final e in exercises) {
      for (final k in [
        e.titleKey,
        e.descKey,
        e.measuresKey,
        e.reminderKey,
        ...e.stepKeys,
        ...e.tipKeys,
      ]) {
        expect(Strings.ru.containsKey(k), isTrue, reason: '${e.id}: $k');
      }
    }
  });

  test('parseExercise: неизвестное и пустое значение — E02', () {
    expect(parseExercise('E04'), 'E04');
    expect(parseExercise('E09'), 'E02');
    expect(parseExercise(null), 'E02');
    expect(exerciseDef('нет').id, 'E02');
  });

  test('запасной каталог: запись только для E02', () {
    final c = fallbackCatalog();
    expect(c.where((e) => e.ready).map((e) => e.id), ['E02']);
    expect(exerciseAvailability(c, 'E01'), 'soon');
    expect(exerciseAvailability(c, 'E02'), 'ready');
  });

  test('parseCatalog: ready берётся с сервера', () {
    final c = parseCatalog([
      {'id': 'E01', 'measure': {'name': 'lift_height', 'unit': 'hand_lengths'}, 'ready': true},
      {'id': 'E02', 'measure': {'name': 'elbow_angle', 'unit': 'deg'}, 'ready': true},
      {'id': 'E03', 'measure': {'name': 'wrist_lift', 'unit': 'deg'}, 'ready': false},
      {'id': 'E04', 'measure': {'name': 'hand_openness', 'unit': 'percent'}, 'ready': true},
    ])!;
    expect(c.map((e) => e.ready), [true, true, false, true]);
    expect(exerciseAvailability(c, 'E03'), 'soon');
    expect(exerciseAvailability(c, 'E04'), 'ready');
  });

  test('parseCatalog: пропавшая запись — не готова, неверные имена — из справочника', () {
    final c = parseCatalog([
      {'id': 'E02', 'measure': {'name': 'что-то', 'unit': 'deg'}, 'ready': true},
      {'id': 'E99', 'ready': true},
    ])!;
    expect(c.length, 4);
    expect(c[1].measureName, 'elbow_angle');
    expect(c[1].ready, isTrue);
    expect(c.where((e) => e.id != 'E02').every((e) => !e.ready), isTrue);
  });

  test('parseCatalog: не каталог — null', () {
    expect(parseCatalog({'a': 1}), isNull);
    expect(parseCatalog([]), isNull);
    expect(parseCatalog([1, 'x']), isNull);
  });

  test('пока каталога нет, доступно только E02', () {
    expect(exerciseAvailability(null, 'E02'), 'ready');
    expect(exerciseAvailability(null, 'E01'), 'loading');
  });
}
