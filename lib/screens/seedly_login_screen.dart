import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_errors.dart';
import '../repositories/seedly_auth_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../repositories/seedly_user_repository.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_validators.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_input.dart';
import 'seedly_home_screen.dart';
import 'seedly_password_reset_screen.dart';
import 'seedly_sign_up_screen.dart';

class SeedlyLoginScreen extends StatefulWidget {
  const SeedlyLoginScreen({
    super.key,
    required this.auth,
    required this.projects,
    required this.users,
  });

  final SeedlyAuthRepository auth;

  /// Only handed on to the home and sign-up screens.
  final SeedlyProjectRepository projects;
  final SeedlyUserRepository users;

  @override
  State<SeedlyLoginScreen> createState() => _SeedlyLoginScreenState();
}

class _SeedlyLoginScreenState extends State<SeedlyLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  /// Off until the first failed submit; then borders clear as fields are
  /// fixed, without waiting for another submit.
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Runs [signIn] once at a time and opens the home when it reports success.
  Future<void> _signIn(Future<bool> Function() signIn) async {
    if (_busy) return;
    hideSeedlyAlert();
    setState(() => _busy = true);
    try {
      if (!await signIn() || !mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => SeedlyHomeScreen(
            auth: widget.auth,
            projects: widget.projects,
            users: widget.users,
          ),
        ),
        (_) => false,
      );
    } on SeedlyAuthException catch (error) {
      if (!mounted) return;
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo iniciar sesión',
        message: error.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSignUp() {
    hideSeedlyAlert();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeedlySignUpScreen(
          auth: widget.auth,
          projects: widget.projects,
          users: widget.users,
        ),
      ),
    );
  }

  Future<void> _openPasswordReset() async {
    hideSeedlyAlert();
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SeedlyPasswordResetScreen(
          auth: widget.auth,
          initialEmail: _email.text.trim(),
        ),
      ),
    );
    if (sent != true || !mounted) return;
    // Worded the same whether or not the email has an account.
    showSeedlyAlert(
      context,
      style: SeedlyAlertStyle.success,
      title: 'Revisa tu correo',
      message:
          'Si hay una cuenta con ese correo, te enviamos un enlace para '
          'cambiar tu contraseña.',
    );
  }

  static String? _passwordError(String? value) =>
      (value?.isNotEmpty ?? false) ? null : 'Ingresa tu contraseña';

  void _submit() {
    // validate() turns the invalid fields' borders red; their messages are
    // gathered into one alert, in field order.
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'Campos incompletos',
        message: [
          seedlyEmailError(_email.text),
          _passwordError(_password.text),
        ].nonNulls.join('\n'),
      );
      return;
    }
    _signIn(() async {
      await widget.auth.signInWithEmail(
        email: _email.text.trim(),
        password: _password.text,
      );
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: SeedlyPalette.neutral[100],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 64,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 2),
                        Text('Bienvenido.', style: textTheme.displaySmall),
                        Text(
                          'Inicia sesión para continuar',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: SeedlyPalette.neutral[700],
                          ),
                        ),
                        const SizedBox(height: 48),
                        Form(
                          key: _formKey,
                          autovalidateMode: _autovalidate,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SeedlyInput(
                                label: 'Correo electrónico *',
                                hint: 'ejemplo@correo.com',
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                validator: seedlyEmailError,
                              ),
                              const SizedBox(height: 24),
                              SeedlyInput(
                                label: 'Contraseña *',
                                hint: '•••••••••••••',
                                controller: _password,
                                password: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                validator: _passwordError,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: SeedlyButton(
                                  label: '¿Olvidaste tu contraseña?',
                                  variant: SeedlyButtonVariant.text,
                                  size: SeedlyButtonSize.medium,
                                  onPressed: _openPasswordReset,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SeedlyButton(
                                label: 'Iniciar sesión',
                                expand: true,
                                trailing: SvgPicture.asset(
                                  'assets/images/login_enter.svg',
                                  width: 24,
                                  height: 24,
                                ),
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: SeedlyPalette.neutral[500],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'o continúa con',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: SeedlyPalette.neutral[600],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: SeedlyPalette.neutral[500],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SeedlyButton(
                                label: 'Google',
                                variant: SeedlyButtonVariant.outline,
                                expand: true,
                                leading: SvgPicture.asset(
                                  'assets/images/login_google.svg',
                                  width: 24,
                                  height: 24,
                                ),
                                onPressed: () =>
                                    _signIn(widget.auth.signInWithGoogle),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Spacer(),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              '¿Aún no tienes cuenta?',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SeedlyButton(
                              label: 'Regístrate',
                              variant: SeedlyButtonVariant.text,
                              size: SeedlyButtonSize.medium,
                              onPressed: _openSignUp,
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
