import 'dart:io';

// parseDict — читает пары «ключ: "текст"» из словаря сайта
Map<String, String> parseDict(String source) {
  final pair = RegExp(r'^  ([a-z0-9_]+): "(.*)",$', multiLine: true);
  return {for (final m in pair.allMatches(source)) m[1]!: m[2]!};
}

// dartString — строка Dart в одинарных кавычках
String dartString(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

// main — собирает lib/core/texts.dart из словарей сайта apps/web/lib/i18n
void main() {
  const langs = ['ru', 'kk', 'en'];
  final out = StringBuffer()
    ..writeln('// Файл создаёт tool/sync_strings.dart из apps/web/lib/i18n, вручную не менять')
    ..writeln();
  for (final lang in langs) {
    final dict = parseDict(File('../web/lib/i18n/$lang.ts').readAsStringSync());
    out.writeln('// texts${lang[0].toUpperCase()}${lang[1]} — тексты сайта: $lang');
    out.writeln('const texts${lang[0].toUpperCase()}${lang[1]} = <String, String>{');
    for (final e in dict.entries) {
      out.writeln('  ${dartString(e.key)}: ${dartString(e.value)},');
    }
    out.writeln('};');
    out.writeln();
  }
  File('lib/core/texts.dart').writeAsStringSync('${out.toString().trimRight()}\n');
}
