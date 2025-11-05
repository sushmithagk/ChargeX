import 'package:geolocator/geolocator.dart';

// Custom exception for when location services are disabled.
class LocationServiceDisabledException implements Exception {}

class LocationService {
  /// Gets the current location.
  /// Throws a [LocationServiceDisabledException] if services are disabled.
  /// Throws other exceptions if permissions are denied.
  Future<Position> getCurrentLocation() async {
    // Check if location services are enabled.
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Throw our custom exception to be caught in the UI.
      throw LocationServiceDisabledException();
    }

    // Check for permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // User denied permissions
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // User permanently denied permissions
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // If permissions are granted, get the position.
    // This returns a non-nullable `Position`.
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }
}

