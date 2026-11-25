import 'strings.dart';

const _ruMonths = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const _kkMonths = [
  'қаңтар', 'ақпан', 'наурыз', 'сәуір', 'мамыр', 'маусым',
  'шілде', 'тамыз', 'қыркүйек', 'қазан', 'қараша', 'желтоқсан',
];
const _enMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// formatTime — время попытки в виде 14:03
String formatTime(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

// formatDateTime — дата и время занятия на языке интерфейса: «25 ноября 2026 г. в 02:26»
String formatDateTime(DateTime t, [String? lang]) {
  final l = t.toLocal();
  final code = lang ?? appLang.value;
  final time = formatTime(l);
  switch (code) {
    case 'kk':
      return '${l.year} ж. ${l.day} ${_kkMonths[l.month - 1]}, $time';
    case 'en':
      return '${l.day} ${_enMonths[l.month - 1]} ${l.year} at $time';
    default:
      return '${l.day} ${_ruMonths[l.month - 1]} ${l.year} г. в $time';
  }
}

// formatDay — «25 ноября» по дате YYYY-MM-DD
String formatDay(String date, [String? lang]) {
  final p = date.split('-').map(int.parse).toList();
  final code = lang ?? appLang.value;
  final months = code == 'kk' ? _kkMonths : (code == 'en' ? _enMonths : _ruMonths);
  return '${p[2]} ${months[p[1] - 1]}';
}
