import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_button.dart';

void main() {
  testWidgets('a disabled filled button keeps white text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: const Scaffold(
          body: SeedlyButton(label: 'Confirmar', onPressed: null),
        ),
      ),
    );
    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
    const disabled = {WidgetState.disabled};
    expect(style.foregroundColor!.resolve(disabled), Colors.white);
    expect(
      style.backgroundColor!.resolve(disabled),
      SeedlyPalette.primary[150],
    );
  });

  testWidgets('disabled text buttons still turn grey', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: const Scaffold(
          body: SeedlyButton(
            label: 'Cancelar',
            variant: SeedlyButtonVariant.text,
            onPressed: null,
          ),
        ),
      ),
    );
    final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
    expect(
      style.foregroundColor!.resolve({WidgetState.disabled}),
      SeedlyPalette.neutral[600],
    );
  });
}
