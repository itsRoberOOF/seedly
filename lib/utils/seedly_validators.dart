/// Shared by the login and sign-up forms so both accept the same emails.
String? seedlyEmailError(String? value) {
  final email = value?.trim() ?? '';
  final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  return valid ? null : 'Ingresa un correo válido';
}

/// The longest bio `firestore.rules` accepts.
const seedlyBioMaxLength = 160;

const seedlyUsernameMinLength = 3;
const seedlyUsernameMaxLength = 20;

/// What is stored for a typed handle: no leading "@" (the field shows its own)
/// or spaces around it, and lowercase.
String seedlyNormalizeUsername(String value) =>
    value.trim().replaceFirst(RegExp(r'^@+'), '').trim().toLowerCase();

/// Null when [normalized] (see [seedlyNormalizeUsername]) can be stored. Empty
/// is fine: it clears the handle.
String? seedlyUsernameError(String normalized) {
  if (normalized.isEmpty) return null;
  final valid =
      normalized.length >= seedlyUsernameMinLength &&
      normalized.length <= seedlyUsernameMaxLength &&
      RegExp(r'^[a-z0-9_]+$').hasMatch(normalized);
  return valid
      ? null
      : 'El usuario debe tener de $seedlyUsernameMinLength a '
            '$seedlyUsernameMaxLength caracteres: letras, números o guion '
            'bajo.';
}
