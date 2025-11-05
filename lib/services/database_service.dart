import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargex/models/user_model.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

/*
  This class handles all database logic (create, read, update)
  for the Firestore database.
*/
class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reference to the 'users' collection with automatic model conversion
  late final CollectionReference<UserModel> _usersCollection;

  DatabaseService() {
    _usersCollection =
        _firestore.collection('users').withConverter<UserModel>(
          // Convert data FROM Firestore to UserModel
          fromFirestore: (snapshot, _) =>
              UserModel.fromJson(snapshot.data()!),

          // Convert UserModel TO Firestore format
          toFirestore: (user, _) => user.toJson(),
        );
  }

  /// 🟢 Create a new user document in Firestore — never overwrite existing fields
  Future<void> createUser(UserModel user) async {
    try {
      final docRef = _usersCollection.doc(user.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        // ✅ If doc doesn't exist, create new user
        await docRef.set(user);
        if (kDebugMode) {
          print("✅ Created new Firestore user: ${user.uid}");
        }
      } else {
        // ⚡ If user already exists, only fill missing fields (no overwrite)
        final existingData = docSnap.data()?.toJson() ?? {};

        // Build a partial update map only for empty or null fields
        final Map<String, dynamic> updateData = {};

        if ((existingData['displayName'] ?? '').toString().isEmpty &&
            user.displayName.isNotEmpty) {
          updateData['displayName'] = user.displayName;
        }

        if ((existingData['email'] ?? '').toString().isEmpty &&
            user.email.isNotEmpty) {
          updateData['email'] = user.email;
        }

        if ((existingData['phoneNumber'] ?? '').toString().isEmpty &&
            user.phoneNumber.isNotEmpty) {
          updateData['phoneNumber'] = user.phoneNumber;
        }

        if ((existingData['vehicleType'] ?? 'Not set') == 'Not set' &&
            user.vehicleType != 'Not set') {
          updateData['vehicleType'] = user.vehicleType;
        }

        if ((existingData['vehicleBrand'] ?? 'Not set') == 'Not set' &&
            user.vehicleBrand != 'Not set') {
          updateData['vehicleBrand'] = user.vehicleBrand;
        }

        if ((existingData['vehicleModel'] ?? 'Not set') == 'Not set' &&
            user.vehicleModel != 'Not set') {
          updateData['vehicleModel'] = user.vehicleModel;
        }

        // ✅ Only update if there’s something new to add
        if (updateData.isNotEmpty) {
          await docRef.update(updateData);
          if (kDebugMode) {
            print("✅ Merged missing fields for existing user: ${user.uid}");
          }
        } else {
          if (kDebugMode) {
            print("ℹ️ No changes — existing user ${user.uid} is up to date.");
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error creating user: $e");
      }
      rethrow;
    }
  }

  /// 🔵 Fetch a user's Firestore document using their UID
  Future<UserModel?> getUser(String uid) async {
    try {
      if (uid.isEmpty) return null;

      DocumentSnapshot<UserModel> doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error fetching user: $e");
      }
      return null;
    }
  }

  /// 🟠 Update specific fields in an existing user's profile
  Future<String?> updateUserProfile({
    required String uid,
    required String displayName,
    required GeoPoint location,
    required String vehicleType,
    required String vehicleBrand,
    required String vehicleModel,
  }) async {
    try {
      if (uid.isEmpty) return "Invalid user ID";

      await _usersCollection.doc(uid).update({
        'displayName': displayName,
        'lastKnownLocation': location,
        'vehicleType': vehicleType,
        'vehicleBrand': vehicleBrand,
        'vehicleModel': vehicleModel,
      });

      if (kDebugMode) {
        print("✅ Updated user profile for UID: $uid");
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error updating user profile: $e");
      }
      return e.toString();
    }
  }

  /// 🔵 Merge full user model (used for CompleteProfileScreen)
  Future<void> updateUser(UserModel user) async {
    try {
      if (user.uid.isEmpty) throw Exception("Invalid user ID");

      await _usersCollection
          .doc(user.uid)
          .set(user, SetOptions(merge: true)); // Merge = safe update

      if (kDebugMode) {
        print("✅ Merged user data for UID: ${user.uid}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error merging user data: $e");
      }
      rethrow;
    }
  }
}
