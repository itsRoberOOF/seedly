import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_errors.dart';
import '../repositories/seedly_auth_repository.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_input.dart';
import 'seedly_home_screen.dart';

class SeedlyLoginScreen extends StatefulWidget {
  const SeedlyLoginScreen({super.key, required this.auth});

  final SeedlyAuthRepository auth;

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

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
          builder: (_) => SeedlyHomeScreen(auth: widget.auth),
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

  static String? _emailError(String? value) {
    final email = value?.trim() ?? '';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'Ingresa un correo válido';
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
          _emailError(_email.text),
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
                                validator: _emailError,
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
                                  onPressed: () => _notice(
                                    'Recuperación de contraseña aún no disponible',
                                  ),
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
                              onPressed: () =>
                                  _notice('Registro aún no disponible'),
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
