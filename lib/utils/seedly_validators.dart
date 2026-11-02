/// Shared by the login and sign-up forms so both accept the same emails.
String? seedlyEmailError(String? value) {
  final email = value?.trim() ?? '';
  final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  return valid ? null : 'Ingresa un correo válido';
}

/// The longest bio `firestore.rules` accepts, counted in UTF-16 code units
/// (`String.length`), as the rules' `size()` does: an emoji takes two.
const seedlyBioMaxLength = 160;

const seedlyBioTooLong = 'La bio admite hasta $seedlyBioMaxLength caracteres.';

/// Null when [bio] fits what the rules accept.
String? seedlyBioError(String bio) =>
    bio.length <= seedlyBioMaxLength ? null : seedlyBioTooLong;

/// The longest display name the profile accepts.
const seedlyNameMaxLength = 50;

/// Null when [name] (already trimmed) can be the account's display name.
String? seedlyNameError(String name) {
  if (name.isEmpty) return 'Ingresa tu nombre';
  return name.length <= seedlyNameMaxLength
      ? null
      : 'El nombre admite hasta $seedlyNameMaxLength caracteres.';
}

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

/// Up to two capital letters for an avatar: the first letters of the first
/// two words of [name], or the first letter of [email] when there is no name.
/// Empty when neither has a letter or digit to show.
String seedlyInitials(String? name, String? email) {
  final letter = RegExp(r'[\p{L}\p{N}]', unicode: true);
  String initialOf(String word) => letter.firstMatch(word)?.group(0) ?? '';
  final fromName = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .map(initialOf)
      .where((initial) => initial.isNotEmpty)
      .take(2)
      .join();
  if (fromName.isNotEmpty) return fromName.toUpperCase();
  return initialOf((email ?? '').split('@').first).toUpperCase();
}
