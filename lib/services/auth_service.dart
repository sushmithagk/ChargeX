import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargex/models/user_model.dart';
import 'package:chargex/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/*
  AuthService — handles all sign-up, sign-in, and sign-out logic.
  Works with Firebase Authentication + Firestore + Google Sign-In.
*/
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream of authentication changes (for AuthWrapper)
  Stream<User?> get user => _auth.authStateChanges();

  /// Currently signed-in user (nullable)
  User? get currentUser => _auth.currentUser;

  // -------------------------------------------------------------------------
  // 🔹 EMAIL SIGN-UP
  // -------------------------------------------------------------------------
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required GeoPoint location,
    required Map<String, dynamic> vehicleData,
  }) async {
    try {
      // 1. Create the Firebase Auth user
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        // 2. Build a new UserModel
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

        // 3. Save user to Firestore
        await _db.createUser(newUser);
        return null; // ✅ Success
      }
      return "User creation failed.";
    } on FirebaseAuthException catch (e) {
      // 🔸 Catch Firebase errors
      if (e.code == 'email-already-in-use') {
        return 'This email is already registered.';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email address.';
      } else if (e.code == 'weak-password') {
        return 'Password must be at least 6 characters.';
      }
      return e.message;
    } catch (e) {
      // 🔸 Catch any unexpected errors
      return e.toString();
    }
  }

  // -------------------------------------------------------------------------
  // 🔹 EMAIL SIGN-IN
  // -------------------------------------------------------------------------
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // ✅ Success
    } on FirebaseAuthException catch (e) {
      // 🔸 Handle specific Firebase error codes
      if (e.code == 'user-not-found') {
        return 'No account found for this email.';
      } else if (e.code == 'wrong-password') {
        return 'Incorrect password. Try again.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is invalid.';
      } else if (e.code == 'user-disabled') {
        return 'This account has been disabled.';
      }
      return e.message;
    } catch (e) {
      // 🔸 Any other error (network issues, etc.)
      return e.toString();
    }
  }

  // -------------------------------------------------------------------------
  // 🔹 GOOGLE SIGN-IN
  // -------------------------------------------------------------------------
  Future<String?> signInWithGoogle(BuildContext context) async {
    try {
      // 1. Start Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return "Sign-in cancelled.";
      }

      // 2. Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 5. Check if this is a NEW Google user
        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          UserModel newUser = UserModel(
            uid: user.uid,
            displayName: user.displayName ?? "Google User",
            email: user.email ?? '',
            phoneNumber: user.phoneNumber ?? '',
            createdAt: Timestamp.now(),
            lastKnownLocation: const GeoPoint(0, 0),
            vehicleType: 'Not set',
            vehicleBrand: 'Not set',
            vehicleModel: 'Not set',
          );
          await _db.createUser(newUser);
        }
        return null; // ✅ Success
      }
      return "Sign-in failed.";
    } on FirebaseAuthException catch (e) {
      // 🔸 Catch specific Firebase errors
      if (e.code == 'account-exists-with-different-credential') {
        return 'Account already exists with a different sign-in method.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // -------------------------------------------------------------------------
  // 🔹 SIGN-OUT
  // -------------------------------------------------------------------------
  Future<void> signOut() async {
    try {
      debugPrint('SIGNOUT STARTED');

      // 1️⃣ Try normal Google signOut
      try {
        await _googleSignIn.signOut();
        debugPrint('Google signOut success');
      } catch (e) {
        debugPrint('Google signOut failed: $e');
      }

      // 2️⃣ Try Google disconnect (removes cached session)
      try {
        await _googleSignIn.disconnect();
        debugPrint('Google disconnect success');
      } catch (e) {
        debugPrint('Google disconnect failed (OK to ignore): $e');
      }

      // 3️⃣ Firebase signOut
      await _auth.signOut();
      debugPrint('Firebase signOut success');

      // 4️⃣ Small delay to make sure AuthWrapper receives NULL
      await Future.delayed(const Duration(milliseconds: 300));

      debugPrint('Current user after signOut = ${_auth.currentUser}');
    } catch (e, st) {
      debugPrint('SIGNOUT ERROR: $e\n$st');
    }
  }


}