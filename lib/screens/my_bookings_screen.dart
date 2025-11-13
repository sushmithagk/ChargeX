// lib/screens/my_bookings_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // helper - format timestamp safely
  String _fmtTs(Timestamp? t) {
    if (t == null) return '-';
    try {
      final dt = t.toDate().toLocal();
      return DateFormat('EEE, dd MMM • hh:mm a').format(dt);
    } catch (_) {
      return '-';
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _bookingStreamForUid(String uid) {
    // Collection group query: all 'slots' docs across subcollections
    // WARNING: this exact query (where + orderBy) requires a composite index in Firestore.
    return _fs
        .collectionGroup('slots')
        .where('bookedBy', isEqualTo: uid)
        .orderBy('startTime')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Bookings')),
        body: const Center(child: Text('Please sign in to see your bookings.')),
      );
    }

    final uid = user.uid;
    final stream = _bookingStreamForUid(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            // Show helpful error: Firestore often provides an index-creation URL in the message
            final err = snap.error.toString();
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Text(
                  'Error loading bookings: $err\n\n'
                      'If the error mentions an index, open the URL the error suggests in the Firebase Console, create the composite collection-group index for collection "slots" (bookedBy + startTime), wait for it to build, then restart the app.',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();

              // Defensive parsing for fields that may not be strictly typed:
              String slotId = doc.id;
              // stationId from path: .../stations/{stationId}/slots/{slotId}
              String? stationId;
              try {
                stationId = doc.reference.parent.parent?.id;
              } catch (_) {
                stationId = null;
              }

              // If you stored stationName inside slot doc, use it; otherwise show stationId
              String stationName = '';
              final rawName = d['stationName'];
              if (rawName is String && rawName.isNotEmpty) {
                stationName = rawName;
              } else if (stationId != null) {
                stationName = stationId;
              } else {
                stationName = 'Station';
              }

              // start and end times
              Timestamp? tStart = d['startTime'] as Timestamp?;
              Timestamp? tEnd = d['endTime'] as Timestamp?;
              final startStr = _fmtTs(tStart);
              final endStr = tEnd == null ? '-' : DateFormat('hh:mm a').format(tEnd.toDate().toLocal());

              // bookedBy may sometimes be stored as list or string depending on earlier bugs: handle both
              String? bookedBy;
              final rawBooked = d['bookedBy'];
              if (rawBooked is String) {
                bookedBy = rawBooked;
              } else if (rawBooked is List && rawBooked.isNotEmpty) {
                bookedBy = rawBooked.first?.toString();
              } else {
                bookedBy = null;
              }

              final status = (d['status'] is String) ? (d['status'] as String) : (d['status']?.toString() ?? 'unknown');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stationName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text('$startStr → $endStr'),
                      const SizedBox(height: 8),
                      Text('Status: ${status.toUpperCase()}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (bookedBy != null && bookedBy == uid)
                            OutlinedButton(
                              onPressed: () async {
                                // cancel booking: set bookedBy to null and status to 'available'
                                try {
                                  await doc.reference.update({
                                    'bookedBy': FieldValue.delete(),
                                    'status': 'available',
                                  });
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
                                }
                              },
                              child: const Text('Cancel'),
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
