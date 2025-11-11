import 'package:chargex/models/user_model.dart';
import 'package:chargex/screens/complete_profile_screen.dart';
import 'package:chargex/screens/login_screen.dart';
import 'package:chargex/screens/profile_screen.dart';
import 'package:chargex/services/auth_service.dart';
import 'package:chargex/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final dbService = context.read<DatabaseService>();

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, authSnapshot) {
        // 🕒 Wait for Firebase Auth to initialize
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 🚪 CASE 1: User is logged out
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final loggedInUser = authSnapshot.data!;

        // 🚫 CASE 2: Invalid or incomplete user (safety check)
        if (loggedInUser.uid.isEmpty || loggedInUser.email == null) {
          return const LoginScreen();
        }

        // 🔍 CASE 3: Fetch Firestore user document
        return FutureBuilder<UserModel?>(
          future: dbService.getUser(loggedInUser.uid),
          builder: (context, userDocSnapshot) {
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userData = userDocSnapshot.data;

            // 🟠 CASE 4: No Firestore user record found (very rare)
            if (userData == null) {
              return const CompleteProfileScreen();
            }

            // 🔍 Identify login method
            bool isGoogleUser = loggedInUser.providerData
                .any((provider) => provider.providerId == 'google.com');

            bool isEmailUser = loggedInUser.providerData
                .any((provider) => provider.providerId == 'password');

            // 🟡 CASE 5: Google user but missing details
            if (isGoogleUser &&
                (userData.vehicleType == 'Not set' ||
                    userData.vehicleBrand == 'Not set' ||
                    userData.vehicleModel == 'Not set')) {
              return const CompleteProfileScreen();
            }

            // 🟢 CASE 6: Email user or complete Google user
            if (isEmailUser || !isGoogleUser) {
              return const ProfileScreen();
            }

            // 🧩 Default fallback (shouldn’t happen)
            return const LoginScreen();
          },
        );
      },
    );
  }
}