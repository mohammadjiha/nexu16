import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../gym/models/exercise_model.dart';
import '../../../smart_workout/models/routine_model.dart';
import '../../../smart_workout/providers/coach_plan_provider.dart';
import '../../../smart_workout/services/workout_plan_engine.dart';
import '../../../user/models/user_model.dart';
import '../../providers/coach_monitoring_provider.dart';

/// Lets a coach author the workout a player will see on a given weekday.
/// Starts from the player's auto-generated routine (or the existing coach
/// routine) and the coach edits it, then saves it to the player's coach plan.
class CoachWorkoutBuilderScreen extends ConsumerStatefulWidget {
  final UserModel player;
  final String dayName; // 'MON'..'SUN'

  const CoachWorkoutBuilderScreen({
    super.key,
    required this.player,
    required this.dayName,
  });

  @override
  ConsumerState<CoachWorkoutBuilderScreen> createState() =>
      _CoachWorkoutBuilderScreenState();
}

class _CoachWorkoutBuilderScreenState
    extends ConsumerState<CoachWorkoutBuilderScreen> {
  List<RoutineExercise>? _exercises; // null until seeded
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Seed the editable list once, from the coach plan (if any) else the auto
  // plan. Waits for the streams to emit before seeding (so it never seeds an
  // empty list prematurely).
  void _seedIfNeeded() {
    if (_exercises != null) return;
    final coachAsync = ref.watch(playerCoachPlanProvider(widget.player.uid));
    if (!coachAsync.hasValue) return; // still loading → build shows a loader

    final coachRoutine = coachAsync.value?.routineFor(widget.dayName);
    if (coachRoutine != null) {
      _exercises = List<RoutineExercise>.from(coachRoutine.exercises);
      // Don't prefill with the generic fallback name — leave the field
      // empty so the placeholder shows, unless the coach set a real name.
      const genericNames = {'خطة المدرّب', "Coach's Workout"};
      if (!genericNames.contains(coachRoutine.routineName)) {
        _nameCtrl.text = coachRoutine.routineName;
      }
      return;
    }

    // No coach routine yet → start from the player's auto plan for this weekday.
    final planAsync = ref.watch(playerGeneratedPlanProvider(widget.player.uid));
    if (!planAsync.hasValue) return; // wait for the auto plan to load
    final generated =
        ref.watch(playerGeneratedRoutinesProvider(widget.player.uid));
    for (final d in (planAsync.value ?? const [])) {
      if (d.dayName == widget.dayName && d.assignedRoutineId != null) {
        final r = generated[d.assignedRoutineId];
        if (r != null) {
          _exercises = List<RoutineExercise>.from(r.exercises);
          return;
        }
      }
    }
    _exercises = <RoutineExercise>[]; // loaded, no auto routine for this day
  }

  Future<void> _save() async {
    final list = _exercises ?? [];
    if (list.isEmpty) {
      _toast(_isAr ? 'أضِف تمرين واحد على الأقل.' : 'Add at least one exercise.');
      return;
    }
    setState(() => _saving = true);
    final coachId = ref.read(authStateProvider).asData?.value?.uid;
    final customName = _nameCtrl.text.trim();
    final routine = RoutineModel(
      id: 'coach_${widget.dayName.toLowerCase()}',
      category: list.first.muscleGroup ?? 'Coach',
      routineName: customName.isNotEmpty
          ? customName
          : (_isAr ? 'خطة المدرّب' : "Coach's Workout"),
      description: _isAr ? 'من مدرّبك' : 'Assigned by your coach',
      exercises: list,
    );
    try {
      await ref.read(coachPlanRepositoryProvider).setDayRoutine(
            playerId: widget.player.uid,
            dayName: widget.dayName,
            routine: routine,
            coachId: coachId,
          );
      if (mounted) {
        _toast(_isAr ? 'تم الحفظ ✅' : 'Saved ✅');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _toast('${_isAr ? 'خطأ' : 'Error'}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _removeAt(int i) => setState(() => _exercises!.removeAt(i));

  void _setSets(int i, int delta) {
    final ex = _exercises![i];
    final newSets = (ex.sets + delta).clamp(1, 10);
    setState(() => _exercises![i] = ex.copyWith(sets: newSets));
  }

  Future<void> _editRepsWeight(int i) async {
    final ex = _exercises![i];
    final repsCtrl = TextEditingController(text: ex.reps);
    final weightCtrl =
        TextEditingController(text: ex.weight > 0 ? ex.weight.toString() : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isAr ? 'تعديل' : 'Edit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: repsCtrl,
              decoration: InputDecoration(
                  labelText: _isAr ? 'التكرارات' : 'Reps (e.g. 8-12)'),
            ),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: _isAr ? 'الوزن (كغ)' : 'Weight (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_isAr ? 'إلغاء' : 'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_isAr ? 'حفظ' : 'Save')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _exercises![i] = ex.copyWith(
          reps: repsCtrl.text.trim().isEmpty ? ex.reps : repsCtrl.text.trim(),
          weight: double.tryParse(weightCtrl.text.trim()) ?? ex.weight,
        );
      });
    }
  }

  Future<void> _addExercise() async {
    final catalog =
        ref.read(firebaseExerciseCatalogProvider).asData?.value ?? const {};
    if (catalog.isEmpty) {
      _toast(_isAr ? 'قاعدة التمارين تحمّل...' : 'Exercise database loading…');
      return;
    }
    final picked = await showModalBottomSheet<ExerciseModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ExercisePickerSheet(catalog: catalog, isAr: _isAr),
    );
    if (picked != null) {
      setState(() {
        _exercises!.add(RoutineExercise(
          name: picked.name,
          sets: 3,
          reps: '8-12',
          restTime: 75,
          muscleGroup: picked.targetMuscleGroup,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _seedIfNeeded();
    if (_exercises == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F7),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
        ),
      );
    }
    final list = _exercises ?? [];
    final name =
        '${widget.player.firstName ?? ''} ${widget.player.lastName ?? ''}'.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_isAr ? 'خطة' : 'Plan'}: $name · ${widget.dayName}',
          style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1C1C1E)),
      ),
      body: ListView(
        padding: EdgeInsets.all(4.w),
        children: [
          Text(
            _isAr ? 'اسم التمرين (يشوفه اللاعب)' : 'Workout name (player sees this)',
            style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A3A3C)),
          ),
          SizedBox(height: 1.h),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: _isAr ? 'مثال: Push Day A' : 'e.g. Push Day A',
              hintStyle: TextStyle(
                  fontSize: 14.sp, color: const Color(0xFFAEAEB2)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.6.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3.w),
                borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3.w),
                borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          ...list.asMap().entries.map((e) => _exerciseRow(e.key, e.value)),
          SizedBox(height: 1.h),
          GestureDetector(
            onTap: _addExercise,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 2.h),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.w),
                border: Border.all(
                    color: const Color(0xFF1C1C1E), width: 1.5),
              ),
              child: Text(
                _isAr ? '+ أضف تمرين' : '+ Add exercise',
                style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E)),
              ),
            ),
          ),
          SizedBox(height: 2.h),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C1C1E),
            padding: EdgeInsets.symmetric(vertical: 2.2.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.w)),
          ),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  _isAr ? 'حفظ الخطة' : 'Save plan',
                  style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
        ),
      ),
    );
  }

  Widget _exerciseRow(int i, RoutineExercise ex) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.5.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _editRepsWeight(i),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name,
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C1C1E))),
                      SizedBox(height: 0.3.h),
                      Text(
                        '${ex.reps}${ex.muscleGroup != null ? ' · ${ex.muscleGroup}' : ''}${ex.weight > 0 ? ' · ${ex.weight}kg' : ''}',
                        style: TextStyle(
                            fontSize: 12.sp, color: const Color(0xFF8E8E93)),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _editRepsWeight(i),
                child: Container(
                  padding: EdgeInsets.all(1.5.w),
                  margin: EdgeInsets.only(right: 1.5.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(1.5.w),
                  ),
                  child: Icon(Icons.edit_rounded,
                      color: const Color(0xFF1C1C1E), size: 16.sp),
                ),
              ),
              GestureDetector(
                onTap: () => _removeAt(i),
                child: Icon(Icons.delete_outline_rounded,
                    color: const Color(0xFFFF3B30), size: 20.sp),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              Text('${_isAr ? 'مجموعات' : 'Sets'}: ',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3A3A3C))),
              _stepBtn(Icons.remove, () => _setSets(i, -1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                child: Text('${ex.sets}',
                    style: TextStyle(
                        fontSize: 16.sp, fontWeight: FontWeight.w800)),
              ),
              _stepBtn(Icons.add, () => _setSets(i, 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 8.w,
        height: 8.w,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(2.w),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Icon(icon, size: 16.sp, color: const Color(0xFF1C1C1E)),
      ),
    );
  }
}

