import 'package:url_launcher/url_launcher.dart';

Future<void> openInMaps(double lat, double lng, String name) async {
  final url = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name");
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch Maps';
  }
}
