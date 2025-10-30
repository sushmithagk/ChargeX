import 'package:cloud_firestore/cloud_firestore.dart';

/*
  This class is a "data model". It defines the structure
  of a User document in our Firestore database.
  It makes our code much cleaner and safer.
*/
class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String phoneNumber;
  final GeoPoint lastKnownLocation;
  final String vehicleType;
  final String vehicleBrand;
  final String vehicleModel;
  final Timestamp createdAt;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.lastKnownLocation,
    required this.vehicleType,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.createdAt,
  });

  // Factory constructor: Creates a UserModel from a Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Handle vehicleDetails map which might be null
    Map<String, dynamic> vehicleData = data['vehicleDetails'] ?? {};

    return UserModel(
      uid: data['uid'],
      displayName: data['displayName'],
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      lastKnownLocation: data['lastKnownLocation'],
      createdAt: data['createdAt'],
      // Get data from the nested map
      vehicleType: vehicleData['type'] ?? 'Not set',
      vehicleBrand: vehicleData['brand'] ?? 'Not set',
      vehicleModel: vehicleData['model'] ?? 'Not set',
    );
  }

  // Method: Converts a UserModel instance to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'lastKnownLocation': lastKnownLocation,
      'createdAt': createdAt,
      // Store vehicle data in a nested map, as planned
      'vehicleDetails': {
        'type': vehicleType,
        'brand': vehicleBrand,
        'model': vehicleModel,
      },
    };
  }
}
