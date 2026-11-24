import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/core/strings.dart';

void main() {
  test('у казахского и русского одинаковые ключи', () {
    expect(Strings.kk.keys.toSet(), Strings.ru.keys.toSet());
  });

  test('есть тексты для всех кодов из integration.md', () {
    const codes = [
      'verdict_completed', 'verdict_check_instructions',
      'label_complete', 'label_incomplete', 'label_uncertain',
      'warning_arm_not_visible',
      'error_missing_video', 'error_empty_file', 'error_unsupported_exercise',
      'error_file_too_large', 'error_unsupported_format',
      'error_video_unreadable', 'error_video_too_short',
      'error_video_too_long', 'error_no_pose_detected', 'error_busy',
      'error_internal_error', 'error_network_error', 'error_camera_denied',
      'error_recording_too_short',
    ];
    for (final c in codes) {
      expect(Strings.ru.containsKey(c), isTrue, reason: c);
    }
  });

  test('в текстах нет слова «плечо»', () {
    final shoulder = RegExp(r'(?<!пред)плеч|иық', caseSensitive: false);
    for (final t in [...Strings.ru.values, ...Strings.kk.values]) {
      expect(shoulder.hasMatch(t), isFalse, reason: t);
    }
  });

  test('уверенность словами', () {
    expect(Strings.of('ru', 'confidence_high'), 'высокая');
    appLang.value = 'ru';
    expect(trConfidence(0.87), 'высокая');
    expect(trConfidence(0.6), 'средняя');
    expect(trConfidence(0.55), 'низкая');
  });

  test('язык сохраняется под seriq.lang', () async {
    SharedPreferences.setMockInitialValues({});
    await appLang.set('kk');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('seriq.lang'), 'kk');
    appLang.value = 'ru';
    await appLang.load();
    expect(appLang.value, 'kk');
    await appLang.set('ru');
  });
}
