import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'nearby_screen.dart';
import 'trip_planner_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String getUserName() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return "User";

    if (u.displayName != null && u.displayName!.isNotEmpty) {
      return u.displayName!;
    }

    if (u.email != null) {
      return u.email!.split('@')[0];
    }

    return "User";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ChargeX",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 10),

            // ===================== PROFILE ROW FIXED (NO OVERFLOW) =====================
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.purple,
                  child: Text(
                    getUserName().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(     // ⭐ Overflow fixed
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome",
                        style: TextStyle(fontSize: 20, color: Colors.grey),
                      ),
                      Text(
                        getUserName(),
                        maxLines: 1,                     // ⭐ Avoid overflow
                        overflow: TextOverflow.ellipsis, // ⭐ Add dots ...
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // ===================== BUTTON GRID =====================
            Expanded(
              child: Center(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 25,
                  crossAxisSpacing: 25,
                  childAspectRatio: 1,
                  shrinkWrap: true,
                  children: [
                    _tile(
                      context,
                      "Find Station",
                      Icons.place,
                      const NearbyScreen(),
                    ),
                    _tile(
                      context,
                      "Plan Trip",
                      Icons.map,
                      const TripPlannerScreen(),
                    ),
                    _tile(
                      context,
                      "My Bookings",
                      Icons.calendar_today,
                      const MyBookingsScreen(),
                    ),
                    _tile(
                      context,
                      "Profile",
                      Icons.person,
                      const ProfileScreen(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== BUTTON TILE WIDGET =====================
  Widget _tile(BuildContext ctx, String title, IconData icon, Widget screen) {
    return InkWell(
      onTap: () => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => screen),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1D1A27), // your exact color
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
