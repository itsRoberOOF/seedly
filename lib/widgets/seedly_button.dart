import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

enum SeedlyButtonVariant { filled, outline, text }

enum SeedlyButtonSize { small, medium, large, giant }

/// Reusable Figma Button variants: Filled, Outline and Only Text.
class SeedlyButton extends StatelessWidget {
  const SeedlyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = SeedlyButtonVariant.filled,
    this.size = SeedlyButtonSize.giant,
    this.leading,
    this.trailing,
    this.expand = false,
    this.foreground,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final SeedlyButtonVariant variant;
  final SeedlyButtonSize size;
  final Widget? leading;
  final Widget? trailing;
  final bool expand;

  /// Text and icon colour for outline and text buttons, such as the grey
  /// "Cancelar"; filled buttons stay white on green.
  final Color? foreground;

  /// Replaces the green, such as the red outline of "Cerrar sesión".
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final filled = variant == SeedlyButtonVariant.filled;
    final textOnly = variant == SeedlyButtonVariant.text;
    final color = this.color ?? SeedlyPalette.primary[500]!;
    final (height, fontSize) = switch (size) {
      SeedlyButtonSize.small => (32.0, 12.0),
      SeedlyButtonSize.medium => (44.0, 14.0),
      SeedlyButtonSize.large => (48.0, 16.0),
      SeedlyButtonSize.giant => (60.0, 18.0),
    };
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, textOnly ? 20 : height)),
      padding: WidgetStatePropertyAll(
        textOnly
            ? const EdgeInsets.symmetric(horizontal: 4)
            : const EdgeInsets.symmetric(horizontal: 16),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return filled ? SeedlyPalette.primary[150] : Colors.transparent;
        }
        return filled ? color : Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        // A disabled filled button keeps white text on its pale green.
        if (states.contains(WidgetState.disabled)) {
          return filled ? Colors.white : SeedlyPalette.neutral[600];
        }
        return filled ? Colors.white : foreground ?? color;
      }),
      side: textOnly || filled
          ? null
          : WidgetStatePropertyAll(BorderSide(color: color, width: 1.5)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SeedlyMetrics.radii['md']!),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: SeedlyTheme.fontFamily,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
    final button = filled
        ? FilledButton(onPressed: onPressed, style: style, child: content)
        : textOnly
        ? TextButton(onPressed: onPressed, style: style, child: content)
        : OutlinedButton(onPressed: onPressed, style: style, child: content);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
