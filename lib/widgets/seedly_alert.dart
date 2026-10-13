import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Variants of the Figma "Alert" component.
enum SeedlyAlertStyle { notification, success, info, warning, danger }

class SeedlyAlertAction {
  const SeedlyAlertAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// Figma "Alert": icon card, coloured title, message and optional close and
/// text actions. Only the accent colour changes between styles.
class SeedlyAlert extends StatelessWidget {
  const SeedlyAlert({
    super.key,
    required this.title,
    required this.message,
    this.style = SeedlyAlertStyle.notification,
    this.icon,
    this.onClose,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final String message;
  final SeedlyAlertStyle style;

  /// SVG asset for the icon card; defaults to the style's icon.
  final String? icon;

  /// Shows the close button when set.
  final VoidCallback? onClose;
  final SeedlyAlertAction? primaryAction;
  final SeedlyAlertAction? secondaryAction;

  static const _closeSize = 24.0;

  Color get _accent => switch (style) {
    SeedlyAlertStyle.notification => SeedlyPalette.neutral[850]!,
    SeedlyAlertStyle.success => SeedlyPalette.success[600]!,
    SeedlyAlertStyle.info => SeedlyPalette.info[600]!,
    SeedlyAlertStyle.warning => SeedlyPalette.warning[600]!,
    SeedlyAlertStyle.danger => SeedlyPalette.danger[600]!,
  };

  String get _icon =>
      icon ??
      (style == SeedlyAlertStyle.danger
          ? 'assets/images/input_warning_circle.svg'
          : 'assets/images/alert_info.svg');

  @override
  Widget build(BuildContext context) {
    final hasActions = primaryAction != null || secondaryAction != null;
    final radius = BorderRadius.circular(SeedlyMetrics.radii['md']!);
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[100],
        borderRadius: radius,
      ),
      // Figma's stroke is inside the box and doesn't add to the padding.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: SeedlyPalette.neutral[500]!, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconCard(asset: _icon, color: _accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    right: onClose == null ? 0 : _closeSize + 4,
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      height: 28 / 18,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: SeedlyPalette.textSecondaryDark,
                  ),
                ),
                if (hasActions) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      if (secondaryAction case final action?)
                        _ActionButton(
                          action: action,
                          color: SeedlyPalette.neutral[600]!,
                        ),
                      if (primaryAction case final action?)
                        _ActionButton(
                          action: action,
                          color: style == SeedlyAlertStyle.notification
                              ? SeedlyPalette.neutral[700]!
                              : _accent,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (onClose == null) return content;
    // The 24px close icon sits where Figma puts it (centred in the 28px title
    // row, 16px from the edges) inside a 48px tap target.
    return Stack(
      children: [
        content,
        Positioned(
          top: 6,
          right: 4,
          child: IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: SvgPicture.asset(
              'assets/images/alert_cancel.svg',
              width: _closeSize,
              height: _closeSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard({required this.asset, required this.color});

  final String asset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const shadow = BoxShadow(
      color: SeedlyPalette.shadow,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    );
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['md']!),
        border: Border.all(color: SeedlyPalette.border),
        // Figma stacks the default shadow twice on this card.
        boxShadow: const [shadow, shadow],
      ),
      child: SvgPicture.asset(
        asset,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.color});

  final SeedlyAlertAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // A button's textStyle replaces the theme's, so restate the family.
        textStyle: const TextStyle(
          fontFamily: SeedlyTheme.fontFamily,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(action.label),
    );
  }
}

({OverlayEntry entry, OverlayState overlay})? _visibleAlert;

/// Shows a [SeedlyAlert] floating at the top of the screen, replacing any
/// alert already visible. It closes itself after [duration] or with its X.
void showSeedlyAlert(
  BuildContext context, {
  required String title,
  required String message,
  SeedlyAlertStyle style = SeedlyAlertStyle.notification,
  Duration duration = const Duration(seconds: 5),
}) {
  hideSeedlyAlert();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _FloatingAlert(
      duration: duration,
      onDismissed: () {
        if (_visibleAlert?.entry == entry) hideSeedlyAlert();
      },
      builder: (close) => SeedlyAlert(
        title: title,
        message: message,
        style: style,
        onClose: close,
      ),
    ),
  );
  final overlay = Overlay.of(context, rootOverlay: true)..insert(entry);
  _visibleAlert = (entry: entry, overlay: overlay);
}

/// Removes the visible floating alert right away, if any.
void hideSeedlyAlert() {
  final visible = _visibleAlert;
  _visibleAlert = null;
  // An entry whose overlay is already gone can't be removed any more.
  if (visible == null || !visible.overlay.mounted) return;
  visible.entry
    ..remove()
    ..dispose();
}

class _FloatingAlert extends StatefulWidget {
  const _FloatingAlert({
    required this.duration,
    required this.onDismissed,
    required this.builder,
  });

  final Duration duration;
  final VoidCallback onDismissed;
  final Widget Function(VoidCallback close) builder;

  @override
  State<_FloatingAlert> createState() => _FloatingAlertState();
}

class _FloatingAlertState extends State<_FloatingAlert>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (_controller.status == AnimationStatus.reverse) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, -0.4),
                  end: Offset.zero,
                ).animate(_curve),
                child: FadeTransition(
                  opacity: _curve,
                  child: Semantics(
                    liveRegion: true,
                    child: Material(
                      type: MaterialType.transparency,
                      child: widget.builder(_close),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
