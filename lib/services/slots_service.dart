// lib/services/slots_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SlotsService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Generate slots for a day (you may already have this)
  Future<void> generateDailySlots({
    required String stationId,
    required DateTime day,
    required int startHour,
    required int endHour,
    required int intervalMinutes,
  }) async {
    final col = _fs.collection('stations').doc(stationId).collection('slots');

    final batch = _fs.batch();

    DateTime cur = DateTime(day.year, day.month, day.day, startHour);
    while (cur.hour < endHour || (cur.hour == endHour && cur.minute == 0)) {
      final start = cur;
      final end = cur.add(Duration(minutes: intervalMinutes));
      final doc = col.doc(); // new id
      batch.set(doc, {
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(end),
        'status': 'available',
        'bookedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      cur = end;
    }

    await batch.commit();
  }

  /// Try to book a slot. Returns:
  /// 'ok'      - booked successfully
  /// 'already' - user already in bookedBy
  /// 'full'    - slot already has 3 bookings
  /// 'not_found' - slot missing
  /// 'error'   - generic failure
  Future<String> bookSlot({
    required String stationId,
    required String slotId,
    required String uid,
    int maxBookings = 3,
  }) async {
    final docRef = _fs.collection('stations').doc(stationId).collection('slots').doc(slotId);

    try {
      final res = await _fs.runTransaction<String>((txn) async {
        final snap = await txn.get(docRef);
        if (!snap.exists) return 'not_found';
        final data = snap.data()!;
        final booked = (data['bookedBy'] ?? []) as List<dynamic>;
        final bookedStr = booked.map((e) => e.toString()).toList();

        if (bookedStr.contains(uid)) {
          return 'already';
        }

        if (bookedStr.length >= maxBookings) {
          return 'full';
        }

        // add uid to array and optionally update status
        txn.update(docRef, {
          'bookedBy': FieldValue.arrayUnion([uid]),
          // you may want to update status when full, but we rely on bookedBy.length checks
        });

        return 'ok';
      });

      return res;
    } catch (e) {
      // log if you have a logger
      return 'error';
    }
  }

  /// Cancel booking for current user. Returns true if cancelled.
  Future<bool> cancelBooking({
    required String stationId,
    required String slotId,
    required String uid,
  }) async {
    final docRef = _fs.collection('stations').doc(stationId).collection('slots').doc(slotId);

    try {
      await _fs.runTransaction((txn) async {
        final snap = await txn.get(docRef);
        if (!snap.exists) return;
        final data = snap.data()!;
        final booked = (data['bookedBy'] ?? []) as List<dynamic>;
        final bookedStr = booked.map((e) => e.toString()).toList();

        if (!bookedStr.contains(uid)) {
          return;
        }

        txn.update(docRef, {
          'bookedBy': FieldValue.arrayRemove([uid]),
        });
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
