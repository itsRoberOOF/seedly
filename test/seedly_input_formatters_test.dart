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
}
