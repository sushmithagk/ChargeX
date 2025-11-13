// lib/screens/trip_planner_screen.dart
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocode;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({Key? key}) : super(key: key);

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  // ← SET YOUR REAL KEY HERE (do NOT commit to public repo)
  static const String googleApiKey = 'AIzaSyBREDegu1Lj5gXhdrSCcnAa1omChs7-EHs';

  GoogleMapController? _mapController;
  final TextEditingController _destinationController = TextEditingController();

  LatLng? _currentLatLng;
  LatLng? _destinationLatLng;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routePoints = [];

  List<Map<String, dynamic>> _stations = []; // loaded from Firestore
  final Set<Marker> _stationMarkers = {};

  bool _loadingRoute = false;
  final double _stationThresholdMeters = 2500; // 2.5km threshold

  @override
  void initState() {
    super.initState();
    _ensureLocationThenInit();
    _fetchStationsFromFirestore();
  }

  Future<void> _ensureLocationThenInit() async {
    final pos = await _determinePosition(showDialogs: true);
    if (pos != null) {
      _currentLatLng = LatLng(pos.latitude, pos.longitude);
      _markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: _currentLatLng!,
        infoWindow: const InfoWindow(title: 'You are here'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
      setState(() {});
      // move camera once map is created
      if (_mapController != null) {
        _mapController!.moveCamera(CameraUpdate.newLatLngZoom(_currentLatLng!, 13));
      }
    }
  }

  Future<void> _fetchStationsFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('stations').get();
      _stations = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': data['name'] ?? data['station_name'] ?? 'Station',
          'lat': (data['lat'] is num) ? (data['lat'] as num).toDouble() : double.tryParse('${data['lat']}') ?? 0.0,
          'lng': (data['lng'] is num) ? (data['lng'] as num).toDouble() : double.tryParse('${data['lng']}') ?? 0.0,
          'raw': data,
        };
      }).toList();
      setState(() {});
    } catch (e) {
      debugPrint('Failed to fetch stations: $e');
    }
  }

  /// returns Position if permission + service OK; shows helpful messages if not.
  Future<Position?> _determinePosition({bool showDialogs = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showDialogs) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable Location services on device')),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (showDialogs) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (showDialogs) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Open app settings.')),
          );
        }
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      return pos;
    } catch (e) {
      debugPrint('determinePosition error: $e');
      if (showDialogs) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error getting location')));
      }
      return null;
    }
  }

  Future<void> _setDestinationFromAddress() async {
    final address = _destinationController.text.trim();
    if (address.isEmpty) return;

    try {
      final locs = await geocode.locationFromAddress(address);
      if (locs.isNotEmpty) {
        final loc = locs.first;
        _destinationLatLng = LatLng(loc.latitude, loc.longitude);
        _markers.removeWhere((m) => m.markerId.value == 'destination');
        _markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          infoWindow: InfoWindow(title: 'Destination', snippet: address),
        ));
        setState(() {});
        _moveCameraTo(_destinationLatLng!, zoom: 13);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address not found')));
      }
    } catch (e) {
      debugPrint('Geocoding failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address lookup failed')));
    }
  }

  Future<void> _findRoute() async {
    // ensure current location
    if (_currentLatLng == null) {
      final p = await _determinePosition(showDialogs: true);
      if (p == null) {
        return;
      }
      _currentLatLng = LatLng(p.latitude, p.longitude);
      _markers.removeWhere((m) => m.markerId.value == 'origin');
      _markers.add(Marker(markerId: const MarkerId('origin'), position: _currentLatLng!, infoWindow: const InfoWindow(title: 'You')));
      setState(() {});
    }

    // ensure destination
    if (_destinationLatLng == null) {
      await _setDestinationFromAddress();
      if (_destinationLatLng == null) {
        return;
      }
    }

    setState(() {
      _loadingRoute = true;
      _polylines.clear();
      _routePoints.clear();
      _stationMarkers.clear();
    });

    try {
      // Use PolylinePoints new API
      final req = PolylineRequest(
        origin: PointLatLng(_currentLatLng!.latitude, _currentLatLng!.longitude),
        destination: PointLatLng(_destinationLatLng!.latitude, _destinationLatLng!.longitude),
        mode: TravelMode.driving,
      );
      final polylinePoints = PolylinePoints();
      final result = await polylinePoints.getRouteBetweenCoordinates(request: req, googleApiKey: googleApiKey);

      if (result.points.isNotEmpty) {
        _routePoints.clear();
        for (final p in result.points) {
          _routePoints.add(LatLng(p.latitude.toDouble(), p.longitude.toDouble()));
        }

        final polyline = Polyline(
          polylineId: PolylineId('route_${DateTime.now().millisecondsSinceEpoch}'),
          points: _routePoints,
          color: Colors.blueAccent,
          width: 6,
        );

        _polylines.clear();
        _polylines.add(polyline);

        _computeStationsOnRoute();

        final bounds = _boundsFromLatLngList(_routePoints);
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No route found')));
      }
    } catch (e) {
      debugPrint('Directions API error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error fetching route')));
    } finally {
      setState(() => _loadingRoute = false);
    }
  }

  void _computeStationsOnRoute() {
    if (_routePoints.isEmpty || _stations.isEmpty) return;
    final found = <Map<String, dynamic>>[];

    for (final s in _stations) {
      final pt = LatLng(s['lat'], s['lng']);
      double minD = double.infinity;
      for (int i = 0; i < _routePoints.length - 1; i++) {
        final a = _routePoints[i];
        final b = _routePoints[i + 1];
        final d = _distancePointToSegmentMeters(pt, a, b);
        if (d < minD) minD = d;
      }
      if (minD <= _stationThresholdMeters) {
        found.add({...s, 'distToRouteMeters': minD});
      }
    }

    found.sort((a, b) => (a['distToRouteMeters'] as double).compareTo(b['distToRouteMeters'] as double));

    _stationMarkers.clear();
    for (final f in found) {
      final pos = LatLng(f['lat'], f['lng']);
      final d = (f['distToRouteMeters'] as double);
      final marker = Marker(
        markerId: MarkerId('station_${f['id']}'),
        position: pos,
        infoWindow: InfoWindow(title: f['name'] ?? 'Station', snippet: '${(d / 1000).toStringAsFixed(2)} km from route'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap: () => _showStationBottomSheet(f, d),
      );
      _stationMarkers.add(marker);
    }

    setState(() {
      _markers.removeWhere((m) => m.markerId.value.startsWith('station_'));
      _markers.addAll(_stationMarkers);
    });
  }

  void _showStationBottomSheet(Map<String, dynamic> station, double distMeters) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final lat = station['lat'];
        final lng = station['lng'];
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(station['name'] ?? 'Station', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Distance from route: ${(distMeters / 1000).toStringAsFixed(2)} km'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openGoogleMapsNavigation(lat, lng),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate (Google Maps)'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  Future<void> _openGoogleMapsNavigation(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(web)) await launchUrl(web);
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = _degToRad(a.latitude), lat2 = _degToRad(b.latitude);
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final sinDlat = math.sin(dLat / 2);
    final sinDlon = math.sin(dLon / 2);
    final aa = sinDlat * sinDlat + math.cos(lat1) * math.cos(lat2) * sinDlon * sinDlon;
    final c = 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
    return R * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180.0;

  double _distancePointToSegmentMeters(LatLng p, LatLng v, LatLng w) {
    final latRef = _degToRad((v.latitude + w.latitude) / 2.0);
    final xP = (p.longitude - v.longitude) * math.cos(latRef);
    final yP = (p.latitude - v.latitude);
    final xW = (w.longitude - v.longitude) * math.cos(latRef);
    final yW = (w.latitude - v.latitude);
    final segLen2 = xW * xW + yW * yW;
    double t = 0.0;
    if (segLen2 > 0) {
      t = ((xP * xW) + (yP * yW)) / segLen2;
      t = t.clamp(0.0, 1.0);
    }
    final projx = v.longitude + (xW * t) / math.cos(latRef);
    final projy = v.latitude + yW * t;
    final proj = LatLng(projy, projx);
    return _distanceMeters(p, proj);
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double south = list.first.latitude, north = list.first.latitude;
    double west = list.first.longitude, east = list.first.longitude;
    for (final p in list) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    return LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east));
  }

  Future<void> _moveCameraTo(LatLng latLng, {double zoom = 14}) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: zoom)));
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Widget _buildControlPanel() {
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
                  decoration: const InputDecoration(hintText: 'Enter destination address', border: InputBorder.none),
                ),
              ),
              ElevatedButton(onPressed: _setDestinationFromAddress, child: const Text('Set')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final pos = await _determinePosition(showDialogs: true);
                  if (pos == null) {
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
            const SizedBox(height: 6),
            Text('Stations on route: ${_stationMarkers.length}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _currentLatLng ?? const LatLng(12.9716, 77.5946);
    final allMarkers = {..._markers, ..._stationMarkers};
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Planner')),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 12),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          markers: allMarkers,
          polylines: _polylines,
          onMapCreated: (c) => _mapController = c,
          onTap: (p) {
            _destinationLatLng = p;
            _destinationController.text = '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
            _markers.removeWhere((m) => m.markerId.value == 'destination');
            _markers.add(Marker(markerId: const MarkerId('destination'), position: p, infoWindow: const InfoWindow(title: 'Destination')));
            setState(() {});
          },
        ),
        _buildControlPanel(),
      ]),
      // NO floatingActionButton (was causing overlap). If you want one, I'll add it placed safely.
    );
  }
}
