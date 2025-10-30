import 'package:flutter/material.dart';
import 'dart:async';
import 'package:chargex/screens/auth_wrapper.dart'; // Import the wrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  void _navigateToHome() {
    // Wait for 3 seconds
    Timer(const Duration(seconds: 3), () {
      // Navigate to the AuthWrapper, which will decide what page to show
      // We use pushReplacement so the user can't press "back" to the splash screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // A simple UI with the logo and app name
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder for your logo
            Icon(
              Icons.ev_station,
              size: 100,
              color: Colors.indigoAccent,
            ),
            SizedBox(height: 24),
            Text(
              'ChargeX',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(
              color: Colors.indigoAccent,
            ),
          ],
        ),
      ),
    );
  }
}
