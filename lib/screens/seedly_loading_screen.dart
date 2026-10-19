import 'package:flutter/material.dart';

import '../repositories/seedly_auth_repository.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_botanical_background.dart';
import '../widgets/seedly_loader.dart';
import '../widgets/seedly_logo.dart';
import 'seedly_home_screen.dart';
import 'seedly_login_screen.dart';

class SeedlyLoadingScreen extends StatelessWidget {
  const SeedlyLoadingScreen({super.key, required this.auth, this.startAfter});

  final SeedlyAuthRepository auth;
  final Future<void>? startAfter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlyPalette.neutral[100],
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: SeedlyBotanicalBackground()),
            ),
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SeedlyLogo(),
                      const SizedBox(height: 14),
                      Text(
                        'Todo progreso empieza\ncon una semilla',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SeedlyPalette.neutral[600],
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 46),
                      SeedlyLoader(
                        startAfter: startAfter,
                        onComplete: () {
                          if (!context.mounted) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => auth.isSignedIn
                                  ? SeedlyHomeScreen(auth: auth)
                                  : SeedlyLoginScreen(auth: auth),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
