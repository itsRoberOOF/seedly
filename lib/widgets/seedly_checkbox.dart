import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Figma "Checkbox" (Type=Icon): a 24px box with radius 8.
///
/// States, as in Figma: unchecked has a green border, [placeholder] a grey
/// one (nothing to check yet), hovered or pressed fills pale green, and
/// checked fills green with a white tick. It has a 48px tap target.
class SeedlyCheckbox extends StatefulWidget {
  const SeedlyCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = false,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool placeholder;
  final String? semanticLabel;

  @override
  State<SeedlyCheckbox> createState() => _SeedlyCheckboxState();
}

class _SeedlyCheckboxState extends State<SeedlyCheckbox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    return Semantics(
      checked: widget.value,
      enabled: onChanged != null,
      label: widget.semanticLabel,
      child: InkResponse(
        onTap: onChanged == null ? null : () => onChanged(!widget.value),
        onHover: (hovered) => setState(() => _hovered = hovered),
        onHighlightChanged: (pressed) => setState(() => _hovered = pressed),
        radius: 20,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: SeedlyCheckboxBox(
              value: widget.value,
              placeholder: widget.placeholder,
              hovered: _hovered && onChanged != null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 24px box alone, for rows that handle the tap themselves.
class SeedlyCheckboxBox extends StatelessWidget {
  const SeedlyCheckboxBox({
    super.key,
    required this.value,
    this.placeholder = false,
    this.hovered = false,
  });

  final bool value;
  final bool placeholder;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final brand = SeedlyPalette.primary[500]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['sm']!),
        color: value
            ? brand
            : hovered
            ? SeedlyPalette.primary[50]
            : null,
        border: value
            ? null
            : Border.all(
                color: placeholder && !hovered
                    ? SeedlyPalette.neutral[500]!
                    : brand,
                width: 1.5,
              ),
      ),
      child: value
          ? SvgPicture.asset('assets/images/icon_check.svg', width: 20)
          : null,
    );
  }
}

/// Figma "Checkbox" (Type=Icon + Text): the box beside a label and an
/// optional time. Tapping anywhere on the row toggles it.
class SeedlyCheckboxTile extends StatelessWidget {
  const SeedlyCheckboxTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.time,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Figma's "Time" property: shown under the label with a clock.
  final String? time;

  @override
  Widget build(BuildContext context) {
    return _CheckboxRow(
      label: label,
      value: value,
      onChanged: onChanged,
      time: time,
    );
  }
}

/// Figma "Checkbox" (Type=Card): the Icon + Text row inside a card. Checked
/// cards turn grey and flat. [actions] fill Figma's three-dot menu.
class SeedlyCheckboxCard extends StatelessWidget {
  const SeedlyCheckboxCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.time,
    this.actions,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? time;
  final List<SeedlyCardAction>? actions;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['sm']!);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: value ? SeedlyPalette.neutral[200] : SeedlyPalette.neutral[50],
        borderRadius: radius,
        border: value ? null : Border.all(color: SeedlyPalette.border),
        boxShadow: value ? null : SeedlyShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: _CheckboxRow(
                label: label,
                value: value,
                onChanged: onChanged,
                time: time,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  actions == null ? 16 : 4,
                  12,
                ),
              ),
            ),
            if (actions case final actions?)
              PopupMenuButton<SeedlyCardAction>(
                tooltip: 'Más opciones',
                icon: SvgPicture.asset(
                  'assets/images/icon_more_vert.svg',
                  width: 20,
                  height: 20,
                ),
                color: SeedlyPalette.neutral[50],
                onSelected: (action) => action.onSelected(),
                itemBuilder: (context) => [
                  for (final action in actions)
                    PopupMenuItem(value: action, child: Text(action.label)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// An entry of [SeedlyCheckboxCard]'s three-dot menu.
class SeedlyCardAction {
  const SeedlyCardAction(this.label, this.onSelected);

  final String label;
  final VoidCallback onSelected;
}

class _CheckboxRow extends StatefulWidget {
  const _CheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.time,
    this.padding = EdgeInsets.zero,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? time;
  final EdgeInsets padding;

  @override
  State<_CheckboxRow> createState() => _CheckboxRowState();
}

class _CheckboxRowState extends State<_CheckboxRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    final grey = SeedlyPalette.neutral[600]!;
    return Semantics(
      checked: widget.value,
      enabled: onChanged != null,
      label: widget.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged(!widget.value),
        onHover: (hovered) => setState(() => _hovered = hovered),
        onHighlightChanged: (pressed) => setState(() => _hovered = pressed),
        child: Padding(
          padding: widget.padding,
          child: Row(
            spacing: 12,
            children: [
              SeedlyCheckboxBox(
                value: widget.value,
                hovered: _hovered && onChanged != null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: widget.value ? grey : SeedlyPalette.neutral[850],
                      ),
                    ),
                    // Figma hides the time once the task is done.
                    if (widget.time != null && !widget.value)
                      Row(
                        spacing: 2,
                        children: [
                          SvgPicture.asset(
                            'assets/images/icon_clock.svg',
                            width: 12,
                            height: 12,
                          ),
                          Text(
                            widget.time!,
                            style: TextStyle(
                              fontSize: 10,
                              height: 14 / 10,
                              color: grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
