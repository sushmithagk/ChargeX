import 'package:chargex/screens/splash_screen.dart';
import 'package:chargex/services/auth_service.dart';
import 'package:chargex/services/database_service.dart';
import 'package:chargex/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart'; // This was created by `flutterfire configure`

Future<void> main() async {
  // Ensure Flutter and Firebase are initialized
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Run the app
  runApp(const ChargeXApp());
}

class ChargeXApp extends StatelessWidget {
  const ChargeXApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We use MultiProvider to make our services available to the whole app
    return MultiProvider(
      providers: [
        // The AuthService handles all sign-in, sign-up, and sign-out logic
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        // The DatabaseService handles all Firestore database operations
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        // The LocationService handles getting the user's GPS location
        Provider<LocationService>(
          create: (_) => LocationService(),
        ),
      ],
      child: MaterialApp(
        title: 'ChargeX',
        theme: ThemeData(
          // --- Your Dark Theme ---
          brightness: Brightness.dark,
          primaryColor: Colors.indigoAccent,
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: const ColorScheme.dark(
            primary: Colors.indigoAccent,
            secondary: Colors.tealAccent,
            background: Color(0xFF121212),
            surface: Color(0xFF1E1E1E),
          ),

          // --- Styled Input Fields ---
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
          ),

          // --- Styled Buttons ---
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
        debugShowCheckedModeBanner: false,
        // The app will always start with the SplashScreen
        home: const SplashScreen(),
      ),
    );
  }
}