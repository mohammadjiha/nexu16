import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/providers/body_metrics_provider.dart';
import '../models/routine_model.dart';
import '../services/workout_plan_engine.dart';
import 'exercise_history_provider.dart';
import 'routines_provider.dart';

class SplitSetupStatusNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appData')
          .doc('split_setup')
          .get()
          .timeout(const Duration(seconds: 5));
      return doc.data()?['isComplete'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error loading split setup status: $e');
      return false; // Fail gracefully
    }
  }

  Future<void> completeSetup() async {
    state = const AsyncValue.loading();

    // Anchor the plan to today so it doesn't shift
    ref.read(splitSetupDataProvider.notifier).setPlanStartDate(DateTime.now());

    final user = ref.read(authStateProvider).asData?.value;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('appData')
            .doc('split_setup')
            .set({
              'isComplete': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error saving split setup: $e');
      }
    }

    state = const AsyncValue.data(true);
  }
  Future<void> resetSetup() async {
    state = const AsyncValue.loading();
    final user = ref.read(authStateProvider).asData?.value;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('appData')
            .doc('split_setup')
            .set({
              'isComplete': false,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error resetting split setup: $e');
      }
    }
    state = const AsyncValue.data(false);
  }
}

final splitSetupStatusProvider =
    AsyncNotifierProvider<SplitSetupStatusNotifier, bool>(() {
      return SplitSetupStatusNotifier();
    });

class WorkoutDay {
  final String dayName;
  final String date;
  final String? fullDate;
  final String title;
  final List<String> categories;
  final String? assignedRoutineId;
  final String? assignedRoutineName;
  final bool isRest;

  WorkoutDay({
    required this.dayName,
    required this.date,
    this.fullDate,
    required this.title,
    required this.categories,
    this.assignedRoutineId,
    this.assignedRoutineName,
    this.isRest = false,
  });
}

// A simple provider to hold the wizard state in memory
class SplitSetupData {
  final int daysPerWeek;
  final String splitType;
  final List<String> trainingDays;
  final DateTime? planStartDate;
  final Map<String, String> swappedDates;

  /// Player experience level: 'beginner' | 'intermediate' | 'advanced'.
  /// Drives which exercises (by ExperienceLevel) and what training volume the
  /// generated plan uses. Empty string means "not chosen yet".
  final String experienceLevel;

  /// For the "Build My Own" (custom) split only: the muscle groups the player
  /// chose to train on each weekday (e.g. {'MON': ['Chest','Triceps']}).
  /// Keys are weekday codes (MON..SUN); values are Firebase MuscleGroup names.
  final Map<String, List<String>> customDayMuscles;

  SplitSetupData({
    this.daysPerWeek = 4,
    this.splitType = '',
    this.trainingDays = const ['MON', 'WED', 'FRI', 'SAT'],
    this.planStartDate,
    this.swappedDates = const {},
    this.experienceLevel = '',
    this.customDayMuscles = const {},
  });

  SplitSetupData copyWith({
    int? daysPerWeek,
    String? splitType,
    List<String>? trainingDays,
    DateTime? planStartDate,
    Map<String, String>? swappedDates,
    String? experienceLevel,
    Map<String, List<String>>? customDayMuscles,
  }) {
    return SplitSetupData(
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      splitType: splitType ?? this.splitType,
      trainingDays: trainingDays ?? this.trainingDays,
      planStartDate: planStartDate ?? this.planStartDate,
      swappedDates: swappedDates ?? this.swappedDates,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      customDayMuscles: customDayMuscles ?? this.customDayMuscles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'daysPerWeek': daysPerWeek,
      'splitType': splitType,
      'trainingDays': trainingDays,
      'planStartDate': planStartDate?.toIso8601String(),
      'swappedDates': swappedDates,
      'experienceLevel': experienceLevel,
      'customDayMuscles': customDayMuscles,
    };
  }

