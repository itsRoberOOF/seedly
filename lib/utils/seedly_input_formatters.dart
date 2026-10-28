import 'package:flutter/services.dart';

/// Caps the text at [maxLength] UTF-16 code units, which is what Firestore
/// rules count with `size()` (an emoji is two), instead of the grapheme count
/// Flutter's `maxLength` uses. Never cuts a surrogate pair in half, so pasted
/// text is shortened to the last whole character that fits.
class SeedlyUtf16LengthFormatter extends TextInputFormatter {
  const SeedlyUtf16LengthFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length <= maxLength) return newValue;
    var end = maxLength;
    final splitsPair =
        end > 0 &&
        _isHighSurrogate(text.codeUnitAt(end - 1)) &&
        _isLowSurrogate(text.codeUnitAt(end));
    if (splitsPair) end--;
    int clamp(int offset) => offset < 0 ? offset : offset.clamp(0, end);
    return TextEditingValue(
      text: text.substring(0, end),
      selection: TextSelection(
        baseOffset: clamp(newValue.selection.baseOffset),
        extentOffset: clamp(newValue.selection.extentOffset),
      ),
    );
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}
