// lib/main.dart

import 'package:chargex/screens/splash_screen.dart';
import 'package:chargex/screens/nearby_screen.dart';
import 'package:chargex/screens/trip_planner_screen.dart';
import 'package:chargex/screens/my_bookings_screen.dart';
import 'package:chargex/screens/station_detail_screen.dart';

import 'package:chargex/services/auth_service.dart';
import 'package:chargex/services/database_service.dart';
import 'package:chargex/services/location_service.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ChargeXApp());
}

class ChargeXApp extends StatelessWidget {
  const ChargeXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<LocationService>(create: (_) => LocationService()),
      ],
      child: MaterialApp(
        title: 'ChargeX',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.indigoAccent,
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: const ColorScheme.dark(
            primary: Colors.indigoAccent,
            secondary: Colors.tealAccent,
            surface: Color(0xFF1E1E1E),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // When app opens → only SplashScreen shows
        home: const SplashScreen(),

        // Named routes
        routes: {
          '/nearby': (_) => const NearbyScreen(),
          '/my-bookings': (_) => const MyBookingsScreen(),
          '/trip': (_) => const TripPlannerScreen(),

          '/station': (context) {
            final stationId =
            ModalRoute.of(context)!.settings.arguments as String;
            return StationDetailScreen(
              stationId: stationId,
              stationName: "Station",
            );
          },
        },
      ),
    );
  }
}
