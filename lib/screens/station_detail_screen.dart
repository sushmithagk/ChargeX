// lib/screens/station_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class StationDetailScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const StationDetailScreen({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  final _fs = FirebaseFirestore.instance;
  final _fmt = DateFormat('EEE, dd MMM • hh:mm a');

  /// Generate slots helper (keeps your existing API/SlotsService separate).
  /// If you already have slot generation logic elsewhere keep it there,
  /// otherwise you can call your service from here.
  Future<void> _generateToday() async {
    final today = DateTime.now();
    // If you have a SlotsService, call it here.
    // For now just show a message (or implement your generator).
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Run your slot generator (dev)')),
    );
  }

  /// Open Google Maps for turn-by-turn navigation
  Future<void> _openDirections(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  /// Book a slot using a transaction.
  /// This enforces a MAX of 3 bookings per slot.
  /// Returns:
  /// - 'ok' -> booked
  /// - 'already' -> user already in bookings
  /// - 'full' -> 3 or more already
  /// - 'error' -> other error
  Future<String> _bookSlotTx({
    required String stationId,
    required String slotId,
    required String uid,
    int maxBookings = 3,
  }) async {
    final slotRef = _fs.collection('stations').doc(stationId).collection('slots').doc(slotId);

    try {
      return await _fs.runTransaction<String>((tx) async {
        final snap = await tx.get(slotRef);
        if (!snap.exists) return 'error';

        final data = snap.data() ?? {};

        // Prefer 'bookings' array (List<String>).
        // But be resilient to different schemas:
        // - If 'bookings' is a List => use it
        // - If 'bookedBy' is a String => convert to list containing that one user
        List<dynamic> bookingsListDynamic = [];
        if (data.containsKey('bookings')) {
          final b = data['bookings'];
          if (b is List) bookingsListDynamic = b;
        } else if (data.containsKey('bookedBy')) {
          final bb = data['bookedBy'];
          if (bb is String && bb.isNotEmpty) bookingsListDynamic = [bb];
        }

        // Normalize and count
        final List<String> bookings =
        bookingsListDynamic.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();

        if (bookings.contains(uid)) return 'already';
        if (bookings.length >= maxBookings) return 'full';

        // Add user UID to the array field 'bookings'
        tx.update(slotRef, {
          'bookings': FieldValue.arrayUnion([uid]),
          // Optional: keep a status
          'status': bookings.length + 1 >= maxBookings ? 'booked' : 'available',
          // Optional: keep a bookingsCount (helps queries)
          'bookingsCount': FieldValue.increment(1),
        });

        return 'ok';
      });
    } catch (e) {
      debugPrint('bookSlotTx error: $e');
      return 'error';
    }
  }

  /// Cancel booking (remove uid from bookings array)
  Future<bool> _cancelBookingTx({
    required String stationId,
    required String slotId,
    required String uid,
  }) async {
    final slotRef = _fs.collection('stations').doc(stationId).collection('slots').doc(slotId);
    try {
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(slotRef);
        if (!snap.exists) return;

        final data = snap.data() ?? {};
        final bookingsListDynamic = (data['bookings'] is List) ? data['bookings'] as List<dynamic> : [];

        final bookings =
        bookingsListDynamic.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();

        if (!bookings.contains(uid)) return;

        tx.update(slotRef, {
          'bookings': FieldValue.arrayRemove([uid]),
          'bookingsCount': FieldValue.increment(-1),
          'status': 'available',
        });
      });
      return true;
    } catch (e) {
      debugPrint('cancelBookingTx error: $e');
      return false;
    }
  }

  String _fmtTs(Timestamp? t) => t == null ? '-' : DateFormat.jm().format(t.toDate().toLocal());

  @override
  Widget build(BuildContext context) {
    final stationRef = _fs.collection('stations').doc(widget.stationId);
    final slotsRef = stationRef.collection('slots').orderBy('startTime');

    return Scaffold(
      appBar: AppBar(title: Text(widget.stationName)),
      body: Column(
        children: [
          // Station header
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: stationRef.snapshots(),
            builder: (_, snap) {
              if (snap.hasError) {
                return ListTile(
                  title: Text(widget.stationName),
                  subtitle: Text('Error: ${snap.error}'),
                );
              }
              if (!snap.hasData) return const LinearProgressIndicator();
              final d = snap.data!.data() ?? {};

              final name = (d['name'] ?? widget.stationName).toString();
              final status = (d['status'] ?? 'unknown').toString();
              final cap = (d['capacity'] ?? 0).toString();
              final lat = (d['lat'] ?? 0).toDouble();
              final lng = (d['lng'] ?? 0).toDouble();

              return ListTile(
                title: Text(name),
                subtitle: Text('$status • $cap connectors'),
                trailing: SizedBox(
                  height: 36,
                  child: TextButton.icon(
                    onPressed: (lat == 0 && lng == 0) ? null : () => _openDirections(lat, lng),
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Navigate'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              );
            },
          ),

          // generate button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _generateToday,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Generate Today’s Slots'),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // slots list (stream)
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: slotsRef.snapshots(),
              builder: (_, s) {
                if (s.hasError) {
                  return Center(child: Text('Error: ${s.error}'));
                }
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final docs = s.data!.docs;

                // Show only today's slots (filter)
                final today = DateTime.now();
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> todayDocs =
                docs.where((doc) {
                  final data = doc.data();
                  if (data['startTime'] is Timestamp) {
                    final ts = (data['startTime'] as Timestamp).toDate().toLocal();
                    return ts.year == today.year && ts.month == today.month && ts.day == today.day;
                  }
                  return false;
                }).toList();

                if (todayDocs.isEmpty) {
                  return const Center(child: Text('No slots yet. Tap “Generate Today’s Slots”.'));
                }

                return ListView.builder(
                  itemCount: todayDocs.length,
                  itemBuilder: (_, i) {
                    final ref = todayDocs[i].reference;
                    final d = todayDocs[i].data();

                    final start = (d['startTime'] as Timestamp).toDate().toLocal();
                    final end = (d['endTime'] as Timestamp).toDate().toLocal();

                    // Determine bookings count robustly:
                    int bookingsCount = 0;
                    if (d.containsKey('bookings') && d['bookings'] is List) {
                      bookingsCount = (d['bookings'] as List).length;
                    } else if (d.containsKey('bookingsCount') && d['bookingsCount'] is int) {
                      bookingsCount = d['bookingsCount'] as int;
                    } else if (d.containsKey('bookedBy') && d['bookedBy'] is String && (d['bookedBy'] as String).isNotEmpty) {
                      // fallback single-booking
                      bookingsCount = 1;
                    }

                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final bool isBookedByMe;
                    if (d.containsKey('bookings') && d['bookings'] is List) {
                      final bookings = (d['bookings'] as List).map((e) => e?.toString() ?? '').toList();
                      isBookedByMe = uid != null && bookings.contains(uid);
                    } else if (d.containsKey('bookedBy') && d['bookedBy'] is String) {
                      isBookedByMe = uid != null && (d['bookedBy'] as String) == uid;
                    } else {
                      isBookedByMe = false;
                    }

                    final status = (d['status'] ?? 'available').toString();

                    Widget trailing;
                    if (isBookedByMe) {
                      trailing = SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: uid == null
                              ? null
                              : () async {
                            final ok = await _cancelBookingTx(
                              stationId: widget.stationId,
                              slotId: todayDocs[i].id,
                              uid: uid,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Cancelled' : 'Failed to cancel')),
                            );
                          },
                          child: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(72, 36)),
                        ),
                      );
                    } else {
                      trailing = SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: uid == null
                              ? null
                              : () async {
                            final res = await _bookSlotTx(
                              stationId: widget.stationId,
                              slotId: todayDocs[i].id,
                              uid: uid,
                              maxBookings: 3,
                            );
                            if (!mounted) return;
                            if (res == 'ok') {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booked!')));
                            } else if (res == 'already') {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already booked this slot.')));
                            } else if (res == 'full') {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Slot full'),
                                  content: const Text('Sorry — this slot is already fully booked.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                                  ],
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking failed. Try again.')));
                            }
                          },
                          child: const Text(
                            'Book',
                            style: TextStyle(color: Colors.white),  // <-- FIXED
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(72, 36),
                            backgroundColor: Colors.blue,          // <-- visible button color
                          ),
                        ),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${_fmt.format(start)} → ${DateFormat('hh:mm a').format(end)}'),
                        subtitle: Text('Bookings: $bookingsCount / 3\nStatus: ${status.toUpperCase()}'),
                        trailing: trailing,
                        isThreeLine: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}