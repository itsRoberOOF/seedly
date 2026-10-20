import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An import or export directive: the file that wrote it and the URI it used.
typedef _Directive = ({String file, String uri});

final _directivePattern = RegExp(
  r'''^\s*(?:import|export)\s+(['"])(.+?)\1''',
  multiLine: true,
);

/// Backend SDKs that only the data layer may touch.
const _backendPackages = [
  'package:firebase_',
  'package:cloud_firestore',
  'package:google_sign_in',
];

/// Every import/export directive of every Dart file under lib/, with paths
/// relative to the package root and always separated by `/`.
List<_Directive> _readDirectives() {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      for (final match in _directivePattern.allMatches(file.readAsStringSync()))
        (file: file.path.replaceAll(r'\', '/'), uri: match.group(2)!),
  ];
}

/// The lib/ path [directive] points at, or null when it points outside the
/// package.
String? _libPathOf(_Directive directive) {
  const ownPackage = 'package:seedly/';
  final uri = directive.uri;
  if (uri.startsWith(ownPackage)) {
    return 'lib/${uri.substring(ownPackage.length)}';
  }
  if (Uri.parse(uri).hasScheme) return null;
  return Uri.parse(directive.file).resolve(uri).path;
}

void _expectNone(List<_Directive> offenders, String rule) {
  if (offenders.isEmpty) return;
  fail(
    '$rule\n'
    '${offenders.map((d) => '  ${d.file} uses ${d.uri}').join('\n')}',
  );
}

void main() {
  final directives = _readDirectives();

  test('the walk finds the app sources', () {
    expect(directives, isNotEmpty);
  });

  test('only the data layer, main and firebase_options import the backend', () {
    _expectNone([
      for (final d in directives)
        if (!d.file.startsWith('lib/data/') &&
            d.file != 'lib/main.dart' &&
            d.file != 'lib/firebase_options.dart' &&
            _backendPackages.any(d.uri.startsWith))
          d,
    ], 'Backend SDK imported outside lib/data/:');
  });

  test('only main reaches into lib/data/ from outside it', () {
    _expectNone([
      for (final d in directives)
        if (!d.file.startsWith('lib/data/') &&
            d.file != 'lib/main.dart' &&
            (_libPathOf(d)?.startsWith('lib/data/') ?? false))
          d,
    ], 'lib/data/ referenced outside lib/data/ and lib/main.dart:');
  });
}
