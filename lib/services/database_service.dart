import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargex/models/user_model.dart';

/*
  This class handles all communication with the Cloud Firestore database.
  - Creating users
  - Getting user data
  - Getting charging stations (for your map)
*/
class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- User Operations ---

  /// Creates a new user document in Firestore from our UserModel
  Future<void> createUser(UserModel user) async {
    try {
      // We use the user's Auth UID as the document ID
      await _db.collection('users').doc(user.uid).set(user.toFirestore());
    } catch (e) {
      print('Error creating user: $e');
      rethrow; // Rethrow the error to be handled by the UI
    }
  }

  /// Gets a user document from Firestore and converts it to a UserModel
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        // Use our factory constructor to create a UserModel from the data
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting user: $e');
    }
    return null;
  }

  // --- Charging Station Operations (for Sneha's Map) ---

  /// Gets all charging stations as a stream
  Stream<QuerySnapshot> getStationsStream() {
    // This returns a "stream" so the map updates in real-time
    return _db.collection('chargingStations').snapshots();
  }
}

