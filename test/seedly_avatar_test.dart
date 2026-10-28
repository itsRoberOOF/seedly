import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/widgets/seedly_avatar.dart';

const _icon = 'assets/images/menu_profile.svg';
const _size = 140.0;

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onEdit,
  double editInset = 0,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: SeedlyAvatar(
          icon: _icon,
          size: _size,
          onEdit: onEdit,
          editInset: editInset,
        ),
      ),
    ),
  ),
);

/// The outer GestureDetector (the InkWell has its own inside it).
Finder get _target => find
    .descendant(
      of: find.byType(Tooltip),
      matching: find.byType(GestureDetector),
    )
    .first;

/// The 36px round button: the white ring around the green Material.
Finder get _circle => find.descendant(
  of: find.byType(Tooltip),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
  ),
);

void main() {
  testWidgets('without onEdit there is no edit button', (tester) async {
    await _pump(tester);

    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  for (final inset in [0.0, 2.0]) {
    group('editInset $inset', () {
      testWidgets('the touch target is at least 48x48', (tester) async {
        await _pump(tester, onEdit: () {}, editInset: inset);

        final size = tester.getSize(_target);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      });

      // Only the 48px target may reach assistive tech: the ink well inside
      // is excluded from semantics so it adds no smaller tappable node.
      for (final (name, guideline) in [
        ('Android', androidTapTargetGuideline),
        ('iOS', iOSTapTargetGuideline),
      ]) {
        testWidgets('meets the $name tap target guideline', (tester) async {
          final semantics = tester.ensureSemantics();
          await _pump(tester, onEdit: () {}, editInset: inset);

          await expectLater(tester, meetsGuideline(guideline));
          semantics.dispose();
        });
      }

      testWidgets('is a labelled button for assistive tech', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, onEdit: () {}, editInset: inset);

        final node = tester.getSemantics(_target);
        expect(node.getSemanticsData().tooltip, 'Cambiar imagen');
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(node.rect.size, const Size(48, 48));
        semantics.dispose();
      });

      testWidgets('tapping the centre calls onEdit once', (tester) async {
        var taps = 0;
        await _pump(tester, onEdit: () => taps++, editInset: inset);

        await tester.tap(find.byType(InkWell));
        await tester.pump();

        expect(taps, 1);
      });

      testWidgets('tapping the ring outside the circle calls onEdit once', (
        tester,
      ) async {
        var taps = 0;
        await _pump(tester, onEdit: () => taps++, editInset: inset);
        final target = tester.getRect(_target);
        final circle = tester.getRect(find.byType(InkWell));
        // Left of the circle yet inside the 48px target.
        final ring = Offset((target.left + circle.left) / 2, circle.center.dy);
        expect(circle.contains(ring), isFalse);
        expect(target.contains(ring), isTrue);

        await tester.tapAt(ring);
        await tester.pump();

        expect(taps, 1);
      });

      testWidgets('the visual circle stays 36x36 in the same corner', (
        tester,
      ) async {
        await _pump(tester, onEdit: () {}, editInset: inset);

        final avatar = tester.getRect(find.byType(SeedlyAvatar));
        final circle = tester.getRect(_circle);

        expect(circle.size, const Size(36, 36));
        expect(avatar.right - circle.right, inset);
        expect(avatar.bottom - circle.bottom, inset);
      });
    });
  }

  testWidgets('a tap just outside the 48px target does not edit', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, onEdit: () => taps++);
    final target = tester.getRect(_target);

    await tester.tapAt(target.topLeft - const Offset(2, 2));
    await tester.pump();

    expect(taps, 0);
  });
}
