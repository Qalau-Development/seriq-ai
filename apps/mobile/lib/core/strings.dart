import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'texts.dart';

// appLangs — языки интерфейса в порядке переключателя
const appLangs = ['kk', 'ru', 'en'];

// Strings — тексты интерфейса на русском, казахском и английском, один в один с сайтом
class Strings {
  static const ru = textsRu;
  static const kk = textsKk;
  static const en = textsEn;

  // of — текст по ключу для языка; нет в языке — русский, нет и там — сам ключ
  static String of(String lang, String key) =>
      byLang(lang)[key] ?? ru[key] ?? key;

  // byLang — словарь языка; неизвестный язык — русский
  static Map<String, String> byLang(String lang) =>
      lang == 'kk' ? kk : (lang == 'en' ? en : ru);
}

// parseLang — язык из сохранённого значения; всё неизвестное — ru
String parseLang(String? value) => appLangs.contains(value) ? value! : 'ru';

// LangController — выбранный язык, хранится под ключом seriq.lang
class LangController extends ValueNotifier<String> {
  static const storageKey = 'seriq.lang';

  LangController() : super('ru');

  // load — читает сохранённый язык
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = parseLang(prefs.getString(storageKey));
  }

  // set — меняет и сохраняет язык
  Future<void> set(String lang) async {
    value = parseLang(lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
  }
}

final appLang = LangController();

// tr — текст по ключу на текущем языке
String tr(String key) => Strings.of(appLang.value, key);

// trFill — текст с подстановкой значений вместо {имя}
String trFill(String key, Map<String, Object> values) => fill(tr(key), values);

// fill — подставляет значения в текст вида «Выполнено {done} из {total}»
String fill(String text, Map<String, Object> values) =>
    text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => '${values[m[1]] ?? ''}');

// localNum — число с десятичным разделителем языка: запятая в русском и казахском, точка в английском
String localNum(String text) => text.replaceFirst('.', tr('decimal_sep'));

// trOr — текст по ключу или запасной текст, если ключа нет
String trOr(String key, String fallback) =>
    Strings.ru.containsKey(key) ? tr(key) : tr(fallback);

// trForExercise — текст по ключу; для упражнений кроме E02 берётся вариант с суффиксом _other, если он есть
String trForExercise(String key, String exercise, String fallback) {
  final other = '${key}_other';
  if (exercise != 'E02' && Strings.ru.containsKey(other)) return tr(other);
  return trOr(key, fallback);
}

// trError — текст для кода ошибки API или клиента
String trError(String code, [String exercise = 'E02']) =>
    trForExercise('error_$code', exercise, 'error_internal_error');

// trConfidence — уверенность словами: от 0,8 высокая, от 0,6 средняя, ниже низкая
String trConfidence(double c) => tr(
  c >= 0.8
      ? 'confidence_high'
      : c >= 0.6
      ? 'confidence_medium'
      : 'confidence_low',
);
