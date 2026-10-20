/// Shared by the login and sign-up forms so both accept the same emails.
String? seedlyEmailError(String? value) {
  final email = value?.trim() ?? '';
  final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  return valid ? null : 'Ingresa un correo válido';
}
