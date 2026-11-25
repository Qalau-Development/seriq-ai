// defaultExercise — упражнение по умолчанию и для старых записей
const defaultExercise = 'E02';

// ExerciseDef — запись справочника: код, ключи текстов и что измеряем (имена и единицы как в контракте API)
class ExerciseDef {
  final String id;
  final String titleKey;
  final String descKey;
  final String measuresKey;
  final List<String> stepKeys;
  final List<String> tipKeys;
  final String reminderKey;
  final bool hasVideo;
  final String measureName;
  final String measureUnit;

  const ExerciseDef({
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.measuresKey,
    required this.stepKeys,
    required this.tipKeys,
    required this.reminderKey,
    required this.hasVideo,
    required this.measureName,
    required this.measureUnit,
  });
}

// exercises — единственный справочник упражнений, порядок как на сайте
const exercises = <ExerciseDef>[
  ExerciseDef(
    id: 'E01',
    titleKey: 'exercise_e01_title',
    descKey: 'exercise_e01_desc',
    measuresKey: 'exercise_e01_measures',
    stepKeys: ['e01_step_1', 'e01_step_2', 'e01_step_3', 'e01_step_4'],
    tipKeys: ['e01_tip_1', 'e01_tip_2', 'e01_tip_3', 'tip_3', 'tip_4'],
    reminderKey: 'e01_reminder',
    hasVideo: false,
    measureName: 'lift_height',
    measureUnit: 'hand_lengths',
  ),
  ExerciseDef(
    id: 'E02',
    titleKey: 'exercise_e02_title',
    descKey: 'exercise_e02_desc',
    measuresKey: 'exercise_e02_measures',
    stepKeys: [
      'instruction_step_1',
      'instruction_step_2',
      'instruction_step_3',
      'instruction_step_4',
    ],
    tipKeys: ['tip_1', 'tip_2', 'tip_3', 'tip_4'],
    reminderKey: 'session_reminder',
    hasVideo: true,
    measureName: 'elbow_angle',
    measureUnit: 'deg',
  ),
  ExerciseDef(
    id: 'E03',
    titleKey: 'exercise_e03_title',
    descKey: 'exercise_e03_desc',
    measuresKey: 'exercise_e03_measures',
    stepKeys: ['e03_step_1', 'e03_step_2', 'e03_step_3', 'e03_step_4'],
    tipKeys: ['e03_tip_1', 'e03_tip_2', 'tip_3', 'tip_4'],
    reminderKey: 'e03_reminder',
    hasVideo: false,
    measureName: 'wrist_lift',
    measureUnit: 'deg',
  ),
  ExerciseDef(
    id: 'E04',
    titleKey: 'exercise_e04_title',
    descKey: 'exercise_e04_desc',
    measuresKey: 'exercise_e04_measures',
    stepKeys: ['e04_step_1', 'e04_step_2', 'e04_step_3', 'e04_step_4'],
    tipKeys: ['e04_tip_1', 'e04_tip_2', 'tip_3', 'tip_4'],
    reminderKey: 'e04_reminder',
    hasVideo: false,
    measureName: 'hand_openness',
    measureUnit: 'percent',
  ),
];

// lessReliableExercises — упражнения с пометкой «Менее надёжно»; текст пометки берётся из словаря сайта, пока ключа там нет, пометка не показывается
const lessReliableExercises = {'E01'};

// exerciseDef — запись справочника по коду; неизвестный код — E02
ExerciseDef exerciseDef(String id) => exercises.firstWhere(
  (e) => e.id == id,
  orElse: () => exercises.firstWhere((e) => e.id == defaultExercise),
);

// parseExercise — код упражнения из хранилища или ответа; неизвестное или пустое значение — E02
String parseExercise(String? value) =>
    exercises.any((e) => e.id == value) ? value! : defaultExercise;

// CatalogEntry — упражнение из каталога сервера: что измеряем и готово ли оно
class CatalogEntry {
  final String id;
  final String measureName;
  final String measureUnit;
  final bool ready;

  const CatalogEntry({
    required this.id,
    required this.measureName,
    required this.measureUnit,
    required this.ready,
  });

  @override
  bool operator ==(Object other) =>
      other is CatalogEntry &&
      other.id == id &&
      other.measureName == measureName &&
      other.measureUnit == measureUnit &&
      other.ready == ready;

  @override
  int get hashCode => Object.hash(id, measureName, measureUnit, ready);
}

// fallbackCatalog — запасной каталог из справочника: запись доступна только для E02
List<CatalogEntry> fallbackCatalog() => [
  for (final e in exercises)
    CatalogEntry(
      id: e.id,
      measureName: e.measureName,
      measureUnit: e.measureUnit,
      ready: e.id == defaultExercise,
    ),
];

// parseCatalog — разбирает ответ GET /api/v1/exercises; null, если это не каталог
List<CatalogEntry>? parseCatalog(Object? body) {
  if (body is! List) return null;
  final known = body
      .whereType<Map<String, dynamic>>()
      .where((item) => exercises.any((e) => e.id == item['id']))
      .toList();
  if (known.isEmpty) return null;
  final names = exercises.map((e) => e.measureName).toSet();
  final units = exercises.map((e) => e.measureUnit).toSet();
  return [
    for (final def in exercises)
      () {
        final item = known.where((k) => k['id'] == def.id).firstOrNull;
        final measure = item?['measure'];
        final name = measure is Map ? measure['name'] : null;
        final unit = measure is Map ? measure['unit'] : null;
        return CatalogEntry(
          id: def.id,
          measureName: names.contains(name) ? name as String : def.measureName,
          measureUnit: units.contains(unit) ? unit as String : def.measureUnit,
          ready: item?['ready'] == true,
        );
      }(),
  ];
}

// exerciseAvailability — состояние упражнения по каталогу: loading, ready или soon; пока каталога нет, доступно только E02
String exerciseAvailability(List<CatalogEntry>? catalog, String id) {
  if (catalog == null) return id == defaultExercise ? 'ready' : 'loading';
  return catalog.any((e) => e.id == id && e.ready) ? 'ready' : 'soon';
}
