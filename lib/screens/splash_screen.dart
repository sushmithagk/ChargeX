import 'dart:async';
import 'package:chargex/screens/auth_wrapper.dart'; // <-- THIS IS THE FIX
import 'package:flutter/material.dart';

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

  /// Wait for 3 seconds then navigate to the AuthWrapper
  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Use a "pushReplacement" so the user can't press "back"
        // to get to the splash screen.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            // Removed 'const' from 'AuthWrapper()'
            builder: (context) => AuthWrapper(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Your Logo ---
            Icon(
              Icons.ev_station_rounded,
              size: 100,
              color: Colors.indigoAccent,
            ),
            SizedBox(height: 20),
            // --- Your App Name ---
            Text(
              'ChargeX',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              color: Colors.indigoAccent,
            ),
          ],
        ),
      ),
    );
  }
}