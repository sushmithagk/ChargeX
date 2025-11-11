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

  @override
  Widget build(BuildContext context) {
    final stationRef = _fs.collection('stations').doc(widget.stationId);
    final slotsRef = stationRef.collection('slots').orderBy('startTime');

    return Scaffold(
      appBar: AppBar(title: Text(widget.stationName)),
      body: Column(
        children: [
          // Header with Navigate button (wrapped to avoid overflow)
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
              final status = (d['status'] ?? 'unknown').toString();
              final cap = (d['capacity'] ?? 0).toString();

              final lat = (d['lat'] ?? 0).toDouble();
              final lng = (d['lng'] ?? 0).toDouble();

              return ListTile(
                title: Text(name),
                subtitle: Text('$status • $cap connectors'),
                // Prevent “BOTTOM OVERFLOWED” by constraining the trailing widget
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

          // (Dev helper) generate today's slots
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
              stream: slotsRef.snapshots(),
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

                    final start =
                    (d['startTime'] as Timestamp).toDate().toLocal();
                    final end =
                    (d['endTime'] as Timestamp).toDate().toLocal();
                    final status = (d['status'] ?? 'available') as String;
                    final owner = d['bookedBy'] as String?;
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final isMine =
                    (owner != null && uid != null && owner == uid);

                    // Keep your booking logic identical; only wrap buttons to avoid overflow
                    Widget trailing;
                    if (status == 'available') {
                      trailing = SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: uid == null
                              ? null
                              : () async {
                            final ok = await _slots.bookSlot(
                              stationId: widget.stationId,
                              slotId: docs[i].id,
                              uid: uid,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    ok ? 'Booked!' : 'Already booked / failed'),
                              ),
                            );
                          },
                          child: const Text('Book'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(72, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      );
                    } else if (status == 'booked' && isMine) {
                      trailing = SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () async {
                            final ok = await _slots.cancelBooking(
                              stationId: widget.stationId,
                              slotId: docs[i].id,
                              uid: uid!,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                Text(ok ? 'Cancelled' : 'Failed to cancel'),
                              ),
                            );
                          },
                          child: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(72, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      );
                    } else {
                      trailing = const Text('Booked');
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(
                          '${_fmt.format(start)} → ${DateFormat('hh:mm a').format(end)}',
                        ),
                        subtitle: Text(status.toUpperCase()),
                        trailing: trailing,
                        isThreeLine: false,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
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
