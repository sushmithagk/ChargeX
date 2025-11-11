import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fmt = DateFormat('EEE, dd MMM • hh:mm a');

    final query = FirebaseFirestore.instance
        .collectionGroup('slots')
        .where('bookedBy', isEqualTo: uid)
        .orderBy('startTime');

    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (_, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No bookings yet."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final start = (d['startTime'] as Timestamp).toDate();
              final end = (d['endTime'] as Timestamp).toDate();
              final stationId = docs[i].reference.parent.parent!.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(fmt.format(start)),
                  subtitle: Text("Ends: ${DateFormat('hh:mm a').format(end)}"),
                  trailing: const Icon(Icons.ev_station, color: Colors.indigoAccent),
                  onTap: () {
                    Navigator.pushNamed(context, '/station', arguments: stationId);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
