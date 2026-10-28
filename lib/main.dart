import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/firebase/firebase_seedly_auth_repository.dart';
import 'data/firebase/firestore_seedly_project_repository.dart';
import 'data/firebase/firestore_seedly_user_repository.dart';
import 'firebase_options.dart';
import 'repositories/seedly_auth_repository.dart';
import 'repositories/seedly_project_repository.dart';
import 'repositories/seedly_user_repository.dart';
import 'screens/seedly_loading_screen.dart';
import 'theme/seedly_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Emails Firebase sends for us, like the password reset, go out in Spanish.
  await FirebaseAuth.instance.setLanguageCode('es');
  final users = FirestoreSeedlyUserRepository();
  final auth = FirebaseSeedlyAuthRepository(users: users);
  final projects = FirestoreSeedlyProjectRepository(auth: auth);
  runApp(MyApp(auth: auth, projects: projects, users: users));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.auth,
    required this.projects,
    required this.users,
  });

  final SeedlyAuthRepository auth;
  final SeedlyProjectRepository projects;
  final SeedlyUserRepository users;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seedly',
      debugShowCheckedModeBanner: false,
      theme: SeedlyTheme.light,
      home: SeedlyLoadingScreen(auth: auth, projects: projects, users: users),
    );
  }
}
