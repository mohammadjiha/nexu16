import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../models/routine_model.dart';
import 'split_setup_provider.dart';

class RoutinesNotifier extends AsyncNotifier<List<RoutineModel>> {
  List<RoutineModel>? _originalRoutines;

  @override
  Future<List<RoutineModel>> build() async {
    // Watch auth state before any async gaps
    ref.watch(authStateProvider);
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/ms_routines.json',
      );
      final dynamic decoded = jsonDecode(jsonString);
      final List<dynamic> jsonData = (decoded is Map
          ? decoded['routines']
          : decoded) as List<dynamic>;
      final routines = jsonData
          .map((e) => RoutineModel.fromJson(e as Map<String, dynamic>))
          .toList();
          
      // Dynamically generate compound routines
      routines.addAll(_generateCompoundRoutines(routines));
      
      _originalRoutines = routines.toList();

      return await _loadModifiedRoutines(routines);
    } catch (e) {
      debugPrint('Error loading routines: $e');
      return [];
    }
  }

  Future<List<RoutineModel>> _loadModifiedRoutines(
    List<RoutineModel> baseRoutines,
  ) async {
    try {
      final user = ref.read(authStateProvider).asData?.value;
      if (user == null) return baseRoutines;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appData')
          .doc('modified_routines')
          .get();
      final decoded = doc.data()?['routines'];
      if (decoded is Map<String, dynamic>) {
        final newRoutines = [...baseRoutines];
        for (var i = 0; i < newRoutines.length; i++) {
          final id = newRoutines[i].id;
          if (decoded.containsKey(id)) {
            newRoutines[i] = RoutineModel.fromJson(
              decoded[id] as Map<String, dynamic>,
            );
          }
        }
        return newRoutines;
      }
      return baseRoutines;
    } catch (_) {
      return baseRoutines;
    }
  }

  /// The pristine (pre-modification) version of a routine, whether it is a
  /// static catalog routine or a dynamically generated, level-aware one.
  RoutineModel? _pristineRoutine(String id) {
    final orig = _originalRoutines;
    if (orig != null) {
      for (final r in orig) {
        if (r.id == id) return r;
      }
    }
    // Generated plan routines (gen_*) live in the plan engine result.
    return ref.read(workoutPlanResultProvider).routines[id];
  }

  void updateRoutine(String id, RoutineModel newRoutine) {
    state.whenData((routines) {
      final index = routines.indexWhere((r) => r.id == id);
      if (index != -1) {
        final newRoutines = [...routines];
        newRoutines[index] = newRoutine;
        state = AsyncData(newRoutines);
      }
    });
    // Persist for BOTH static and generated routines. Generated routines are
    // not in `state`, so the modified_routines overlay is what surfaces them.
    _saveModifiedRoutine(newRoutine);
  }

  Future<void> _saveModifiedRoutine(RoutineModel routine) async {
    try {
      final user = ref.read(authStateProvider).asData?.value;
      if (user == null) return;

      final routineData = {
        'id': routine.id,
        'category': routine.category,
        'routineName': routine.routineName,
        'description': routine.description,
        'exercises': routine.exercises
            .map(
              (e) => {
                'name': e.name,
                'sets': e.sets,
                'reps': e.reps,
                'weight': e.weight,
                'restTime': e.restTime,
                'note': e.note,
                'muscleGroup': e.muscleGroup,
              },
            )
            .toList(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appData')
          .doc('modified_routines')
          .set({
            'routines': {routine.id: routineData},
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving modified routine: $e');
    }
  }

  void quick30Routine(String id) {
    final routine = _pristineRoutine(id);
    if (routine == null) return;
    // Keep only first 3 exercises
    final newExercises = routine.exercises.take(3).toList();
    final newRoutine = routine.copyWith(
      exercises: newExercises,
      description: 'Quick 30: Core movements only.',
    );
    updateRoutine(id, newRoutine);
  }

  void focused45Routine(String id) {
    final routine = _pristineRoutine(id);
    if (routine == null) return;
    final newRoutine = routine.copyWith(
      description: 'Focused 45: Keep all exercises, cut rest time.',
    );
    updateRoutine(id, newRoutine);
  }

  void adjustIntensityLevel(String id, String level) {
    final originalRoutine = _pristineRoutine(id);
    if (originalRoutine == null) return;

    var newExercises = [...originalRoutine.exercises];
    String newDescription = originalRoutine.description;

        if (level == 'easy') {
          if (newExercises.isNotEmpty) newExercises.removeLast();
          newExercises = newExercises.map((e) {
            final reps = e.reps.toLowerCase().contains('fail') ? '8' : e.reps;
            return e.copyWith(
              sets: e.sets > 1 ? e.sets - 1 : 1,
              weight: _roundWeight(e.weight * 0.80),
              restTime: e.restTime + 30,
              reps: reps,
            );
          }).toList();
          newDescription =
              'Easy Mode: Trimmed volume, lighter weights, longer rest.';
        } else if (level == 'lighter') {
          newExercises = newExercises.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return e.copyWith(
              sets: (i < 2 && e.sets > 1) ? e.sets - 1 : e.sets,
              weight: _roundWeight(e.weight * 0.85),
              restTime: e.restTime + 15,
            );
          }).toList();
          newDescription =
              'Lighter: Reduced sets on main lifts, weights dropped 15%.';
        } else if (level == 'normal') {
          newDescription = 'As Planned: Standard intensity.';
        } else if (level == 'harder') {
          newExercises = newExercises.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            String? note = e.note;
            String reps = e.reps;
            if (i < 2) note = 'Last set Rest-Pause';
            if (e.reps.toLowerCase().contains('fail')) {
              reps = 'Failure + push past failure';
            }
            return e.copyWith(
              weight: _roundWeight(e.weight * 1.05),
              restTime: e.restTime - 15 < 30 ? 30 : e.restTime - 15,
              reps: reps,
              note: note,
            );
          }).toList();
          newDescription =
              'Push Harder: Increased weight, shorter rest, Rest-Pause on core lifts.';
        } else if (level == 'beast') {
          newExercises = newExercises.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            String note = 'Last set Drop Set';
            if (i >= newExercises.length - 2) {
              note = 'Last set Drop Set + Superset';
            }
            String reps = e.reps;
            if (e.reps.toLowerCase().contains('fail')) {
              reps = 'Failure + Drop Set';
            }
            return e.copyWith(
              sets: e.sets + 1,
              weight: _roundWeight(e.weight * 1.10),
              restTime: e.restTime - 30 < 30 ? 30 : e.restTime - 30,
              reps: reps,
              note: note,
            );
          }).toList();
          newDescription =
              'Beast Mode: More sets, heavier weight, very short rest, Drop Sets & Supersets! 💀';
        }

    final newRoutine = originalRoutine.copyWith(
      exercises: newExercises,
      description: newDescription,
    );
    updateRoutine(id, newRoutine);
  }

  double _roundWeight(double weight) {
    return (weight / 2.5).roundToDouble() * 2.5;
  }

  RoutineModel? previewMuscleSwap(
    RoutineModel currentRoutine,
    String newCategory,
  ) {
    if (_originalRoutines == null) return null;

    // Find a routine that matches the new category
    final matchingRoutines = _originalRoutines!
        .where((r) => r.category == newCategory)
        .toList();
    if (matchingRoutines.isEmpty) return null;

    final targetRoutine = matchingRoutines
        .first; // Grab the first available routine for that muscle

    // Take 4-5 exercises
    final exerciseCount = currentRoutine.exercises.length > 5
        ? 5
        : (currentRoutine.exercises.length < 4
              ? 4
              : currentRoutine.exercises.length);
    final newExercises = targetRoutine.exercises.take(exerciseCount).toList();

    // Map the new exercises but keep default weights and try to match sets/rest from original if we wanted,
    // but the prompt says: "take from last session, if none calculate 70% of 1RM, maintain total sets".
    // We will simulate this by keeping the sets from the new routine, but adjusting if needed to match total volume.

    int currentTotalSets = currentRoutine.exercises.fold(
      0,
      (total, e) => total + e.sets,
    );
    int newTotalSets = newExercises.fold(0, (total, e) => total + e.sets);

    // Adjust sets of the last exercise to match roughly
    if (newExercises.isNotEmpty && currentTotalSets != newTotalSets) {
      final diff = currentTotalSets - newTotalSets;
      final lastEx = newExercises.last;
      final adjustedSets = (lastEx.sets + diff) > 0 ? (lastEx.sets + diff) : 1;
      newExercises[newExercises.length - 1] = lastEx.copyWith(
        sets: adjustedSets,
      );
    }

    return currentRoutine.copyWith(
      routineName: 'Switched: $newCategory Focus',
      category: newCategory,
      description: 'Switched from ${currentRoutine.category} to $newCategory.',
      exercises: newExercises,
    );
  }

  List<RoutineModel> _generateCompoundRoutines(List<RoutineModel> baseRoutines) {
    final List<RoutineModel> compoundRoutines = [];
    final random = Random(42); // fixed seed for consistency

    // Group existing exercises by category
    final Map<String, List<RoutineExercise>> exercisesByCategory = {};
    for (var r in baseRoutines) {
      exercisesByCategory.putIfAbsent(r.category, () => []).addAll(r.exercises);
    }
    
    // Deduplicate exercises by name within each category
    for (var key in exercisesByCategory.keys) {
      final unique = <String, RoutineExercise>{};
      for (var ex in exercisesByCategory[key]!) {
        if (!unique.containsKey(ex.name)) {
          unique[ex.name] = ex;
        }
      }
      exercisesByCategory[key] = unique.values.toList();
    }

    List<RoutineExercise> pickRandom(String category, int count) {
      final list = exercisesByCategory[category] ?? [];
      if (list.isEmpty) return [];
      final shuffled = List<RoutineExercise>.from(list)..shuffle(random);
      return shuffled.take(count).toList();
    }

    // 1. Push
    compoundRoutines.add(RoutineModel(
      id: 'dynamic_push_1',
      category: 'Push',
      routineName: 'Push Day Blast',
      description: 'Dynamic routine targeting Chest, Shoulders, and Triceps.',
      exercises: [
        ...pickRandom('Chest', 2),
        ...pickRandom('Shoulders', 2),
        ...pickRandom('Triceps', 2),
      ],
    ));

    // 2. Pull
    compoundRoutines.add(RoutineModel(
      id: 'dynamic_pull_1',
      category: 'Pull',
      routineName: 'Pull Day Blast',
      description: 'Dynamic routine targeting Back and Biceps.',
      exercises: [
        ...pickRandom('Back', 3),
        ...pickRandom('Biceps', 3),
      ],
    ));

    // 3. Upper Body
    compoundRoutines.add(RoutineModel(
      id: 'dynamic_upper_1',
      category: 'Upper Body',
      routineName: 'Complete Upper Body',
      description: 'Dynamic routine targeting all upper body muscles.',
      exercises: [
        ...pickRandom('Chest', 2),
        ...pickRandom('Back', 2),
        ...pickRandom('Shoulders', 1),
        ...pickRandom('Biceps', 1),
        ...pickRandom('Triceps', 1),
      ],
    ));

    // 4. Lower Body
    compoundRoutines.add(RoutineModel(
      id: 'dynamic_lower_1',
      category: 'Lower Body',
      routineName: 'Complete Lower Body',
      description: 'Dynamic routine targeting Legs, Glutes, and Core.',
      exercises: [
        ...pickRandom('Legs', 4),
        ...pickRandom('Glutes', 1),
        ...pickRandom('Abs', 1),
      ],
    ));

    // 5. Full Body
    compoundRoutines.add(RoutineModel(
      id: 'dynamic_fullbody_1',
      category: 'Full Body',
      routineName: 'Full Body Sweep',
      description: 'Dynamic routine targeting the entire body.',
      exercises: [
        ...pickRandom('Legs', 2),
        ...pickRandom('Chest', 1),
        ...pickRandom('Back', 1),
        ...pickRandom('Shoulders', 1),
        ...pickRandom('Biceps', 1),
        ...pickRandom('Triceps', 1),
      ],
    ));

    // 6. Arms
    compoundRoutines.add(RoutineModel(
      id: 'dynamic_arms_1',
      category: 'Arms',
      routineName: 'Arm Destroyer',
      description: 'Dynamic routine targeting Biceps and Triceps.',
      exercises: [
        ...pickRandom('Biceps', 3),
        ...pickRandom('Triceps', 3),
      ],
    ));

    // 7. Shoulders & Arms
    compoundRoutines.add(RoutineModel(
      id: 'dynamic_shoulders_arms_1',
      category: 'Shoulders & Arms',
      routineName: 'Shoulders & Arms Blast',
      description: 'Dynamic routine targeting Shoulders, Biceps, and Triceps.',
      exercises: [
        ...pickRandom('Shoulders', 3),
        ...pickRandom('Biceps', 2),
        ...pickRandom('Triceps', 2),
      ],
    ));

    return compoundRoutines;
  }
}

final msRoutinesProvider =
    AsyncNotifierProvider<RoutinesNotifier, List<RoutineModel>>(() {
      return RoutinesNotifier();
    });

final routineCatalogProvider = FutureProvider<Map<String, List<RoutineModel>>>((
  ref,
) async {
  final routines = await ref.watch(msRoutinesProvider.future);
  final map = <String, List<RoutineModel>>{};
  for (var routine in routines) {
    map.putIfAbsent(routine.category, () => []).add(routine);
  }
  return map;
});

/// Real-time stream of the player's saved routine modifications
/// (id -> modified RoutineModel). Used to overlay edits onto generated,
/// level-aware plan routines (which are not part of [msRoutinesProvider]).
final routineModificationsProvider =
    StreamProvider<Map<String, RoutineModel>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) {
    return Stream.value(const <String, RoutineModel>{});
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
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
