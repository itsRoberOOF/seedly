import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Tabs of the Figma "Menu - App" component; each one is a variant.
enum SeedlyMenuTab {
  inicio('Inicio', 'assets/images/menu_home.svg'),
  proyectos('Proyectos', 'assets/images/menu_projects.svg'),
  riego('Riego', 'assets/images/menu_watering.svg'),
  perfil('Mi perfil', 'assets/images/menu_profile.svg');

  const SeedlyMenuTab(this.label, this.icon);

  final String label;
  final String icon;
}

/// Figma "Menu - App": bottom bar with four tabs and a central add button.
/// [active] picks the variant; only tabs in [enabledTabs] respond to taps.
class SeedlyMenu extends StatelessWidget {
  const SeedlyMenu({
    super.key,
    required this.active,
    this.onSelected,
    this.enabledTabs = const {...SeedlyMenuTab.values},
    this.onAdd,
  });

  final SeedlyMenuTab active;
  final ValueChanged<SeedlyMenuTab>? onSelected;
  final Set<SeedlyMenuTab> enabledTabs;

  /// The add button only responds when set.
  final VoidCallback? onAdd;

  /// Extra padding above and below the tabs, over Figma's 16px.
  static const _extraTop = 4.0;
  static const _extraBottom = 12.0;

  /// Left and right padding.
  static const _side = 8.0;

  /// Space on each side of the add button.
  static const _addGap = 16.0;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(24));
    // Equal-width slots keep the add button centred whatever the label
    // widths; Figma's space-between pushed it off centre.
    Widget tab(SeedlyMenuTab tab) => Expanded(
      child: _MenuTab(
        tab: tab,
        active: tab == active,
        onTap: enabledTabs.contains(tab) && onSelected != null
            ? () => onSelected!(tab)
            : null,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        borderRadius: radius,
      ),
      foregroundDecoration: const BoxDecoration(
        borderRadius: radius,
        border: Border.fromBorderSide(BorderSide(color: SeedlyPalette.border)),
      ),
      // Taller than Figma's 16px top and bottom padding, by request: the
      // add button reaches lower than the labels and looked stuck to the
      // system bar. The bar's inset replaces Figma's 16px below instead of
      // adding to it, and the extra space goes on top of either. Sides are
      // narrower than Figma's 24px so the outer tabs sit near the edges.
      padding: EdgeInsets.fromLTRB(
        _side,
        16 + _extraTop,
        _side,
        math.max(16, MediaQuery.paddingOf(context).bottom) + _extraBottom,
      ),
      child: Row(
        children: [
          tab(SeedlyMenuTab.inicio),
          tab(SeedlyMenuTab.proyectos),
          // Lets the add button breathe and keeps the inner labels off it.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _addGap),
            child: _AddButton(onPressed: onAdd),
          ),
          tab(SeedlyMenuTab.riego),
          tab(SeedlyMenuTab.perfil),
        ],
      ),
    );
  }
}

class _MenuTab extends StatelessWidget {
  const _MenuTab({required this.tab, required this.active, this.onTap});

  final SeedlyMenuTab tab;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? SeedlyPalette.primary[500]!
        : SeedlyPalette.neutral[600]!;
    return Semantics(
      button: true,
      selected: active,
      enabled: onTap != null,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              tab.icon,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 6),
            // Shrinks rather than overflowing when a slot is narrower than
            // its label, as on 320px phones.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Agregar',
      excludeSemantics: true,
      child: Material(
        color: SeedlyPalette.primary[500],
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SvgPicture.asset(
              'assets/images/menu_plus.svg',
              width: 24,
              height: 24,
            ),
          ),
        ),
      ),
    );
  }
}
