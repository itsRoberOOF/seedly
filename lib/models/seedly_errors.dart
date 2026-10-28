/// Why signing up, in or out, or sending a password reset failed. Each
/// backend maps its own error codes to these, so the Spanish text is written
/// once.
enum SeedlyAuthError {
  invalidCredentials,
  invalidEmail,
  userDisabled,
  tooManyRequests,
  network,
  accountExistsWithDifferentCredential,
  methodNotAllowed,
  googleFailed,
  googleConfig,
  signInFailed,
  signOutFailed,
  emailInUse,
  weakPassword,
  signUpFailed,
  resetFailed,
}

class SeedlyAuthException implements Exception {
  const SeedlyAuthException(this.reason);

  final SeedlyAuthError reason;

  /// Ready to show.
  String get message => switch (reason) {
    SeedlyAuthError.invalidCredentials => 'Correo o contraseña incorrectos',
    SeedlyAuthError.invalidEmail => 'Ingresa un correo válido',
    SeedlyAuthError.userDisabled => 'Esta cuenta está deshabilitada',
    SeedlyAuthError.tooManyRequests =>
      'Demasiados intentos. Espera un momento.',
    SeedlyAuthError.network => 'Sin conexión. Revisa tu internet.',
    SeedlyAuthError.accountExistsWithDifferentCredential =>
      'Este correo ya usa otro método de acceso',
    SeedlyAuthError.methodNotAllowed =>
      'Este método de acceso no está habilitado',
    SeedlyAuthError.googleFailed =>
      'No se pudo iniciar sesión con Google. Inténtalo de nuevo.',
    SeedlyAuthError.googleConfig =>
      'Google no pudo confirmar tu cuenta. Inténtalo de nuevo o inicia '
          'sesión con tu correo.',
    SeedlyAuthError.signInFailed =>
      'No se pudo iniciar sesión. Inténtalo de nuevo.',
    // The alert's title already says "No se pudo cerrar sesión".
    SeedlyAuthError.signOutFailed => 'Inténtalo de nuevo en un momento.',
    SeedlyAuthError.emailInUse => 'Este correo ya tiene una cuenta',
    SeedlyAuthError.weakPassword => 'Elige una contraseña más segura',
    // The alert's title already says "No se pudo crear la cuenta".
    SeedlyAuthError.signUpFailed => 'Inténtalo de nuevo en un momento.',
    // The alert's title already says "No se pudo enviar el enlace".
    SeedlyAuthError.resetFailed => 'Inténtalo de nuevo en un momento.',
  };

  @override
  String toString() => message;
}

/// Why saving a project failed.
enum SeedlyProjectError { sessionExpired, saveFailed }

class SeedlyProjectException implements Exception {
  const SeedlyProjectException(this.reason);

  final SeedlyProjectError reason;

  /// Ready to show.
  String get message => switch (reason) {
    SeedlyProjectError.sessionExpired =>
      'Tu sesión expiró. Vuelve a iniciar sesión.',
    SeedlyProjectError.saveFailed =>
      'No se pudo guardar el proyecto. Inténtalo de nuevo.',
  };

  @override
  String toString() => message;
}

/// Why saving the profile failed.
enum SeedlyProfileError { sessionExpired, saveFailed }

class SeedlyProfileException implements Exception {
  const SeedlyProfileException(this.reason);

  final SeedlyProfileError reason;

  /// Ready to show.
  String get message => switch (reason) {
    SeedlyProfileError.sessionExpired =>
      'Tu sesión expiró. Vuelve a iniciar sesión.',
    SeedlyProfileError.saveFailed => 'Inténtalo de nuevo en un momento.',
  };

  @override
  String toString() => message;
}
