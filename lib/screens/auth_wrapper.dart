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
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 🚪 Not logged in
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final loggedInUser = authSnapshot.data!;
        bool isGoogleUser = loggedInUser.providerData
            .any((p) => p.providerId == 'google.com');
        bool isEmailUser = loggedInUser.providerData
            .any((p) => p.providerId == 'password');

        return FutureBuilder<UserModel?>(
          future: dbService.getUser(loggedInUser.uid),
          builder: (context, userDocSnapshot) {
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final userData = userDocSnapshot.data;

            // 🟡 Case 1: New Google user with no Firestore data
            if (isGoogleUser && userData == null) {
              return const CompleteProfileScreen();
            }

            // 🟡 Case 2: Google user but incomplete data
            if (isGoogleUser &&
                userData != null &&
                (userData.vehicleType == 'Not set' ||
                    userData.vehicleBrand == 'Not set' ||
                    userData.vehicleModel == 'Not set')) {
              return const CompleteProfileScreen();
            }

            // 🟢 Case 3: Email user with complete data
            if (isEmailUser) return const ProfileScreen();

            // 🟢 Case 4: Returning Google user with complete data
            if (isGoogleUser && userData != null) {
              return const ProfileScreen();
            }

            // Default
            return const LoginScreen();
          },
        );
      },
    );
  }
}
