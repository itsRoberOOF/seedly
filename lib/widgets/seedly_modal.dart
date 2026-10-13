import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Figma "Modal": bottom sheet with a drag handle, a content slot ([child])
/// and an optional round close button. Every Seedly modal is this base with
/// different content; open it with [showSeedlyModal].
class SeedlyModal extends StatelessWidget {
  const SeedlyModal({
    super.key,
    required this.child,
    this.showClose = true,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(24, 40, 24, 20),
    this.childScrolls = false,
  });

  /// The Figma "Content" slot.
  final Widget child;

  /// Set when [child] is its own scroll view, such as a `ListView.builder`
  /// for a long list: the modal then doesn't wrap it in another one and
  /// [child] applies [scrollPadding] itself. The modal takes its full height.
  final bool childScrolls;

  /// Figma's "Button" property: the round close button under the content.
  final bool showClose;

  /// Defaults to closing the modal without a result.
  final VoidCallback? onClose;

  /// Padding around [child]: Figma's slot padding with 24px sides instead of
  /// 40, which left too little width on phones narrower than the 440px frame.
  /// The bottom part always stays clear, even while the content scrolls.
  final EdgeInsets padding;

  /// Space inside the scroll view so the last card's shadow isn't clipped.
  static const _shadowRoom = 4.0;

  /// The padding a [childScrolls] child gives its scroll view; the bottom
  /// part of [padding] stays outside it, fixed above the close button.
  static EdgeInsets scrollPadding(EdgeInsets padding) =>
      padding.copyWith(bottom: _shadowRoom);

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(24));
    const shadow = BoxShadow(
      color: SeedlyPalette.shadow,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[100],
        borderRadius: radius,
        // Figma stacks the default shadow twice on the modal.
        boxShadow: const [shadow, shadow],
      ),
      foregroundDecoration: const BoxDecoration(
        borderRadius: radius,
        border: Border.fromBorderSide(BorderSide(color: SeedlyPalette.border)),
      ),
      // The system bar inset replaces the bottom padding, as in the menu.
      padding: EdgeInsets.only(top: 20, bottom: math.max(20, bottomInset)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 8,
            decoration: BoxDecoration(
              color: SeedlyPalette.neutral[500],
              borderRadius: BorderRadius.circular(SeedlyMetrics.radii['full']!),
            ),
          ),
          const SizedBox(height: 10),
          // Long content scrolls instead of pushing the sheet off screen. The
          // bottom padding sits outside the scroll view so scrolled content
          // is clipped there and never runs into the close button, as in
          // Figma's "Modal tareas"; a little stays inside for card shadows.
          Flexible(
            child: childScrolls
                ? child
                : SingleChildScrollView(
                    padding: scrollPadding(padding),
                    child: child,
                  ),
          ),
          SizedBox(height: padding.bottom),
          if (showClose) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: _CloseButton(
                onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = SeedlyPalette.primary[500]!;
    return Tooltip(
      message: 'Cerrar',
      child: Material(
        type: MaterialType.transparency,
        shape: CircleBorder(side: BorderSide(color: color, width: 1.5)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(
              'assets/images/alert_cancel.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [builder]'s content inside a [SeedlyModal] from the bottom and
/// completes with the value it is popped with, or null when dismissed by
/// dragging it down, tapping outside or the close button.
Future<T?> showSeedlyModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool showClose = true,
  EdgeInsets padding = const EdgeInsets.fromLTRB(24, 40, 24, 20),
  bool childScrolls = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // SeedlyModal draws Figma's own handle; the theme would add Material's.
    showDragHandle: false,
    barrierColor: SeedlyPalette.neutral[900]!.withValues(alpha: 0.4),
    // Taller than this and the sheet would hide the whole screen behind it.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (context) => SeedlyModal(
      showClose: showClose,
      padding: padding,
      childScrolls: childScrolls,
      child: Builder(builder: builder),
    ),
  );
}
