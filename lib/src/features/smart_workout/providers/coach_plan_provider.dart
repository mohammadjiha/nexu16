import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../models/routine_model.dart';

/// A coach-authored weekly plan: per-weekday routines the coach assigned to a
/// player. It recurs weekly and stays until the coach updates it.
class CoachPlan {
  final Map<String, RoutineModel> days; // 'MON'.. -> routine
  final String? coachId;

  const CoachPlan({this.days = const {}, this.coachId});

  bool get isEmpty => days.isEmpty;
  bool get isNotEmpty => days.isNotEmpty;
  RoutineModel? routineFor(String dayName) => days[dayName];

  static CoachPlan fromDoc(Map<String, dynamic>? data) {
    if (data == null) return const CoachPlan();
    final out = <String, RoutineModel>{};
    final rawDays = data['days'];
    if (rawDays is Map<String, dynamic>) {
      rawDays.forEach((day, value) {
        if (value is Map<String, dynamic>) {
          out[day] = RoutineModel.fromJson(value);
        }
      });
    }
    return CoachPlan(days: out, coachId: data['coachId'] as String?);
  }
}

/// The player's own coach plan (real-time).
final coachPlanProvider = StreamProvider<CoachPlan>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(const CoachPlan());
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('appData')
      .doc('coach_plan')
      .snapshots()
      .map((d) => CoachPlan.fromDoc(d.data()));
});

/// A specific player's coach plan — used by the coach while authoring it.
final playerCoachPlanProvider =
    StreamProvider.family<CoachPlan, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('appData')
      .doc('coach_plan')
      .snapshots()
      .map((d) => CoachPlan.fromDoc(d.data()));
});

/// Which plan the player follows: 'coach' or 'self'. [chosen] is false until the
/// player makes their first selection (drives the first-time selector).
class PlanPrefs {
  final String source; // 'coach' | 'self'
  final bool chosen;

  const PlanPrefs({this.source = 'self', this.chosen = false});

  bool get isCoach => source == 'coach';
}

final planSourceProvider = StreamProvider<PlanPrefs>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(const PlanPrefs());
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('appData')
      .doc('plan_prefs')
      .snapshots()
      .map((d) {
    final data = d.data();
    if (data == null) return const PlanPrefs();
    return PlanPrefs(
      source: (data['source'] as String?) ?? 'self',
      chosen: (data['chosen'] as bool?) ?? false,
    );
  });
});

/// A specific player's plan-source preference — used by the coach (e.g. on
/// the Monitor screen) so it reflects whichever plan the player actually
/// follows (coach vs self), instead of assuming the coach plan is active.
final playerPlanSourceProvider =
    StreamProvider.family<PlanPrefs, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('appData')
      .doc('plan_prefs')
      .snapshots()
      .map((d) {
    final data = d.data();
    if (data == null) return const PlanPrefs();
    return PlanPrefs(
      source: (data['source'] as String?) ?? 'self',
      chosen: (data['chosen'] as bool?) ?? false,
    );
  });
});

/// Reads/writes the coach plan + the player's plan-source preference.
class CoachPlanRepository {
  final FirebaseFirestore _fs;
  CoachPlanRepository([FirebaseFirestore? fs])
      : _fs = fs ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _coachPlanDoc(String playerId) => _fs
      .collection('users')
      .doc(playerId)
      .collection('appData')
      .doc('coach_plan');

  /// Coach saves/updates ONE weekday's routine in a player's coach plan.
  /// Deep-merges so other days are untouched.
  Future<void> setDayRoutine({
    required String playerId,
    required String dayName,
    required RoutineModel routine,
    String? coachId,
  }) async {
    await _coachPlanDoc(playerId).set({
      'days': {dayName: routine.toJson()},
      if (coachId != null) 'coachId': coachId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Coach removes a single day from the player's coach plan.
  Future<void> removeDay({
    required String playerId,
    required String dayName,
  }) async {
    await _coachPlanDoc(playerId).update({
      'days.$dayName': FieldValue.delete(),
    });
  }

  /// Player chooses which plan they follow ('coach' | 'self').
  Future<void> setPlanSource({
    required String uid,
    required String source,
  }) async {
    await _fs
        .collection('users')
        .doc(uid)
        .collection('appData')
        .doc('plan_prefs')
        .set({
      'source': source,
      'chosen': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final coachPlanRepositoryProvider =
    Provider<CoachPlanRepository>((ref) => CoachPlanRepository());