/// Bottom sheet: pick a muscle group, then tap an exercise to add it.
class _ExercisePickerSheet extends StatefulWidget {
  final Map<String, List<ExerciseModel>> catalog;
  final bool isAr;
  const _ExercisePickerSheet({required this.catalog, required this.isAr});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  late String _muscle;
  String _query = '';
  // Same filter dimensions as the player's Exercises screen (equipment +
  // experience level), so coaches search the exact same way players do.
  String _equipment = 'All';
  String _level = 'All';

  @override
  void initState() {
    super.initState();
    _muscle = widget.catalog.keys.first;
  }

  bool get _hasActiveFilters => _equipment != 'All' || _level != 'All';

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      builder: (ctx) => _ExerciseFilterSheet(
        isAr: widget.isAr,
        initialEquipment: _equipment,
        initialLevel: _level,
      ),
    );
    if (result != null) {
      setState(() {
        _equipment = result['equipment'] ?? 'All';
        _level = result['level'] ?? 'All';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final muscles = widget.catalog.keys.toList();
    final all = widget.catalog[_muscle] ?? const <ExerciseModel>[];
    var exercises = _query.isEmpty
        ? all
        : all.where((e) => e.matchesSearch(_query)).toList();
    if (_equipment != 'All') {
      exercises = exercises
          .where((e) =>
              e.equipmentRequired.toLowerCase() == _equipment.toLowerCase())
          .toList();
    }
    if (_level != 'All') {
      exercises = exercises
          .where((e) => e.experienceLevel.toLowerCase() == _level.toLowerCase())
          .toList();
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (ctx, scroll) => Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          children: [
            Text(widget.isAr ? 'اختر تمرين' : 'Pick an exercise',
                style: TextStyle(
                    fontSize: 16.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 1.h),
            SizedBox(
              height: 5.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: muscles.map((m) {
                  final sel = m == _muscle;
                  return GestureDetector(
                    onTap: () => setState(() => _muscle = m),
                    child: Container(
                      margin: EdgeInsets.only(right: 2.w),
                      padding:
                          EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(5.w),
                        border: Border.all(color: const Color(0xFFD1D1D6)),
                      ),
                      child: Text(m,
                          style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF3A3A3C))),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 1.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: widget.isAr ? 'بحث...' : 'Search…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(3.w)),
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                GestureDetector(
                  onTap: _showFilterSheet,
                  child: Container(
                    padding: EdgeInsets.all(3.2.w),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(3.w),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: Icon(Icons.tune_rounded,
                        size: 20.sp,
                        color: _hasActiveFilters
                            ? Colors.white
                            : const Color(0xFF1C1C1E)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: exercises.length,
                itemBuilder: (c, i) {
                  final ex = exercises[i];
                  return ListTile(
                    title: Text(ex.name,
                        style: TextStyle(
                            fontSize: 16.sp, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${ex.targetMuscleGroup} · ${ex.experienceLevel}',
                        style: TextStyle(
                            fontSize: 13.sp, color: const Color(0xFF8E8E93))),
                    trailing: const Icon(Icons.add_circle_outline_rounded),
                    onTap: () => Navigator.pop(context, ex),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Equipment + experience-level filter — mirrors the player's Exercises
/// screen filter sheet, so the coach filters exercises the exact same way.
class _ExerciseFilterSheet extends StatefulWidget {
  final bool isAr;
  final String initialEquipment;
  final String initialLevel;

  const _ExerciseFilterSheet({
    required this.isAr,
    required this.initialEquipment,
    required this.initialLevel,
  });

  @override
  State<_ExerciseFilterSheet> createState() => _ExerciseFilterSheetState();
}

class _ExerciseFilterSheetState extends State<_ExerciseFilterSheet> {
  late String _equipment;
  late String _level;

  @override
  void initState() {
    super.initState();
    _equipment = widget.initialEquipment;
    _level = widget.initialLevel;
  }

  static const _equipmentOptions = [
    'All', 'Dumbbell', 'Barbell', 'Cable', 'Machine', 'Bodyweight',
  ];
  static const _levelOptions = ['All', 'Beginner', 'Intermediate', 'Advanced'];

  String _label(String value) {
    if (!widget.isAr) return value;
    const ar = {
      'All': 'الكل',
      'Dumbbell': 'دمبل',
      'Barbell': 'بار',
      'Cable': 'كيبل',
      'Machine': 'جهاز',
      'Bodyweight': 'وزن الجسم',
      'Beginner': 'مبتدئ',
      'Intermediate': 'متوسط',
      'Advanced': 'متقدم',
    };
    return ar[value] ?? value;
  }

  Widget _chip(String value, String selected, ValueChanged<String> onTap) {
    final sel = selected.toLowerCase() == value.toLowerCase();
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1C1C1E) : const Color(0xFFF0F0F5),
          borderRadius: BorderRadius.circular(4.w),
        ),
        child: Text(
          _label(value),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: sel ? Colors.white : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.only(
        start: 5.w,
        end: 5.w,
        bottom: MediaQuery.of(context).padding.bottom + 3.h,
        top: 2.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 12.w,
              height: 0.6.h,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(1.w),
              ),
            ),
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.isAr ? 'الفلاتر' : 'Filters',
                  style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E))),
              TextButton(
                onPressed: () =>
                    setState(() => _equipment = _level = 'All'),
                child: Text(widget.isAr ? 'إعادة تعيين' : 'Reset',
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF007AFF))),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Text(widget.isAr ? 'المعدات' : 'Equipment',
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A3A3C))),
          SizedBox(height: 1.5.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.5.h,
            children: _equipmentOptions
                .map((v) => _chip(
                    v, _equipment, (val) => setState(() => _equipment = val)))
                .toList(),
          ),
          SizedBox(height: 3.h),
          Text(widget.isAr ? 'مستوى الخبرة' : 'Experience level',
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A3A3C))),
          SizedBox(height: 1.5.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.5.h,
            children: _levelOptions
                .map((v) =>
                    _chip(v, _level, (val) => setState(() => _level = val)))
                .toList(),
          ),
          SizedBox(height: 4.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                  context, {'equipment': _equipment, 'level': _level}),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.w)),
              ),
              child: Text(widget.isAr ? 'تطبيق الفلاتر' : 'Apply filters',
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
