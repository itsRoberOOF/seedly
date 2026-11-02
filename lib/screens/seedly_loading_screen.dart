import 'package:flutter/material.dart';

import '../repositories/seedly_auth_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../repositories/seedly_user_repository.dart';
import '../services/seedly_notification_service.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_botanical_background.dart';
import '../widgets/seedly_loader.dart';
import '../widgets/seedly_logo.dart';
import 'seedly_home_screen.dart';
import 'seedly_login_screen.dart';

class SeedlyLoadingScreen extends StatelessWidget {
  const SeedlyLoadingScreen({
    super.key,
    required this.auth,
    required this.projects,
    required this.users,
    this.startAfter,
    this.notifications,
  });

  final SeedlyAuthRepository auth;

  /// Only handed on to the home and login screens.
  final SeedlyProjectRepository projects;
  final SeedlyUserRepository users;
  final SeedlyNotificationService? notifications;

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
                                  ? SeedlyHomeScreen(
                                      auth: auth,
                                      projects: projects,
                                      users: users,
                                      notifications: notifications,
                                    )
                                  : SeedlyLoginScreen(
                                      auth: auth,
                                      projects: projects,
                                      users: users,
                                      notifications: notifications,
                                    ),
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
