import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

/// Figma "Segment Control" (Style=Card): equal-width pill options where the
/// selected one is filled with the brand green.
class SeedlySegmentedControl<T> extends StatelessWidget {
  const SeedlySegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// Values in display order, each with its label.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    const pill = BorderRadius.all(Radius.circular(999));
    return Container(
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        borderRadius: pill,
        boxShadow: SeedlyShadows.card,
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: Material(
                  color: value == selected
                      ? SeedlyPalette.primary[500]
                      : Colors.transparent,
                  borderRadius: pill,
                  child: InkWell(
                    borderRadius: pill,
                    onTap: value == selected ? null : () => onChanged(value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 24 / 16,
                          fontWeight: FontWeight.w500,
                          color: value == selected
                              ? SeedlyPalette.neutral[50]
                              : SeedlyPalette.neutral[850],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
