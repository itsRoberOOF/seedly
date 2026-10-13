import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';
import 'seedly_checkbox.dart';

/// Figma "Checkbox" (Type=Card) as an editable task row: a [SeedlyCheckbox]
/// beside an inline text field. The box shows Figma's Placeholder state
/// while the row is empty, and a [done] task looks like the Check state.
/// [onRemove] adds a remove button for the extra rows of a full project.
class SeedlyTaskField extends StatelessWidget {
  const SeedlyTaskField({
    super.key,
    required this.controller,
    this.done = false,
    this.onDoneChanged,
    this.validator,
    this.onRemove,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final bool done;
  final ValueChanged<bool>? onDoneChanged;
  final String? Function(String?)? validator;
  final VoidCallback? onRemove;
  final bool autofocus;
  final TextInputAction textInputAction;

  static const maxLength = 200;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['sm']!);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    // A done task is flat and grey, like Figma's checked card.
    final idle = done
        ? border(Colors.transparent)
        : border(SeedlyPalette.border);
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: done ? null : SeedlyShadows.card,
        ),
        child: TextFormField(
          controller: controller,
          validator: validator,
          autofocus: autofocus,
          maxLength: maxLength,
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => null,
          textInputAction: textInputAction,
          textCapitalization: TextCapitalization.sentences,
          // Errors go to the form's alert; the border alone marks the field.
          errorBuilder: (context, message) => const SizedBox.shrink(),
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: done
                ? SeedlyPalette.neutral[600]
                : SeedlyPalette.neutral[850],
          ),
          decoration: InputDecoration(
            hintText: '¿Cuál es la tarea?',
            hintStyle: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: SeedlyPalette.neutral[600],
            ),
            filled: true,
            fillColor: done
                ? SeedlyPalette.neutral[200]
                : SeedlyPalette.neutral[50],
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            // 4px + half of the 48px tap target puts the box 16px in and
            // leaves Figma's 12px gap before the text.
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: SeedlyCheckbox(
                value: done,
                placeholder: value.text.trim().isEmpty,
                semanticLabel: 'Tarea hecha',
                onChanged: onDoneChanged,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(),
            suffixIcon: onRemove == null
                ? const SizedBox(width: 16)
                : IconButton(
                    tooltip: 'Quitar tarea',
                    onPressed: onRemove,
                    icon: SvgPicture.asset(
                      'assets/images/alert_cancel.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        SeedlyPalette.neutral[600]!,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
            suffixIconConstraints: onRemove == null
                ? const BoxConstraints()
                : null,
            border: idle,
            enabledBorder: idle,
            focusedBorder: border(SeedlyPalette.primary[500]!, 1.5),
            errorBorder: border(SeedlyPalette.danger[600]!),
            focusedErrorBorder: border(SeedlyPalette.danger[600]!, 1.5),
          ),
        ),
      ),
    );
  }
}
