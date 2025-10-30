import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/*
  This class handles all logic for getting the user's GPS location.
  It's used in the SignUpScreen.
*/
class LocationService {
  /// Asks for permission and gets the user's current location.
  /// Returns a GeoPoint for Firebase or null if permission is denied.
  Future<GeoPoint?> getCurrentLocation() async {
    // 1. Check for location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 2. If denied, request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // User denied permission
        throw Exception('Location permission is required to sign up.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // User permanently denied, we can't ask again
      throw Exception(
          'Location permissions are permanently denied. Please go to settings to enable it.');
    }

    // 3. If permissions are granted, get the position.
    // This line will AUTOMATICALLY throw a 'LocationServiceDisabledException'
    // if the phone's GPS is turned off. We will catch this in the UI.
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    // 4. Convert to a Firebase GeoPoint and return it
    return GeoPoint(position.latitude, position.longitude);
  }
}

