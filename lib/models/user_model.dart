import 'package:cloud_firestore/cloud_firestore.dart';

/*
  This class is our "data model". It defines the structure of our
  user document in Firestore and provides two key functions:

  1. toJson(): Converts a UserModel object into a Map (JSON format)
              so it can be *uploaded* to Firestore.

  2. fromJson(): Creates a UserModel object *from* a Map (JSON format)
                that is *downloaded* from Firestore.
*/

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String phoneNumber;
  final Timestamp createdAt;
  final GeoPoint lastKnownLocation;
  final String vehicleType;
  final String vehicleBrand;
  final String vehicleModel;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.createdAt,
    required this.lastKnownLocation,
    required this.vehicleType,
    required this.vehicleBrand,
    required this.vehicleModel,
  });

  /// 1. toJson()
  /// This function converts our Dart object into a Map (JSON)
  /// that Firestore understands. This is what `_db.createUser(newUser)` calls.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt,
      'lastKnownLocation': lastKnownLocation,
      'vehicleType': vehicleType,
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
    };
  }

  /// 2. fromJson()
  /// This "factory constructor" creates a UserModel object
  /// by reading a Map (JSON) from Firestore.
  /// This is what `_db.getUser(uid)` calls.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      createdAt: json['createdAt'] as Timestamp,
      lastKnownLocation: json['lastKnownLocation'] as GeoPoint,
      vehicleType: json['vehicleType'] as String,
      vehicleBrand: json['vehicleBrand'] as String,
      vehicleModel: json['vehicleModel'] as String,
    );
  }
}

