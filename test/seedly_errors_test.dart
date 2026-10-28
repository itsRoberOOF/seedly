import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';

void main() {
  group('SeedlyAuthException', () {
    const texts = {
      SeedlyAuthError.invalidCredentials: 'Correo o contraseña incorrectos',
      SeedlyAuthError.invalidEmail: 'Ingresa un correo válido',
      SeedlyAuthError.userDisabled: 'Esta cuenta está deshabilitada',
      SeedlyAuthError.tooManyRequests:
          'Demasiados intentos. Espera un momento.',
      SeedlyAuthError.network: 'Sin conexión. Revisa tu internet.',
      SeedlyAuthError.accountExistsWithDifferentCredential:
          'Este correo ya usa otro método de acceso',
      SeedlyAuthError.methodNotAllowed:
          'Este método de acceso no está habilitado',
      SeedlyAuthError.googleFailed:
          'No se pudo iniciar sesión con Google. Inténtalo de nuevo.',
      SeedlyAuthError.googleConfig: 'Google no pudo confirmar tu cuenta. Inténtalo de nuevo o inicia sesión con tu correo.',
      SeedlyAuthError.signInFailed:
          'No se pudo iniciar sesión. Inténtalo de nuevo.',
      SeedlyAuthError.signOutFailed: 'Inténtalo de nuevo en un momento.',
      SeedlyAuthError.emailInUse: 'Este correo ya tiene una cuenta',
      SeedlyAuthError.weakPassword: 'Elige una contraseña más segura',
      SeedlyAuthError.signUpFailed: 'Inténtalo de nuevo en un momento.',
      SeedlyAuthError.resetFailed: 'Inténtalo de nuevo en un momento.',
    };

    test('the table covers every reason', () {
      expect(texts.keys, unorderedEquals(SeedlyAuthError.values));
    });

    for (final MapEntry(key: reason, value: text) in texts.entries) {
      test('${reason.name} reads "$text"', () {
        final error = SeedlyAuthException(reason);
        expect(error.reason, reason);
        expect(error.message, text);
        expect(error.toString(), text);
      });
    }
  });

  group('SeedlyProfileException', () {
    const texts = {
      SeedlyProfileError.sessionExpired:
          'No se pudo guardar tu perfil. Cierra sesión y vuelve a entrar; si '
          'sigue fallando, inténtalo más tarde.',
      SeedlyProfileError.saveFailed: 'Inténtalo de nuevo en un momento.',
    };

    test('the table covers every reason', () {
      expect(texts.keys, unorderedEquals(SeedlyProfileError.values));
    });

    for (final MapEntry(key: reason, value: text) in texts.entries) {
      test('$reason says its own text', () {
        expect(SeedlyProfileException(reason).message, text);
      });
    }
  });

  group('SeedlyProjectException', () {
    const texts = {
      SeedlyProjectError.sessionExpired:
          'Tu sesión expiró. Vuelve a iniciar sesión.',
      SeedlyProjectError.saveFailed:
          'No se pudo guardar el proyecto. Inténtalo de nuevo.',
    };

    test('the table covers every reason', () {
      expect(texts.keys, unorderedEquals(SeedlyProjectError.values));
    });

    for (final MapEntry(key: reason, value: text) in texts.entries) {
      test('${reason.name} reads "$text"', () {
        final error = SeedlyProjectException(reason);
        expect(error.reason, reason);
        expect(error.message, text);
        expect(error.toString(), text);
      });
    }
  });
}
