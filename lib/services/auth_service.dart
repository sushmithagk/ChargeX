import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chargex/models/user_model.dart';
import 'package:chargex/services/database_service.dart';

/*
  This class handles all communication with Firebase Authentication.
  - Sign Up
  - Sign In
  - Sign Out
*/
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  // --- Email & Password Sign Up ---
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required GeoPoint location,
    required Map<String, dynamic> vehicleData,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        // 2. Create our custom UserModel with all the data
        UserModel newUser = UserModel(
          uid: user.uid,
          displayName: name,
          email: email,
          phoneNumber: phone,
          lastKnownLocation: location,
          vehicleType: vehicleData['type'],
          vehicleBrand: vehicleData['brand'],
          vehicleModel: vehicleData['model'],
          createdAt: Timestamp.now(), // Use current time
        );

        // 3. Save this user object to our Firestore database
        await _db.createUser(newUser);
        return null; // Success!
      }
    } on FirebaseAuthException catch (e) {
      // Return a user-friendly error message
      return e.message;
    } catch (e) {
      return e.toString();
    }
    return 'An unknown error occurred.';
  }

  // --- Email & Password Sign In ---
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      // Return a user-friendly error message
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Invalid email or password.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
    return 'An unknown error occurred.';
  }

  // --- Sign Out ---
  Future<void> signOut() async {
    // TODO: Also sign out from Google
    // await GoogleSignIn().signOut();
    await _auth.signOut();
  }

// TODO: Add Google Sign-In logic
// TODO: Add Phone/OTP Sign-In logic
}

