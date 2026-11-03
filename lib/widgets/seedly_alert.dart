import 'dart:async';
import 'dart:math' as math;

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

/// Everything the floating alert has to stay below.
final _keepClear = <_SeedlyAlertKeepClearState>{};

/// Keeps the floating alert below [child] while it is on the current screen,
/// so the alert never covers it. [SeedlyHeader] wraps its back arrow in it.
class SeedlyAlertKeepClear extends StatefulWidget {
  const SeedlyAlertKeepClear({super.key, required this.child});

  final Widget child;

  @override
  State<SeedlyAlertKeepClear> createState() => _SeedlyAlertKeepClearState();
}

class _SeedlyAlertKeepClearState extends State<SeedlyAlertKeepClear> {
  @override
  void initState() {
    super.initState();
    _keepClear.add(this);
  }

  @override
  void dispose() {
    _keepClear.remove(this);
    super.dispose();
  }

  /// Where the child ends in [overlay]'s coordinates, or null while it isn't
  /// laid out on the current screen.
  double? bottomIn(RenderBox overlay) {
    // A screen underneath stays mounted after another is pushed on top.
    if (ModalRoute.isCurrentOf(context) == false) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final bottom = box.localToGlobal(box.size.bottomLeft(Offset.zero));
    return overlay.globalToLocal(bottom).dy;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows a [SeedlyAlert] floating at the top of the screen, replacing any
/// alert already visible. It closes itself after [duration] or with its X,
/// and stays below anything wrapped in [SeedlyAlertKeepClear]. Returns a
/// handle for [isSeedlyAlertVisible].
Object showSeedlyAlert(
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
  return entry;
}

/// Whether the alert [handle], from [showSeedlyAlert], is still on screen:
/// neither closed nor replaced by another.
bool isSeedlyAlertVisible(Object handle) =>
    identical(_visibleAlert?.entry, handle);

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

  /// The lowest [SeedlyAlertKeepClear] edge on screen, in overlay
  /// coordinates.
  double? _clearLine;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _close);
    _watchClearLine();
  }

  /// A header can open, scroll or close while the alert is up, so it looks
  /// again after every frame. Nothing runs while the screen doesn't redraw.
  void _watchClearLine() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final line = _findClearLine();
      if (line != _clearLine) setState(() => _clearLine = line);
      _watchClearLine();
    });
  }

  double? _findClearLine() {
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return null;
    double? line;
    for (final keepClear in _keepClear) {
      final bottom = keepClear.bottomIn(overlay);
      if (bottom != null) line = math.max(line ?? bottom, bottom);
    }
    return line;
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
    // 12px under the status bar, or 8px under what it must keep clear.
    final top = math.max(
      MediaQuery.paddingOf(context).top + 12,
      (_clearLine ?? 0) + 8,
    );
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
