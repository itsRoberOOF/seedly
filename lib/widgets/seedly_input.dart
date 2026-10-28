import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

enum SeedlyInputVariant { outline, filled }

enum SeedlyInputSize { medium, large }

/// Reusable labelled Input with focus, error, disabled and password states.
/// An invalid value only turns the border danger-600: the form shows the
/// [validator] messages in an alert instead of under the field.
class SeedlyInput extends StatefulWidget {
  const SeedlyInput({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.initialValue,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.password = false,
    this.enabled = true,
    this.variant = SeedlyInputVariant.outline,
    this.size = SeedlyInputSize.large,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.prefixAsset,
    this.suffixAsset,
    this.fieldHeight,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;

  /// The starting text when there is no [controller].
  final String? initialValue;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool password;
  final bool enabled;
  final SeedlyInputVariant variant;
  final SeedlyInputSize size;

  /// Multi-line inputs such as a description: Figma's is 3 lines tall.
  final int? minLines;
  final int? maxLines;

  /// Caps the text without showing a counter.
  final int? maxLength;
  final TextCapitalization textCapitalization;

  /// Shows the value in the normal outline look without letting it be edited.
  final bool readOnly;

  /// SVG drawn inside the box before the text, such as the "@" of a handle.
  final String? prefixAsset;

  /// SVG drawn in the box's lower right corner, such as a textarea's expand
  /// icon. Only for multi-line inputs given a [fieldHeight].
  final String? suffixAsset;

  /// Fixes the box height; the text then fills it from the top, like Figma's
  /// Textarea.
  final double? fieldHeight;

  @override
  State<SeedlyInput> createState() => _SeedlyInputState();
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

class _SeedlyInputState extends State<SeedlyInput> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final border = _ShadowedOutlineBorder(
      borderRadius: BorderRadius.circular(SeedlyMetrics.radii['lg']!),
      borderSide: const BorderSide(color: SeedlyPalette.border),
    );
    final fixedHeight = widget.fieldHeight != null;
    final suffix = widget.suffixAsset;
    final prefix = widget.prefixAsset;
    Widget field = TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      validator: widget.validator,
      // An empty error keeps the red border without taking any space
      // under the field.
      errorBuilder: (context, message) => const SizedBox.shrink(),
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      obscureText: widget.password && _obscured,
      expands: fixedHeight,
      textAlignVertical: fixedHeight ? TextAlignVertical.top : null,
      minLines: fixedHeight ? null : widget.minLines,
      maxLines: fixedHeight
          ? null
          : widget.password
          ? 1
          : widget.maxLines,
      maxLength: widget.maxLength,
      // No counter under the field, even with maxLength.
      buildCounter: _noCounter,
      textCapitalization: widget.textCapitalization,
      style: const TextStyle(fontSize: 16, height: 24 / 16),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: SeedlyPalette.neutral[600], fontSize: 16),
        filled: true,
        fillColor: widget.enabled
            ? widget.variant == SeedlyInputVariant.outline
                  ? Colors.white
                  : SeedlyPalette.neutral[200]
            : SeedlyPalette.neutral[150],
        contentPadding: EdgeInsets.fromLTRB(
          12,
          widget.size == SeedlyInputSize.large ? 12 : 8,
          // Keeps the text clear of the icon in the corner.
          suffix != null ? 12 + 20 + 12 : 12,
          widget.size == SeedlyInputSize.large ? 12 : 8,
        ),
        prefixIcon: prefix != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: SvgPicture.asset(prefix, width: 24, height: 24),
              )
            : null,
        prefixIconConstraints: const BoxConstraints(),
        isDense: true,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(
            color: SeedlyPalette.primary[500]!,
            width: 1.5,
          ),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: SeedlyPalette.danger[600]!),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: SeedlyPalette.danger[600]!, width: 1.5),
        ),
        suffixIcon: widget.password
            ? IconButton(
                tooltip: _obscured
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: _obscured
                    ? SvgPicture.asset(
                        'assets/images/login_eye.svg',
                        width: 24,
                        height: 24,
                      )
                    : Icon(
                        Icons.visibility_off_outlined,
                        size: 20,
                        color: SeedlyPalette.neutral[600],
                      ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
      ),
    );
    if (fixedHeight) {
      field = SizedBox(
        height: widget.fieldHeight,
        child: Stack(
          children: [
            Positioned.fill(child: field),
            if (suffix != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: SvgPicture.asset(suffix, width: 20, height: 20),
                ),
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

/// Outline border that also paints the Figma drop shadow. Painting it here
/// keeps the shadow on the input box only, never behind the error message.
class _ShadowedOutlineBorder extends OutlineInputBorder {
  const _ShadowedOutlineBorder({super.borderSide, super.borderRadius});

  static const _shadow = BoxShadow(
    color: Color(0x1F000000),
    offset: Offset(0, 2),
    blurRadius: 4,
    spreadRadius: -2,
  );

  @override
  _ShadowedOutlineBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => _ShadowedOutlineBorder(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  // Keep the shadow while focus and error states animate between borders.
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      a is OutlineInputBorder ? _lerp(a, this, t) : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is OutlineInputBorder ? _lerp(this, b, t) : super.lerpTo(b, t);

  static _ShadowedOutlineBorder _lerp(
    OutlineInputBorder a,
    OutlineInputBorder b,
    double t,
  ) => _ShadowedOutlineBorder(
    borderSide: BorderSide.lerp(a.borderSide, b.borderSide, t),
    borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t)!,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final box = borderRadius.toRRect(rect);
    // The fill is already painted, so only draw the shadow outside the box.
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(_shadow.blurRadius * 2)),
          Path()..addRRect(box),
        ),
      )
      ..drawRRect(
        box.shift(_shadow.offset).inflate(_shadow.spreadRadius),
        _shadow.toPaint(),
      )
      ..restore();
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }
}
