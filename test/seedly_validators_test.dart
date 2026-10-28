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

  test('the bio limit matches firestore.rules', () {
    expect(seedlyBioMaxLength, 160);
  });
}
