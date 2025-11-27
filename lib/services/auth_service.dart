import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargex/models/user_model.dart';
import 'package:chargex/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Auth State Stream
  Stream<User?> get user => _auth.authStateChanges();

  /// Current Firebase User
  User? get currentUser => _auth.currentUser;

  // ============================================================================
  // 🔹 EMAIL SIGN UP
  // ============================================================================
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required GeoPoint location,
    required Map<String, dynamic> vehicleData,
  }) async {
    try {
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        UserModel newUser = UserModel(
          uid: user.uid,
          displayName: name,
          email: email,
          phoneNumber: phone,
          lastKnownLocation: location,
          vehicleType: vehicleData['type'],
          vehicleBrand: vehicleData['brand'],
          vehicleModel: vehicleData['model'],
          createdAt: Timestamp.now(),
        );

        await _db.createUser(newUser);
        return null;
      }

      return "User creation failed.";
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'This email is already registered.';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email address.';
      } else if (e.code == 'weak-password') {
        return 'Password must be at least 6 characters.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ============================================================================
  // 🔹 EMAIL SIGN IN
  // ============================================================================
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No account found for this email.';
      } else if (e.code == 'wrong-password') {
        return 'Incorrect password.';
      } else if (e.code == 'user-disabled') {
        return 'Your account is disabled.';
      }
      return e.message;
    }
  }

  // ============================================================================
  // 🔹 GOOGLE SIGN IN
  // ============================================================================
  Future<String?> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser =
      await _googleSignIn.signIn();

      if (googleUser == null) return "Sign-in cancelled.";

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCred =
      await _auth.signInWithCredential(credential);

      final User? user = userCred.user;

      if (user != null) {
        // New Google User → Create Firestore Record
        if (userCred.additionalUserInfo?.isNewUser ?? false) {
          UserModel newUser = UserModel(
            uid: user.uid,
            displayName: user.displayName ?? "Google User",
            email: user.email ?? "",
            phoneNumber: user.phoneNumber ?? "",
            createdAt: Timestamp.now(),
            lastKnownLocation: const GeoPoint(0, 0),
            vehicleType: "Not set",
            vehicleBrand: "Not set",
            vehicleModel: "Not set",
          );

          await _db.createUser(newUser);
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        return "This email is already linked with another sign-in method.";
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ============================================================================
  // 🔹 FORGOT PASSWORD (RESET EMAIL)
  // ============================================================================
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found with this email.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ============================================================================
  // 🔹 SIGN OUT
  // ============================================================================
  Future<void> signOut() async {
    debugPrint("SIGN OUT STARTED");

    try {
      // Google SignOut (safe attempts)
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      try {
        await _googleSignIn.disconnect();
      } catch (_) {}

      await _auth.signOut();

      await Future.delayed(const Duration(milliseconds: 300));

      debugPrint("SIGN OUT COMPLETE");
    } catch (e) {
      debugPrint("SIGN OUT ERROR: $e");
    }
  }
}
