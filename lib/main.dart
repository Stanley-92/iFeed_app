import 'package:flutter/material.dart';
import 'package:ifeed/login.dart';
import 'Mainfeed.dart';
import 'services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/home': (_) => const MainfeedScreen(),
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isLoggedIn(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return (snap.data == true) ? const MainfeedScreen() : const LoginScreen();
      },
    );
  }
}