  factory SplitSetupData.fromJson(Map<String, dynamic> json) {
    return SplitSetupData(
      experienceLevel: json['experienceLevel'] as String? ?? '',
      daysPerWeek: json['daysPerWeek'] as int? ?? 4,
      splitType: json['splitType'] as String? ?? '',
      trainingDays:
          (json['trainingDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['MON', 'WED', 'FRI', 'SAT'],
      planStartDate: json['planStartDate'] != null
          ? DateTime.parse(json['planStartDate'] as String)
          : null,
      swappedDates:
          (json['swappedDates'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          const {},
      customDayMuscles:
          (json['customDayMuscles'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
                  const <String>[],
            ),
          ) ??
          const {},
    );
  }
}

class SplitSetupDataNotifier extends AsyncNotifier<SplitSetupData> {
  @override
  Future<SplitSetupData> build() async {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) return SplitSetupData(planStartDate: DateTime.now());

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('appData')
        .doc('split_setup');

    // Stay live: a coach can edit this same doc from their side (Set/Edit
    // Plan), so we listen for remote changes instead of a one-time get() —
    // otherwise the player would need to restart the app to see updates.
    final sub = docRef.snapshots().listen((snap) {
      final data = snap.data()?['setupData'];
      if (data is Map<String, dynamic>) {
        final setupData = SplitSetupData.fromJson(data);
        state = AsyncData(setupData.planStartDate == null
            ? setupData.copyWith(planStartDate: DateTime.now())
            : setupData);
      }
    });
    ref.onDispose(sub.cancel);

    final doc = await docRef.get();
    final data = doc.data()?['setupData'];
    if (data is Map<String, dynamic>) {
      final setupData = SplitSetupData.fromJson(data);
      return setupData.planStartDate == null
          ? setupData.copyWith(planStartDate: DateTime.now())
          : setupData;
    }
    return SplitSetupData(planStartDate: DateTime.now());
  }

  Future<void> _saveData(SplitSetupData data) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('appData')
        .doc('split_setup')
        .set({
          'setupData': data.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void setDaysPerWeek(int days) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final defaultDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final newTrainingDays = defaultDays.take(days).toList();
    final data = current.copyWith(
      daysPerWeek: days,
      trainingDays: newTrainingDays,
      splitType: '',
    );
    state = AsyncData(data);
    _saveData(data);
  }

  void setSplitType(String type) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final data = current.copyWith(splitType: type);
    state = AsyncData(data);
    _saveData(data);
  }

  /// Sets the player's experience level: 'beginner' | 'intermediate' | 'advanced'.
  void setExperienceLevel(String level) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final data = current.copyWith(experienceLevel: level);
    state = AsyncData(data);
    _saveData(data);
  }

  /// Custom split only: toggle a muscle group on/off for a given weekday.
  void toggleCustomMuscle(String day, String muscle) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final map = {
      for (final e in current.customDayMuscles.entries)
        e.key: List<String>.from(e.value),
    };
    final list = map[day] ?? <String>[];
    if (list.contains(muscle)) {
      list.remove(muscle);
    } else {
      list.add(muscle);
    }
    map[day] = list;
    final data = current.copyWith(customDayMuscles: map);
    state = AsyncData(data);
    _saveData(data);
  }

  void toggleTrainingDay(String day) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final days = List<String>.from(current.trainingDays);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      if (days.length < current.daysPerWeek) {
        days.add(day);
        final week = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
        days.sort((a, b) => week.indexOf(a).compareTo(week.indexOf(b)));
      }
    }
    final data = current.copyWith(trainingDays: days);
    state = AsyncData(data);
    _saveData(data);
  }

  void setPlanStartDate(DateTime date) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final data = current.copyWith(planStartDate: date);
    state = AsyncData(data);
    _saveData(data);
  }

  void addSwap(String date1, String date2) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final newSwaps = Map<String, String>.from(current.swappedDates);
    newSwaps[date1] = date2;
    newSwaps[date2] = date1;
    final data = current.copyWith(swappedDates: newSwaps);
    state = AsyncData(data);
    _saveData(data);
  }
}

final splitSetupDataProvider =
    AsyncNotifierProvider<SplitSetupDataNotifier, SplitSetupData>(() {
      return SplitSetupDataNotifier();
    });

/// Full generated plan: the 7-day schedule plus the level-aware routines it
/// references, built from the real Firebase exercise database.
final workoutPlanResultProvider = Provider<WorkoutPlanResult>((ref) {
  final setupData =
      ref.watch(splitSetupDataProvider).value ??
      SplitSetupData(planStartDate: DateTime.now());
  final catalog = ref.watch(firebaseExerciseCatalogProvider).value ?? {};
  if (catalog.isEmpty) return WorkoutPlanResult.empty;

  // Personalize via the player's InBody/body-composition metrics + a stable
  // per-player seed, plus their lifting history for progressive overload — so
  // the plan depends on goal/body-fat and keeps progressing, not just on level.
  final uid = ref.watch(authStateProvider).asData?.value?.uid ?? '';
  final metrics = ref.watch(bodyMetricsProvider).asData?.value;
  final records = ref.watch(exerciseHistoryProvider).asData?.value ?? const {};
  final history = {
    for (final e in records.entries) e.key: e.value.weight,
  };
  final profile = metrics != null
      ? TrainingProfile.fromMetrics(metrics, seed: uid.hashCode, history: history)
      : TrainingProfile(seed: uid.hashCode, history: history);

  return WorkoutPlanEngine.generate(
    experienceLevel: setupData.experienceLevel,
    daysPerWeek: setupData.daysPerWeek,
    splitType: setupData.splitType,
    trainingDays: setupData.trainingDays,
    exerciseCatalog: catalog,
    startDate: setupData.planStartDate ?? DateTime.now(),
    swaps: setupData.swappedDates,
    customDayMuscles: setupData.customDayMuscles,
    profile: profile,
  );
});

final generatedPlanProvider = Provider<List<WorkoutDay>>((ref) {
  return ref.watch(workoutPlanResultProvider).days;
});

/// Generated routines (id -> RoutineModel) for the current plan, with the
/// player's saved modifications overlaid on top (edits, intensity, quick-30…).
final generatedRoutinesProvider = Provider<Map<String, RoutineModel>>((ref) {
  final base = ref.watch(workoutPlanResultProvider).routines;
  final mods = ref.watch(routineModificationsProvider).value ?? const {};
  if (mods.isEmpty) return base;
  final out = <String, RoutineModel>{...base};
  for (final id in base.keys) {
    final modified = mods[id];
    if (modified != null) out[id] = modified;
  }
  return out;
});

/// Every routine a generated plan day might reference: the static asset catalog
/// plus the dynamically generated, level-aware routines. Resolve
/// `WorkoutDay.assignedRoutineId` against THIS (not `msRoutinesProvider`).
final resolvedRoutinesProvider = Provider<List<RoutineModel>>((ref) {
  final base = ref.watch(msRoutinesProvider).value ?? const <RoutineModel>[];
  final generated = ref.watch(generatedRoutinesProvider).values.toList();
  return [...base, ...generated];
});
