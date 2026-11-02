import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/firebase/firebase_seedly_auth_repository.dart';
import 'data/firebase/firestore_seedly_drops_repository.dart';
import 'data/firebase/firestore_seedly_project_repository.dart';
import 'data/firebase/firestore_seedly_user_repository.dart';
import 'data/notifications/flutter_seedly_notification_service.dart';
import 'firebase_options.dart';
import 'repositories/seedly_auth_repository.dart';
import 'repositories/seedly_drops_repository.dart';
import 'repositories/seedly_project_repository.dart';
import 'repositories/seedly_user_repository.dart';
import 'services/seedly_notification_service.dart';
import 'screens/seedly_drops_debug_view.dart';
import 'screens/seedly_loading_screen.dart';
import 'theme/seedly_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Emails Firebase sends for us, like the password reset, go out in Spanish.
  await FirebaseAuth.instance.setLanguageCode('es');
  // Local testing: flutter run -d chrome --dart-define=FIRESTORE_EMULATOR=127.0.0.1
  // Without it, the app talks to the real database as always.
  const emulatorHost = String.fromEnvironment('FIRESTORE_EMULATOR');
  if (kDebugMode && emulatorHost.isNotEmpty) {
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  }
  final users = FirestoreSeedlyUserRepository();
  final auth = FirebaseSeedlyAuthRepository(users: users);
  final projects = FirestoreSeedlyProjectRepository(auth: auth);
  final drops = FirestoreSeedlyDropsRepository(auth: auth);
  final notifications = FlutterSeedlyNotificationService();
  await notifications.initialize();
  runApp(
    MyApp(
      auth: auth,
      projects: projects,
      users: users,
      drops: drops,
      notifications: notifications,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.auth,
    required this.projects,
    required this.users,
    required this.drops,
    this.notifications,
  });

  final SeedlyAuthRepository auth;
  final SeedlyProjectRepository projects;
  final SeedlyUserRepository users;
  final SeedlyDropsRepository drops;
  final SeedlyNotificationService? notifications;

  // Local testing: --dart-define=DROPS_PANEL=true opens the drops panel
  // instead of the app. Debug builds only.
  static const _dropsPanel = kDebugMode && bool.fromEnvironment('DROPS_PANEL');

  @override
  Widget build(BuildContext context) {
    final app = SeedlyLoadingScreen(
      auth: auth,
      projects: projects,
      users: users,
      drops: drops,
      notifications: notifications,
    );
    return MaterialApp(
      title: 'Seedly',
      debugShowCheckedModeBanner: false,
      theme: SeedlyTheme.light,
      home: _dropsPanel
          ? SeedlyDropsDebugView(
              auth: auth,
              drops: drops,
              projects: projects,
              app: app,
            )
          : app,
    );
  }
}
