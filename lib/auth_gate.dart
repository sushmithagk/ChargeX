import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/nearby_screen.dart'; // or your home/profile after login

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SplashScreen(); // simple loader
        }
        // If signed in -> go to app
        if (snap.hasData) {
          return const NearbyScreen(); // or Profile/Home
        }
        // If signed out -> show your login screen
        return const SplashScreen(); // if Splash shows Login; otherwise use LoginScreen()
      },
    );
  }
}
