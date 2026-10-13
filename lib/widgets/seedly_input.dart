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
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.password = false,
    this.enabled = true,
    this.variant = SeedlyInputVariant.outline,
    this.size = SeedlyInputSize.large,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool password;
  final bool enabled;
  final SeedlyInputVariant variant;
  final SeedlyInputSize size;

  @override
  State<SeedlyInput> createState() => _SeedlyInputState();
}

class _SeedlyInputState extends State<SeedlyInput> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final border = _ShadowedOutlineBorder(
      borderRadius: BorderRadius.circular(SeedlyMetrics.radii['lg']!),
      borderSide: const BorderSide(color: SeedlyPalette.border),
    );
    final field = TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      // An empty error keeps the red border without taking any space
      // under the field.
      errorBuilder: (context, message) => const SizedBox.shrink(),
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      obscureText: widget.password && _obscured,
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: widget.size == SeedlyInputSize.large ? 12 : 8,
        ),
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
