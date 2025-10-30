import 'package:chargex/models/user_model.dart';
import 'package:chargex/services/auth_service.dart';
import 'package:chargex/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/show_snack_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the services from Provider
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    // Get the current user's ID
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () {
              // Call the sign-out function
              // The AuthWrapper will automatically move user to LoginScreen
              authService.signOut();
            },
          )
        ],
      ),
      // FutureBuilder is perfect for fetching data once
      body: FutureBuilder<UserModel?>(
        // Call the DatabaseService to get this user's data
        future: dbService.getUser(uid),
        builder: (context, snapshot) {

          // --- 1. While loading ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- 2. If an error occurred ---
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // --- 3. If data is empty or user not found ---
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Could not find user data.'));
          }

          // --- 4. SUCCESS! We have the user data ---
          final user = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // --- Show Profile Info ---
                _buildSectionTitle('Account'),
                _buildInfoTile(
                  icon: Icons.person_outline,
                  title: 'Name',
                  subtitle: user.displayName,
                ),
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: user.email,
                ),
                _buildInfoTile(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  subtitle: user.phoneNumber,
                ),

                // --- Show Vehicle Info ---
                const SizedBox(height: 24),
                _buildSectionTitle('Vehicle'),
                _buildInfoTile(
                  icon: Icons.directions_car_filled_outlined,
                  title: 'Type',
                  subtitle: user.vehicleType,
                ),
                _buildInfoTile(
                  icon: Icons.factory_outlined,
                  title: 'Brand',
                  subtitle: user.vehicleBrand,
                ),
                _buildInfoTile(
                  icon: Icons.label_outline,
                  title: 'Model',
                  subtitle: user.vehicleModel,
                ),
              ],
            ),
          );
        },
      ),

      // TODO: Replace this with a real Map Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to Sneha's MapScreen
          showSnackBar(context, "Map Screen not implemented yet.");
        },
        label: const Text('Find Stations'),
        icon: const Icon(Icons.map_outlined),
      ),
    );
  }

  // Helper widget for section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.indigoAccent,
        ),
      ),
    );
  }

  // Helper widget for info tiles
  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle}) {
    return Card(
      color: Colors.grey.withOpacity(0.1),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigoAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
