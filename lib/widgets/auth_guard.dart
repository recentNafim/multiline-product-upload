import 'package:flutter/material.dart';
import '../services/auth_session.dart';
import '../screens/login/login_screen.dart';

/// Also protects routes opened using MaterialPageRoute (not just named routes).
class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AuthSession.instance,
    builder: (context, _) {
      final session = AuthSession.instance;
      if (!session.initialized) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!session.authenticated) return const LoginScreen();
      return child;
    },
  );
}
