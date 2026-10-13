import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/seedly_loading_screen.dart';
import 'services/seedly_auth.dart';
import 'theme/seedly_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp(auth: FirebaseSeedlyAuth()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.auth});

  final SeedlyAuth auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seedly',
      debugShowCheckedModeBanner: false,
      theme: SeedlyTheme.light,
      home: SeedlyLoadingScreen(auth: auth),
    );
  }
}
