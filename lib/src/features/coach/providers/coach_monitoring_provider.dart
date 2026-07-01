import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/body_metrics_provider.dart';
import '../../smart_workout/models/routine_model.dart';
import '../../smart_workout/providers/coach_plan_provider.dart';
import '../../smart_workout/providers/split_setup_provider.dart';
import '../../smart_workout/providers/workout_history_provider.dart';
import '../../smart_workout/services/workout_plan_engine.dart';

// 1. Workout History Provider for a specific player
final playerWorkoutHistoryProvider = StreamProvider.family<List<CompletedSession>, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('workoutHistory')
      .orderBy('timestampIso', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => CompletedSession.fromJson(doc.data()))
        .toList();
  });
});

// 2. Body Metrics Provider for a specific player
final playerBodyMetricsProvider = StreamProvider.family<BodyMetrics, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('metrics')
      .doc('body_composition')
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) {
      return BodyMetrics();
    }
    return BodyMetrics.fromJson(snapshot.data()!);
  });
});

// 2b. Player lifting history (exercise name -> best weight) for progressive
// overload in the coach's view of the player's plan.
final playerExerciseHistoryProvider =
    StreamProvider.family<Map<String, double>, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('exerciseHistory')
      .doc('personal_records')
      .snapshots()
      .map((snapshot) {
    final records = snapshot.data()?['records'];
    final out = <String, double>{};
    if (records is Map<String, dynamic>) {
      records.forEach((name, value) {
        if (value is Map<String, dynamic>) {
          out[name] = (value['weight'] as num?)?.toDouble() ?? 0.0;
        }
      });
    }
    return out;
  });
});

// Helper: Player Base + Modified Routines — real-time stream
final playerRoutinesProvider = StreamProvider.family<List<RoutineModel>, String>((ref, playerId) async* {
  // Load base routines from JSON once (static asset)
  List<RoutineModel> baseRoutines = [];
  try {
    final jsonString = await rootBundle.loadString('assets/data/ms_routines.json');
    final dynamic decoded = jsonDecode(jsonString);
    final List<dynamic> jsonData = decoded is Map ? decoded['routines'] : decoded;
    baseRoutines = jsonData.map((e) => RoutineModel.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    baseRoutines = [];
  }

  // Stream the player's modified routines from Firestore in real-time
  yield* FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('appData')
      .doc('modified_routines')
      .snapshots()
      .map((doc) {
    final decodedMods = doc.data()?['routines'];
    if (decodedMods is Map<String, dynamic>) {
      final newRoutines = List<RoutineModel>.from(baseRoutines);
      for (var i = 0; i < newRoutines.length; i++) {
        final id = newRoutines[i].id;
        if (decodedMods.containsKey(id)) {
          newRoutines[i] = RoutineModel.fromJson(decodedMods[id] as Map<String, dynamic>);
        }
      }
      return newRoutines;
    }
    return baseRoutines;
  });
});

// Helper: Player Split Setup
final playerSplitSetupProvider = StreamProvider.family<SplitSetupData, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('appData')
      .doc('split_setup')
      .snapshots()
      .map((snapshot) {
    final data = snapshot.data()?['setupData'];
    if (data is Map<String, dynamic>) {
      final setupData = SplitSetupData.fromJson(data);
      return setupData.planStartDate == null
          ? setupData.copyWith(planStartDate: DateTime.now())
          : setupData;
    }
    return SplitSetupData(planStartDate: DateTime.now());
  });
});

