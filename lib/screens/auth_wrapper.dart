import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chargex/screens/login_screen.dart';
import 'package:chargex/screens/profile_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to Firebase Auth state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // If the connection is still loading, show a loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If the user IS logged in (snapshot has data)
        if (snapshot.hasData) {
          // Show the ProfileScreen, as you requested
          return const ProfileScreen();
        }

        // If the user is NOT logged in
        return const LoginScreen();
      },
    );
  }
}
