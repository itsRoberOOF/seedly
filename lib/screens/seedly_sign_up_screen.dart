import 'dart:math' as math;

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

/// Figma "Crear cuenta", opened from the login and closed back into it. Like
/// the login, it offers only Google next to email.
class SeedlySignUpScreen extends StatefulWidget {
  const SeedlySignUpScreen({
    super.key,
    required this.auth,
    required this.projects,
    required this.users,
  });

  final SeedlyAuthRepository auth;

  /// Only handed on to the home screen.
  final SeedlyProjectRepository projects;
  final SeedlyUserRepository users;

  @override
  State<SeedlySignUpScreen> createState() => _SeedlySignUpScreenState();
}

class _SeedlySignUpScreenState extends State<SeedlySignUpScreen> {
  /// Stricter than Firebase's six, which is too easy to guess.
  static const _minPasswordLength = 8;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  /// Off until the first failed submit; then borders clear as fields are
  /// fixed, without waiting for another submit.
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Runs [signUp] once at a time and opens the home when it reports success.
  Future<void> _signUp(Future<bool> Function() signUp) async {
    if (_busy) return;
    hideSeedlyAlert();
    setState(() => _busy = true);
    try {
      if (!await signUp() || !mounted) return;
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
        title: 'No se pudo crear la cuenta',
        message: error.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String? _nameError(String? value) =>
      (value?.trim().isNotEmpty ?? false) ? null : 'Ingresa tu nombre';

  static String? _passwordError(String? value) =>
      (value?.length ?? 0) >= _minPasswordLength
      ? null
      : 'La contraseña debe tener al menos $_minPasswordLength caracteres';

  String? _confirmError(String? value) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña';
    return value == _password.text ? null : 'Las contraseñas no coinciden';
  }

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
          _nameError(_name.text),
          seedlyEmailError(_email.text),
          _passwordError(_password.text),
          _confirmError(_confirm.text),
        ].nonNulls.join('\n'),
      );
      return;
    }
    _signUp(() async {
      await widget.auth.signUpWithEmail(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      // An alert about this form must not linger over the login.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) hideSeedlyAlert();
      },
      child: Scaffold(
        backgroundColor: SeedlyPalette.neutral[100],
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 96),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      Text('Crea tu cuenta', style: textTheme.displaySmall),
                      Text(
                        'Empieza a cultivar tu progreso.',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: SeedlyPalette.neutral[700],
                        ),
                      ),
                      const SizedBox(height: 64),
                      Form(
                        key: _formKey,
                        autovalidateMode: _autovalidate,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SeedlyInput(
                              label: 'Nombre *',
                              hint: '',
                              controller: _name,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              validator: _nameError,
                            ),
                            const SizedBox(height: 16),
                            SeedlyInput(
                              label: 'Correo electrónico *',
                              hint: 'ejemplo@correo.com',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: seedlyEmailError,
                            ),
                            const SizedBox(height: 16),
                            SeedlyInput(
                              label: 'Contraseña *',
                              hint: '•••••••••••••',
                              controller: _password,
                              password: true,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              validator: _passwordError,
                            ),
                            const SizedBox(height: 16),
                            SeedlyInput(
                              label: 'Confirmar contraseña *',
                              hint: '•••••••••••••',
                              controller: _confirm,
                              password: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              validator: _confirmError,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      SeedlyButton(
                        label: 'Crear cuenta',
                        expand: true,
                        trailing: SvgPicture.asset(
                          'assets/images/signup_add_user.svg',
                          width: 24,
                          height: 24,
                        ),
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: SeedlyPalette.neutral[500]),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'o regístrate con',
                              style: textTheme.bodySmall?.copyWith(
                                color: SeedlyPalette.neutral[600],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: SeedlyPalette.neutral[500]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SeedlyButton(
                        label: 'Google',
                        variant: SeedlyButtonVariant.outline,
                        expand: true,
                        leading: SvgPicture.asset(
                          'assets/images/login_google.svg',
                          width: 24,
                          height: 24,
                        ),
                        onPressed: () => _signUp(widget.auth.signInWithGoogle),
                      ),
                      // Figma pins the login link to the bottom; on short
                      // screens it still keeps some room from Google.
                      const SizedBox(height: 32),
                      const Spacer(),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            '¿Ya tienes cuenta?',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SeedlyButton(
                            label: 'Inicia sesión',
                            variant: SeedlyButtonVariant.text,
                            size: SeedlyButtonSize.medium,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ],
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
