// lib/screens/my_bookings_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/slots_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _fs = FirebaseFirestore.instance;
  final _slotsService = SlotsService();
  final _fmt = DateFormat('EEE, dd MMM • hh:mm a');

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Bookings')),
        body: const Center(child: Text('Sign in to view your bookings')),
      );
    }

    final bookingsRef = _fs.collection('users').doc(uid).collection('bookings').orderBy('startTime');

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: bookingsRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error loading bookings: ${snap.error}'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final start = (d['startTime'] as Timestamp?)?.toDate();
              final end = (d['endTime'] as Timestamp?)?.toDate();
              final stationId = d['stationId'] as String?;
              final stationNameFromDoc = d['stationName'] as String?;
              final status = (d['status'] as String?) ?? 'booked';

              // if booking saved stationName in the booking doc use it, otherwise fetch
              Widget titleWidget;
              if (stationNameFromDoc != null && stationNameFromDoc.isNotEmpty) {
                titleWidget = Text(stationNameFromDoc, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
              } else if (stationId != null) {
                // fetch station doc name
                titleWidget = FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: _fs.collection('stations').doc(stationId).get(),
                  builder: (context, ss) {
                    if (ss.hasError) return Text(stationId);
                    if (!ss.hasData) return Text(stationId);
                    final stationData = ss.data!.data();
                    final name = stationData?['name']?.toString() ?? stationId;
                    return Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
                  },
                );
              } else {
                titleWidget = const Text('Station');
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: titleWidget,
                  subtitle: Text(
                    '${start != null ? _fmt.format(start.toLocal()) : '-'} → ${end != null ? DateFormat('hh:mm a').format(end.toLocal()) : '-'}\nStatus: ${status.toUpperCase()}',
                  ),
                  isThreeLine: true,
                  trailing: SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () async {
                        final slotId = d['slotId'] as String?;
                        final bookingDocId = docs[i].id;
                        final stId = stationId;
                        if (stId == null || slotId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing booking meta')));
                          return;
                        }

                        final ok = await _slotsService.cancelBooking(
                          stationId: stId,
                          slotId: slotId,
                          uid: uid,
                          bookingDocId: bookingDocId,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Cancelled' : 'Cancel failed')),
                        );
                      },
                      child: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(72, 36)),
                    ),
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
