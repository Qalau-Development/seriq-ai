import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/accounts.dart';
import '../../services/auth.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_field.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';

// AuthScreen — вход или регистрация по логину и паролю; форма показывается, только если сервер включил аккаунты
class AuthScreen extends StatefulWidget {
  final bool register;
  final AuthService? service;
  final AccountsAvailability? availability;

  const AuthScreen({
    super.key,
    this.register = false,
    this.service,
    this.availability,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _show = false;
  bool _busy = false;
  String? _error;

  AuthService get _auth => widget.service ?? auth;
  AccountsAvailability get _available => widget.availability ?? accountsAvailable;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // _submit — проверяет поля, отправляет запрос и при успехе открывает главную
  Future<void> _submit() async {
    setState(() => _error = null);
    final login = _login.text.trim();
    final password = _password.text;
    if (widget.register && !validLogin(login)) {
      return setState(() => _error = tr('error_invalid_login'));
    }
    if (widget.register && !validPassword(password, login)) {
      return setState(() => _error = tr('error_weak_password'));
    }
    setState(() => _busy = true);
    try {
      await _auth.signIn(widget.register ? 'register' : 'login', login, password);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      final code = e is AccountError ? e.code : 'internal_error';
      final retry = e is AccountError ? e.retryAfter : null;
      if (mounted) {
        setState(() {
          _error = fill(trOr('error_$code', 'error_internal_error'), {
            'time': waitText(retry),
          });
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.register;
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => ListenableBuilder(
        listenable: Listenable.merge([_available, _auth]),
        builder: (context, _) {
          final title = tr(register ? 'auth_register_title' : 'auth_login_title');
          if (!accountsOn(_available.value, _auth.value.kind == AuthKind.signedIn)) {
            return PageShell(
              tab: AppTab.account,
              children: [
                Text(title, style: AppText.title),
                const SizedBox(height: 24),
                MessageBox(text: tr('auth_unavailable')),
                const SizedBox(height: 20),
                BigButton(
                  label: tr('nav_home'),
                  kind: ButtonKind.secondary,
                  onPressed: () => goTab(context, AppTab.home),
                ),
              ],
            );
          }
          final disabled = _busy || _login.text.isEmpty || _password.text.isEmpty;
          return PageShell(
            tab: AppTab.account,
            children: [
              Text(title, style: AppText.title),
              const SizedBox(height: 20),
              if (_auth.value.kind == AuthKind.expired) ...[
                MessageBox(text: tr('session_expired')),
                const SizedBox(height: 16),
              ],
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (register) ...[
                      MessageBox(
                        text: tr('auth_remember_warning'),
                        kind: MessageKind.warn,
                      ),
                      const SizedBox(height: 20),
                    ],
                    AppField(
                      fieldKey: const Key('login'),
                      label: tr('auth_login_label'),
                      hint: register ? tr('auth_login_rules') : null,
                      controller: _login,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),
                    AppField(
                      fieldKey: const Key('password'),
                      label: tr('auth_password_label'),
                      hint: register ? tr('auth_password_rules') : null,
                      controller: _password,
                      focusNode: _passwordFocus,
                      obscure: !_show,
                      autofillHints: [
                        register ? AutofillHints.newPassword : AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => disabled ? null : _submit(),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      toggled: _show,
                      child: InkWell(
                        onTap: () => setState(() => _show = !_show),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: AppSizes.touch),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _show
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.link,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                tr(_show ? 'auth_hide_password' : 'auth_show_password'),
                                style: AppText.bodyStrong.copyWith(
                                  color: AppColors.link,
                                  decoration: TextDecoration.underline,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      MessageBox(text: _error!, kind: MessageKind.error),
                    ],
                    const SizedBox(height: 20),
                    BigButton(
                      label: _busy
                          ? tr('auth_working')
                          : tr(register ? 'auth_register_submit' : 'auth_login_submit'),
                      onPressed: disabled ? null : _submit,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${tr(register ? 'auth_have_account' : 'auth_no_account')} ',
                          style: AppText.body,
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).pushReplacementNamed(
                            register ? '/login' : '/register',
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: AppSizes.touch),
                            child: Align(
                              widthFactor: 1,
                              child: Text(
                                tr(register ? 'nav_login' : 'nav_register'),
                                style: AppText.bodyStrong.copyWith(
                                  color: AppColors.link,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(tr('auth_guest_note'), style: AppText.small),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
