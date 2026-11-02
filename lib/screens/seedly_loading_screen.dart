import 'package:flutter/material.dart';

import '../repositories/seedly_auth_repository.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../repositories/seedly_user_repository.dart';
import '../services/seedly_notification_service.dart';
import '../services/seedly_startup.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_botanical_background.dart';
import '../widgets/seedly_loader.dart';
import '../widgets/seedly_logo.dart';
import 'seedly_home_screen.dart';
import 'seedly_login_screen.dart';

/// The first screen: the logo and a bar that follows what the app is really
/// loading (see [seedlyStartupSteps]), then Inicio or the login.
class SeedlyLoadingScreen extends StatefulWidget {
  const SeedlyLoadingScreen({
    super.key,
    required this.auth,
    required this.projects,
    required this.users,
    this.drops,
    this.startAfter,
    this.startup,
    this.notifications,
  });

  final SeedlyAuthRepository auth;

  /// Only handed on to the home and login screens.
  final SeedlyProjectRepository projects;
  final SeedlyUserRepository users;
  final SeedlyDropsRepository? drops;
  final SeedlyNotificationService? notifications;

  /// Defaults to the first frame being rasterized, so loading starts onscreen.
  final Future<void>? startAfter;

  /// Replaced in tests to choose what loads and how long it takes; by default
  /// it loads what [seedlyStartupSteps] lists for the person signed in.
  final SeedlyStartup? startup;

  @override
  State<SeedlyLoadingScreen> createState() => _SeedlyLoadingScreenState();
}

class _SeedlyLoadingScreenState extends State<SeedlyLoadingScreen> {
  SeedlyStartup? _startup;
  var _progress = 0.0;

  @override
  void initState() {
    super.initState();
    final ready =
        widget.startAfter ??
        WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    ready.then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final startup =
        widget.startup ??
        SeedlyStartup(
          steps: seedlyStartupSteps(
            auth: widget.auth,
            projects: widget.projects,
            users: widget.users,
            drops: widget.drops,
          ),
        );
    _startup = startup;
    await startup.run((progress) {
      if (mounted) setState(() => _progress = progress);
    });
    if (mounted) _open();
  }

  @override
  void dispose() {
    _startup?.cancel();
    super.dispose();
  }

  void _open() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => widget.auth.isSignedIn
            ? SeedlyHomeScreen(
                auth: widget.auth,
                projects: widget.projects,
                users: widget.users,
                drops: widget.drops,
                notifications: widget.notifications,
              )
            : SeedlyLoginScreen(
                auth: widget.auth,
                projects: widget.projects,
                users: widget.users,
                drops: widget.drops,
                notifications: widget.notifications,
              ),
      ),
    );
  }

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
                      SeedlyLoader(progress: _progress),
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
