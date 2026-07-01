class RoutineExercise {
  final String name;
  final int sets;
  final String reps;
  final double weight;
  final int restTime;
  final String? note;

  /// The muscle group this exercise targets (e.g. "Chest"). Populated for
  /// generated routines so the UI can label each exercise by muscle.
  final String? muscleGroup;

  RoutineExercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.weight = 60.0,
    this.restTime = 60,
    this.note,
    this.muscleGroup,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      name: json['name'] as String,
      sets: json['sets'] as int,
      reps: json['reps'] as String,
      weight: (json['weight'] as num?)?.toDouble() ?? 60.0,
      restTime: json['restTime'] as int? ?? 60,
      note: json['note'] as String?,
      muscleGroup: json['muscleGroup'] as String?,
    );
  }

  RoutineExercise copyWith({
    String? name,
    int? sets,
    String? reps,
    double? weight,
    int? restTime,
    String? note,
    String? muscleGroup,
  }) {
    return RoutineExercise(
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      restTime: restTime ?? this.restTime,
      note: note ?? this.note,
      muscleGroup: muscleGroup ?? this.muscleGroup,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'restTime': restTime,
      'note': note,
      'muscleGroup': muscleGroup,
    };
  }
}

class RoutineModel {
  final String id;
  final String category;
  final String routineName;
  final String description;
  final List<RoutineExercise> exercises;

  RoutineModel({
    required this.id,
    required this.category,
    required this.routineName,
    required this.description,
    required this.exercises,
  });

  factory RoutineModel.fromJson(Map<String, dynamic> json) {
    return RoutineModel(
      id: json['id'] as String? ?? 'unknown_id',
      category: json['category'] as String? ?? 'Unknown',
      routineName: json['routineName'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      exercises: json['exercises'] != null
          ? (json['exercises'] as List)
              .map((e) => RoutineExercise.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  RoutineModel copyWith({
    String? id,
    String? category,
    String? routineName,
    String? description,
    List<RoutineExercise>? exercises,
  }) {
    return RoutineModel(
      id: id ?? this.id,
      category: category ?? this.category,
      routineName: routineName ?? this.routineName,
      description: description ?? this.description,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'routineName': routineName,
      'description': description,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}
