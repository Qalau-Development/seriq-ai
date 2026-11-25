import 'package:flutter/widgets.dart';

import '../services/accounts.dart';
import '../services/auth.dart';
import '../services/sync_runtime.dart';

// AccountsLifecycle — при запуске проверяет, включены ли аккаунты, восстанавливает вход и отправляет неотправленное; то же при возвращении в приложение
class AccountsLifecycle extends StatefulWidget {
  final Widget child;

  const AccountsLifecycle({super.key, required this.child});

  @override
  State<AccountsLifecycle> createState() => _AccountsLifecycleState();
}

class _AccountsLifecycleState extends State<AccountsLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    accountsAvailable.start();
    auth.addListener(_onAuth);
    auth.restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    auth.removeListener(_onAuth);
    accountsAvailable.stop();
    super.dispose();
  }

  // _onAuth — вход состоялся: отправляет неотправленные занятия
  void _onAuth() {
    if (auth.value.kind == AuthKind.signedIn) syncRuntime.syncNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      accountsAvailable.refresh();
      syncRuntime.syncNow();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
