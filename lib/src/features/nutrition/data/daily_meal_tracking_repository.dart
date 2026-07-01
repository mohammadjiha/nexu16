import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/daily_meal_tracking.dart';

class DailyMealTrackingRepository {
  final _db = FirebaseFirestore.instance;

  DocumentReference _doc(String playerUid, String date) => _db
      .collection('users')
      .doc(playerUid)
      .collection('daily_nutrition')
      .doc(date);

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Player: stream today's tracking ────────────────────────────────────────
  Stream<DailyMealTracking?> todayStream(String playerUid) {
    final date = _todayStr();
    return _doc(playerUid, date).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('coachMealTracking')) return null;
      return DailyMealTracking.fromMap(date, data);
    });
  }

  // ── Player: toggle a meal completed/not ────────────────────────────────────
  Future<void> toggleMeal({
    required String playerUid,
    required int mealIdx,
    required List<String> mealNames, // from the coach plan
  }) async {
    final date = _todayStr();
    final ref = _doc(playerUid, date);
    final snap = await ref.get();

    List<Map<String, dynamic>> meals;

    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>?;
      final raw = data?['coachMealTracking'] as List?;
      if (raw != null && raw.length == mealNames.length) {
        meals = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        // Re-init if lengths differ (plan changed)
        meals = mealNames
            .map((n) => <String, dynamic>{
                  'mealName': n,
                  'completed': false,
                  'completedAt': null,
                })
            .toList();
      }
    } else {
      meals = mealNames
          .map((n) => <String, dynamic>{
                'mealName': n,
                'completed': false,
                'completedAt': null,
              })
          .toList();
    }

    if (mealIdx < meals.length) {
      final current = meals[mealIdx]['completed'] as bool? ?? false;
      meals[mealIdx] = {
        'mealName': meals[mealIdx]['mealName'],
        'completed': !current,
        'completedAt': !current ? Timestamp.now() : null,
      };
    }

    await ref.set(
      {
        'coachMealTracking': meals,
        'trackingUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ── Coach: last 7 days for a player ────────────────────────────────────────
  Future<List<DailyMealTracking>> getLast7Days(String playerUid) async {
    final now = DateTime.now();
    final futures = <Future<DailyMealTracking>>[];

    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: i));
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      futures.add(_doc(playerUid, dateStr).get().then((snap) {
        if (!snap.exists) return DailyMealTracking.empty(dateStr);
        final data = snap.data() as Map<String, dynamic>?;
        if (data == null || !data.containsKey('coachMealTracking')) {
          return DailyMealTracking.empty(dateStr);
        }
        return DailyMealTracking.fromMap(dateStr, data);
      }));
    }

    return Future.wait(futures);
  }
}

final dailyMealTrackingRepositoryProvider =
    Provider<DailyMealTrackingRepository>((_) => DailyMealTrackingRepository());

// ── Riverpod providers ────────────────────────────────────────────────────────

final todayMealTrackingProvider =
    StreamProvider.family<DailyMealTracking?, String>((ref, playerUid) {
  return ref
      .read(dailyMealTrackingRepositoryProvider)
      .todayStream(playerUid);
});

final last7DaysTrackingProvider =
    FutureProvider.family<List<DailyMealTracking>, String>((ref, playerUid) {
  return ref
      .read(dailyMealTrackingRepositoryProvider)
      .getLast7Days(playerUid);
});
