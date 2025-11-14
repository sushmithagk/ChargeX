// lib/screens/station_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/slots_service.dart';

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
  final _slots = SlotsService();
  final _fmt = DateFormat('EEE, dd MMM • hh:mm a');

  /// generate today's slots (keeps existing logic)
  Future<void> _generateToday() async {
    final today = DateTime.now();
    await _slots.generateDailySlots(
      stationId: widget.stationId,
      day: today,
      startHour: 9,
      endHour: 21,
      intervalMinutes: 30,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Slots generated for today')),
    );
  }

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

  /// safe util to get booking count from a slot document value
  int _getBookingCount(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is List) return v.length;
    if (v is String) {
      // if some string representation — try to parse integer
      final parsed = int.tryParse(v);
      return parsed ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final stationRef = _fs.collection('stations').doc(widget.stationId);

    // Only today's slots: from local start of day to next day start
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));

    // Note: Firestore stores Timestamps; we use Timestamp.fromDate()
    final slotsQuery = stationRef
        .collection('slots')
        .where('startTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThan: Timestamp.fromDate(startOfNextDay))
        .orderBy('startTime');

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
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }

              final d = snap.data!.data() ?? {};
              final name = (d['name'] ?? widget.stationName).toString();
              final statusRaw = d['status'];
              final status = (statusRaw is String) ? statusRaw : statusRaw?.toString() ?? 'unknown';
              final capValue = d['capacity'];
              final cap = (capValue is int) ? capValue : int.tryParse(capValue?.toString() ?? '') ?? 0;

              final lat = (d['lat'] is num) ? (d['lat'] as num).toDouble() : 0.0;
              final lng = (d['lng'] is num) ? (d['lng'] as num).toDouble() : 0.0;

              return ListTile(
                title: Text(name),
                //subtitle: Text('$status • $cap connectors'),
                trailing: SizedBox(
                  height: 36,
                  child: TextButton.icon(
                    onPressed: (lat == 0 && lng == 0)
                        ? null
                        : () => _openDirections(lat, lng),
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

          // Slots list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: slotsQuery.snapshots(),
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
                    final doc = docs[i];
                    final d = doc.data();

                    final start = (d['startTime'] as Timestamp?)?.toDate()?.toLocal();
                    final end = (d['endTime'] as Timestamp?)?.toDate()?.toLocal();
                    final statusRaw = d['status'];
                    final status = (statusRaw is String) ? statusRaw : statusRaw?.toString() ?? 'available';
                    final owner = d['bookedBy'];
                    final bookingsCount = _getBookingCount(d['bookedBy'] ?? d['bookings']);

                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final isMine = (owner is String && uid != null && owner == uid) ||
                        (owner is List && uid != null && owner.contains(uid));

                    // trailing button: constrained to avoid overflow
                    Widget trailingWidget;
                    if (status == 'available') {
                      trailingWidget = SizedBox(
                        width: 84,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: uid == null
                              ? null
                              : () async {
                            // call slots service; it should handle concurrency & limit=3
                            final res = await _slots.bookSlot(
                              stationId: widget.stationId,
                              slotId: doc.id,
                              uid: uid,
                            );

                            if (!mounted) return;
                            switch (res) {
                              case 'ok':
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booked!')));
                                break;
                              case 'already':
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already booked this slot.')));
                                break;
                              case 'full':
                              // popup
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
                                break;
                              case 'not_found':
                              case 'error':
                              default:
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking failed. Try again.')));
                            }
                          },
                          child: const Text(
                            'Book',
                            style: TextStyle(fontSize: 14, height: 1.2), // prevents text from cutting
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(72, 42),   // increased height
                            padding: const EdgeInsets.symmetric(vertical: 8), // balanced padding
                            alignment: Alignment.center,        // proper alignment
                          ),

                        ),
                      );
                    } else if (status == 'booked' && isMine) {
                      // show cancel/booked state for user's own booking
                      trailingWidget = SizedBox(
                        width: 84,
                        height: 40,
                        child: OutlinedButton(
                          onPressed: uid == null
                              ? null
                              : () async {
                            // call your slots service to toggle/cancel (adapt to your API)
                            final res = await _slots.bookSlot(
                              stationId: widget.stationId,
                              slotId: doc.id,
                              uid: uid,
                            );
                            if (!mounted) return;
                            // we expect your service to return codes as above
                            switch (res) {
                              case 'ok':
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booked!')));
                                break;
                              case 'already':
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already booked this slot.')));
                                break;
                              case 'full':
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
                                break;
                              case 'not_found':
                              case 'error':
                              default:
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking failed. Try again.')));
                            }
                          },
                          child: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(72, 36)),
                        ),
                      );
                    } else {
                      trailingWidget = SizedBox(
                        width: 84,
                        height: 40,
                        child: OutlinedButton(
                          onPressed: null,
                          child: const Text('Booked'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(72, 36)),
                        ),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${start != null ? _fmt.format(start) : '-'} → ${end != null ? DateFormat('hh:mm a').format(end) : '-'}'),
                        subtitle: Text('Bookings: $bookingsCount / ${d['capacity'] ?? 3}'),
                        trailing: trailingWidget,
                        isThreeLine: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
