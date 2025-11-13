// lib/screens/my_bookings_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:intl/intl.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late final String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = _auth.currentUser?.uid;
  }

  String _formatSlot(DateTime dtStart, DateTime dtEnd) {
    final f = DateFormat('EEE, dd MMM • hh:mm a');
    return '${f.format(dtStart)} → ${DateFormat('hh:mm a').format(dtEnd)}';
  }

  /// We query collection-group 'slots' only by bookedBy equality.
  /// This avoids composite index requirements. We then filter status
  /// client-side to only show booked slots.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _bookingsStream() {
    if (_uid == null) return null;
    return _fs.collectionGroup('slots').where('bookedBy', isEqualTo: _uid).snapshots();
  }

  Future<void> _cancelBooking(DocumentReference slotRef) async {
    try {
      // revert slot to available; remove bookedBy
      await slotRef.update({
        'status': 'available',
        'bookedBy': FieldValue.delete(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Bookings')),
        body: const Center(child: Text('You must be signed in to see bookings.')),
      );
    }

    final stream = _bookingsStream();

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: stream == null
          ? const Center(child: Text('No bookings (not signed in).'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            // Show helpful message but keep concise
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Text(
                  'Error loading bookings: ${snap.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Only show docs where status == 'booked' (client-side filter)
          final allDocs = snap.data!.docs;
          final bookedDocs = allDocs.where((d) {
            final map = d.data();
            final status = map['status'];
            // status might be null or non-string; handle safely
            return status != null && status.toString().toLowerCase() == 'booked';
          }).toList();

          if (bookedDocs.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: bookedDocs.length,
            itemBuilder: (context, i) {
              final doc = bookedDocs[i];
              final data = doc.data();

              // startTime / endTime may be Timestamp or null
              DateTime? start;
              DateTime? end;
              final s = data['startTime'];
              final e = data['endTime'];
              if (s is Timestamp) start = s.toDate().toLocal();
              if (e is Timestamp) end = e.toDate().toLocal();

              // Station info: prefer a stationName field in the slot doc;
              // otherwise try to derive the parent station id from the doc ref path.
              String stationLabel = '';
              if (data.containsKey('stationName') && data['stationName'] != null) {
                stationLabel = data['stationName'].toString();
              } else {
                // slot document path: /stations/{stationId}/slots/{slotId}
                final parent = doc.reference.parent.parent;
                stationLabel = parent?.id ?? '(unknown station)';
              }

              final slotId = doc.id;
              final statusText = (data['status'] ?? '').toString().toUpperCase();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // top row: station label + actions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              stationLabel,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                          // small copy button for slot id
                          IconButton(
                            onPressed: () => _copyToClipboard(slotId),
                            icon: const Icon(Icons.copy_outlined, size: 20),
                            tooltip: 'Copy slot id',
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // times
                      if (start != null && end != null)
                        Text(
                          _formatSlot(start, end),
                          style: const TextStyle(fontSize: 14),
                        )
                      else
                        const Text('-', style: TextStyle(fontSize: 14)),

                      const SizedBox(height: 8),

                      // status + actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status: $statusText', style: const TextStyle(fontWeight: FontWeight.w500)),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () async {
                                  // confirm cancel
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Cancel booking'),
                                      content: const Text('Are you sure you want to cancel this booking?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await _cancelBooking(doc.reference);
                                  }
                                },
                                child: const Text('Cancel'),
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
