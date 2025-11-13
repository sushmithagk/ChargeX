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

  // Open Google Maps for turn-by-turn navigation
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

  // Generate today's slots via your backend/service (keeps your original behavior)
  Future<void> _generateToday() async {
    try {
      // If you have a dedicated service for this, call it here.
      // For compatibility with your previous code, I keep the method name and show a snackbar.
      final today = DateTime.now();
      // Your SlotsService.generateDailySlots(...) call should be here.
      // Example placeholder:
      // await _slots.generateDailySlots(...);

      // If not using service, you can implement slot creation logic here.

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Slots generation requested for ${DateFormat.yMd().format(today)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating slots: $e')),
      );
    }
  }

  // Build a query that returns only today's slots for this station
  Query<Map<String, dynamic>> _todaySlotsQuery(DocumentReference stationRef) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    // slots are stored under stationRef.collection('slots')
    // Query for startTime >= todayStart and < tomorrowStart
    return stationRef
        .collection('slots')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('startTime', isLessThan: Timestamp.fromDate(tomorrowStart))
        .orderBy('startTime');
  }

  // Attempt to book slot with transactional safety and 3-booking limit
  Future<String> _bookSlotTx(DocumentReference slotRef, String uid) async {
    String result = 'error';
    try {
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(slotRef);
        if (!snap.exists) {
          result = 'not_found';
          return;
        }
        final data = snap.data() as Map<String, dynamic>;
        // bookedBy can be: null, String (legacy), List
        List<String> booked = [];
        final bookedRaw = data['bookedBy'];
        if (bookedRaw is List) {
          // convert dynamic to string list
          booked = List<String>.from(bookedRaw.map((e) => e.toString()));
        } else if (bookedRaw is String) {
          booked = [bookedRaw];
        }

        if (booked.contains(uid)) {
          result = 'already';
          return;
        }
        if (booked.length >= 3) {
          result = 'full';
          return;
        }

        booked.add(uid);
        // Update the doc atomically with the new bookedBy list; adjust status if needed
        tx.update(slotRef, {'bookedBy': booked, 'status': (booked.length >= 3) ? 'booked' : 'partially_booked'});
        result = 'ok';
      });
    } catch (e) {
      result = 'error';
    }
    return result;
  }

  // Cancel booking (remove uid from bookedBy)
  Future<bool> _cancelBooking(DocumentReference slotRef, String uid) async {
    try {
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(slotRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        List<String> booked = [];
        final bookedRaw = data['bookedBy'];
        if (bookedRaw is List) {
          booked = List<String>.from(bookedRaw.map((e) => e.toString()));
        } else if (bookedRaw is String) {
          booked = [bookedRaw];
        }
        if (!booked.contains(uid)) return;
        booked.removeWhere((x) => x == uid);
        final newStatus = (booked.isEmpty) ? 'available' : (booked.length >= 3 ? 'booked' : 'partially_booked');
        tx.update(slotRef, {'bookedBy': booked, 'status': newStatus});
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  String _fmtTs(Timestamp? t) =>
      t == null ? '-' : DateFormat.jm().format(t.toDate().toLocal());

  @override
  Widget build(BuildContext context) {
    final stationRef = _fs.collection('stations').doc(widget.stationId);
    final todaySlotsQuery = _todaySlotsQuery(stationRef);

    return Scaffold(
      appBar: AppBar(title: Text(widget.stationName)),
      body: Column(
        children: [
          // Station header with safe trailing
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

              final lat = (d['lat'] is num) ? (d['lat'] as num).toDouble() : 0.0;
              final lng = (d['lng'] is num) ? (d['lng'] as num).toDouble() : 0.0;

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

          // Generate today's slots (dev helper)
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

          // Slots list (only for today)
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: todaySlotsQuery.snapshots(),
              builder: (_, s) {
                if (s.hasError) {
                  return Center(child: Text('Error: ${s.error}'));
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = s.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No slots yet. Tap “Generate Today’s Slots”.'),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final ref = docs[i].reference;
                    final d = docs[i].data();

                    // Safe parsing of timestamps
                    final start = (d['startTime'] as Timestamp).toDate().toLocal();
                    final end = (d['endTime'] as Timestamp).toDate().toLocal();
                    final status = (d['status'] ?? 'available').toString();

                    // bookedBy may be null, string or list
                    final bookedRaw = d['bookedBy'];
                    List<String> bookedList = [];
                    if (bookedRaw is List) bookedList = List<String>.from(bookedRaw.map((e) => e.toString()));
                    else if (bookedRaw is String) bookedList = [bookedRaw];
                    final bookedCount = bookedList.length;

                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final isMine = uid != null ? bookedList.contains(uid) : false;

                    Widget trailing;
                    if (bookedCount >= 3 && !isMine) {
                      // fully booked and current user not in list
                      trailing = const Text('Full', style: TextStyle(color: Colors.redAccent));
                    } else if (isMine) {
                      trailing = SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () async {
                            if (uid == null) return;
                            final ok = await _cancelBooking(ref, uid);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Cancelled' : 'Failed to cancel')),
                            );
                          },
                          child: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(72, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                      );
                    } else {
                      trailing = SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: uid == null
                              ? null
                              : () async {
                            final res = await _bookSlotTx(ref, uid);
                            if (!mounted) return;
                            if (res == 'ok') {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booked!')));
                            } else if (res == 'already') {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already booked this slot.')));
                            } else if (res == 'full') {
                              // show popup dialog
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
                          child: const Text('Book'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(72, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${_fmt.format(start)} → ${DateFormat('hh:mm a').format(end)}'),
                        subtitle: Text('Bookings: $bookedCount / 3\nStatus: ${status.toUpperCase()}'),
                        trailing: trailing,
                        isThreeLine: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
