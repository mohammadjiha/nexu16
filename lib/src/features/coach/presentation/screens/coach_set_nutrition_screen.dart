import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';
import 'coach_player_nutrition_detail_screen.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../nutrition/data/coach_nutrition_repository.dart';
import '../../../nutrition/domain/models/coach_nutrition_plan.dart';
import '../../../user/models/user_model.dart';

class CoachSetNutritionScreen extends ConsumerStatefulWidget {
  final UserModel player;

  const CoachSetNutritionScreen({super.key, required this.player});

  @override
  ConsumerState<CoachSetNutritionScreen> createState() =>
      _CoachSetNutritionScreenState();
}

class _CoachSetNutritionScreenState
    extends ConsumerState<CoachSetNutritionScreen> {
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  bool _loaded = true; // show form immediately

  // Meals list — mutable
  List<_MealDraft> _meals = [];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final repo = ref.read(coachNutritionRepositoryProvider);
      final plan = await repo.getPlan(widget.player.uid);
      if (!mounted) return;
      if (plan != null) {
        setState(() {
          _noteCtrl.text = plan.coachNote;
          _meals = plan.meals
              .map((m) => _MealDraft(
                    icon: m.icon,
                    name: m.name,
                    time: m.time,
                    foods: m.foods
                        .map((f) => _FoodDraft(
                              emoji: f.emoji,
                              name: f.name,
                              amount: f.amount,
                              calories: f.calories,
                              protein: f.protein,
                              carbs: f.carbs,
                              fat: f.fat,
                            ))
                        .toList(),
                  ))
              .toList();
          _loaded = true;
        });
      } else {
        setState(() => _loaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    for (final m in _meals) {
      m.dispose();
    }
    super.dispose();
  }

  int get _totalCal =>
      _meals.fold(0, (s, m) => s + m.foods.fold(0, (ss, f) => ss + f.calories));
  double get _totalProtein =>
      _meals.fold(0.0, (s, m) => s + m.foods.fold(0.0, (ss, f) => ss + f.protein));
  double get _totalCarbs =>
      _meals.fold(0.0, (s, m) => s + m.foods.fold(0.0, (ss, f) => ss + f.carbs));
  double get _totalFat =>
      _meals.fold(0.0, (s, m) => s + m.foods.fold(0.0, (ss, f) => ss + f.fat));

  Future<void> _save() async {
    if (_meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('add_at_least_one_meal'.tr(context))),
      );
      return;
    }

    setState(() => _saving = true);

    final coachModel = ref.read(currentUserModelProvider).value;
    final coachName =
        '${coachModel?.firstName ?? ''} ${coachModel?.lastName ?? ''}'.trim();
    final coachDesc = 'certified_nutrition_coach'.tr(context);

    final plan = CoachNutritionPlan(
      coachUid: coachModel?.uid ?? '',
      coachName: coachName.isEmpty ? 'coach_label'.tr(context) : coachName,
      coachDesc: coachDesc,
      coachNote: _noteCtrl.text.trim(),
      totalCalories: _totalCal,
      protein: _totalProtein,
      carbs: _totalCarbs,
      fat: _totalFat,
      meals: _meals
          .map((m) => CoachMeal(
                icon: m.icon,
                name: m.name,
                time: m.time,
                foods: m.foods
                    .map((f) => CoachFoodItem(
                          emoji: f.emoji,
                          name: f.name,
                          amount: f.amount,
                          calories: f.calories,
                          protein: f.protein,
                          carbs: f.carbs,
                          fat: f.fat,
                        ))
                    .toList(),
              ))
          .toList(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref
          .read(coachNutritionRepositoryProvider)
          .setPlan(widget.player.uid, plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('nutrition_plan_saved'.tr(context)),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
        // Replace current route with nutrition detail screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CoachPlayerNutritionDetailScreen(player: widget.player),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_with_detail'.trP(context, {'e': e}))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerName =
        '${widget.player.firstName ?? ''} ${widget.player.lastName ?? ''}'.trim();

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          shadowColor: const Color(0x1A000000),
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: EdgeInsets.only(left: 2.w),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20.sp, color: const Color(0xFF1C1C1E)),
            ),
          ),
          title: Column(
            children: [
              Text(
                'set_meal_plan'.tr(context),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                playerName,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            if (_saving)
              Padding(
                padding: EdgeInsets.only(right: 4.w),
                child: SizedBox(
                  width: 18.sp,
                  height: 18.sp,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF007AFF)),
                ),
              )
            else
              GestureDetector(
                onTap: _save,
                child: Container(
                  margin: EdgeInsets.only(right: 4.w),
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(6.w),
                  ),
                  child: Text(
                    'save'.tr(context),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF)))
            : SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 2.h),

                    // ── Macro Summary ───────────────────────────────────
                    _buildMacroSummary(),

                    SizedBox(height: 1.5.h),

                    // ── Coach Note ──────────────────────────────────────
                    _buildNoteSection(),

                    SizedBox(height: 2.5.h),

                    // ── Meals label ─────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: Text(
                        'meals'.tr(context).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF8E8E93),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),

                    SizedBox(height: 1.h),

                    ..._meals.asMap().entries.map((e) =>
                        _buildMealCard(e.key, e.value)),

                    // ── Add Meal ────────────────────────────────────────
                    GestureDetector(
                      onTap: _addMeal,
                      child: Container(
                        margin: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 0.5.h),
                        padding: EdgeInsets.symmetric(vertical: 1.8.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3.5.w),
                          border: Border.all(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded,
                                color: const Color(0xFF007AFF), size: 18.sp),
                            SizedBox(width: 1.5.w),
                            Text(
                              'add_meal'.tr(context),
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF007AFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── Macro summary ──────────────────────────────────────────────────────────
  Widget _buildMacroSummary() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.5.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _macroTile('$_totalCal', 'kcal_upper'.tr(context), Colors.white),
          _macroDivider(),
          _macroTile('${_totalProtein.toStringAsFixed(0)}g', 'protein_upper'.tr(context),
              const Color(0xFF4DA6FF)),
          _macroDivider(),
          _macroTile('${_totalCarbs.toStringAsFixed(0)}g', 'carbs_upper'.tr(context),
              const Color(0xFFFFAA44)),
          _macroDivider(),
          _macroTile('${_totalFat.toStringAsFixed(0)}g', 'fat_upper'.tr(context),
              const Color(0xFFFF6B6B)),
        ],
      ),
    );
  }

  Widget _macroDivider() => Container(
        width: 1,
        height: 4.h,
        color: Colors.white.withValues(alpha: 0.1),
      );

  Widget _macroTile(String val, String lbl, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(val,
            style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5)),
        SizedBox(height: 0.4.h),
        Text(lbl,
            style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: 0.5)),
      ],
    );
  }

  // ─── Coach Note ─────────────────────────────────────────────────────────────
  Widget _buildNoteSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
            child: Row(
              children: [
                Container(
                  width: 7.w,
                  height: 7.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E8),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  alignment: Alignment.center,
                  child: Text('📝', style: TextStyle(fontSize: 13.sp)),
                ),
                SizedBox(width: 2.5.w),
                Text(
                  'coach_notes'.tr(context),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
            child: TextField(
              controller: _noteCtrl,
              maxLines: 3,
              style: TextStyle(
                fontSize: 15.sp,
                color: const Color(0xFF3A3A3C),
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'coach_note_hint'.tr(context),
                hintStyle: TextStyle(
                    fontSize: 15.sp,
                    color: const Color(0xFFAEAEB2),
                    height: 1.6),
                filled: true,
                fillColor: const Color(0xFFF9F9FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.5.w),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(3.w),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Meal card ──────────────────────────────────────────────────────────────
  Widget _buildMealCard(int mealIdx, _MealDraft meal) {
    final mealCal = meal.foods.fold(0, (s, f) => s + f.calories);

    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Meal header
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 3.w, 1.5.h),
            child: Row(
              children: [
                // Icon picker
                GestureDetector(
                  onTap: () => _pickMealIcon(mealIdx),
                  child: Container(
                    width: 11.w,
                    height: 11.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    alignment: Alignment.center,
                    child: Text(meal.icon,
                        style: TextStyle(fontSize: 22.sp)),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stableField(
                        controller: meal.nameCtrl,
                        hint: 'meal_name'.tr(context),
                        style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1C1C1E)),
                      ),
                      GestureDetector(
                        onTap: () => _pickTime(mealIdx),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 13.sp, color: const Color(0xFF8E8E93)),
                            SizedBox(width: 1.w),
                            Text(
                              meal.time.isNotEmpty ? meal.time : 'Set time...',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: meal.time.isNotEmpty
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFFAEAEB2),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Total kcal
                Text(
                  '$mealCal kcal',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(width: 2.w),
                // Delete meal
                GestureDetector(
                  onTap: () => setState(() => _meals.removeAt(mealIdx)),
                  child: Icon(Icons.remove_circle_outline_rounded,
                      color: const Color(0xFFFF3B30), size: 18.sp),
                ),
              ],
            ),
          ),

          // Foods
          ...meal.foods.asMap().entries.map((e) =>
              _buildFoodRow(mealIdx, e.key, e.value)),

          // Add food
          GestureDetector(
            onTap: () => _addFood(mealIdx),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 1.6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9FB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(3.5.w),
                  bottomRight: Radius.circular(3.5.w),
                ),
                border: const Border(
                    top: BorderSide(color: Color(0xFFEEEEF0), width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: const Color(0xFF007AFF), size: 15.sp),
                  SizedBox(width: 1.5.w),
                  Text(
                    'add_food'.tr(context),
                    style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF007AFF)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Food row ────────────────────────────────────────────────────────────────
  Widget _buildFoodRow(int mealIdx, int foodIdx, _FoodDraft food) {
    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.5.h),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF5F5F7), width: 0.5)),
      ),
      child: Row(
        children: [
          // Emoji picker
          GestureDetector(
            onTap: () => _pickFoodEmoji(mealIdx, foodIdx),
            child: Text(food.emoji, style: TextStyle(fontSize: 22.sp)),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stableField(
                  controller: food.nameCtrl,
                  hint: 'food_name'.tr(context),
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E)),
                ),
                _stableField(
                  controller: food.amountCtrl,
                  hint: 'amount_hint'.tr(context),
                  style: TextStyle(
                      fontSize: 13.sp, color: const Color(0xFF8E8E93)),
                ),
                SizedBox(height: 0.6.h),
                // P / C / F mini row
                Row(
                  children: [
                    Flexible(child: _macroMiniField('P', food.proteinCtrl, const Color(0xFF007AFF))),
                    SizedBox(width: 1.5.w),
                    Flexible(child: _macroMiniField('C', food.carbsCtrl, const Color(0xFFFF9500))),
                    SizedBox(width: 1.5.w),
                    Flexible(child: _macroMiniField('F', food.fatCtrl, const Color(0xFFFF3B30))),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          // Calories field
          SizedBox(
            width: 14.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _stableField(
                  controller: food.caloriesCtrl,
                  hint: '0',
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E)),
                  textAlign: TextAlign.end,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                Text('kcal',
                    style: TextStyle(
                        fontSize: 12.sp, color: const Color(0xFF8E8E93))),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          // Delete food
          GestureDetector(
            onTap: () =>
                setState(() => _meals[mealIdx].foods.removeAt(foodIdx)),
            child: Icon(Icons.close_rounded,
                color: const Color(0xFFAEAEB2), size: 16.sp),
          ),
        ],
      ),
    );
  }

  // ─── Macro mini input (P / C / F) ────────────────────────────────────────────
  Widget _macroMiniField(String label, TextEditingController ctrl, Color color) {
    return Row(
        children: [
          Text('$label:',
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: color)),
          SizedBox(width: 1.w),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E)),
              cursorColor: color,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                    fontSize: 13.sp, color: const Color(0xFFAEAEB2)),
                suffix: Text('g',
                    style: TextStyle(
                        fontSize: 12.sp, color: const Color(0xFF8E8E93))),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: color, width: 1),
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
    );
  }

  // ─── Time picker ─────────────────────────────────────────────────────────────
  Future<void> _pickTime(int mealIdx) async {
    final current = _meals[mealIdx].pickedTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _meals[mealIdx].pickedTime = picked);
    }
  }

  // ─── Stable text field (controller never recreated on rebuild) ───────────────
  Widget _stableField({
    required TextEditingController controller,
    required String hint,
    required TextStyle style,
    TextAlign textAlign = TextAlign.start,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      textAlign: textAlign,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: style.copyWith(color: const Color(0xFF1C1C1E)),
      cursorColor: const Color(0xFF007AFF),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(
            color: const Color(0xFFAEAEB2), fontWeight: FontWeight.w400),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  void _addMeal() {
    setState(() {
      _meals.add(_MealDraft(
        icon: '🍽️',
        name: '',
        time: '',
        foods: [],
      ));
    });
  }

  void _addFood(int mealIdx) {
    setState(() {
      _meals[mealIdx].foods.add(_FoodDraft(
        emoji: '🥗',
        name: '',
        amount: '',
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
      ));
    });
  }

  final List<String> _mealIcons = [
    '🌅', '☀️', '🌙', '🏆', '🍽️', '🥗', '💪', '⚡', '🌿', '🔥'
  ];

  void _pickMealIcon(int mealIdx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(5.w))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(4.w),
        child: Wrap(
          spacing: 3.w,
          runSpacing: 2.h,
          children: _mealIcons
              .map((e) => GestureDetector(
                    onTap: () {
                      setState(() => _meals[mealIdx].icon = e);
                      Navigator.pop(context);
                    },
                    child: Text(e, style: TextStyle(fontSize: 30.sp)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  final List<String> _foodEmojis = [
    '🥣', '🍳', '🥚', '🍗', '🥩', '🐟', '🍠', '🥗', '🥦',
    '🍌', '🍎', '🥛', '🧃', '🥜', '🍚', '🥙', '🍞', '🧈',
  ];

  void _pickFoodEmoji(int mealIdx, int foodIdx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(5.w))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(4.w),
        child: Wrap(
          spacing: 3.w,
          runSpacing: 2.h,
          children: _foodEmojis
              .map((e) => GestureDetector(
                    onTap: () {
                      setState(() => _meals[mealIdx].foods[foodIdx].emoji = e);
                      Navigator.pop(context);
                    },
                    child: Text(e, style: TextStyle(fontSize: 30.sp)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─── Draft models (mutable during editing) ────────────────────────────────────
class _FoodDraft {
  String emoji;

  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController caloriesCtrl;
  final TextEditingController proteinCtrl;
  final TextEditingController carbsCtrl;
  final TextEditingController fatCtrl;

  _FoodDraft({
    required this.emoji,
    required String name,
    required String amount,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
  })  : nameCtrl = TextEditingController(text: name),
        amountCtrl = TextEditingController(text: amount),
        caloriesCtrl = TextEditingController(text: calories == 0 ? '' : '$calories'),
        proteinCtrl = TextEditingController(text: protein == 0 ? '' : '${protein.toStringAsFixed(0)}'),
        carbsCtrl = TextEditingController(text: carbs == 0 ? '' : '${carbs.toStringAsFixed(0)}'),
        fatCtrl = TextEditingController(text: fat == 0 ? '' : '${fat.toStringAsFixed(0)}');

  String get name => nameCtrl.text;
  String get amount => amountCtrl.text;
  int get calories => int.tryParse(caloriesCtrl.text) ?? 0;
  double get protein => double.tryParse(proteinCtrl.text) ?? 0;
  double get carbs => double.tryParse(carbsCtrl.text) ?? 0;
  double get fat => double.tryParse(fatCtrl.text) ?? 0;

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    caloriesCtrl.dispose();
    proteinCtrl.dispose();
    carbsCtrl.dispose();
    fatCtrl.dispose();
  }
}

class _MealDraft {
  String icon;
  List<_FoodDraft> foods;
  TimeOfDay? pickedTime;

  final TextEditingController nameCtrl;

  _MealDraft({
    required this.icon,
    required String name,
    required String time,
    required this.foods,
  })  : nameCtrl = TextEditingController(text: name),
        pickedTime = _parseTime(time);

  String get name => nameCtrl.text;

  String get time {
    if (pickedTime == null) return '';
    final h = pickedTime!.hourOfPeriod == 0 ? 12 : pickedTime!.hourOfPeriod;
    final m = pickedTime!.minute.toString().padLeft(2, '0');
    final period = pickedTime!.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  static TimeOfDay? _parseTime(String s) {
    if (s.isEmpty) return null;
    try {
      final parts = s.split(':');
      if (parts.length < 2) return null;
      int hour = int.parse(parts[0].trim());
      final rest = parts[1].trim().split(' ');
      int minute = int.parse(rest[0]);
      final isPm = rest.length > 1 && rest[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    nameCtrl.dispose();
    for (final f in foods) {
      f.dispose();
    }
  }
}
