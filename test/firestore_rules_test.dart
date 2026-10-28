import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // No rules emulator here, so this only pins the profile rules' text.
  final rules = File('firestore.rules').readAsStringSync();
  final profile = RegExp(
    r'function validProfile\(\) \{.*?\n    \}',
    dotAll: true,
  ).firstMatch(rules)!.group(0)!;

  test('validProfile allows username and bio with their limits', () {
    final keys = RegExp(
      r'hasOnly\(\s*\[(.*?)\]',
      dotAll: true,
    ).firstMatch(profile)!.group(1)!;
    expect(keys, contains("'username'"));
    expect(keys, contains("'bio'"));
    expect(profile, contains('>= 3'));
    expect(profile, contains('<= 20'));
    expect(profile, contains(r"'^[a-z0-9_]+$'"));
    expect(profile, contains('<= 160'));
  });

  test('create requires a fresh lastSignInAt', () {
    expect(
      rules,
      contains(
        'allow create: if isOwner(uid) && validProfile()\n'
        '        && request.resource.data.lastSignInAt == request.time;',
      ),
    );
  });

  test('update stamps lastSignInAt or leaves it as it was', () {
    final update = RegExp(
      r'allow update: if isOwner\(uid\).*?;',
      dotAll: true,
    ).firstMatch(rules)!.group(0)!;
    expect(update, contains('validProfile()'));
    expect(
      update,
      contains('request.resource.data.lastSignInAt == request.time'),
    );
    expect(
      update,
      contains(
        'request.resource.data.lastSignInAt == resource.data.lastSignInAt',
      ),
    );
  });
}
