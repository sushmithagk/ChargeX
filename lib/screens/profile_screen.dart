import 'package:chargex/models/user_model.dart';
import 'package:chargex/services/auth_service.dart';
import 'package:chargex/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);

              print("Before logout: ${auth.currentUser?.email}");

              await auth.signOut();

              print("After logout: ${auth.currentUser}");

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                    (route) => false,
              );
            },
          ),
        ],
      ),

      body: FutureBuilder<UserModel?>(
        future: dbService.getUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('User data not found.'));
          }

          final user = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
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
    );
  }

  // --- Helpers ---
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

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
