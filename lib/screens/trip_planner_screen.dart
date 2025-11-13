// lib/screens/trip_planner_screen.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocode;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _destinationController = TextEditingController();

  LatLng? _currentLatLng;
  LatLng? _destinationLatLng;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  List<Map<String, dynamic>> _stations = [];
  final Set<Marker> _stationMarkers = {};

  // <<< Replace this with your real API key >>>
  final String googleApiKey = "AIzaSyBREDegu1Lj5gXhdrSCcnAa1omChs7-EHs";

  bool _loadingRoute = false;
  final double thresholdMeters = 1000;

  @override
  void initState() {
    super.initState();

    _determinePosition().then((pos) {
      if (pos != null) {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
        _moveCameraTo(_currentLatLng!);
        _markers.add(
          Marker(
            markerId: const MarkerId('me'),
            position: _currentLatLng!,
            infoWindow: const InfoWindow(title: 'You are here'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );
        setState(() {});
      }
    });

    _fetchStations();
  }

  // ---------------- FETCH FIRESTORE STATIONS ----------------
  Future<void> _fetchStations() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('stations').get();

      _stations.clear();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['lat'] != null && data['lng'] != null) {
          _stations.add({
            'id': doc.id,
            'lat': (data['lat'] as num).toDouble(),
            'lng': (data['lng'] as num).toDouble(),
            'raw': data,
          });
        }
      }
      setState(() {});
    } catch (e) {
      debugPrint('Fetch stations error: $e');
    }
  }

  // ---------------- LOCATION PERMISSION & CURRENT LOCATION ----------------
  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  // ---------------- CAMERA ----------------
  Future<void> _moveCameraTo(LatLng pos, {double zoom = 14}) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)),
    );
  }

  // ---------------- GEOCODE ADDRESS -> DESTINATION ----------------
  Future<void> _setDestinationFromAddress() async {
    final address = _destinationController.text.trim();
    if (address.isEmpty) return;

    try {
      final list = await geocode.locationFromAddress(address);
      if (list.isNotEmpty) {
        final loc = list.first;
        _destinationLatLng = LatLng(loc.latitude, loc.longitude);

        _markers.removeWhere((m) => m.markerId.value == 'destination');
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _destinationLatLng!,
            infoWindow: InfoWindow(title: 'Destination', snippet: address),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
        _moveCameraTo(_destinationLatLng!, zoom: 13);
        setState(() {});
      }
    } catch (e) {
      debugPrint('Geocoding failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address lookup failed')),
      );
    }
  }

  // ---------------- GET ROUTE (PolylinePoints new API) ----------------
  Future<void> _findRoute() async {
    if (_currentLatLng == null) {
      final p = await _determinePosition();
      if (p == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get current location')));
        return;
      }
      _currentLatLng = LatLng(p.latitude, p.longitude);
    }

    if (_destinationLatLng == null) {
      await _setDestinationFromAddress();
      if (_destinationLatLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set a destination')),
        );
        return;
      }
    }

    setState(() {
      _loadingRoute = true;
      _polylines.clear();
      _routePoints.clear();
      _stationMarkers.clear();
    });

    // origin/destination markers
    _markers.removeWhere((m) => m.markerId.value == 'origin');
    _markers.add(Marker(markerId: const MarkerId('origin'), position: _currentLatLng!));

    try {
      final polylinePoints = PolylinePoints();
      final request = PolylineRequest(
        origin: PointLatLng(_currentLatLng!.latitude, _currentLatLng!.longitude),
        destination: PointLatLng(_destinationLatLng!.latitude, _destinationLatLng!.longitude),
        mode: TravelMode.driving, // <<-- correct parameter name
      );

      final result = await polylinePoints.getRouteBetweenCoordinates(
        request: request,
        googleApiKey: googleApiKey,
      );

      if (result.points.isNotEmpty) {
        _routePoints = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

        final polyline = Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: Colors.blue,
          width: 6,
        );

        _polylines.add(polyline);

        // center camera around route midpoint
        final mid = _routePoints[_routePoints.length ~/ 2];
        await _moveCameraTo(mid, zoom: 12);

        _computeStationsOnRoute();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No route found')));
      }
    } catch (e) {
      debugPrint('Route error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route fetch failed')));
    } finally {
      setState(() => _loadingRoute = false);
    }
  }

  // ---------------- GEOMETRY: distance point -> segment (meters) ----------------
  double _distancePointToSegment(LatLng p, LatLng v, LatLng w) {
    const R = 6371000.0;
    double rad(double d) => d * pi / 180;

    final latRef = rad((v.latitude + w.latitude) / 2.0);
    final xP = (p.longitude - v.longitude) * cos(latRef);
    final yP = (p.latitude - v.latitude);
    final xW = (w.longitude - v.longitude) * cos(latRef);
    final yW = (w.latitude - v.latitude);

    final px = xP, py = yP, sx = xW, sy = yW;
    final segLen2 = sx * sx + sy * sy;
    double t = 0.0;
    if (segLen2 > 0) {
      t = ((px * sx) + (py * sy)) / segLen2;
      t = t.clamp(0.0, 1.0);
    }
    final projx = v.longitude + (xW * t) / cos(latRef);
    final projy = v.latitude + yW * t;
    final proj = LatLng(projy, projx);
    return _distanceMeters(p, proj);
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final sinDlat = sin(dLat / 2);
    final sinDlon = sin(dLon / 2);
    final aa = sinDlat * sinDlat + cos(lat1) * cos(lat2) * sinDlon * sinDlon;
    final c = 2 * atan2(sqrt(aa), sqrt(1 - aa));
    return R * c;
  }

  // ---------------- COMPUTE STATIONS ON ROUTE ----------------
  void _computeStationsOnRoute() {
    if (_routePoints.isEmpty) return;
    _stationMarkers.clear();

    for (final station in _stations) {
      final pt = LatLng(station['lat'], station['lng']);
      double minD = double.infinity;
      for (int i = 0; i < _routePoints.length - 1; i++) {
        final d = _distancePointToSegment(pt, _routePoints[i], _routePoints[i + 1]);
        if (d < minD) minD = d;
      }

      if (minD <= thresholdMeters) {
        final marker = Marker(
          markerId: MarkerId('station_${station['id']}'),
          position: pt,
          infoWindow: InfoWindow(title: station['raw']?['name'] ?? 'Station', snippet: 'Dist: ${minD.toStringAsFixed(0)} m'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
        _stationMarkers.add(marker);
      }
    }

    _markers.removeWhere((m) => m.markerId.value.startsWith('station_'));
    _markers.addAll(_stationMarkers);
    setState(() {});
  }

  // ---------------- CONTROL PANEL UI ----------------
  Widget _panel() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 18,
      child: Card(
        color: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                      hintText: 'Enter destination', border: InputBorder.none),
                ),
              ),
              ElevatedButton(
                onPressed: _setDestinationFromAddress,
                child: const Text('Set'),
              )
            ]),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final pos = await _determinePosition();
                  if (pos == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to get current location')));
                    return;
                  }
                  setState(() {
                    _currentLatLng = LatLng(pos.latitude, pos.longitude);
                    _markers.removeWhere((m) => m.markerId.value == 'origin');
                    _markers.add(Marker(markerId: const MarkerId('origin'), position: _currentLatLng!, infoWindow: const InfoWindow(title: 'You')));
                  });
                  _moveCameraTo(_currentLatLng!, zoom: 14);
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Use my location'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loadingRoute ? null : _findRoute,
                  child: _loadingRoute ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Find route'),
                ),
              )
            ]),
            const SizedBox(height: 4),
            Text(
              'Stations on route: ${_stationMarkers.length}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            )
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _currentLatLng ?? const LatLng(12.9716, 77.5946);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Planner')),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 12),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (c) => _mapController = c,
          onTap: (p) {
            _destinationLatLng = p;
            _destinationController.text = '${p.latitude}, ${p.longitude}';
            _markers.removeWhere((m) => m.markerId.value == 'destination');
            _markers.add(Marker(markerId: const MarkerId('destination'), position: p, infoWindow: const InfoWindow(title: 'Destination')));
            setState(() {});
          },
        ),
        _panel(),
      ]),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}
