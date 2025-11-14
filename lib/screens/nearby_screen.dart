// lib/screens/nearby_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../api_service.dart';
import 'package:chargex/screens/station_detail_screen.dart';
import 'package:chargex/utils/map_launcher.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final _fs = FirebaseFirestore.instance;

  Position? _pos;
  double _radiusKm = 3.0;
  Timer? _autoRefresh;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _latRangeStream;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _pos = await _loc();
    await _pullPublicData();
    _startLatRangeStream();
    setState(() {});
  }

  Future<void> _refresh() async {
    try {
      _pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _pullPublicData();
      _startLatRangeStream();
    } catch (_) {}
  }

  Future<void> _pullPublicData() async {
    try {
      await ChargerApiService.updateStationsNear(
        lat: _pos!.latitude,
        lon: _pos!.longitude,
        radiusKm: _radiusKm,
        maxResults: 50,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn’t load stations: $e')),
        );
      }
    }
  }

  Future<Position> _loc() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) await Geolocator.openLocationSettings();

    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) {
      throw Exception('Location permanently denied. Enable it in Settings.');
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Map<String, double> _bbox(double lat, double lng, double radiusKm) {
    const earth = 6371.0;
    final rad = radiusKm / earth;
    final latRad = lat * pi / 180.0;
    final minLat = lat - rad * 180.0 / pi;
    final maxLat = lat + rad * 180.0 / pi;
    final minLng = lng - rad * 180.0 / pi / cos(latRad);
    final maxLng = lng + rad * 180.0 / pi / cos(latRad);
    return {'minLat': minLat, 'maxLat': maxLat, 'minLng': minLng, 'maxLng': maxLng};
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    double toRad(double d) => d * pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * R * atan2(sqrt(a), sqrt(1 - a));
  }

  void _startLatRangeStream() {
    if (_pos == null) return;
    final box = _bbox(_pos!.latitude, _pos!.longitude, _radiusKm);
    _latRangeStream = _fs
        .collection('stations')
        .where('lat', isGreaterThanOrEqualTo: box['minLat'])
        .where('lat', isLessThanOrEqualTo: box['maxLat'])
        .snapshots();
  }

  String _fmtTs(Timestamp? t) =>
      t == null ? '-' : DateFormat.jm().format(t.toDate().toLocal());

  @override
  Widget build(BuildContext context) {
    if (_latRangeStream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Charging Stations'),
        actions: [
          PopupMenuButton<double>(
            initialValue: _radiusKm,
            onSelected: (v) {
              setState(() => _radiusKm = v);
              _startLatRangeStream();
              _refresh();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1.0, child: Text('1 km')),
              PopupMenuItem(value: 3.0, child: Text('3 km')),
              PopupMenuItem(value: 5.0, child: Text('5 km')),
            ],
            icon: const Icon(Icons.filter_alt),
          ),
          IconButton(icon: const Icon(Icons.my_location), onPressed: _refresh),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _latRangeStream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No stations found nearby'));

          final box = _bbox(_pos!.latitude, _pos!.longitude, _radiusKm);
          final filtered = docs.where((doc) {
            final d = doc.data();
            final lat = (d['lat'] ?? 0).toDouble();
            final lng = (d['lng'] ?? 0).toDouble();
            if (lng < box['minLng']! || lng > box['maxLng']!) return false;
            final distM = _haversineMeters(_pos!.latitude, _pos!.longitude, lat, lng);
            return distM <= _radiusKm * 1000.0;
          }).toList();

          if (filtered.isEmpty) return const Center(child: Text('No stations in range'));

          filtered.sort((a, b) {
            final da = a.data();
            final db = b.data();
            final d1 = _haversineMeters(
              _pos!.latitude,
              _pos!.longitude,
              (da['lat'] ?? 0).toDouble(),
              (da['lng'] ?? 0).toDouble(),
            );
            final d2 = _haversineMeters(
              _pos!.latitude,
              _pos!.longitude,
              (db['lat'] ?? 0).toDouble(),
              (db['lng'] ?? 0).toDouble(),
            );
            return d1.compareTo(d2);
          });

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final doc = filtered[i];
              final d = doc.data();
              final distM = _haversineMeters(
                _pos!.latitude,
                _pos!.longitude,
                (d['lat'] ?? 0).toDouble(),
                (d['lng'] ?? 0).toDouble(),
              );
              final km = (distM / 1000).toStringAsFixed(2);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (d['name'] ?? doc.id).toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // ❌ Removed "1 connector" text
                            // Text(
                            //   '${d['capacity'] ?? 0} connectors • ${_fmtTs(d['lastUpdated'] as Timestamp?)}',
                            //   style: TextStyle(color: Colors.grey[300]),
                            // ),

                            Text(
                              _fmtTs(d['lastUpdated'] as Timestamp?),
                              style: TextStyle(color: Colors.grey[300]),
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$km km',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StationDetailScreen(
                                        stationId: doc.id,
                                        stationName: (d['name'] ?? doc.id).toString(),
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Slots', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                onPressed: () {
                                  MapLauncher.openMap(
                                    lat: (d['lat'] ?? 0).toDouble(),
                                    lng: (d['lng'] ?? 0).toDouble(),
                                  );
                                },
                                child: const Text('Navigate', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
