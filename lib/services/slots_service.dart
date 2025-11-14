// lib/services/slots_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SlotsService {
  final _fs = FirebaseFirestore.instance;

  /// Generate daily slots (dev helper).
  Future<void> generateDailySlots({
    required String stationId,
    required DateTime day,
    required int startHour,
    required int endHour,
    required int intervalMinutes,
  }) async {
    final stationRef = _fs.collection('stations').doc(stationId);
    final slotsCol = stationRef.collection('slots');

    final baseDate = DateTime(day.year, day.month, day.day, 0, 0);
    final batch = _fs.batch();

    DateTime cur = DateTime(baseDate.year, baseDate.month, baseDate.day, startHour);
    while (cur.hour < endHour || (cur.hour == endHour && cur.minute == 0)) {
      final start = cur;
      final end = cur.add(Duration(minutes: intervalMinutes));
      final doc = slotsCol.doc(); // new slot id
      batch.set(doc, {
        'startTime': Timestamp.fromDate(start.toUtc()),
        'endTime': Timestamp.fromDate(end.toUtc()),
        'status': 'available',
        'bookings': <String>[],
        'bookingsCount': 0,
        'capacity': 3,
      });
      cur = end;
    }
    await batch.commit();
  }

  /// Attempts to book a slot. Returns:
  /// 'ok' - success, 'already' - user already in bookings,
  /// 'full' - reached capacity, 'not_found' - slot missing, 'error' - generic failure.
  Future<String> bookSlot({
    required String stationId,
    required String slotId,
    required String uid,
    int capacity = 3,
  }) async {
    final slotRef = _fs.collection('stations').doc(stationId).collection('slots').doc(slotId);
    final userBookingRef = _fs.collection('users').doc(uid).collection('bookings').doc(); // new booking doc

    try {
      return await _fs.runTransaction<String>((tx) async {
        final slotSnap = await tx.get(slotRef);
        if (!slotSnap.exists) return 'not_found';
        final data = slotSnap.data() ?? {};

        // get bookingsCount or bookings array
        int bookingsCount = 0;
        if (data['bookingsCount'] is int) {
          bookingsCount = data['bookingsCount'] as int;
        } else if (data['bookings'] is List) {
          bookingsCount = (data['bookings'] as List).length;
        } else if (data['bookedBy'] is String) {
          bookingsCount = 1;
        }

        // check if user already booked (bookings list or bookedBy)
        bool already = false;
        if (data['bookings'] is List) {
          final list = (data['bookings'] as List).cast<dynamic>();
          if (list.contains(uid)) already = true;
        } else if (data['bookedBy'] is String) {
          if ((data['bookedBy'] as String) == uid) already = true;
        }

        if (already) return 'already';
        if (bookingsCount >= capacity) return 'full';

        // compute booking fields to update slot doc
        final newBookingsCount = bookingsCount + 1;

        // update slot doc
        final updated = <String, dynamic>{'bookingsCount': newBookingsCount};

        // maintain bookings array (if present)
        if (data['bookings'] is List) {
          final newList = List.from(data['bookings'] as List)..add(uid);
          updated['bookings'] = newList;
        } else if (data['bookedBy'] == null) {
          // first booking: set bookedBy to string (legacy)
          updated['bookedBy'] = uid;
        } else if (data['bookedBy'] is String) {
          // convert to list when second booking occurs
          updated['bookings'] = [data['bookedBy'], uid];
          updated.remove('bookedBy');
        }

        tx.update(slotRef, updated);

        // create booking under users/{uid}/bookings
        final slotData = slotSnap.data()!;
        final startTs = slotData['startTime'] as Timestamp?;
        final endTs = slotData['endTime'] as Timestamp?;
        final bookingDoc = {
          'stationId': stationId,
          'slotId': slotId,
          'startTime': startTs,
          'endTime': endTs,
          'status': 'booked',
          'createdAt': FieldValue.serverTimestamp(),
          // optionally copy station name if you have it elsewhere
        };
        tx.set(userBookingRef, bookingDoc);

        return 'ok';
      });
    } catch (e, st) {
      // log(e, st);
      return 'error';
    }
  }

  /// Cancel booking: station must exist and user must be allowed to cancel.
  /// bookingDocId can be null (we search for user booking) but it's better to pass it.
  Future<bool> cancelBooking({
    required String stationId,
    required String slotId,
    required String uid,
    String? bookingDocId,
  }) async {
    final slotRef = _fs.collection('stations').doc(stationId).collection('slots').doc(slotId);
    final userBookingsCol = _fs.collection('users').doc(uid).collection('bookings');

    try {
      return await _fs.runTransaction<bool>((tx) async {
        final slotSnap = await tx.get(slotRef);
        if (!slotSnap.exists) return false;
        final data = slotSnap.data() ?? {};

        int bookingsCount = 0;
        if (data['bookingsCount'] is int) bookingsCount = data['bookingsCount'] as int;
        if (bookingsCount > 0) bookingsCount = bookingsCount - 1;
        final updated = <String, dynamic>{'bookingsCount': bookingsCount};

        // remove uid from bookings array if present
        if (data['bookings'] is List) {
          final list = List.from(data['bookings'] as List);
          list.remove(uid);
          updated['bookings'] = list;
        } else if (data['bookedBy'] is String && (data['bookedBy'] as String) == uid) {
          // clear bookedBy or set to null
          updated['bookedBy'] = FieldValue.delete();
        }

        tx.update(slotRef, updated);

        // delete booking doc under users/{uid}/bookings
        if (bookingDocId != null) {
          final bookingRef = userBookingsCol.doc(bookingDocId);
          tx.delete(bookingRef);
        } else {
          // fallback: find a booking doc that matches slotId
          final q = await userBookingsCol.where('slotId', isEqualTo: slotId).limit(1).get();
          if (q.docs.isNotEmpty) {
            tx.delete(q.docs.first.reference);
          }
        }
        return true;
      });
    } catch (e) {
      return false;
    }
  }
}
