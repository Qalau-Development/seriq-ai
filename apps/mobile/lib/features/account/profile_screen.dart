import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/accounts.dart';
import '../../services/auth.dart';
import '../../services/sync_runtime.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_field.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';

// ProfileScreen — профиль: логин, выход, удаление аккаунта и данных с подтверждением паролем
class ProfileScreen extends StatefulWidget {
  final AuthService? service;
  final AccountsAvailability? availability;
  final SyncRuntime? sync;

  const ProfileScreen({super.key, this.service, this.availability, this.sync});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _password = TextEditingController();
  bool _deleting = false;
  bool _busy = false;
  String? _error;

  AuthService get _auth => widget.service ?? auth;
  AccountsAvailability get _available => widget.availability ?? accountsAvailable;
  SyncRuntime get _sync => widget.sync ?? syncRuntime;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  // _logout — выходит из аккаунта и открывает главную
  Future<void> _logout() async {
    await _sync.logout();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // _remove — удаляет аккаунт; при неверном пароле показывает ошибку
  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _sync.removeAccount(_password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      final code = e is AccountError ? e.code : 'internal_error';
      if (mounted) {
        setState(() {
          _error = fill(trOr('error_$code', 'error_internal_error'), {
            'time': waitText((e is AccountError) ? e.retryAfter : null),
          });
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => ListenableBuilder(
        listenable: Listenable.merge([_available, _auth]),
        builder: (context, _) {
          final state = _auth.value;
          final title = Text(tr('profile_title'), style: AppText.title);
          if (state.kind == AuthKind.restoring) {
            return PageShell(
              tab: AppTab.account,
              children: [Text(tr('loading'), style: AppText.body)],
            );
          }
          final user = _auth.user;
          if (!accountsOn(_available.value, user != null) || user == null) {
            final available = accountsOn(_available.value, false);
            return PageShell(
              tab: AppTab.account,
              children: [
                title,
                const SizedBox(height: 24),
                MessageBox(
                  text: tr(available ? 'profile_not_logged' : 'auth_unavailable'),
                ),
                const SizedBox(height: 20),
                BigButton(
                  label: tr(available ? 'nav_login' : 'nav_home'),
                  onPressed: () => available
                      ? Navigator.of(context).pushReplacementNamed('/login')
                      : goTab(context, AppTab.home),
                ),
              ],
            );
          }
          return PageShell(
            tab: AppTab.account,
            children: [
              title,
              const SizedBox(height: 20),
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: AppColors.tile,
                        borderRadius: BorderRadius.circular(AppSizes.tileRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('profile_login'),
                            style: AppText.bodyStrong.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.login,
                            style: const TextStyle(
                              fontSize: 28,
                              height: 36 / 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(tr('profile_stored_note'), style: AppText.body),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => Navigator.of(context).pushNamed('/privacy'),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: AppSizes.touch),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1,
                          child: Text(
                            tr('privacy_link'),
                            style: AppText.bodyStrong.copyWith(
                              color: AppColors.link,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    BigButton(
                      label: tr('profile_logout'),
                      icon: Icons.logout_rounded,
                      kind: ButtonKind.secondary,
                      onPressed: _busy ? null : _logout,
                    ),
                    if (!_deleting) ...[
                      const SizedBox(height: 12),
                      BigButton(
                        label: tr('profile_delete'),
                        icon: Icons.delete_outline_rounded,
                        kind: ButtonKind.secondary,
                        onPressed: () => setState(() => _deleting = true),
                      ),
                    ],
                    if (_deleting) ...[
                      const SizedBox(height: 20),
                      _deleteForm(),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // _deleteForm — подтверждение удаления: предупреждение, пароль, ошибка и две кнопки
  Widget _deleteForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.errorLine, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('profile_delete_warning'),
            style: AppText.bodyStrong.copyWith(
              color: AppColors.errorInk,
              height: 27 / 18,
            ),
          ),
          const SizedBox(height: 16),
          AppField(
            fieldKey: const Key('delete-password'),
            label: tr('auth_password_label'),
            controller: _password,
            obscure: true,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            MessageBox(text: _error!, kind: MessageKind.error),
          ],
          const SizedBox(height: 16),
          BigButton(
            label: tr('profile_delete_yes'),
            kind: ButtonKind.danger,
            onPressed: _busy || _password.text.isEmpty ? null : _remove,
          ),
          const SizedBox(height: 12),
          BigButton(
            label: tr('clear_history_no'),
            kind: ButtonKind.secondary,
            onPressed: _busy ? null : () => setState(() => _deleting = false),
          ),
        ],
      ),
    );
  }
}
