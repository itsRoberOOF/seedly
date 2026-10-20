import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_errors.dart';
import '../repositories/seedly_auth_repository.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_validators.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_header.dart';
import '../widgets/seedly_input.dart';

/// Figma "Olvidaste tu contraseña", opened from the login. Pops with true
/// once the link is sent, so the login can say so.
class SeedlyPasswordResetScreen extends StatefulWidget {
  const SeedlyPasswordResetScreen({
    super.key,
    required this.auth,
    this.initialEmail = '',
  });

  final SeedlyAuthRepository auth;

  /// What was typed in the login, so it needn't be typed twice.
  final String initialEmail;

  @override
  State<SeedlyPasswordResetScreen> createState() =>
      _SeedlyPasswordResetScreenState();
}

class _SeedlyPasswordResetScreenState extends State<SeedlyPasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;

  /// Off until the first failed submit; then the border clears once the
  /// email is fixed, without waiting for another submit.
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'Campos incompletos',
        message: seedlyEmailError(_email.text)!,
      );
      return;
    }
    hideSeedlyAlert();
    setState(() => _busy = true);
    try {
      await widget.auth.sendPasswordReset(_email.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on SeedlyAuthException catch (error) {
      if (!mounted) return;
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo enviar el enlace',
        message: error.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SeedlyHeader(
                  title: '',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 40),
                Center(
                  // Shrinks with the screen on phones narrower than Figma's.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox.square(
                      dimension: 300,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/recover_blob.svg',
                            width: 300,
                            height: 300,
                          ),
                          SvgPicture.asset(
                            'assets/images/recover_lock.svg',
                            width: 150,
                            height: 180,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  '¿Olvidaste tu contraseña?',
                  textAlign: TextAlign.center,
                  style: textTheme.displayMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ingresa tu correo electrónico y te enviaremos un enlace '
                  'para recuperar tu contraseña.',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: SeedlyPalette.neutral[700],
                  ),
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  autovalidateMode: _autovalidate,
                  child: SeedlyInput(
                    label: 'Correo electrónico *',
                    hint: 'ejemplo@correo.com',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    validator: seedlyEmailError,
                  ),
                ),
                const SizedBox(height: 40),
                SeedlyButton(
                  label: 'Enviar enlace',
                  expand: true,
                  trailing: SvgPicture.asset(
                    'assets/images/recover_send.svg',
                    width: 24,
                    height: 24,
                  ),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
