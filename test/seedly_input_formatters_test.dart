import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/utils/seedly_input_formatters.dart';

const _formatter = SeedlyUtf16LengthFormatter(160);

TextEditingValue _format(String text, {int? cursor}) =>
    _formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor ?? text.length),
      ),
    );

void main() {
  test('keeps 160 ASCII characters intact', () {
    final text = 'a' * 160;
    expect(_format(text).text, text);
  });

  test('keeps 80 emojis, which are 160 code units', () {
    final text = '😀' * 80;
    expect(text.length, 160);
    expect(_format(text).text, text);
  });

  test('cuts 81 emojis to 80, never in the middle of a pair', () {
    final result = _format('😀' * 81).text;
    expect(result, '😀' * 80);
    expect(result.length, 160);
  });

  test('cuts 150 letters and 10 emojis to 150 letters and 5 emojis', () {
    final result = _format('a' * 150 + '😀' * 10).text;
    expect(result, 'a' * 150 + '😀' * 5);
    expect(result.length, 160);
  });

  test('keeps a pair that ends exactly at the limit', () {
    expect(_format('a' * 158 + '😀' + 'b').text, 'a' * 158 + '😀');
  });

  test('drops a pair that would straddle the limit', () {
    final result = _format('a' * 159 + '😀').text;
    expect(result, 'a' * 159);
  });

  test('counts a combining accent as two code units', () {
    const accented = 'e\u0301';
    expect(accented.length, 2);
    expect(_format(accented * 80).text, accented * 80);
    expect(_format(accented * 81).text, accented * 80);
  });

  test('truncates pasted long text without splitting emojis', () {
    final pasted = 'Hola 😀 ' * 40;
    final result = _format(pasted).text;
    expect(result.length, lessThanOrEqualTo(160));
    expect(pasted.startsWith(result), isTrue);
    final last = result.codeUnitAt(result.length - 1);
    expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
  });

  test('leaves short text unchanged, selection included', () {
    const value = TextEditingValue(
      text: 'Hola',
      selection: TextSelection(baseOffset: 1, extentOffset: 3),
    );
    expect(_formatter.formatEditUpdate(TextEditingValue.empty, value), value);
  });

  test('keeps the cursor and selection inside the cut text', () {
    final text = 'a' * 200;
    final cursorAtEnd = _format(text);
    expect(cursorAtEnd.selection, const TextSelection.collapsed(offset: 160));

    final selected = _formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: const TextSelection(baseOffset: 10, extentOffset: 190),
      ),
    );
    expect(selected.selection.baseOffset, 10);
    expect(selected.selection.extentOffset, 160);
  });

  test('the cursor of a cut emoji text stays inside it', () {
    final result = _format('😀' * 81);
    expect(result.selection.extentOffset, 160);
  });

  group('typing at a full field', () {
    TextEditingValue type(TextEditingValue old, String text, int cursor) =>
        _formatter.formatEditUpdate(
          old,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: cursor),
          ),
        );

    test('in the middle rejects the key and keeps the old value', () {
      final old = TextEditingValue(
        text: 'a' * 160,
        selection: const TextSelection.collapsed(offset: 10),
      );
      final text = '${'a' * 10}X${'a' * 150}';
      expect(text.length, 161);
      final result = type(old, text, 11);
      expect(result, old);
      expect(result.text, 'a' * 160);
    });

    test('at the end rejects the key', () {
      final old = TextEditingValue(
        text: 'a' * 160,
        selection: const TextSelection.collapsed(offset: 160),
      );
      expect(type(old, '${'a' * 160}X', 161), old);
    });

    test('a field full of emojis rejects one more character', () {
      final old = TextEditingValue(
        text: '😀' * 80,
        selection: const TextSelection.collapsed(offset: 160),
      );
      expect(type(old, '${'😀' * 80}X', 161), old);
    });

    test('replacing a selection that makes room is allowed', () {
      final old = TextEditingValue(
        text: 'a' * 160,
        selection: const TextSelection(baseOffset: 10, extentOffset: 20),
      );
      final text = '${'a' * 10}X${'a' * 140}';
      expect(text.length, 151);
      expect(type(old, text, 11).text, text);
    });

    test('replacing a selection with a longer paste still cuts', () {
      final old = TextEditingValue(
        text: 'a' * 160,
        selection: const TextSelection(baseOffset: 10, extentOffset: 20),
      );
      final text = '${'a' * 10}${'b' * 30}${'a' * 140}';
      final result = type(old, text, 40);
      expect(result.text.length, 160);
      expect(text.startsWith(result.text), isTrue);
    });

    test('pasting long text with room left cuts without splitting emojis', () {
      final old = TextEditingValue(
        text: 'a' * 100,
        selection: const TextSelection.collapsed(offset: 100),
      );
      final result = type(old, 'a' * 100 + '😀' * 40, 180);
      expect(result.text, 'a' * 100 + '😀' * 30);
    });
  });
}
