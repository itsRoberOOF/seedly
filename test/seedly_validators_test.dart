import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/utils/seedly_validators.dart';

void main() {
  group('seedlyNormalizeUsername', () {
    test('drops the leading @, spaces and case', () {
      expect(seedlyNormalizeUsername(' @Rober '), 'rober');
      expect(seedlyNormalizeUsername('@@a'), 'a');
      expect(seedlyNormalizeUsername('@ Rober_1'), 'rober_1');
      expect(seedlyNormalizeUsername('a@b'), 'a@b');
      expect(seedlyNormalizeUsername('  '), '');
    });
  });

  group('seedlyUsernameError', () {
    test('accepts empty and 3 to 20 letters, digits or underscores', () {
      expect(seedlyUsernameError(''), isNull);
      expect(seedlyUsernameError('abc'), isNull);
      expect(seedlyUsernameError('rober_1'), isNull);
      expect(seedlyUsernameError('a' * 20), isNull);
    });

    test('rejects short, long and out-of-charset handles', () {
      expect(seedlyUsernameError('ab'), isNotNull);
      expect(seedlyUsernameError('a' * 21), isNotNull);
      expect(seedlyUsernameError('rober.x'), isNotNull);
      expect(seedlyUsernameError('josé'), isNotNull);
      expect(seedlyUsernameError('ñandú'), isNotNull);
      expect(seedlyUsernameError('a b c'), isNotNull);
    });

    test('accents are rejected after normalizing too', () {
      expect(seedlyUsernameError(seedlyNormalizeUsername('@José')), isNotNull);
    });
  });

  group('seedlyInitials', () {
    test('uses the first letter of up to two words', () {
      expect(seedlyInitials('Rober', null), 'R');
      expect(seedlyInitials('Rober Morán', null), 'RM');
      expect(seedlyInitials('Ana María de la Cruz', null), 'AM');
    });

    test('capitalizes and ignores extra spaces', () {
      expect(seedlyInitials('  rober   morán  ', null), 'RM');
    });

    test('falls back to the email, then to nothing', () {
      expect(seedlyInitials(null, 'ana@x.com'), 'A');
      expect(seedlyInitials('', 'ana@x.com'), 'A');
      expect(seedlyInitials('   ', 'ana@x.com'), 'A');
      expect(seedlyInitials(null, null), '');
      expect(seedlyInitials('', ''), '');
      expect(seedlyInitials('---', '@x.com'), '');
    });

    test('skips leading punctuation', () {
      expect(seedlyInitials('(ana) lópez', null), 'AL');
    });

    test('handles accents and digits', () {
      expect(seedlyInitials('ángel', null), 'Á');
      expect(seedlyInitials('3M Company', null), '3C');
      expect(seedlyInitials(null, '7up@x.com'), '7');
    });
  });

  test('the bio limit matches firestore.rules', () {
    expect(seedlyBioMaxLength, 250);
  });

  group('seedlyBioError', () {
    test('accepts up to 250 code units', () {
      expect(seedlyBioError(''), isNull);
      expect(seedlyBioError('a' * 250), isNull);
      expect(seedlyBioError('😀' * 125), isNull);
    });

    test('rejects 251 code units', () {
      expect(seedlyBioError('a' * 251), seedlyBioTooLong);
      expect(seedlyBioError('😀' * 125 + 'a'), seedlyBioTooLong);
      expect(seedlyBioError('😀' * 126), seedlyBioTooLong);
    });

    test('has the message for 250 characters', () {
      expect(seedlyBioTooLong, 'La bio admite hasta 250 caracteres.');
    });
  });
}
