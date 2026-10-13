import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

enum SeedlyButtonVariant { filled, outline, text }

enum SeedlyButtonSize { medium, giant }

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
  });

  final String label;
  final VoidCallback? onPressed;
  final SeedlyButtonVariant variant;
  final SeedlyButtonSize size;
  final Widget? leading;
  final Widget? trailing;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final giant = size == SeedlyButtonSize.giant;
    final filled = variant == SeedlyButtonVariant.filled;
    final textOnly = variant == SeedlyButtonVariant.text;
    final color = SeedlyPalette.primary[500]!;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(
          0,
          textOnly
              ? 20
              : giant
              ? 60
              : 44,
        ),
      ),
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
        if (states.contains(WidgetState.disabled)) {
          return SeedlyPalette.neutral[600];
        }
        return filled ? Colors.white : color;
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
          fontSize: giant ? 18 : 14,
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
