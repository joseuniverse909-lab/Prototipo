import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'maps/map_screen.dart';
import 'screens/login_screen.dart';
import 'services/game_state_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  GameStateService.startOnlineSync();
  runApp(const AsphixiaApp());
}

class AsphixiaApp extends StatelessWidget {
  const AsphixiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aphixia',
      theme: ThemeData.dark(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastSyncedUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final userId = snapshot.data!.uid;
          if (_lastSyncedUserId != userId) {
            _lastSyncedUserId = userId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              GameStateService.syncCurrentUser();
            });
          }
          return const MapScreen();
        }

        _lastSyncedUserId = null;
        return const LoginScreen();
      },
    );
  }
}