// Helper: Player Generated Plan Result — level-aware, built from the real
// Firebase exercise database. Rebuilds whenever the player's split setup or the
// exercise catalog changes. This is the SAME engine the player sees.
final playerWorkoutPlanResultProvider =
    StreamProvider.family<WorkoutPlanResult, String>((ref, playerId) {
  final splitAsync = ref.watch(playerSplitSetupProvider(playerId));
  final catalog = ref.watch(firebaseExerciseCatalogProvider).value ?? {};

  final splitSetupData =
      splitAsync.value ?? SplitSetupData(planStartDate: DateTime.now());

  if (catalog.isEmpty) return Stream.value(WorkoutPlanResult.empty);

  // Same personalization the player sees: profile from their InBody metrics +
  // lifting history (progressive overload), seeded by the player id so the
  // coach's view matches the player's plan exactly.
  final metrics = ref.watch(playerBodyMetricsProvider(playerId)).value;
  final history =
      ref.watch(playerExerciseHistoryProvider(playerId)).value ?? const {};
  final profile = metrics != null
      ? TrainingProfile.fromMetrics(metrics,
          seed: playerId.hashCode, history: history)
      : TrainingProfile(seed: playerId.hashCode, history: history);

  final result = WorkoutPlanEngine.generate(
    experienceLevel: splitSetupData.experienceLevel,
    daysPerWeek: splitSetupData.daysPerWeek,
    splitType: splitSetupData.splitType,
    trainingDays: splitSetupData.trainingDays,
    exerciseCatalog: catalog,
    startDate: splitSetupData.planStartDate ?? DateTime.now(),
    swaps: splitSetupData.swappedDates,
    customDayMuscles: splitSetupData.customDayMuscles,
    profile: profile,
  );

  return Stream.value(result);
});

final playerGeneratedPlanProvider =
    StreamProvider.family<List<WorkoutDay>, String>((ref, playerId) {
  final result =
      ref.watch(playerWorkoutPlanResultProvider(playerId)).value ??
          WorkoutPlanResult.empty;
  return Stream.value(result.days);
});

/// Real-time stream of THIS player's saved routine modifications
/// (id -> modified RoutineModel), read from their own Firestore doc.
final playerRoutineModificationsProvider =
    StreamProvider.family<Map<String, RoutineModel>, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('appData')
      .doc('modified_routines')
      .snapshots()
      .map((doc) {
    final decoded = doc.data()?['routines'];
    final out = <String, RoutineModel>{};
    if (decoded is Map<String, dynamic>) {
      decoded.forEach((id, value) {
        if (value is Map<String, dynamic>) {
          out[id] = RoutineModel.fromJson(value);
        }
      });
    }
    return out;
  });
});

/// Generated routines (id -> RoutineModel) for the player's current plan, with
/// the player's live modifications overlaid — so the coach follows every edit
/// the player makes (intensity, edits, quick-30…) in real time.
final playerGeneratedRoutinesProvider =
    Provider.family<Map<String, RoutineModel>, String>((ref, playerId) {
  final base =
      ref.watch(playerWorkoutPlanResultProvider(playerId)).value?.routines ??
          const <String, RoutineModel>{};
  final mods =
      ref.watch(playerRoutineModificationsProvider(playerId)).value ??
          const <String, RoutineModel>{};
  if (mods.isEmpty) return Map<String, RoutineModel>.from(base);
  final out = <String, RoutineModel>{...base};
  for (final id in base.keys) {
    final modified = mods[id];
    if (modified != null) out[id] = modified;
  }
  return out;
});

// 3. Routine Provider — today's routine, updates in real-time
final playerRoutineProvider =
    StreamProvider.family<List<RoutineModel>, String>((ref, playerId) {
  final plan = ref.watch(playerGeneratedPlanProvider(playerId)).value ?? [];
  if (plan.isEmpty) return Stream.value([]);

  final today = plan.first;
  if (today.isRest) return Stream.value([]);

  // If this player is following their coach's plan, show the coach's
  // authored routine for today (same source of truth as the player app) —
  // not the auto-generated one, so the Monitor screen never disagrees with
  // what the player actually sees.
  final planPrefs = ref.watch(playerPlanSourceProvider(playerId)).value ??
      const PlanPrefs();
  if (planPrefs.isCoach) {
    final coachPlan = ref.watch(playerCoachPlanProvider(playerId)).value;
    final coachRoutine = coachPlan?.routineFor(today.dayName);
    return Stream.value(coachRoutine != null ? [coachRoutine] : []);
  }

  if (today.assignedRoutineId == null) return Stream.value([]);
  final generated = ref.watch(playerGeneratedRoutinesProvider(playerId));
  final match = generated[today.assignedRoutineId];
  return Stream.value(match != null ? [match] : []);
});

// 4. Daily Nutrition Provider for a specific player
final playerNutritionHistoryProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  final dateStr = DateTime.now().toIso8601String().split('T').first;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_nutrition')
      .doc(dateStr)
      .snapshots()
      .map((snapshot) {
    if (snapshot.exists && snapshot.data() != null) {
      return snapshot.data() as Map<String, dynamic>;
    }
    return null;
  });
});
