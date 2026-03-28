import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    // Wait for Firebase to resolve persisted auth state
    if (authService.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
      );
    }

    // Return child regardless of auth state to allow guest access
    return child;
  }
}
