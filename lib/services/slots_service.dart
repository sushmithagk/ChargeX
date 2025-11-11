// lib/services/slots_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SlotsService {
  final _fs = FirebaseFirestore.instance;

  /// Path helper
  CollectionReference<Map<String, dynamic>> _slotsCol(String stationId) =>
      _fs.collection('stations').doc(stationId).collection('slots');

  /// Generate slots for a given day (idempotent: won't duplicate same startTime)
  Future<void> generateDailySlots({
    required String stationId,
    required DateTime day,
    required int startHour, // e.g., 9
    required int endHour,   // e.g., 21  (exclusive)
    required int intervalMinutes, // e.g., 30
  }) async {
    final dateOnly = DateTime(day.year, day.month, day.day);
    final batch = _fs.batch();

    DateTime t = DateTime(day.year, day.month, day.day, startHour);
    final end = DateTime(day.year, day.month, day.day, endHour);

    while (t.isBefore(end)) {
      final start = t;
      final finish = t.add(Duration(minutes: intervalMinutes));
      final q = await _slotsCol(stationId)
          .where('startTime', isEqualTo: Timestamp.fromDate(start.toUtc()))
          .limit(1)
          .get();

      // only create if not exists
      if (q.docs.isEmpty) {
        final doc = _slotsCol(stationId).doc();
        batch.set(doc, {
          'startTime': Timestamp.fromDate(start.toUtc()),
          'endTime': Timestamp.fromDate(finish.toUtc()),
          'status': 'available',    // 'available' | 'booked'
          'bookedBy': null,         // uid or null
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      t = finish;
    }

    await batch.commit();
  }

  /// Book a slot if it's still available (atomic)
  Future<bool> bookSlot({
    required String stationId,
    required String slotId,
    required String uid,
  }) async {
    final ref = _slotsCol(stationId).doc(slotId);
    try {
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw Exception('Slot missing');
        }
        final data = snap.data() as Map<String, dynamic>;
        if ((data['status'] as String?) != 'available') {
          throw Exception('Already booked');
        }
        // Optional: prevent booking past slots
        final start = (data['startTime'] as Timestamp).toDate();
        if (start.isBefore(DateTime.now().toUtc())) {
          throw Exception('Past slot');
        }

        tx.update(ref, {
          'status': 'booked',
          'bookedBy': uid,
          'bookedAt': FieldValue.serverTimestamp(),
        });
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancel only if I’m the owner (atomic)
  Future<bool> cancelBooking({
    required String stationId,
    required String slotId,
    required String uid,
  }) async {
    final ref = _slotsCol(stationId).doc(slotId);
    try {
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Slot missing');
        final data = snap.data() as Map<String, dynamic>;
        if ((data['status'] as String?) != 'booked' ||
            (data['bookedBy'] as String?) != uid) {
          throw Exception('Not your booking');
        }
        tx.update(ref, {
          'status': 'available',
          'bookedBy': null,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
