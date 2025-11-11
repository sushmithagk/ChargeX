// lib/services/slots_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SlotsService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Create slots for one station for a given day range (local time → stored as UTC)
  /// Example: 09:00–21:00 every 30 mins → creates 24 slots.
  Future<void> generateDailySlots({
    required String stationId,
    required DateTime day,          // local date (only Y-M-D used)
    int startHour = 9,              // 09:00
    int endHour = 21,               // 21:00
    int intervalMinutes = 30,
  }) async {
    final start = DateTime(day.year, day.month, day.day, startHour).toUtc();
    final end = DateTime(day.year, day.month, day.day, endHour).toUtc();

    final batch = _fs.batch();
    final slotsCol = _fs.collection('stations').doc(stationId).collection('slots');

    for (DateTime t = start; t.isBefore(end); t = t.add(Duration(minutes: intervalMinutes))) {
      final slotId = t.toIso8601String();                       // stable id
      final ref = slotsCol.doc(slotId);
      batch.set(ref, {
        'startTime': Timestamp.fromDate(t),
        'endTime': Timestamp.fromDate(t.add(Duration(minutes: intervalMinutes))),
        'status': 'available',         // available | booked
        'bookedBy': null,
        'bookedAt': null,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Book a single slot (transaction prevents double-book)
  Future<bool> bookSlot({
    required String stationId,
    required String slotId,
    required String uid,
  }) async {
    final ref = _fs.collection('stations').doc(stationId).collection('slots').doc(slotId);
    try {
      final ok = await _fs.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final data = snap.data() as Map<String, dynamic>;
        if ((data['status'] as String?) != 'available') return false;
        tx.update(ref, {
          'status': 'booked',
          'bookedBy': uid,
          'bookedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Cancel your own booking
  Future<bool> cancelBooking({
    required String stationId,
    required String slotId,
    required String uid,
  }) async {
    final ref = _fs.collection('stations').doc(stationId).collection('slots').doc(slotId);
    try {
      final ok = await _fs.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final d = snap.data() as Map<String, dynamic>;
        if (d['status'] == 'booked' && d['bookedBy'] == uid) {
          tx.update(ref, {
            'status': 'available',
            'bookedBy': null,
            'bookedAt': null,
          });
          return true;
        }
        return false;
      });
      return ok;
    } catch (_) {
      return false;
    }
  }
}
