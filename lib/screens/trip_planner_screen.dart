// lib/screens/trip_planner_screen.dart
import 'dart:async';
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
  // === Put your Google API key here (Directions & Maps enabled) ===
  static const String googleApiKey = 'AIzaSyBREDegu1Lj5gXhdrSCcnAa1omChs7-EHs';

  GoogleMapController? _mapController;
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  LatLng? _currentLatLng; // device location
  LatLng? _originLatLng; // source/origin (editable)
  LatLng? _destinationLatLng; // destination (editable)

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routePoints = [];

  List<Map<String, dynamic>> _stations = []; // loaded from Firestore
  final Set<Marker> _stationMarkers = {};

  bool _loadingRoute = false;

  /// How close a station must be to the route (meters) to be considered "on route".
  double _stationThresholdMeters = 5000.0; // 5 km

  @override
  void initState() {
    super.initState();
    _fetchStationsFromFirestore();
    _initLocation(); // get device location but don't force it as origin
  }

  Future<void> _initLocation() async {
    final pos = await _determinePosition();
    if (pos != null) {
      _currentLatLng = LatLng(pos.latitude, pos.longitude);
      // if user hasn't set origin, keep "current" as a hint but don't automatically set origin marker
      setState(() {});
    }
  }

  Future<void> _fetchStationsFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('stations').get();
      _stations = snap.docs.map((d) {
        final data = d.data();
        double lat = 0.0, lng = 0.0;
        try {
          lat = (data['lat'] is num) ? (data['lat'] as num).toDouble() : double.parse('${data['lat']}');
          lng = (data['lng'] is num) ? (data['lng'] as num).toDouble() : double.parse('${data['lng']}');
        } catch (_) {}
        return {
          'id': d.id,
          'name': data['name'] ?? data['station_name'] ?? 'Station',
          'lat': lat,
          'lng': lng,
          'raw': data,
        };
      }).toList();
      setState(() {});
    } catch (e) {
      debugPrint('Failed to fetch stations: $e');
    }
  }

  Future<Position?> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    } catch (e) {
      debugPrint('Location permission/availability error: $e');
      return null;
    }
  }

  // Set origin from address typed into source field
  Future<void> _setOriginFromAddress() async {
    final address = _sourceController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a source address')));
      return;
    }
    try {
      final locs = await geocode.locationFromAddress(address);
      if (locs.isNotEmpty) {
        final loc = locs.first;
        _originLatLng = LatLng(loc.latitude, loc.longitude);
        _addOrUpdateMarker('origin', _originLatLng!, title: 'Source');
        setState(() {});
        await _moveCameraTo(_originLatLng!, zoom: 13);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source address not found')));
      }
    } catch (e) {
      debugPrint('Geocoding origin failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source lookup failed')));
    }
  }

  // Set destination from address typed into destination field
  Future<void> _setDestinationFromAddress() async {
    final address = _destinationController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a destination address')));
      return;
    }
    try {
      final locs = await geocode.locationFromAddress(address);
      if (locs.isNotEmpty) {
        final loc = locs.first;
        _destinationLatLng = LatLng(loc.latitude, loc.longitude);
        _addOrUpdateMarker('destination', _destinationLatLng!, title: 'Destination');
        setState(() {});
        await _moveCameraTo(_destinationLatLng!, zoom: 13);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination address not found')));
      }
    } catch (e) {
      debugPrint('Geocoding destination failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination lookup failed')));
    }
  }

  // Use device location as origin
  Future<void> _useMyLocationAsOrigin() async {
    final pos = await _determinePosition();
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to get current location')));
      return;
    }
    _currentLatLng = LatLng(pos.latitude, pos.longitude);
    _originLatLng = _currentLatLng;
    _sourceController.text = '${_originLatLng!.latitude.toStringAsFixed(6)}, ${_originLatLng!.longitude.toStringAsFixed(6)}';
    _addOrUpdateMarker('origin', _originLatLng!, title: 'You (origin)');
    setState(() {});
    await _moveCameraTo(_originLatLng!, zoom: 14);
  }

  // Shared helper: add or update a marker by id string
  void _addOrUpdateMarker(String id, LatLng pos, {String? title}) {
    _markers.removeWhere((m) => m.markerId.value == id);
    _markers.add(Marker(markerId: MarkerId(id), position: pos, infoWindow: InfoWindow(title: title ?? id)));
  }

  // Long press on map: set origin; Tap on map: set destination
  void _onMapTap(LatLng p) async {
    _destinationLatLng = p;
    _destinationController.text = '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
    _addOrUpdateMarker('destination', p, title: 'Destination');
    setState(() {});
    await _moveCameraTo(p, zoom: 13);
  }

  void _onMapLongPress(LatLng p) async {
    _originLatLng = p;
    _sourceController.text = '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
    _addOrUpdateMarker('origin', p, title: 'Source (custom)');
    setState(() {});
    await _moveCameraTo(p, zoom: 13);
  }

  // Main route calculation using v2 API (PolylineRequest)
  Future<void> _findRoute() async {
    // Validate origin/destination
    if (_originLatLng == null) {
      // If origin not set but current location available, ask user to use it
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set source (origin) first (use my location or type/set one).')));
      return;
    }
    if (_destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set destination first.')));
      return;
    }

    setState(() {
      _loadingRoute = true;
      _polylines.clear();
      _routePoints.clear();
      _stationMarkers.clear();
    });

    try {
      final polylinePoints = PolylinePoints();
      final originPoint = PointLatLng(_originLatLng!.latitude, _originLatLng!.longitude);
      final destPoint = PointLatLng(_destinationLatLng!.latitude, _destinationLatLng!.longitude);

      final request = PolylineRequest(
        origin: originPoint,
        destination: destPoint,
        mode: TravelMode.driving, // v2 requires `mode` named argument in request
      );

      debugPrint('Requesting route (v2) via flutter_polyline_points...');
      final result = await polylinePoints.getRouteBetweenCoordinates(
        request: request,
        googleApiKey: googleApiKey,
      );

      debugPrint('Polyline result: points=${result.points.length}, status=${result.status ?? 'null'}, error=${result.errorMessage ?? 'null'}');

      if (result.points.isEmpty) {
        // If no points returned, show helpful message (could be REQUEST_DENIED)
        final status = (result.status ?? '').toUpperCase();
        if (status == 'REQUEST_DENIED') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Directions request denied. Check API, billing, key restrictions.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No route found')));
        }
        return;
      }

      _routePoints.clear();
      for (final p in result.points) {
        _routePoints.add(LatLng(p.latitude.toDouble(), p.longitude.toDouble()));
      }

      // Densify route to improve station proximity checks
      final densified = _densifyRoute(_routePoints, 100.0);
      _routePoints
        ..clear()
        ..addAll(densified);

      // Draw polyline
      final polyline = Polyline(
        polylineId: PolylineId('route_${DateTime.now().millisecondsSinceEpoch}'),
        points: _routePoints,
        color: Colors.blueAccent,
        width: 6,
      );
      _polylines.clear();
      _polylines.add(polyline);

      // Compute stations on route and add markers
      _computeStationsOnRoute();

      // Fit map bounds to route
      final bounds = _boundsFromLatLngList(_routePoints);
      if (_mapController != null) {
        try {
          await Future.delayed(const Duration(milliseconds: 100));
          await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
        } catch (e) {
          // fallback: center and zoom
          final center = LatLng((bounds.northeast.latitude + bounds.southwest.latitude) / 2,
              (bounds.northeast.longitude + bounds.southwest.longitude) / 2);
          await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(center, 12));
        }
      }
    } catch (e, st) {
      debugPrint('Directions API error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error fetching route')));
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  // Densify route: insert intermediate points so no segment > max meters
  List<LatLng> _densifyRoute(List<LatLng> pts, double maxSegmentMeters) {
    if (pts.length < 2) return List<LatLng>.from(pts);
    final out = <LatLng>[];
    for (int i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      out.add(a);
      final segLen = _distanceMeters(a, b);
      if (segLen > maxSegmentMeters) {
        final segments = (segLen / maxSegmentMeters).ceil();
        for (int s = 1; s < segments; s++) {
          final t = s / segments;
          final lat = a.latitude + (b.latitude - a.latitude) * t;
          final lng = a.longitude + (b.longitude - a.longitude) * t;
          out.add(LatLng(lat, lng));
        }
      }
    }
    out.add(pts.last);
    return out;
  }

  // Compute and add station markers that are within threshold to the route
  void _computeStationsOnRoute() {
    if (_routePoints.isEmpty || _stations.isEmpty) return;

    // Pre-filter stations by route bounding box expanded by threshold
    final bounds = _boundsFromLatLngList(_routePoints);
    final degLatPerMeter = 1 / 111320.0;
    final expandDeg = _stationThresholdMeters * degLatPerMeter;

    final south = bounds.southwest.latitude - expandDeg;
    final north = bounds.northeast.latitude + expandDeg;
    final west = bounds.southwest.longitude - expandDeg;
    final east = bounds.northeast.longitude + expandDeg;

    final candidates = _stations.where((s) {
      final lat = (s['lat'] as num).toDouble();
      final lng = (s['lng'] as num).toDouble();
      return lat >= south && lat <= north && lng >= west && lng <= east;
    }).toList();

    final found = <Map<String, dynamic>>[];

    for (final s in candidates) {
      final LatLng stationPt = LatLng(s['lat'], s['lng']);
      double minD = double.infinity;
      for (int i = 0; i < _routePoints.length - 1; i++) {
        final a = _routePoints[i];
        final b = _routePoints[i + 1];
        final d = _distancePointToSegmentMeters(stationPt, a, b);
        if (d < minD) minD = d;
      }
      if (minD <= _stationThresholdMeters) {
        found.add({...s, 'distToRouteMeters': minD});
      }
    }

    // sort by distance to route
    found.sort((a, b) => (a['distToRouteMeters'] as double).compareTo(b['distToRouteMeters'] as double));

    // create markers
    _stationMarkers.clear();
    for (final f in found) {
      final LatLng pos = LatLng(f['lat'], f['lng']);
      final double distMeters = (f['distToRouteMeters'] as double);
      final marker = Marker(
        markerId: MarkerId('station_${f['id']}'),
        position: pos,
        infoWindow: InfoWindow(
          title: f['name'] ?? 'Station',
          snippet: '${(distMeters / 1000).toStringAsFixed(2)} km from route',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap: () => _showStationBottomSheet(f, distMeters),
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
        final lat = station['lat'] as double;
        final lng = station['lng'] as double;
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(station['name'] ?? 'Station', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d'); // driving
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(web)) await launchUrl(web);
  }

  // haversine distance (meters)
  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final sinDlat = math.sin(dLat / 2);
    final sinDlon = math.sin(dLon / 2);
    final aa = sinDlat * sinDlat + math.cos(lat1) * math.cos(lat2) * sinDlon * sinDlon;
    final c = 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
    return R * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180.0;

  // distance from point p to segment v-w (meters) approximate but good for short distances
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
    if (list.isEmpty) {
      return LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(0, 0));
    }
    if (list.length == 1) {
      final p = list.first;
      final delta = 0.001;
      return LatLngBounds(southwest: LatLng(p.latitude - delta, p.longitude - delta), northeast: LatLng(p.latitude + delta, p.longitude + delta));
    }
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
    final c = _mapController;
    if (c == null) return;
    try {
      await c.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: zoom)));
    } catch (_) {
      try {
        await c.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: zoom)));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    _mapController?.dispose();
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
            // Source row
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _sourceController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Enter source address / coords', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
                  onSubmitted: (_) => _setOriginFromAddress(),
                ),
              ),
              ElevatedButton(onPressed: _setOriginFromAddress, child: const Text('Set')),
            ]),
            const SizedBox(height: 8),
            // Destination row
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Enter destination address / coords', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
                  onSubmitted: (_) => _setDestinationFromAddress(),
                ),
              ),
              ElevatedButton(onPressed: _setDestinationFromAddress, child: const Text('Set')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _useMyLocationAsOrigin,
                icon: const Icon(Icons.my_location),
                label: const Text('Use my location'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loadingRoute ? null : _findRoute,
                  child: _loadingRoute ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Find route'),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Stations on route: ${_stationMarkers.length}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 4),
            const Text('Tap map to set destination. Long-press to set source.', style: TextStyle(fontSize: 11, color: Colors.white60)),
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
          onTap: _onMapTap,
          onLongPress: _onMapLongPress,
        ),
        _buildControlPanel(),
      ]),
    );
  }
}
