import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/strings.dart';
import 'widgets/accounts_lifecycle.dart';

// main — загружает выбранный язык и запускает приложение
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appLang.load();
  installErrorScreen();
  runApp(const AccountsLifecycle(child: SeriqApp()));
}
