import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/intl_formatter.dart';
import '../../../profile/providers/body_metrics_provider.dart';
import '../../../smart_workout/models/routine_model.dart';
import '../../../smart_workout/providers/coach_plan_provider.dart';
import '../../../smart_workout/providers/split_setup_provider.dart';
import '../../../smart_workout/providers/workout_history_provider.dart';
import '../../../user/models/user_model.dart';
import '../../providers/coach_monitoring_provider.dart';

class CoachMonitoringScreen extends ConsumerStatefulWidget {
  final UserModel? player;

  const CoachMonitoringScreen({super.key, this.player});

  @override
  ConsumerState<CoachMonitoringScreen> createState() =>
      _CoachMonitoringScreenState();
}

class _CoachMonitoringScreenState extends ConsumerState<CoachMonitoringScreen> {
  int _currentTab = 0;
  String _fbTypeSelected = '💬 General';
  String _wfTypeSelected = '✅ Good form';
  String _nfTypeSelected = '🍗 Add protein';
  DateTime _selectedWorkoutDate = DateTime.now();

  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _workoutFeedbackController =
      TextEditingController();
  final TextEditingController _nutritionFeedbackController =
      TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    _workoutFeedbackController.dispose();
    _nutritionFeedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    if (player == null) {
      return Scaffold(
        body: Center(child: Text('player_not_found'.tr(context))),
      );
    }

