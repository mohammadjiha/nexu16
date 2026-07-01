import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import '../../../coaching/presentation/screens/human_coach_chat_screen.dart';
import '../../../auth/data/auth_repository.dart' show assignedCoachProvider, currentUserModelProvider;

import '../../../../../core/localization/app_localizations.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../nutrition/data/coach_nutrition_repository.dart';
import '../../../nutrition/data/daily_meal_tracking_repository.dart';
import '../../../nutrition/domain/models/coach_nutrition_plan.dart';
import '../../../nutrition/domain/models/daily_meal_tracking.dart';
import '../widgets/nutrition_settings_sheet.dart';
import '../../services/alarm_service.dart';
import 'meal_tracking_screen.dart';

class CoachPlanScreen extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const CoachPlanScreen({super.key, required this.navigatorKey});

  @override
  ConsumerState<CoachPlanScreen> createState() => _CoachPlanScreenState();
}

class _CoachPlanScreenState extends ConsumerState<CoachPlanScreen> {
  bool _following = false;

  Future<void> _followPlan(BuildContext context, CoachNutritionPlan plan) async {
    setState(() => _following = true);
    try {
      final alarm = AlarmService();
      await alarm.cancelAll(); // clear old meal alarms
      int id = 200;
      for (final meal in plan.meals) {
        final t = _parseTimeOfDay(meal.time);
        if (t != null) {
          await alarm.scheduleMealAlarm(
            id: id++,
            title: '🍽️ ${meal.name}',
            body: meal.time.isNotEmpty ? 'Meal time: ${meal.time}' : 'Time to eat!',
            time: t,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('meal_reminders_set'.tr(context)),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _following = false);
  }

  TimeOfDay? _parseTimeOfDay(String s) {
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

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).asData?.value;
    final uid = authUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUser = ref.watch(currentUserModelProvider).asData?.value;
    final coachAsync = ref.watch(assignedCoachProvider);
    final coach = coachAsync.asData?.value;

    final playerName =
        '${currentUser?.firstName ?? ''} ${currentUser?.lastName ?? ''}'.trim();
    final coachUid = currentUser?.assignedCoachUid ?? '';

    final planAsync = ref.watch(coachNutritionPlanProvider(uid));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => widget.navigatorKey.currentState!.pop(),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16.sp, color: const Color(0xFF1C1C1E)),
        ),
        title: Text(
          'coach_plan_title'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () => NutritionSettingsSheet.show(
              context,
              widget.navigatorKey.currentState!,
              playerUid: uid,
              playerName: playerName,
              assignedCoachUid: coachUid,
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 3.w),
              child: Icon(Icons.settings_rounded,
                  color: const Color(0xFF1C1C1E), size: 20.sp),
            ),
          ),
          // ── Chat with coach ─────────────────────────────────────────
          if (coachUid.isNotEmpty)
            GestureDetector(
              onTap: () {
                final chatId = '${uid}_$coachUid';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HumanCoachChatScreen(
                      chatId: chatId,
                      participantName: coach != null
                          ? '${coach.firstName ?? ''} ${coach.lastName ?? ''}'.trim()
                          : 'Coach',
                    ),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: 4.w),
                child: Icon(Icons.message_rounded,
                    color: const Color(0xFF1C1C1E), size: 20.sp),
              ),
            )
          else
            Padding(
              padding: EdgeInsetsDirectional.only(end: 4.w),
              child: Icon(Icons.message_rounded,
                  color: const Color(0xFFD1D1D6), size: 20.sp),
            ),
        ],
      ),
      body: planAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('error_with_detail'.trP(context, {'e': e}))),
        data: (plan) {
          if (plan == null) return _buildEmptyState(context);
          return _buildPlan(context, plan);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🍽️', style: TextStyle(fontSize: 50.sp)),
            SizedBox(height: 2.h),
            Text(
              'no_coach_plan_yet'.tr(context),
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              'coach_will_set_plan'.tr(context),
              style: TextStyle(
                  fontSize: 14.sp, color: const Color(0xFF8E8E93)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlan(BuildContext context, CoachNutritionPlan plan) {
    final uid = ref.watch(authStateProvider).asData?.value?.uid ?? '';
    final trackingAsync = ref.watch(todayMealTrackingProvider(uid));
    final tracking = trackingAsync.asData?.value;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 14.h),
          child: Column(
            children: [
              _buildCoachCard(context, plan),
              _buildTodayProgress(context, plan, tracking),
              _buildCoachNote(context, plan),
              _buildMealsSection(context, plan, tracking),
            ],
          ),
        ),
        // Follow button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 5.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFFF5F5F7),
                  const Color(0xFFF5F5F7).withValues(alpha: 0.0),
                ],
                stops: const [0.68, 1.0],
              ),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MealTrackingScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A7A30),
                minimumSize: Size(double.infinity, 6.5.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.5.w)),
                elevation: 0,
              ),
              child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            color: Colors.white, size: 16.sp),
                        SizedBox(width: 2.w),
                        Text(
                          'follow_coach_plan'.tr(context),
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoachCard(BuildContext context, CoachNutritionPlan plan) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'assigned_by'.tr(context),
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 0.7),
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('👨‍💼', style: TextStyle(fontSize: 22.sp)),
              ),
              SizedBox(width: 3.5.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.coachName,
                        style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    SizedBox(height: 0.2.h),
                    Text(plan.coachDesc,
                        style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.white.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroStat(
                  '${plan.computedCalories}', 'KCAL', Colors.white),
              _buildMacroStat('${plan.computedProtein.toStringAsFixed(0)}g',
                  'PROTEIN', const Color(0xFF007AFF)),
              _buildMacroStat('${plan.computedCarbs.toStringAsFixed(0)}g',
                  'CARBS', const Color(0xFFFF9500)),
              _buildMacroStat('${plan.computedFat.toStringAsFixed(0)}g', 'FAT',
                  const Color(0xFFFF3B30)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(String val, String lbl, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val,
            style: TextStyle(
                fontSize: 18.sp, fontWeight: FontWeight.w800, color: color)),
        SizedBox(height: 0.2.h),
        Text(lbl,
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.4))),
      ],
    );
  }

  Widget _buildTodayProgress(
      BuildContext context, CoachNutritionPlan plan, DailyMealTracking? tracking) {
    final total = plan.meals.length;
    if (total == 0) return const SizedBox.shrink();

    final done = tracking == null
        ? 0
        : tracking.meals.where((m) => m.completed).length;
    final rate = total > 0 ? done / total : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Progress",
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E)),
              ),
              Text(
                '$done / $total meals',
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF34C759)),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E5EA),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachNote(BuildContext context, CoachNutritionPlan plan) {
    if (plan.coachNote.isEmpty) return const SizedBox.shrink();

    String timeLabel = 'coach_note_updated'.tr(context);
    try {
      timeLabel =
          'Updated ${DateFormat('MMM d').format(plan.updatedAt)}';
    } catch (_) {}

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(3.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(timeLabel,
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8E8E93),
                  letterSpacing: 0.5)),
          SizedBox(height: 1.h),
          Text(
            '"${plan.coachNote}"',
            style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF3A3A3C),
                height: 1.5,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsSection(BuildContext context, CoachNutritionPlan plan,
      DailyMealTracking? tracking) {
    if (plan.meals.isEmpty) return const SizedBox.shrink();

    final uid = ref.read(authStateProvider).asData?.value?.uid ?? '';
    final mealNames = plan.meals.map((m) => m.name).toList();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 1.5.h),
            child: Row(
              children: [
                Text(
                  'coachs_meal_plan'.tr(context),
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E)),
                ),
              ],
            ),
          ),
          ...plan.meals.asMap().entries.map((e) {
            final isCompleted = tracking != null &&
                e.key < tracking.meals.length &&
                tracking.meals[e.key].completed;
            return _buildMealRow(
              context,
              meal: e.value,
              mealIdx: e.key,
              playerUid: uid,
              mealNames: mealNames,
              isCompleted: isCompleted,
              isLast: e.key == plan.meals.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMealRow(BuildContext context,
      {required CoachMeal meal,
      required int mealIdx,
      required String playerUid,
      required List<String> mealNames,
      bool isCompleted = false,
      bool isLast = false}) {
    final mealCal = meal.totalCalories;
    final macroStr = '$mealCal kcal'
        ' · P:${meal.totalProtein.toStringAsFixed(0)}g'
        ' · C:${meal.totalCarbs.toStringAsFixed(0)}g'
        ' · F:${meal.totalFat.toStringAsFixed(0)}g';

    return Container(
      decoration: const BoxDecoration(
          border:
              Border(top: BorderSide(color: Color(0xFFF5F5F7), width: 0.5))),
      padding: EdgeInsets.only(bottom: isLast ? 2.h : 0),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFE8F8EE)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(2.5.w)),
                  alignment: Alignment.center,
                  child: Text(meal.icon, style: TextStyle(fontSize: 20.sp)),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.time.isNotEmpty
                            ? '${meal.name} — ${meal.time}'
                            : meal.name,
                        style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: isCompleted
                                ? const Color(0xFF34C759)
                                : const Color(0xFF1C1C1E),
                            decoration: isCompleted
                                ? TextDecoration.none
                                : null),
                      ),
                      SizedBox(height: 0.2.h),
                      Text(macroStr,
                          style: TextStyle(
                              fontSize: 13.sp,
                              color: const Color(0xFF8E8E93))),
                    ],
                  ),
                ),
                // ── Done button ─────────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    ref
                        .read(dailyMealTrackingRepositoryProvider)
                        .toggleMeal(
                          playerUid: playerUid,
                          mealIdx: mealIdx,
                          mealNames: mealNames,
                        );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF34C759)
                          : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFF34C759)
                            : const Color(0xFFD1D1D6),
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: isCompleted
                        ? Icon(Icons.check_rounded,
                            color: Colors.white, size: 12.sp)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          ...meal.foods.map((f) => _buildFoodItem(f)),
        ],
      ),
    );
  }

  Widget _buildFoodItem(CoachFoodItem food) {
    final macroStr =
        '${food.amount}${food.amount.isNotEmpty ? ' · ' : ''}P:${food.protein.toStringAsFixed(0)}g · C:${food.carbs.toStringAsFixed(0)}g · F:${food.fat.toStringAsFixed(0)}g';

    return Container(
      padding: EdgeInsets.fromLTRB(5.w, 1.5.h, 4.w, 1.5.h),
      decoration: const BoxDecoration(
          border:
              Border(top: BorderSide(color: Color(0xFFF8F8F8), width: 0.5))),
      child: Row(
        children: [
          Text(food.emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E))),
                SizedBox(height: 0.2.h),
                Text(macroStr,
                    style: TextStyle(
                        fontSize: 12.sp, color: const Color(0xFF8E8E93))),
              ],
            ),
          ),
          Text('${food.calories} kcal',
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E))),
        ],
      ),
    );
  }
}
