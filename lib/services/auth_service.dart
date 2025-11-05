import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargex/models/user_model.dart';
import 'package:chargex/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/*
  This class handles all authentication logic (sign up, sign in, sign out).
  It communicates directly with Firebase Authentication.
*/
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream of user authentication state (for the AuthWrapper)
  Stream<User?> get user => _auth.authStateChanges();

  /// Gets the currently signed-in user object (synchronously)
  User? get currentUser => _auth.currentUser;

  /// --- EMAIL SIGN UP ---
  /// Creates a Firebase Auth user and a Firestore user document.
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
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        // 2. Create a UserModel object
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

        // 3. Save the user to Firestore
        await _db.createUser(newUser);
        return null; // success
      }
      return "User creation failed.";
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// --- EMAIL SIGN IN ---
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// --- GOOGLE SIGN IN ---
  Future<String?> signInWithGoogle(BuildContext context) async {
    try {
      // 1. Trigger the Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return "Sign-in cancelled.";
      }

      // 2. Obtain auth details from Google
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // 3. Create Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase
      UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 5. If new user, create Firestore record
        if (userCredential.additionalUserInfo!.isNewUser) {
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
        return null; // success
      }
      return "Sign-in failed.";
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// --- SIGN OUT ---
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
