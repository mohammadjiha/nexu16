import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/coach_nutrition_plan.dart';

// Firestore path: users/{playerUid}/coachNutritionPlan/current
final _db = FirebaseFirestore.instance;

DocumentReference _planDoc(String playerUid) =>
    _db.collection('users').doc(playerUid).collection('coachNutritionPlan').doc('current');

class CoachNutritionRepository {
  Future<void> setPlan(String playerUid, CoachNutritionPlan plan) =>
      _planDoc(playerUid).set(plan.toMap());

  Stream<CoachNutritionPlan?> planStream(String playerUid) =>
      _planDoc(playerUid).snapshots().map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        return CoachNutritionPlan.fromMap(snap.data()! as Map<String, dynamic>);
      });

  Future<CoachNutritionPlan?> getPlan(String playerUid) async {
    final snap = await _planDoc(playerUid).get();
    if (!snap.exists || snap.data() == null) return null;
    return CoachNutritionPlan.fromMap(snap.data()! as Map<String, dynamic>);
  }
}

final coachNutritionRepositoryProvider = Provider<CoachNutritionRepository>(
  (_) => CoachNutritionRepository(),
);

/// StreamProvider that watches a specific player's nutrition plan.
/// Usage: ref.watch(coachNutritionPlanProvider('uid'))
final coachNutritionPlanProvider =
    StreamProvider.family<CoachNutritionPlan?, String>((ref, playerUid) {
  return ref.watch(coachNutritionRepositoryProvider).planStream(playerUid);
});
