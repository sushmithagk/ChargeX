// lib/utils/map_launcher.dart
import 'package:url_launcher/url_launcher.dart';

class MapLauncher {
  /// Opens Google Maps / Apple Maps with turn-by-turn navigation to [lat, lng].
  static Future<void> openMap({required double lat, required double lng}) async {
    final googleNav = Uri.parse('google.navigation:q=$lat,$lng'); // Android Google Maps
    final appleMaps = Uri.parse('http://maps.apple.com/?daddr=$lat,$lng');   // iOS fallback
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    // Try native Google Maps intent first (Android)
    if (await canLaunchUrl(googleNav)) {
      await launchUrl(googleNav, mode: LaunchMode.externalApplication);
      return;
    }
    // Try Apple Maps (iOS)
    if (await canLaunchUrl(appleMaps)) {
      await launchUrl(appleMaps, mode: LaunchMode.externalApplication);
      return;
    }
    // Fallback: open in browser
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }
}