    final historyAsync = ref.watch(playerWorkoutHistoryProvider(player.uid));
    final metricsAsync = ref.watch(playerBodyMetricsProvider(player.uid));
    final routinesAsync = ref.watch(playerRoutineProvider(player.uid));
    final nutritionAsync = ref.watch(
      playerNutritionHistoryProvider(player.uid),
    );
    final planAsync = ref.watch(playerGeneratedPlanProvider(player.uid));
    final splitAsync = ref.watch(playerSplitSetupProvider(player.uid));

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5EA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopbar(player, context),
            _buildTabs(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _buildCurrentTab(
                  player,
                  historyAsync,
                  metricsAsync,
                  routinesAsync,
                  nutritionAsync,
                  planAsync,
                  splitAsync,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopbar(UserModel player, BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(Icons.arrow_back_ios_new_rounded, () => context.pop()),
          Text(
            'monitoring'.tr(context),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          Row(
            children: [
              if (_currentTab == 3)
                _circleButton(Icons.download_rounded, () {
                  final metricsAsync = ref.read(
                    playerBodyMetricsProvider(player.uid),
                  );
                  final historyAsync = ref.read(
                    playerWorkoutHistoryProvider(player.uid),
                  );
                  final metrics = metricsAsync.value ?? BodyMetrics();
                  final history = historyAsync.value ?? [];
                  _exportProgressReport(context, player, metrics, history);
                })
              else
                _circleButton(Icons.refresh_rounded, () {
                  _showToast('refreshing_data'.tr(context));
                  // Riverpod streams will auto update if firebase changes
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 10.w,
        height: 10.w,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16.sp, color: const Color(0xFF1C1C1E)),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
      padding: EdgeInsets.all(1.w),
      decoration: BoxDecoration(
        color: const Color(0xFFD1D1D6).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Row(
        children: [
          _tabButton(0, 'today_label'.tr(context)),
          _tabButton(1, 'workout_label'.tr(context)),
          _tabButton(2, 'nutrition_label'.tr(context)),
          _tabButton(3, 'progress_label'.tr(context)),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final selected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.2.h),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(2.w),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFF8E8E93),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab(
    UserModel player,
    AsyncValue<List<CompletedSession>> historyAsync,
    AsyncValue<BodyMetrics> metricsAsync,
    AsyncValue<List<RoutineModel>> routinesAsync,
    AsyncValue<Map<String, dynamic>?> nutritionAsync,
    AsyncValue<List<WorkoutDay>> planAsync,
    AsyncValue<SplitSetupData> splitAsync,
  ) {
    switch (_currentTab) {
      case 0:
        return _buildTodayTab(
          player,
          historyAsync,
          routinesAsync,
          nutritionAsync,
        );
      case 1:
        return _buildWorkoutTab(player, routinesAsync, historyAsync, planAsync, splitAsync);
      case 2:
        return _buildNutritionTab(player, nutritionAsync);
      case 3:
        return _buildProgressTab(player, metricsAsync, historyAsync);
      default:
        return const SizedBox();
    }
  }

  // =========================================================================
  // TAB 1: TODAY
  // =========================================================================
  Widget _buildTodayTab(
    UserModel player,
    AsyncValue<List<CompletedSession>> historyAsync,
    AsyncValue<List<RoutineModel>> routinesAsync,
    AsyncValue<Map<String, dynamic>?> nutritionAsync,
  ) {
    final history = historyAsync.value ?? [];
    final hasSessionToday =
        history.isNotEmpty &&
        DateFormat('MMM d').format(DateTime.now()) == history.first.date;
    final routines = routinesAsync.value ?? [];
    final activeRoutine = routines.isNotEmpty ? routines.first : null;
    final nutData = nutritionAsync.value;

    return Column(
      children: [
        _buildPlayerMiniHeader(player, hasSessionToday, activeRoutine),
        _buildTodayHero(player, hasSessionToday, activeRoutine, history),
        _buildTodaySnapshot(
          player,
          hasSessionToday,
          nutData,
          activeRoutine,
          history,
        ),
        _buildWeeklyAdherence(player, history),
        _buildFeedbackForm(
          player,
          'fb-types',
          '📝 ${'send_feedback_title'.tr(context)}',
          _feedbackController,
          _fbTypeSelected,
          (val) => setState(() => _fbTypeSelected = val),
        ),
      ],
    );
  }

  Widget _buildPlayerMiniHeader(
    UserModel player,
    bool hasSessionToday,
    RoutineModel? routine,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 14.w,
                height: 14.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8FFF0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('💪', style: TextStyle(fontSize: 22.sp)),
              ),
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: Container(
                  width: 4.w,
                  height: 4.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF5F5F7),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName(player),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                Text(
                  '${routine?.routineName ?? "No plan"} · ${hasSessionToday ? "Active today" : "Offline"}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayHero(
    UserModel player,
    bool hasSessionToday,
    RoutineModel? routine,
    List<CompletedSession> history,
  ) {
    final sessionToday = hasSessionToday ? history.first : null;
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF0055CC)],
        ),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2.w,
                height: 2.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 2.w),
              Text(
                '${'today'.tr(context).toUpperCase()} · ${AppIntl.weekdayFull(context, DateTime.now()).toUpperCase()} ${AppIntl.shortDate(context, DateTime.now()).toUpperCase()}',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            hasSessionToday
                ? '${sessionToday?.routineName ?? "Workout"} Completed ✅'
                : 'Pending Workout / Rest 😴',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            hasSessionToday
                ? 'min_elapsed_sets'.trP(context, {
                    'min': sessionToday?.durationMinutes ?? 0,
                    'sets': sessionToday?.completedSets ?? 0,
                  })
                : 'player_not_completed_workout_today'.tr(context),
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              _buildHeroStat(
                hasSessionToday
                    ? '${sessionToday?.completedSets ?? 0}/${sessionToday?.totalSets ?? 0}'
                    : '0/0',
                'sets_done_upper'.tr(context),
              ),
              _buildHeroStat(
                '142',
                'avg_hr_upper'.tr(context),
                valColor: const Color(0xFFFF3B30),
              ), // Fixed HR as requested
              _buildHeroStat(
                hasSessionToday ? '84%' : '100%',
                'recovery_upper'.tr(context),
                valColor: const Color(0xFF34C759),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String val, String label, {Color? valColor}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: valColor ?? Colors.white,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySnapshot(
    UserModel player,
    bool hasSessionToday,
    Map<String, dynamic>? nutData,
    RoutineModel? activeRoutine,
    List<CompletedSession> history,
  ) {
    int workoutCompletion = 0;
    int hr = 0;
    if (hasSessionToday && history.isNotEmpty) {
      final sessionToday = history.first;
      workoutCompletion = sessionToday.totalSets > 0
          ? ((sessionToday.completedSets / sessionToday.totalSets) * 100)
                .clamp(0, 100)
                .toInt()
          : 100;
      hr = 0; // avgHeartRate is not defined in CompletedSession
    }

    int cKcal = 0;
    int tKcal = 0;
    double nutCompletion = 0;
    if (nutData != null) {
      cKcal =
          ((nutData['proteinCurrent'] ?? 0) * 4) +
          ((nutData['carbsCurrent'] ?? 0) * 4) +
          ((nutData['fatCurrent'] ?? 0) * 9);
      tKcal = nutData['totalCaloriesTarget'] ?? 0;
      if (tKcal > 0) {
        nutCompletion = ((cKcal / tKcal) * 100).clamp(0, 100);
      }
    }

    return _buildCard(
      title: 'today_snapshot'.tr(context),
      icon: '🏋🏻',
      iconBg: const Color(0xFFE8FFF0),
      children: [
        _buildProgressBarRow(
          '🏋️',
          'workout_completion'.tr(context),
          workoutCompletion,
          const Color(0xFF007AFF),
        ),
        _buildProgressBarRow(
          '🍗',
          '${'nutrition'.tr(context)} ($cKcal/$tKcal kcal)',
          nutCompletion.toInt(),
          const Color(0xFF34C759),
        ),
        _buildProgressBarRow(
          '💧',
          '${'water'.tr(context)} (0/0 ml)',
          0,
          const Color(0xFF007AFF),
        ),
        _buildProgressBarRow(
          '❤️',
          'avg_hr_during_workout'.tr(context),
          hasSessionToday ? 100 : 0,
          const Color(0xFFFF3B30),
          valText: hasSessionToday ? '--' : '0',
        ),
      ],
    );
  }

  Widget _buildWeeklyAdherence(
    UserModel player,
    List<CompletedSession> history,
  ) {
    final now = DateTime.now();
    List<Widget> dayWidgets = [];

    // Generate last 7 days including today
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      // dateStr is used for comparing with stored history — keep English.
      final dateStr = DateFormat('MMM d').format(date);
      final dayName = AppIntl.weekday(context, date).toUpperCase();

      final hasWorkout = history.any((h) => h.date == dateStr);
      final isToday = i == 0;

      if (hasWorkout) {
        dayWidgets.add(
          _buildAdherenceDay(
            dayName,
            '💪',
            'done_label'.tr(context),
            const Color(0xFF34C759),
            const Color(0xFFE8FFF0),
            hasBorder: isToday,
          ),
        );
      } else {
        dayWidgets.add(
          _buildAdherenceDay(
            dayName,
            '😴',
            'rest_day_short_label'.tr(context),
            const Color(0xFF8E8E93),
            const Color(0xFFF5F5F7),
            hasBorder: isToday,
          ),
        );
      }
    }

    return _buildCard(
      title: 'last_7_days'.tr(context),
      icon: '📅',
      iconBg: const Color(0xFFFFF8E8),
      actionText: 'full_arrow'.tr(context),
      onAction: () => setState(() => _currentTab = 3),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dayWidgets,
          ),
        ),
      ],
    );
  }

  Widget _buildAdherenceDay(
    String day,
    String icon,
    String pct,
    Color color,
    Color bg, {
    bool hasBorder = false,
  }) {
    return Column(
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: hasBorder ? color : const Color(0xFF8E8E93),
          ),
        ),
        SizedBox(height: 0.5.h),
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: hasBorder ? Border.all(color: color, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Text(icon, style: TextStyle(fontSize: 18.sp)),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: WORKOUT
  // =========================================================================
  Widget _buildWorkoutTab(
    UserModel player,
    AsyncValue<List<RoutineModel>> routinesAsync,
    AsyncValue<List<CompletedSession>> historyAsync,
    AsyncValue<List<WorkoutDay>> planAsync,
    AsyncValue<SplitSetupData> splitAsync,
  ) {
    final history = historyAsync.value ?? [];
    final plan = planAsync.value ?? [];
    final splitData = splitAsync.value;

    // Find the session for the selected date
    final selectedDateStr = DateFormat('MMM d').format(_selectedWorkoutDate);
    CompletedSession? selectedSession;
    for (final s in history) {
      if (s.date == selectedDateStr) {
        selectedSession = s;
        break;
      }
    }

    // Check if the selected date is a rest day (from plan or trainingDays)
    final selectedFullDate = DateFormat('yyyy-MM-dd').format(_selectedWorkoutDate);
    WorkoutDay? planDay;
    for (final day in plan) {
      if (day.fullDate == selectedFullDate) {
        planDay = day;
        break;
      }
    }

    // Determine rest vs workout day
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final selectedDayName = weekdays[_selectedWorkoutDate.weekday - 1];
    bool isRestDay;
    if (planDay != null) {
      isRestDay = planDay.isRest;
    } else if (splitData != null && splitData.trainingDays.isNotEmpty) {
      // Fall back to weekday check
      isRestDay = !splitData.trainingDays.contains(selectedDayName);
    } else {
      // If no plan and no setup, show based on whether session exists
      isRestDay = selectedSession == null;
    }

    // Resolve the routine for THIS specific day (not just "today") — respects
    // whether the player follows their coach's plan or their own, so the
    // 7-day scroller never shows the wrong workout for a past/other day.
    final planPrefs =
        ref.watch(playerPlanSourceProvider(player.uid)).value ??
            const PlanPrefs();
    RoutineModel? selectedRoutine;
    if (planPrefs.isCoach) {
      final coachPlan = ref.watch(playerCoachPlanProvider(player.uid)).value;
      selectedRoutine = coachPlan?.routineFor(selectedDayName);
    } else if (planDay?.assignedRoutineId != null) {
      final generated = ref.watch(playerGeneratedRoutinesProvider(player.uid));
      selectedRoutine = generated[planDay!.assignedRoutineId];
    }

    return Column(
      children: [
        // 7-day date scroller
        _buildWorkoutDayScroller(),
        // Day content
        if (isRestDay && selectedSession == null)
          _buildRestDayCard()
        else if (selectedSession != null)
          _buildCompletedWorkoutContent(selectedSession, player)
        else
          _buildPendingWorkoutContent(selectedRoutine, planDay, player),
        _buildFeedbackForm(
          player,
          'wf-types',
          '💬 ${'workout_feedback_title'.tr(context)}',
          _workoutFeedbackController,
          _wfTypeSelected,
          (val) => setState(() => _wfTypeSelected = val),
          opts: [
            '✅ Good form',
            '📈 Increase weight',
            '⚠️ Check form',
            '🔄 Rest more',
          ],
        ),
      ],
    );
  }

  Widget _buildWorkoutDayScroller() {
    final today = DateTime.now();
    return SizedBox(
      height: 11.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        itemCount: 7,
        itemBuilder: (_, i) {
          final date = today.subtract(Duration(days: 6 - i));
          final isSelected = DateFormat('yyyy-MM-dd').format(date) ==
              DateFormat('yyyy-MM-dd').format(_selectedWorkoutDate);
          final isToday = DateFormat('yyyy-MM-dd').format(date) ==
              DateFormat('yyyy-MM-dd').format(today);
          final dayName = AppIntl.weekday(context, date);

          return GestureDetector(
            onTap: () => setState(() => _selectedWorkoutDate = date),
            child: Container(
              width: 11.w,
              margin: EdgeInsets.only(right: 2.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF007AFF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(3.w),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF007AFF)
                      : isToday
                          ? const Color(0xFF007AFF).withOpacity(0.4)
                          : const Color(0xFFE5E5EA),
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                    ),
                  ),
                  SizedBox(height: 0.4.h),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRestDayCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
      padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        children: [
          Text('😴', style: TextStyle(fontSize: 40.sp)),
          SizedBox(height: 1.h),
          Text(
            'rest_day'.tr(context),
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            '${'recovery_is_part_of_training'.tr(context)} 💪',
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedWorkoutContent(CompletedSession session, UserModel player) {
    final exercisesLog = session.exercisesLog;
    return Column(
      children: [
        // Completed session header card
        Container(
          margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(4.5.w),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 2.w,
                    height: 2.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34C759),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    '${'completed_upper'.tr(context)} ✅',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Text(
                session.routineName,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                '${session.durationMinutes} min · ${session.completedSets}/${session.totalSets} sets',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
        // Exercises with actual weights
        if (exercisesLog != null && exercisesLog.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.5.h),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'exercises_performed_upper'.tr(context),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          ...exercisesLog.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final ex = entry.value as Map<dynamic, dynamic>;
            final name = ex['name'] as String? ??
                'exercise_num'.trP(context, {'n': index});
            final sets = (ex['sets'] as List<dynamic>?) ?? [];

            final doneCount = sets.where((s) => (s as Map)['skipped'] != true).length;
            final totalCount = sets.length;

            final String statusLabel;
            final _EtState headerState;
            if (doneCount == 0) {
              statusLabel = '${'skipped_label'.tr(context)} ✗';
              headerState = _EtState.skip;
            } else if (doneCount == totalCount) {
              statusLabel = '${'done_label'.tr(context)} ✅';
              headerState = _EtState.active;
            } else {
              statusLabel = 'count_of_count_sets'.trP(context, {'done': doneCount, 'total': totalCount});
              headerState = _EtState.active;
            }

            return _buildExerciseTrack(
              index.toString(),
              name,
              'sets_completed_count'.trP(context, {'done': doneCount, 'total': totalCount}),
              statusLabel,
              headerState,
              sets.map((s) {
                final setMap = s as Map<dynamic, dynamic>;
                final kg = setMap['kg']?.toString() ?? '0';
                final reps = setMap['reps']?.toString() ?? '0';
                final skipped = setMap['skipped'] == true;
                return _EtSet(
                  kg.isEmpty || kg == '0' ? '--' : '${kg}kg',
                  '×$reps',
                  skipped ? _EtState.skip : _EtState.active,
                );
              }).toList(),
            );
          }),
        ] else ...[
          Container(
            margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4.w),
            ),
            child: Text(
              'session_logged_no_details'.tr(context),
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingWorkoutContent(
    RoutineModel? routine,
    WorkoutDay? planDay,
    UserModel player,
  ) {
    final routineName = planDay?.assignedRoutineName ?? routine?.routineName ?? 'workout_label'.tr(context);

    return Column(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(4.5.w),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 2.w,
                    height: 2.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8E8E93),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'pending_not_logged'.tr(context),
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Text(
                routineName,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              if (routine != null) ...[
                SizedBox(height: 0.5.h),
                Text(
                  'exercises_planned_count'.trP(context, {'count': routine.exercises.length}),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (routine != null) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.5.h),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'planned_exercises_upper'.tr(context),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          ...routine.exercises.asMap().entries.map((e) {
            final index = e.key + 1;
            final exercise = e.value;
            return _buildExerciseTrack(
              index.toString(),
              exercise.name,
              'target_sets_reps'.trP(context, {'sets': exercise.sets, 'reps': exercise.reps}),
              'pending_label'.tr(context),
              _EtState.wait,
              List.generate(
                exercise.sets,
                (i) => _EtSet(
                  '${exercise.weight > 0 ? "${exercise.weight}kg" : "--"}',
                  '×${exercise.reps}',
                  _EtState.wait,
                ),
              ),
            );
          }),
        ] else ...[
          Container(
            margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4.w),
            ),
            child: Text(
              'workout_scheduled_no_routine'.tr(context),
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLiveSessionCard(
    RoutineModel routine,
    CompletedSession? sessionToday,
  ) {
    final hasSession = sessionToday != null;
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2.w,
                height: 2.w,
                decoration: BoxDecoration(
                  color: hasSession
                      ? const Color(0xFF34C759)
                      : const Color(0xFF8E8E93),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 2.w),
              Text(
                hasSession
                    ? 'completed_today'.tr(context).toUpperCase()
                    : 'offline_pending'.tr(context).toUpperCase(),
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            hasSession ? sessionToday.routineName : routine.routineName,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            '${routine.exercises.length} exercises',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.only(top: 2.h),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                _buildHeroStat(
                  hasSession ? '${sessionToday.completedSets}' : '0',
                  'sets_done_upper'.tr(context),
                ),
                _buildHeroStatDivider(),
                _buildHeroStat(hasSession ? '--' : '0', 'volume_kg_upper'.tr(context)),
                _buildHeroStatDivider(),
                _buildHeroStat(
                  hasSession ? '--' : '0',
                  'avg_hr_upper'.tr(context),
                  valColor: const Color(0xFFFF3B30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatDivider() {
    return Container(
      width: 1,
      height: 3.h,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildExerciseTrack(
    String num,
    String name,
    String target,
    String status,
    _EtState state,
    List<_EtSet> sets,
  ) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(3.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                alignment: Alignment.center,
                child: Text(
                  num,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    Text(
                      target,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: state == _EtState.active
                      ? const Color(0xFF34C759).withOpacity(0.12)
                      : state == _EtState.skip
                          ? const Color(0xFFFF3B30).withOpacity(0.10)
                          : const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: state == _EtState.active
                        ? const Color(0xFF34C759)
                        : state == _EtState.skip
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFF8E8E93),
                  ),
                ),
              ),
            ],
          ),
          if (sets.isNotEmpty) ...[
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: sets.map((s) => _buildSetChip(s)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetChip(_EtSet s) {
    final Color chipColor;
    final Color chipBg;
    final Color borderColor;
    if (s.state == _EtState.active) {
      chipColor = const Color(0xFF34C759);
      chipBg = const Color(0xFFE8FFF0);
      borderColor = const Color(0xFF34C759).withOpacity(0.4);
    } else if (s.state == _EtState.skip) {
      chipColor = const Color(0xFFFF3B30);
      chipBg = const Color(0xFFFFEEED);
      borderColor = const Color(0xFFFF3B30).withOpacity(0.35);
    } else {
      chipColor = const Color(0xFFC7C7CC);
      chipBg = const Color(0xFFF5F5F7);
      borderColor = const Color(0xFFC7C7CC);
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(2.5.w),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            s.state == _EtState.skip ? 'skip_label'.tr(context) : s.w,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: chipColor,
            ),
          ),
          Text(
            s.state == _EtState.skip ? '—' : s.r,
            style: TextStyle(fontSize: 12.sp, color: chipColor),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: NUTRITION
  // =========================================================================
  Widget _buildNutritionTab(
    UserModel player,
    AsyncValue<Map<String, dynamic>?> nutritionAsync,
  ) {
    return nutritionAsync.when(
      data: (nutData) {
        int cP = nutData?['proteinCurrent'] ?? 0;
        int tP = nutData?['proteinTarget'] ?? 0;
        int cC = nutData?['carbsCurrent'] ?? 0;
        int tC = nutData?['carbsTarget'] ?? 0;
        int cF = nutData?['fatCurrent'] ?? 0;
        int tF = nutData?['fatTarget'] ?? 0;
        int cKcal = (cP * 4) + (cC * 4) + (cF * 9);
        int tKcal = nutData?['totalCaloriesTarget'] ?? 0;

        double pPct = tP > 0 ? (cP / tP) * 100 : 0;
        double cPct = tC > 0 ? (cC / tC) * 100 : 0;
        double fPct = tF > 0 ? (cF / tF) * 100 : 0;
        double kcalPct = tKcal > 0 ? (cKcal / tKcal) * 100 : 0;

        return Column(
          children: [
            _buildNutHero(cKcal, tKcal, cP, cC, cF, context),
            _buildCard(
              title: 'plan_vs_eaten'.tr(context),
              icon: '📊',
              iconBg: const Color(0xFFE8FFF0),
              children: [
                _buildProgressBarRow(
                  '🔥',
                  'Calories ($cKcal / $tKcal)',
                  kcalPct.toInt(),
                  const Color(0xFF34C759),
                ),
                _buildProgressBarRow(
                  '🍗',
                  'Protein (${cP}g / ${tP}g)',
                  pPct.toInt(),
                  const Color(0xFF007AFF),
                ),
                _buildProgressBarRow(
                  '🍚',
                  'Carbs (${cC}g / ${tC}g)',
                  cPct.toInt(),
                  const Color(0xFFFF9500),
                ),
                _buildProgressBarRow(
                  '🥑',
                  'Fat (${cF}g / ${tF}g)',
                  fPct.toInt(),
                  const Color(0xFFFF3B30),
                ),
              ],
            ),
            _buildCard(
              title: 'todays_meals'.tr(context),
              icon: '🍽️',
              iconBg: const Color(0xFFFFF8E8),
              children: [
                Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Text(
                    nutData != null
                        ? 'Nutrition data received from player ✅'
                        : 'coach_nutrition_not_available'.tr(context),
                    style: TextStyle(
                      color: const Color(0xFF8E8E93),
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
            ),
            _buildFeedbackForm(
              player,
              'nf-types',
              '🍗 ${'nutrition_feedback_title'.tr(context)}',
              _nutritionFeedbackController,
              _nfTypeSelected,
              (val) => setState(() => _nfTypeSelected = val),
              opts: [
                '🍗 Add protein',
                '🚫 Skip junk',
                '💧 Drink more',
                '🕐 Meal timing',
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('${'error_prefix'.tr(context)}$e')),
    );
  }

  Widget _buildNutHero(int cKcal, int tKcal, int cP, int cC, int cF, BuildContext context) {
    int pct = tKcal > 0 ? ((cKcal / tKcal) * 100).clamp(0, 100).toInt() : 0;
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF2C3E50)],
        ),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY · NUTRITION',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$cKcal',
                    style: TextStyle(
                      fontSize: 34.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    '${'coach_of_kcal_target'.tr(context)} $tKcal ${'coach_kcal'.tr(context)}',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF34C759), width: 4),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'coach_eaten'.tr(context),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.only(top: 1.5.h),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                _buildHeroStat(
                  '${cP}g',
                  'protein_upper'.tr(context),
                  valColor: const Color(0xFF5BA8FF),
                ),
                _buildHeroStatDivider(),
                _buildHeroStat(
                  '${cC}g',
                  'carbs_upper'.tr(context),
                  valColor: const Color(0xFFFFB347),
                ),
                _buildHeroStatDivider(),
                _buildHeroStat(
                  '${cF}g',
                  'fat_upper'.tr(context),
                  valColor: const Color(0xFFFF6B6B),
                ),
                _buildHeroStatDivider(),
                _buildHeroStat(
                  '0L',
                  'water_upper'.tr(context),
                  valColor: const Color(0xFF5BA8FF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 4: PROGRESS
  // =========================================================================
  Widget _buildProgressTab(
    UserModel player,
    AsyncValue<BodyMetrics> metricsAsync,
    AsyncValue<List<CompletedSession>> historyAsync,
  ) {
    return metricsAsync.when(
      data: (metrics) {
        final history = historyAsync.value ?? [];
        return Column(
          children: [
            _buildProgressHero(player, metrics, history),
            _buildCard(
              title: 'body_metrics'.tr(context),
              icon: '⚖️',
              iconBg: const Color(0xFFE8F5FF),
              children: [
                _buildInfoRow(
                  'weight_label'.tr(context),
                  '${metrics.weight} kg',
                  color: const Color(0xFF34C759),
                ),
                _buildInfoRow(
                  'body_fat_label'.tr(context),
                  '${metrics.bodyFat}%',
                  color: const Color(0xFF34C759),
                ),
                _buildInfoRow(
                  'muscle_mass_label'.tr(context),
                  '${metrics.muscleMass} kg',
                  color: const Color(0xFF34C759),
                ),
              ],
            ),
            _buildCard(
              title: 'adherence'.tr(context),
              icon: '💪',
              iconBg: const Color(0xFFE8FFF0),
              children: [
                _buildProgressBarRow(
                  '✅',
                  'total_sessions_completed'.tr(context),
                  100,
                  const Color(0xFF34C759),
                  valText: '${history.length}',
                ),
              ],
            ),
            _buildCard(
              title: 'coach_notes'.tr(context),
              icon: '📝',
              iconBg: const Color(0xFFF0EEFF),
              children: [
                Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Text(
                    'coach_keep_pushing_forward'.tr(context),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF3A3A3C),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('${'error_prefix'.tr(context)}$e')),
    );
  }

  Widget _buildProgressHero(
    UserModel player,
    BodyMetrics metrics,
    List<CompletedSession> history,
  ) {
    final weightDiff = metrics.weight - metrics.initialWeight;
    final isLoss = weightDiff <= 0;

    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34C759), Color(0xFF28A447)],
        ),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'coach_progress_overview'.tr(context),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            _displayName(player),
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              _buildHeroStat(
                '${isLoss ? weightDiff.toStringAsFixed(1) : "+${weightDiff.toStringAsFixed(1)}"} kg',
                'weight_change_upper'.tr(context),
              ),
              _buildHeroStat('${metrics.bodyFat}%', 'body_fat_upper'.tr(context)),
              _buildHeroStat('${metrics.muscleMass} kg', 'muscle_mass_upper'.tr(context)),
              _buildHeroStat('${history.length}', 'sessions_upper'.tr(context)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportProgressReport(
    BuildContext context,
    UserModel player,
    BodyMetrics metrics,
    List<CompletedSession> history,
  ) async {
    _showToast('generating_pdf'.tr(context));
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context pdfContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'NEXUS - ${'player_progress_report'.tr(context)}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                '${'coach_player'.tr(context)}: ${_displayName(player)}',
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.Text(
                '${'date'.tr(context)}: ${AppIntl.date(context, DateTime.now())}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'body_metrics'.tr(context),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              pw.Text(
                '${'weight'.tr(context)}: ${metrics.weight > 0 ? metrics.weight : "N/A"} ${'kg'.tr(context)}',
              ),
              pw.Text(
                '${'initial_weight'.tr(context)}: ${metrics.initialWeight > 0 ? metrics.initialWeight : "N/A"} ${'kg'.tr(context)}',
              ),
              pw.Text(
                '${'body_fat'.tr(context)}: ${metrics.bodyFat > 0 ? metrics.bodyFat : "N/A"} %',
              ),
              pw.Text(
                '${'muscle_mass'.tr(context)}: ${metrics.muscleMass > 0 ? metrics.muscleMass : "N/A"} ${'kg'.tr(context)}',
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'training_data'.tr(context),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              pw.Text(
                '${'total_sessions_completed'.tr(context)}: ${history.length}',
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${_displayName(player).replaceAll(" ", "_")}_progress.pdf',
    );
  }

  // =========================================================================
  // SHARED UI
  // =========================================================================

  Widget _buildFeedbackForm(
    UserModel player,
    String id,
    String title,
    TextEditingController controller,
    String selected,
    Function(String) onSelect, {
    List<String>? opts,
  }) {
    final options =
        opts ??
        [
          '💬 General',
          '✅ Plan',
          '🍗 Nutrition',
          '🏆 Motivation',
          '⚠️ Warning',
        ];
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: options.map((opt) {
              final sel = selected == opt;
              return GestureDetector(
                onTap: () => onSelect(opt),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 0.8.h,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(4.w),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFE5E5EA),
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 1.5.h),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'write_feedback_to'.trP(context, {'name': _displayName(player)}),
              hintStyle: TextStyle(
                color: const Color(0xFFC7C7CC),
                fontSize: 14.sp,
              ),
              filled: true,
              fillColor: const Color(0xFFF9F9FB),
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
          SizedBox(height: 1.5.h),
          GestureDetector(
            onTap: () {
              if (controller.text.isEmpty) {
                _showToast('please_write_message_first'.tr(context));
                return;
              }
              _showToast('${'feedback_sent_to'.trP(context, {'name': _displayName(player)})} ✓ 📲');
              controller.clear();
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(3.w),
              ),
              alignment: Alignment.center,
              child: Text(
                'coach_send_feedback'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String icon,
    Color? iconBg,
    String? actionText,
    VoidCallback? onAction,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (iconBg != null)
                      Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(2.w),
                        ),
                        alignment: Alignment.center,
                        child: Text(icon, style: TextStyle(fontSize: 18.sp)),
                      ),
                    if (iconBg != null) SizedBox(width: 2.w),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ],
                ),
                if (actionText != null && onAction != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionText,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String key, String value, {Color? color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF5F5F7), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            key,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6E6E73),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: color ?? const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBarRow(
    String icon,
    String title,
    int percentage,
    Color color, {
    String? valText,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF5F5F7), width: 0.5)),
      ),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Container(
                  height: 0.8.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(1.h),
                  ),
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(1.h),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 3.w),
          SizedBox(
            width: 10.w,
            child: Text(
              valText ?? '$percentage%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _displayName(UserModel? player) {
    if (player == null) return 'player_label'.tr(context);
    final name = [
      player.firstName,
      player.lastName,
    ].where((p) => p != null && p.trim().isNotEmpty).join(' ');
    return name.isEmpty ? 'player_label'.tr(context) : name;
  }
}

enum _EtState { active, wait, skip }

class _EtSet {
  final String w;
  final String r;
  final _EtState state;

  _EtSet(this.w, this.r, this.state);
}
