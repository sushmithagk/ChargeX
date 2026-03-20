// lib/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChargerApiService {
  // ⬅️ paste your real key between the quotes
  static String get ocmApiKey => dotenv.env['OCM_API_KEY']!;

  static Future<void> updateStationsNear({
    required double lat,
    required double lon,
    double radiusKm = 3.0,
    int maxResults = 50,
  }) async {
    // you can filter to India with &countrycode=IN (optional)
    final uri = Uri.parse(
        "https://api.openchargemap.io/v3/poi"
            "?output=json"
            "&latitude=$lat"
            "&longitude=$lon"
            "&distance=$radiusKm"
            "&distanceunit=KM"
            "&maxresults=$maxResults"
            "&compact=true"
            "&verbose=false"
            "&countrycode=IN"
            "&key=$ocmApiKey" // ← make sure key is included
    );

    // also send it as a header (OCM accepts either)
    final res = await http.get(
      uri,
      headers: {
        "Accept": "application/json",
        "User-Agent": "ChargeX Student Research Project"
      },
    );


    if (res.statusCode != 200) {
      throw Exception("OCM API error ${res.statusCode}: ${res.body}");
    }

    final List list = jsonDecode(res.body);
    final fs = FirebaseFirestore.instance;

    for (final item in list) {
      final String id = (item["ID"] ?? "").toString();
      if (id.isEmpty) continue;

      final addr = item["AddressInfo"] ?? {};
      final String name = (addr["Title"] ?? "Station $id").toString();
      final double sLat = (addr["Latitude"] ?? 0).toDouble();
      final double sLon = (addr["Longitude"] ?? 0).toDouble();

      final statusType = item["StatusType"] ?? {};
      final bool isOperational = (statusType["IsOperational"] ?? false) == true;
      final String status = isOperational ? "available" : "offline";

      final int numPoints = (item["NumberOfPoints"] ?? 0) as int;

      await fs.collection("stations").doc(id).set({
        "name": name,
        "location": GeoPoint(sLat, sLon),
        "lat": sLat,
        "lng": sLon,
        "status": status,
        "currentUsers": 0,
        "capacity": numPoints,
        "pricePerKWh": 0.0,
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
