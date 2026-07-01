import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/src/features/payment/commission_payment_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../nutrition/data/daily_meal_tracking_repository.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/intl_formatter.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../coaching/presentation/screens/human_coach_chat_screen.dart';
import '../../../smart_workout/providers/split_setup_provider.dart';
import '../../../smart_workout/providers/coach_plan_provider.dart';
import 'coach_workout_builder_screen.dart';
import 'coach_set_nutrition_screen.dart';
import 'coach_player_nutrition_detail_screen.dart';
import '../../../user/models/user_model.dart';
import '../../../admin/data/admin_repository.dart' hide PaymentRecord;
import '../../data/coach_repository.dart';
import '../../models/payment_record.dart';
import '../../providers/coach_monitoring_provider.dart';

class CoachPlayerDetailScreen extends ConsumerStatefulWidget {
  final UserModel? player;
  final String? playerName;

  const CoachPlayerDetailScreen({super.key, this.player, this.playerName});

  @override
  ConsumerState<CoachPlayerDetailScreen> createState() =>
      _CoachPlayerDetailScreenState();
}

class _CoachPlayerDetailScreenState
    extends ConsumerState<CoachPlayerDetailScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final player = _currentPlayer();
    if (player == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopbar(player),
            Expanded(
              child: SingleChildScrollView(child: _buildCurrentTab(player)),
            ),
          ],
        ),
      ),
    );
  }

  UserModel? _currentPlayer() {
    if (widget.player != null) return widget.player;
    final players = ref.watch(coachMembersProvider).asData?.value ?? [];
    try {
      return players.firstWhere(
        (p) => '${p.firstName} ${p.lastName}'.trim() == widget.playerName,
      );
    } catch (e) {
      return null;
    }
  }

  String _displayName(UserModel player) {
    return '${player.firstName ?? ''} ${player.lastName ?? ''}'.trim();
  }

  String _formatDob(DateTime? date) {
    if (date == null) return 'unknown'.tr(context);
    return AppIntl.shortDateYear(context, date);
  }

  String _formatLastLogin(DateTime? date) {
    if (date == null) return 'never'.tr(context);
    return AppIntl.fullDateTime(context, date);
  }

  Widget _buildTopbar(UserModel player) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(Icons.arrow_back_ios_new_rounded, () => context.pop()),
          Expanded(
            child: Column(
              children: [
                Text(
                  _tabTitle(),
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C1C1E),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 11.w),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 11.w,
        height: 11.w,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 19.sp, color: const Color(0xFF1C1C1E)),
      ),
    );
  }

  String _tabTitle() {
    switch (_currentTab) {
      case 0:
        return 'player_profile_tab'.tr(context);
      case 1:
        return 'training_plan_tab'.tr(context);
      case 2:
        return 'body_vitals_tab'.tr(context);
      case 3:
        return 'activity_history_tab'.tr(context);
      case 4:
        return 'finance_tab'.tr(context);
      default:
        return 'player_tab_fallback'.tr(context);
    }
  }

  Widget _buildCurrentTab(UserModel player) {
    switch (_currentTab) {
      case 0:
        return _buildOverviewTab(player);
      case 1:
        return _buildTrainingTab(player, context);
      case 2:
        return _buildBodyTab(player, context);
      case 3:
        return _buildHistoryTab(player, context);
      case 4:
        return _buildFinanceTab(player, context);
      default:
        return const SizedBox();
    }
  }

  Widget _buildOverviewTab(UserModel player) {
    return Column(
      children: [
        _buildHeroSection(player),
        _buildQuickActions(player),
        _buildNutritionComplianceCard(player),
        _buildPersonalInfoCard(player, context),
        _buildAccountInfoCard(player, context),
        SizedBox(height: 4.h),
      ],
    );
  }

  Widget _buildNutritionComplianceCard(UserModel player) {
    final trackingAsync =
        ref.watch(last7DaysTrackingProvider(player.uid));

    return trackingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (days) {
        // Only show if player has any tracking data
        final hasDays = days.any((d) => d.totalCount > 0);
        if (!hasDays) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.w),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('🍽️', style: TextStyle(fontSize: 16.sp)),
                  SizedBox(width: 2.w),
                  Text(
                    'nutrition_compliance_label'.tr(context),
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E)),
                  ),
                  const Spacer(),
                  Text(
                    'last_7_days_label'.tr(context),
                    style: TextStyle(
                        fontSize: 13.sp, color: const Color(0xFF8E8E93)),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: days.reversed.map((d) {
                  final label = _shortDayLabel(d.date);
                  final rate = d.complianceRate;
                  final color = rate == 0
                      ? const Color(0xFFE5E5EA)
                      : rate < 0.5
                          ? const Color(0xFFFF9500)
                          : const Color(0xFF34C759);

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 0.5.w),
                      child: Column(
                        children: [
                          Container(
                            height: 7.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            alignment: Alignment.bottomCenter,
                            clipBehavior: Clip.hardEdge,
                            child: FractionallySizedBox(
                              heightFactor: d.totalCount == 0 ? 0.05 : rate.clamp(0.05, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2.w),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            label,
                            style: TextStyle(
                                fontSize: 11.sp,
                                color: const Color(0xFF8E8E93),
                                fontWeight: FontWeight.w600),
                          ),
                          if (d.totalCount > 0) ...[
                            Text(
                              '${d.completedCount}/${d.totalCount}',
                              style: TextStyle(
                                  fontSize: 10.sp,
                                  color: color,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  String _shortDayLabel(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final d = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final now = DateTime.now();
      if (d.day == now.day && d.month == now.month) return 'today'.tr(context);
      return DateFormat('EEE').format(d); // Mon, Tue...
    } catch (_) {
      return '';
    }
  }

  Widget _buildHeroSection(UserModel player) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF242A32),
        borderRadius: BorderRadius.circular(6.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 18.w,
                height: 18.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF333942),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('💪', style: TextStyle(fontSize: 28.sp)),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(player),
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      'id_member_since'.trP(context, {
                        'id': player.uid.substring(0, 4).toUpperCase(),
                        'date': DateFormat('d MMM yyyy').format(player.subscriptionStart ?? player.createdAt),
                      }),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 1.h,
                      children: [
                        _buildHeroBadge(
                          'gamma_membership_plan'.tr(context),
                          const Color(0xFF1B406B),
                          Colors.blue[300]!,
                        ),
                        _buildHeroBadge(
                          player.isSubscriptionExpired
                              ? '🔴 ${'expired_label'.tr(context)}'
                              : (player.isActive ? '🟢 ${'active_label'.tr(context)}' : '🔴 ${'inactive_label'.tr(context)}'),
                          player.isSubscriptionExpired || !player.isActive
                              ? const Color(0xFF4A1A1A)
                              : const Color(0xFF1A4731),
                          player.isSubscriptionExpired || !player.isActive
                              ? Colors.redAccent
                              : Colors.greenAccent,
                        ),
                        _buildHeroBadge(
                          '${player.currentStreak}🔥 ${'streak_label'.tr(context)}',
                          const Color(0xFF3A3B3C),
                          Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.5.h),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          SizedBox(height: 2.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHeroStat('${player.totalSessionsCompleted}', 'sessions_upper'.tr(context)),
              _buildHeroVerticalDivider(),
              _buildHeroStat('${player.adherenceScore.toInt()}%', 'adherence_upper'.tr(context)),
              _buildHeroVerticalDivider(),
              _buildHeroStat(
                '${player.weightProgress > 0 ? '+' : ''}${player.weightProgress} kg',
                'progress_upper'.tr(context),
              ),
              _buildHeroVerticalDivider(),
              _buildHeroStat(
                '${player.subscriptionEnd != null ? (player.subscriptionEnd!.difference(DateTime.now()).inDays > 0 ? player.subscriptionEnd!.difference(DateTime.now()).inDays : 0) : 0}d',
                'remaining_upper'.tr(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(2.w),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildHeroStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroVerticalDivider() {
    return Container(
      height: 4.h,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildQuickActions(UserModel player) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 3.h),
      child: Row(
        children: [
          _buildQaItem('💬', 'message_label'.tr(context), () {
            final coachUid = ref.read(currentUserModelProvider).value?.uid;
            if (coachUid != null && widget.player != null) {
              final name = [
                widget.player!.firstName,
                widget.player!.lastName,
              ].where((p) => p != null).join(' ');
              final displayName = name.trim().isEmpty
                  ? widget.player!.email
                  : name.trim();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HumanCoachChatScreen(
                    chatId: '${widget.player!.uid.trim()}_${coachUid.trim()}',
                    participantName: displayName,
                    isCoachView: true,
                  ),
                ),
              );
            }
          }),
          SizedBox(width: 2.w),
          _buildQaItem('🏋️', 'training_label'.tr(context), () => setState(() => _currentTab = 1)),
          SizedBox(width: 2.w),
          _buildQaItem('💰', 'payment_label'.tr(context), () => setState(() => _currentTab = 4)),
          SizedBox(width: 2.w),
          _buildQaItem('📅', 'renew_label'.tr(context), () => _showRenewSheet(player)),
          SizedBox(width: 2.w),
          _buildQaItem('✏️', 'edit_sub_label'.tr(context), () => _showEditSubSheet(player)),
          SizedBox(width: 2.w),
          _buildQaItem('📋', 'monitor_label'.tr(context), () => context.push('/coach_monitoring', extra: player)),
          SizedBox(width: 2.w),
          _buildQaItem('🍽️', 'nutrition_label'.tr(context), () {
            if (widget.player != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CoachPlayerNutritionDetailScreen(player: widget.player!),
                ),
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildQaItem(String emoji, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 17.w,
        padding: EdgeInsets.symmetric(vertical: 1.5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: 24.sp)),
            SizedBox(height: 1.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAiTrackingSheet(UserModel player, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            5.w,
            4.h,
            5.w,
            MediaQuery.of(ctx).viewInsets.bottom + 6.h,
          ),
          height: 75.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'coach_ai_nutrition_tracking'.tr(context),
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 0.8.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5FF),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Text(
                      'today'.tr(context),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Text(
                'monitor_name_macro_adherence'.trP(context, {'name': _displayName(player)}),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF8E8E93),
                ),
              ),
              SizedBox(height: 4.h),
              _buildMacroProgress('protein_title'.tr(context), 150, 200, Colors.blue),
              SizedBox(height: 2.h),
              _buildMacroProgress('carbs_title'.tr(context), 200, 250, Colors.orange),
              SizedBox(height: 2.h),
              _buildMacroProgress('fat_title'.tr(context), 50, 70, Colors.red),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: const Color(0xFF007AFF),
                      size: 24.sp,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'coach_ai_analysis_macro_warning'.tr(context),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF1C1C1E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 6.5.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'close'.tr(context),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroProgress(
    String label,
    int current,
    int target,
    Color color,
  ) {
    double progress = current / target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
            Text(
              '$current / $target g',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(2.w),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 1.5.h,
            backgroundColor: const Color(0xFFE5E5EA),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showRenewSheet(UserModel player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RenewSubscriptionSheet(player: player),
    );
  }

  void _showEditSubSheet(UserModel player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RenewSubscriptionSheet(player: player, isEditMode: true),
    );
  }

  Widget _buildPersonalInfoCard(UserModel player, BuildContext context) {
    return _buildCard(
      title: 'personal_info'.tr(context),
      icon: '👤',
      iconBg: const Color(0xFFE6F2FF),
      iconColor: const Color(0xFF007AFF),
      children: [
        _buildInfoRow('full_name'.tr(context), _displayName(player)),
        _buildDivider(),
        _buildInfoRow(
          'date_of_birth'.tr(context),
          _formatAgeAndDob(player.dateOfBirth, context),
        ),
        _buildDivider(),
        _buildInfoRow('gender'.tr(context), player.gender ?? 'male'),
        _buildDivider(),
        _buildInfoRow(
          'phone'.tr(context),
          player.phone ?? '0780805230',
          valueColor: const Color(0xFF007AFF),
        ),
        _buildDivider(),
        _buildInfoRow(
          'email'.tr(context),
          player.email,
          valueColor: const Color(0xFF007AFF),
        ),
        _buildDivider(),
        _buildInfoRow(
          'gym'.tr(context),
          '${player.gymId ?? 'Iron Peak Gym'} 📍',
        ),
        _buildDivider(),
        _buildInfoRow(
          'coach'.tr(context),
          player.assignedCoachName ?? 'qutaiba',
        ),
        _buildDivider(),
        _buildInfoRow(
          'training_mode'.tr(context),
          '${player.trainingMode ?? 'gym_only'} 🏋️',
        ),
      ],
    );
  }

  String _formatAgeAndDob(DateTime? date, BuildContext context) {
    if (date == null) return 'Dec 31, 2006 (20 ${'years_short'.tr(context)})';
    int age = DateTime.now().year - date.year;
    return '${DateFormat('MMM d, yyyy').format(date)} ($age ${'years_short'.tr(context)})';
  }

  Widget _buildAccountInfoCard(UserModel player, BuildContext context) {
    return _buildCard(
      title: 'account'.tr(context),
      icon: '🔐',
      iconBg: const Color(0xFFF3E8FF),
      iconColor: Colors.purple,
      children: [
        _buildInfoRow(
          'username'.tr(context),
          '@${player.firstName ?? 'غالب'}',
          valueColor: const Color(0xFF007AFF),
        ),
        _buildDivider(),
        _buildInfoRow('login_email'.tr(context), player.email),
        _buildDivider(),
        _buildInfoRow('password'.tr(context), '........'),
        _buildDivider(),
        _buildInfoRow(
          'account_status'.tr(context),
          player.isSubscriptionExpired
              ? 'coach_expired'.tr(context)
              : (player.isActive
                    ? 'active'.tr(context)
                    : 'suspended'.tr(context)),
          valueColor: player.isSubscriptionExpired || !player.isActive
              ? Colors.red
              : Colors.green,
        ),
        _buildDivider(),
        _buildInfoRow(
          'last_login'.tr(context),
          _formatLastLogin(player.lastLogin),
        ),
        _buildDivider(),
        _buildInfoRow(
          'device'.tr(context),
          (player.deviceInfo == null || player.deviceInfo!.isEmpty)
              ? '—'
              : player.deviceInfo!,
        ),
        _buildDivider(),
        _buildInfoRow(
          'app_version'.tr(context),
          (player.appVersion == null || player.appVersion!.isEmpty)
              ? '—'
              : 'NEXUS v${player.appVersion}',
        ),
        _buildDivider(),
        _buildResetPasswordRow(context),
      ],
    );
  }

  Widget _buildResetPasswordRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('🔑', style: TextStyle(fontSize: 16.sp)),
              SizedBox(width: 2.w),
              Text(
                'coach_reset_password'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            'coach_send_email'.tr(context),
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF007AFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Color(0xFFF2F2F7), height: 1, thickness: 1);
  }

  Widget _buildTrainingTab(UserModel player, BuildContext context) {
    return _CoachPlanTab(player: player);
  }

  Widget _buildBodyTab(UserModel player, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Center(
        child: Text(
          'coach_body_vitals_area'.tr(context),
          style: TextStyle(fontSize: 16.sp, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(UserModel player, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Center(
        child: Text(
          'coach_activity_history_area'.tr(context),
          style: TextStyle(fontSize: 16.sp, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildFinanceTab(UserModel player, BuildContext context) {
    final isExpired =
        player.subscriptionEnd != null &&
        player.subscriptionEnd!.isBefore(DateTime.now());

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2.h),
          _buildSubscriptionCard(player, isExpired, context),
          if (isExpired) _buildRenewalAlert(player, context),
          SizedBox(height: 3.h),
          _buildFinancialSummary(player),
          SizedBox(height: 3.h),
          Text(
            'coach_payment_history'.tr(context),
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 2.h),
          _buildPaymentHistoryList(player, context),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    UserModel player,
    bool isExpired,
    BuildContext context,
  ) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired
              ? [Colors.redAccent, Colors.red]
              : [const Color(0xFF007AFF), const Color(0xFF0056B3)],
        ),
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'coach_current_subscription'.tr(context),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13.sp,
                ),
              ),
              Icon(
                isExpired ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text(
            player.subscriptionPlan ?? 'coach_custom_plan'.tr(context),
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'coach_expires_on'.tr(context),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.sp,
                    ),
                  ),
                  Text(
                    player.subscriptionEnd != null
                        ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(player.subscriptionEnd!)
                        : 'never_label'.tr(context),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'coach_status'.tr(context),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.sp,
                    ),
                  ),
                  Text(
                    isExpired ? 'expired_label'.tr(context) : 'active_label'.tr(context),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRenewalAlert(UserModel player, BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.red, size: 22.sp),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              'coach_subscription_expired_suspended'.tr(context),
              style: TextStyle(
                color: Colors.red[800],
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(UserModel player) {
    // Always compute from real payment records — stored field may be stale
    final paymentsAsync = ref.watch(coachPaymentsProvider(player.uid));
    final payments = paymentsAsync.asData?.value ?? [];

    final totalPaid = payments.isEmpty
        ? (player.amountPaid ?? 0.0)
        : payments.fold(0.0, (sum, p) => sum + p.amount);
    final totalAmount = (player.totalAmount ?? 0.0) > 0
        ? player.totalAmount!
        : totalPaid;
    final remaining = (totalAmount - totalPaid).clamp(0.0, double.infinity);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryBox(
                'total_amount_label'.tr(context),
                '${totalAmount.toStringAsFixed(0)} JD',
                const Color(0xFF1C1C1E),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildSummaryBox(
                'total_paid_label'.tr(context),
                '${totalPaid.toStringAsFixed(0)} JD',
                Colors.green,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildSummaryBox(
                'remaining_label'.tr(context),
                '${remaining.toStringAsFixed(0)} JD',
                remaining > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        if (payments.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(2.w),
            ),
            child: Text(
              'records_total_paid'.trP(context, {
                'count': payments.length,
                'total': totalPaid.toStringAsFixed(0),
              }),
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryBox(String label, String amount, Color color) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryList(UserModel player, BuildContext context) {
    final paymentsAsync = ref.watch(coachPaymentsProvider(player.uid));
    return paymentsAsync.when(
      data: (payments) {
        final visiblePayments = payments.isEmpty
            ? _fallbackPaymentRecords(player, context)
            : payments;
        if (visiblePayments.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Text(
                'coach_no_payment_history'.tr(context),
                style: TextStyle(color: Colors.grey, fontSize: 14.sp),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visiblePayments.length,
          itemBuilder: (context, index) {
            return _buildPaymentRecordCard(visiblePayments[index], player);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('${'error_prefix'.tr(context)} $e')),
    );
  }

  List<PaymentRecord> _fallbackPaymentRecords(
    UserModel player,
    BuildContext context,
  ) {
    if (!player.isActive) return const [];

    final total = player.totalAmount ?? 0.0;
    final paid = player.amountPaid ?? 0.0;
    final remaining = player.amountRemaining ?? 0.0;

    final start = player.subscriptionStart ?? player.createdAt;
    final end = player.subscriptionEnd ?? start;
    return [
      PaymentRecord(
        id: 'current-finance',
        planName: player.subscriptionPlan ?? 'coach_custom_plan'.tr(context),
        amount: paid,
        totalAmount: total,
        discountAmount: player.discountAmount ?? 0.0,
        amountRemaining: remaining,
        paymentMethod: player.paymentMethod ?? 'pending_label'.tr(context),
        paymentDate: start,
        durationDays: end.difference(start).inDays,
        type: 'current_balance',
      ),
    ];
  }

  Future<void> _deletePaymentRecord(UserModel player, PaymentRecord p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('delete_record'.tr(context), style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        content: Text('delete_record_confirm_full'.tr(context),
            style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr(context), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('delete_label'.tr(context), style: const TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(coachRepositoryProvider).deletePaymentRecord(player.uid, p.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_with_detail'.trP(context, {'e': e})), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildPaymentRecordCard(PaymentRecord p, UserModel player) {
    final isFallback = p.type == 'current_balance';

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  p.planName,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                isFallback
                    ? '-${p.amountRemaining.toStringAsFixed(0)} JD'
                    : '+${p.amount.toStringAsFixed(0)} JD',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.bold,
                  color: isFallback ? Colors.red : Colors.green,
                ),
              ),
              if (!isFallback) ...[
                SizedBox(width: 2.w),
                GestureDetector(
                  onTap: () => _deletePaymentRecord(player, p),
                  child: Icon(Icons.delete_outline_rounded,
                      color: Colors.red.shade300, size: 18.sp),
                ),
              ],
            ],
          ),
          SizedBox(height: 0.6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(p.paymentDate),
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
              Text(
                p.paymentMethod,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ],
          ),
          if (isFallback || p.totalAmount > 0 || p.amountRemaining > 0) ...[
            SizedBox(height: 1.2.h),
            Container(height: 1, color: const Color(0xFFF0F0F5)),
            SizedBox(height: 1.2.h),
            Row(
              children: [
                Expanded(
                  child: _buildMiniFinanceValue(
                    'total_label'.tr(context),
                    p.totalAmount,
                    const Color(0xFF1C1C1E),
                  ),
                ),
                Expanded(
                  child: _buildMiniFinanceValue('paid_label'.tr(context), p.amount, Colors.green),
                ),
                Expanded(
                  child: _buildMiniFinanceValue(
                    'remaining_label'.tr(context),
                    p.amountRemaining,
                    isFallback ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniFinanceValue(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
        ),
        SizedBox(height: 0.3.h),
        Text(
          '${value.toStringAsFixed(0)} JD',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String icon,
    required Color iconBg,
    required Color iconColor,
    String? actionText,
    VoidCallback? onAction,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.5.w),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Text(icon, style: TextStyle(fontSize: 18.sp)),
              ),
              SizedBox(width: 3.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const Spacer(),
              if (actionText != null && onAction != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionText,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFF8E8E93),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class RenewSubscriptionSheet extends ConsumerStatefulWidget {
  final UserModel player;
  /// true  → Edit mode: pre-fills current start/end, uses editSubscription()
  /// false → Renew mode: starts after current end, uses renewSubscription()
  final bool isEditMode;
  const RenewSubscriptionSheet({
    super.key,
    required this.player,
    this.isEditMode = false,
  });

  @override
  ConsumerState<RenewSubscriptionSheet> createState() =>
      _RenewSubscriptionSheetState();
}

class _RenewSubscriptionSheetState
    extends ConsumerState<RenewSubscriptionSheet> {
  late DateTime _startDate;
  late DateTime _endDate;

  // Plan chips state
  Map<String, dynamic>? _selectedPlan;
  bool _useCustomPlan = true; // default to custom so dates stay editable
  String _planName = '';

  String _paymentMethod = 'cash';
  double _totalAmount = 0.0;
  double _amount = 0.0;
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.player;

    if (widget.isEditMode) {
      // Edit mode: show the CURRENT subscription period
      _startDate = p.subscriptionStart ?? DateTime.now();
      _endDate   = p.subscriptionEnd   ?? DateTime(_startDate.year, _startDate.month + 1, _startDate.day);
    } else {
      // Renew mode: start a NEW period from when current one ends
      _startDate = (p.subscriptionEnd != null && p.subscriptionEnd!.isAfter(DateTime.now()))
          ? p.subscriptionEnd!
          : DateTime.now();
      _endDate = DateTime(_startDate.year, _startDate.month + 1, _startDate.day);
    }

    // Pre-fill amounts from player data
    _totalAmount = p.totalAmount ?? 0.0;
    _amount      = p.amountPaid  ?? 0.0;
    if (_totalAmount > 0) _totalController.text = _totalAmount.toStringAsFixed(0);
    if (_amount > 0)      _amountController.text = _amount.toStringAsFixed(0);
    // Pre-fill plan name
    _planName = p.subscriptionPlan ?? '';
    // Pre-fill payment method
    const validMethods = ['cash', 'visa', 'bank_transfer', 'wallet', 'cliq'];
    _paymentMethod = validMethods.contains(p.paymentMethod) ? p.paymentMethod! : 'cash';
  }

  @override
  void dispose() {
    _totalController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double get _remainingAmount =>
      (_totalAmount - _amount).clamp(0.0, double.infinity);

  void _recalcEnd() {
    if (_selectedPlan != null && !_useCustomPlan) {
      final days = _selectedPlan!['durationDays'] as int? ?? 30;
      setState(() => _endDate = _startDate.add(Duration(days: days)));
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() { _startDate = picked; _recalcEnd(); });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Widget _buildPlanChips() {
    final gymId      = widget.player.gymId ?? '';
    final plansAsync = ref.watch(subscriptionPlansProvider(gymId));
    final plans      = plansAsync.asData?.value ?? [];

    if (gymId.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('the_plan_label'.tr(context),
            style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E))),
        SizedBox(height: 1.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: [
            ...plans.map((plan) {
              final isSelected = !_useCustomPlan &&
                  _selectedPlan != null &&
                  _selectedPlan!['id'] == plan['id'];
              final name  = plan['name']  as String? ?? '';
              final days  = plan['durationDays'] as int? ?? 30;
              final price = (plan['price'] as num?)?.toDouble() ?? 0.0;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedPlan  = plan;
                  _useCustomPlan = false;
                  _planName      = name;
                  _totalAmount   = price;
                  _totalController.text = price.toStringAsFixed(0);
                  _endDate = _startDate.add(Duration(days: days));
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF007AFF)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : const Color(0xFFD1D1D6),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700)),
                      Text('$days ${'day_unit'.tr(context)} · ${price.toStringAsFixed(0)} JD',
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white70
                                  : Colors.grey,
                              fontSize: 9.sp)),
                    ],
                  ),
                ),
              );
            }),
            // Custom chip
            GestureDetector(
              onTap: () => setState(() {
                _useCustomPlan = true;
                _selectedPlan  = null;
                _planName      = '';
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: _useCustomPlan
                      ? const Color(0xFFE5E5EA)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _useCustomPlan
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFFD1D1D6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded,
                        color: _useCustomPlan
                            ? const Color(0xFF1C1C1E)
                            : Colors.grey,
                        size: 12.sp),
                    SizedBox(width: 1.w),
                    Text('custom_label'.tr(context),
                        style: TextStyle(
                            color: _useCustomPlan
                                ? const Color(0xFF1C1C1E)
                                : Colors.grey,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (plansAsync.isLoading) ...[
          SizedBox(height: 1.h),
          const Center(
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Color(0xFF007AFF), strokeWidth: 2),
            ),
          ),
        ],
        SizedBox(height: 2.h),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: EdgeInsets.fromLTRB(
          6.w,
          2.w,
          6.w,
          MediaQuery.of(context).viewInsets.bottom + 14.w,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 12.w,
                height: 5,
                margin: EdgeInsets.only(bottom: 2.h),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.isEditMode
                                ? 'edit_subscription'.tr(context)
                                : 'coach_renew_subscription'.tr(context),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.close, color: Color(0xFF1C1C1E)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        '${widget.player.firstName ?? ''}',
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700]),
                      ),
                      SizedBox(height: 2.h),

                      // ── Plan chips ──────────────────────────────────────
                      _buildPlanChips(),

                      // ── Start Date ──────────────────────────────────────
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'coach_start_date'.tr(context),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy').format(_startDate),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFF007AFF),
                          ),
                        ),
                        trailing: const Icon(Icons.calendar_today,
                            color: Color(0xFF007AFF)),
                        onTap: _pickStartDate,
                      ),
                      Divider(color: Colors.grey[200]),

                      // ── End Date (auto when plan selected; manual when custom) ──
                      if (_useCustomPlan || _selectedPlan == null) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'coach_end_date'.tr(context),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('MMM dd, yyyy').format(_endDate),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                          trailing: const Icon(Icons.edit_calendar,
                              color: Color(0xFF007AFF)),
                          onTap: _pickEndDate,
                        ),
                        Divider(color: Colors.grey[200]),
                      ] else ...[
                        // Auto-calculated end date pill (read-only)
                        Container(
                          margin: EdgeInsets.only(bottom: 1.5.h),
                          padding: EdgeInsets.symmetric(
                              horizontal: 4.w, vertical: 1.2.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(3.w),
                            border: Border.all(
                                color:
                                    const Color(0xFF34C759).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_available_rounded,
                                  color: Color(0xFF34C759), size: 20),
                              SizedBox(width: 3.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('expiry_date_label'.tr(context),
                                      style: TextStyle(
                                          fontSize: 10.sp,
                                          color: Colors.grey[500])),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(_endDate),
                                    style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF34C759)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Payment Method ──────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'coach_payment_method'.tr(context),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          DropdownButton<String>(
                            value: _paymentMethod,
                            dropdownColor: Colors.white,
                            items: ['cash', 'visa', 'bank_transfer', 'wallet']
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        'coach_$m'.tr(context),
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _paymentMethod = v);
                            },
                          ),
                        ],
                      ),
                      Divider(color: Colors.grey[200]),

                      SizedBox(height: 2.h),

                      // ── Total Amount ────────────────────────────────────
                      TextField(
                        controller: _totalController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFF1C1C1E)),
                        decoration: InputDecoration(
                          labelText: 'coach_total_amount'.tr(context),
                          labelStyle:
                              const TextStyle(color: Color(0xFF8E8E93)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3.w),
                            borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3.w),
                            borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3.w),
                            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF8E8E93)),
                        ),
                        onChanged: (v) {
                          setState(() => _totalAmount = double.tryParse(v) ?? 0.0);
                        },
                      ),

                      SizedBox(height: 1.5.h),

                      // ── Amount Paid ─────────────────────────────────────
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFF1C1C1E)),
                        decoration: InputDecoration(
                          labelText: 'coach_amount_paid_usd'.tr(context),
                          labelStyle:
                              const TextStyle(color: Color(0xFF8E8E93)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3.w),
                            borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3.w),
                            borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3.w),
                            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF8E8E93)),
                        ),
                        onChanged: (v) {
                          setState(() => _amount = double.tryParse(v) ?? 0.0);
                        },
                      ),

                      SizedBox(height: 1.5.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(3.w),
                          border: Border.all(color: const Color(0xFFE5E5EA)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'coach_remaining'.tr(context),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF3A3A3C),
                              ),
                            ),
                            Text(
                              '${_remainingAmount.toStringAsFixed(0)} JD',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w900,
                                color: _remainingAmount > 0
                                    ? Colors.orange
                                    : const Color(0xFF34C759),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 4.h),
                      SizedBox(
                        width: double.infinity,
                        height: 6.5.h,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3.w),
                            ),
                          ),
                          onPressed: () async {
                            if (_totalAmount <= 0 ||
                                _amount < 0 ||
                                _amount > _totalAmount) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'coach_please_fill_required'
                                          .tr(context)),
                                ),
                              );
                              return;
                            }
                            // Derive plan name
                            final planName = _useCustomPlan || _selectedPlan == null
                                ? (_planName.isNotEmpty
                                    ? _planName
                                    : '${_endDate.difference(_startDate).inDays} يوم')
                                : (_selectedPlan!['name'] as String? ?? '');

                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            final coachRepo = ref.read(coachRepositoryProvider);
                            final gymId = widget.player.gymId ?? '';
                            final coachUid = ref.read(currentUserModelProvider).asData?.value?.uid ?? '';

                            final playerName = [
                                widget.player.firstName,
                                widget.player.lastName,
                              ].where((s) => s != null && s.isNotEmpty).join(' ');

                            // ── Commission payment ────────────────────────
                            final months = (_endDate.difference(_startDate).inDays / 30).round().clamp(1, 120);
                            final monthlyPrice = months > 0 ? _totalAmount / months : _totalAmount;
                            if (!context.mounted) return;
                            final commissionPaid = await showCommissionPaymentDialog(
                              context: context,
                              monthlyPrice: monthlyPrice,
                              months: months,
                              gymId: gymId,
                              playerName: playerName,
                              operationType: widget.isEditMode ? 'edit_subscription' : 'renew_subscription',
                            );
                            if (!commissionPaid) return;
                            // ─────────────────────────────────────────────

                            if (widget.isEditMode) {
                              // Edit mode: SET-based update, only records payment if new money paid
                              await coachRepo.editSubscription(
                                uid: widget.player.uid,
                                startDate: _startDate,
                                endDate: _endDate,
                                totalAmount: _totalAmount,
                                amountPaid: _amount,
                                planName: planName,
                                paymentMethod: _paymentMethod,
                                gymId: gymId,
                                coachUid: coachUid,
                                playerName: playerName,
                              );
                            } else {
                              // Renew mode: SET-based, always records payment
                              await coachRepo.renewSubscription(
                                uid: widget.player.uid,
                                startDate: _startDate,
                                endDate: _endDate,
                                totalAmount: _totalAmount,
                                amountPaid: _amount,
                                amountRemaining: _remainingAmount,
                                planName: planName,
                                paymentMethod: _paymentMethod,
                                gymId: gymId,
                                coachUid: coachUid,
                                playerName: playerName,
                              );
                            }
                            if (!mounted) return;
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(content: Text(widget.isEditMode
                                  ? 'subscription_updated_success'.tr(context)
                                  : 'coach_subscription_renewed'.tr(context))),
                            );
                          },
                          child: Text(
                            widget.isEditMode
                                ? 'save_changes'.tr(context)
                                : 'coach_confirm_renewal'.tr(context),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ]

        )
    );
  }
}

// ─── Coach Plan Tab ───────────────────────────────────────────────────────────

class _CoachPlanTab extends ConsumerStatefulWidget {
  final UserModel player;
  const _CoachPlanTab({required this.player});

  @override
  ConsumerState<_CoachPlanTab> createState() => _CoachPlanTabState();
}

class _CoachPlanTabState extends ConsumerState<_CoachPlanTab> {

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(playerSplitSetupProvider(widget.player.uid));
    final planAsync = ref.watch(playerGeneratedPlanProvider(widget.player.uid));

    return setupAsync.when(
      data: (setup) => _buildContent(context, setup, planAsync),
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF1C1C1E))),
      ),
      error: (e, _) => Center(
        child: Text('error_with_detail'.trP(context, {'e': e}), style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SplitSetupData setup,
    AsyncValue<List<WorkoutDay>> planAsync,
  ) {
    final name = '${widget.player.firstName ?? ''} ${widget.player.lastName ?? ''}'.trim();
    final hasPlan = setup.splitType.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2.h),

          // ── Header ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasPlan ? 'active_training_plan_label'.tr(context) : 'no_plan_set_label'.tr(context),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              GestureDetector(
                onTap: () => _showEditSheet(context, setup),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(2.5.w),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasPlan ? Icons.edit_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                      SizedBox(width: 1.5.w),
                      Text(
                        hasPlan ? 'edit_plan_label'.tr(context) : 'set_plan_label'.tr(context),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 2.h),

          if (!hasPlan) ...[
            // ── No Plan Placeholder ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(4.w),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Column(
                children: [
                  Text('📋', style: TextStyle(fontSize: 36.sp)),
                  SizedBox(height: 1.h),
                  Text(
                    'no_training_plan_assigned'.tr(context),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'tap_set_plan_for_name'.trP(context, {'name': name}),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Plan Config Card ───────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(4.w),
              ),
              child: Column(
                children: [
                  _configRow('split_label'.tr(context), splitTypeDisplayLabel(context, setup.splitType), Icons.fitness_center_rounded),
                  Divider(color: Colors.white.withOpacity(0.08), height: 2.5.h),
                  _configRow(
                    'days_per_week_label'.tr(context),
                    'n_days'.trP(context, {'n': setup.daysPerWeek}),
                    Icons.calendar_today_rounded,
                  ),
                  Divider(color: Colors.white.withOpacity(0.08), height: 2.5.h),
                  _configRow(
                    'training_days_label'.tr(context),
                    setup.trainingDays.join(' · '),
                    Icons.event_available_rounded,
                  ),
                  Divider(color: Colors.white.withOpacity(0.08), height: 2.5.h),
                  _configRow(
                    'start_date_label'.tr(context),
                    setup.planStartDate != null
                        ? DateFormat('MMM d, yyyy').format(setup.planStartDate!)
                        : 'today'.tr(context),
                    Icons.play_arrow_rounded,
                  ),
                ],
              ),
            ),

            SizedBox(height: 3.h),

            // ── Weekly Schedule ────────────────────────────────────────────
            Text(
              'weekly_schedule_label'.tr(context),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            SizedBox(height: 1.5.h),

            planAsync.when(
              data: (plan) => _buildWeekStrip(plan),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
              ),
              error: (_, __) => const SizedBox(),
            ),

            SizedBox(height: 3.h),

            // ── Coach Workouts (assign exercises per day) ───────────────────
            Text(
              'coach_workouts_label'.tr(context),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              'Assign the exact exercises this player trains each day.',
              style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93)),
            ),
            SizedBox(height: 1.5.h),
            ...setup.trainingDays.map((day) => _coachDayRow(context, day, setup)),
          ],

          SizedBox(height: 6.h),
        ],
      ),
    );
  }

  Widget _coachDayRow(BuildContext context, String day, SplitSetupData setup) {
    final coachPlan =
        ref.watch(playerCoachPlanProvider(widget.player.uid)).asData?.value;
    final routine = coachPlan?.routineFor(day);
    final hasWorkout = routine != null;
    final count = routine?.exercises.length ?? 0;

    // Restriction: lock a day once its most recent scheduled occurrence has
    // passed, or once the player has logged today's session — but occurrences
    // are computed relative to the plan's own Start Date (not just "today"),
    // so if the plan hasn't started yet nothing is locked at all. (Previously
    // this used the calendar Mon-Sun week regardless of Start Date, which
    // could mark a day "already done today" even while the plan's Start Date
    // was still weeks in the future.)
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rawStart = setup.planStartDate ?? today;
    final planStart = DateTime(rawStart.year, rawStart.month, rawStart.day);
    final startIndex = planStart.weekday - 1; // 0=MON
    final targetIndex = weekdays.indexOf(day);
    final rawOffset = targetIndex - startIndex;
    final dayOffset = rawOffset < 0 ? rawOffset % 7 + 7 : rawOffset % 7;

    // The calendar date this row refers to: if the plan hasn't started yet,
    // its first occurrence on/after Start Date; otherwise the occurrence
    // within the current 7-day cycle (could be past, today, or upcoming).
    final DateTime occurrence;
    if (today.isBefore(planStart)) {
      occurrence = planStart.add(Duration(days: dayOffset));
    } else {
      final daysSinceStart = today.difference(planStart).inDays;
      final cycleStart =
          planStart.add(Duration(days: (daysSinceStart ~/ 7) * 7));
      occurrence = cycleStart.add(Duration(days: dayOffset));
    }
    final isPastDay = occurrence.isBefore(today);
    final isToday = occurrence.isAtSameMomentAs(today);

    final history = ref
            .watch(playerWorkoutHistoryProvider(widget.player.uid))
            .asData
            ?.value ??
        const [];
    final completedToday = isToday &&
        history.any((s) => s.date == DateFormat('MMM d').format(today));

    final isLocked = isPastDay || completedToday;

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              completedToday
                  ? 'اللاعب خلّص تمرين اليوم — ما ينعدّل هلق. رح يصير قابل للتعديل الأسبوع الجاي.'
                  : 'هاد اليوم راح، ما بينعدّل بعد فوات وقته. رح يصير قابل للتعديل الأسبوع الجاي.',
              style: TextStyle(fontSize: 13.sp),
            ),
            backgroundColor: const Color(0xFFFF9500),
          ));
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CoachWorkoutBuilderScreen(
              player: widget.player,
              dayName: day,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 1.2.h),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.6.h),
        decoration: BoxDecoration(
          color: isLocked ? const Color(0xFFF5F5F7) : Colors.white,
          borderRadius: BorderRadius.circular(3.w),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: [
            Container(
              width: 12.w,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: 0.6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: isLocked
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.2.h),
                  Text(
                    DateFormat('MMM d').format(occurrence),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Text(
                isLocked
                    ? (completedToday
                        ? 'workout_done_today_locked'.tr(context)
                        : 'time_passed_locked'.tr(context))
                    : (hasWorkout
                        ? 'exercises_assigned_count'.trP(context, {'count': count})
                        : 'no_coach_workout_tap_to_add'.tr(context)),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: isLocked || !hasWorkout
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF1C1C1E),
                ),
              ),
            ),
            Icon(
              isLocked
                  ? Icons.lock_rounded
                  : (hasWorkout ? Icons.edit_rounded : Icons.add_rounded),
              size: 18.sp,
              color: isLocked
                  ? const Color(0xFF8E8E93)
                  : const Color(0xFF1C1C1E),
            ),
          ],
        ),
      ),
    );
  }

  Widget _configRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2.w),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 14.sp),
        ),
        SizedBox(width: 3.w),
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }

  Widget _buildWeekStrip(List<WorkoutDay> plan) {
    if (plan.isEmpty) return const SizedBox();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: plan.map((day) {
          final isRest = day.isRest;
          return Container(
            width: 30.w,
            margin: EdgeInsetsDirectional.only(end: 2.5.w),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: isRest ? const Color(0xFFF5F5F7) : Colors.white,
              borderRadius: BorderRadius.circular(3.5.w),
              border: Border.all(
                color: isRest
                    ? const Color(0xFFE5E5EA)
                    : const Color(0xFF1C1C1E).withOpacity(0.15),
                width: isRest ? 0.5 : 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.dayName,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(height: 0.8.h),
                Text(
                  isRest ? 'rest_day_short_label'.tr(context) : day.title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Icon(
                  isRest
                      ? Icons.weekend_rounded
                      : Icons.fitness_center_rounded,
                  size: 14.sp,
                  color: isRest
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF1C1C1E),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showEditSheet(BuildContext context, SplitSetupData current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPlanSheet(
        player: widget.player,
        current: current,
        onSaved: () {
          // StreamProviders auto-update from Firestore — no manual invalidation needed
        },
      ),
    );
  }
}

// Split-type VALUES are stored/compared in English everywhere (Firestore,
// providers, matching logic) — only the on-screen label is translated.
const _splitTypeKeys = {
  'Push/Pull/Legs': 'split_ppl',
  'Upper/Lower': 'split_upper_lower',
  'Full Body': 'split_full_body',
  'Bro Split': 'split_bro',
  'Arnold Split': 'split_arnold',
  'Custom': 'custom_label',
};
String splitTypeDisplayLabel(BuildContext context, String s) {
  final key = _splitTypeKeys[s];
  return key != null ? key.tr(context) : s;
}

// ─── Edit Plan Sheet ──────────────────────────────────────────────────────────

class _EditPlanSheet extends ConsumerStatefulWidget {
  final UserModel player;
  final SplitSetupData current;
  final VoidCallback onSaved;

  const _EditPlanSheet({
    required this.player,
    required this.current,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditPlanSheet> createState() => _EditPlanSheetState();
}

class _EditPlanSheetState extends ConsumerState<_EditPlanSheet> {
  static const _dayOrder = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _splitTypes = [
    'Push/Pull/Legs',
    'Upper/Lower',
    'Full Body',
    'Bro Split',
    'Arnold Split',
    'Custom',
  ];

  late int _daysPerWeek;
  late String _splitType;
  late List<String> _trainingDays;
  late DateTime _startDate;
  bool _saving = false;

  String _splitTypeLabel(BuildContext context, String s) =>
      splitTypeDisplayLabel(context, s);

  @override
  void initState() {
    super.initState();
    _daysPerWeek = widget.current.daysPerWeek;
    _splitType = widget.current.splitType.isNotEmpty
        ? widget.current.splitType
        : _splitTypes.first;
    _trainingDays = List<String>.from(widget.current.trainingDays);
    _startDate = widget.current.planStartDate ?? DateTime.now();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (_trainingDays.length != _daysPerWeek) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Select exactly $_daysPerWeek training days (${_trainingDays.length} selected)'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(coachRepositoryProvider).savePlayerSplitSetup(
            playerUid: widget.player.uid,
            daysPerWeek: _daysPerWeek,
            splitType: _splitType,
            trainingDays: _trainingDays,
            planStartDate: _startDate,
          );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('training_plan_saved'.tr(context))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('error_with_detail'.trP(context, {'e': e}))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      padding: EdgeInsets.fromLTRB(
          5.w, 2.h, 5.w, MediaQuery.of(context).viewInsets.bottom + 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 12.w,
              height: 4,
              margin: EdgeInsets.only(bottom: 2.h),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'set_training_plan_title'.tr(context),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'plan_for_name'.trP(context, {
              'name': '${widget.player.firstName ?? ''} ${widget.player.lastName ?? ''}'.trim(),
            }),
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),

          SizedBox(height: 2.h),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Days per week ────────────────────────────────────────
                  _sectionTitle('days_per_week_label'.tr(context)),
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [3, 4, 5, 6].map((d) {
                      final sel = _daysPerWeek == d;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _daysPerWeek = d;
                              // Keep only d days
                              if (_trainingDays.length > d) {
                                _trainingDays = _trainingDays.take(d).toList();
                              }
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: d < 6 ? 2.w : 0),
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Text(
                                  '$d',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: sel
                                        ? Colors.white
                                        : const Color(0xFF1C1C1E),
                                  ),
                                ),
                                Text(
                                  'days',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: sel
                                        ? Colors.white70
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 3.h),

                  // ── Split type ───────────────────────────────────────────
                  _sectionTitle('split_type_label'.tr(context)),
                  SizedBox(height: 1.h),
                  Wrap(
                    spacing: 2.w,
                    runSpacing: 1.h,
                    children: _splitTypes.map((s) {
                      final sel = _splitType == s;
                      return GestureDetector(
                        onTap: () => setState(() => _splitType = s),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 3.5.w, vertical: 1.2.h),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(2.w),
                            border: sel
                                ? null
                                : Border.all(
                                    color: const Color(0xFFE5E5EA)),
                          ),
                          child: Text(
                            _splitTypeLabel(context, s),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 3.h),

                  // ── Training days ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle('training_days_label'.tr(context)),
                      Text(
                        'n_of_n_selected'.trP(context, {'sel': _trainingDays.length, 'total': _daysPerWeek}),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _trainingDays.length == _daysPerWeek
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Builder(builder: (_) {
                    // Show the 7 day-chips in chronological order STARTING
                    // at the Start Date's weekday, not fixed Mon-first — so
                    // the dates underneath always read left-to-right in
                    // ascending order instead of jumping backwards mid-row
                    // (e.g. Mon/Tue showing dates from the *next* week after
                    // Wed/Thu/Fri/Sat/Sun of the start week).
                    final normalizedStart = DateTime(
                        _startDate.year, _startDate.month, _startDate.day);
                    final startIndex = normalizedStart.weekday - 1; // 0=MON
                    final orderedDays = List.generate(
                        7, (i) => _dayOrder[(startIndex + i) % 7]);
                    return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: orderedDays.map((d) {
                      final sel = _trainingDays.contains(d);
                      // Calendar date for this weekday: the FIRST occurrence
                      // of that weekday on or after the Plan Start Date —
                      // never before it.
                      final targetIndex = _dayOrder.indexOf(d);
                      final offset = (targetIndex - startIndex) % 7;
                      final date = normalizedStart
                          .add(Duration(days: offset < 0 ? offset + 7 : offset));
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (sel) {
                                _trainingDays.remove(d);
                              } else if (_trainingDays.length <
                                  _daysPerWeek) {
                                _trainingDays.add(d);
                                _trainingDays.sort((a, b) =>
                                    _dayOrder.indexOf(a)
                                        .compareTo(_dayOrder.indexOf(b)));
                              }
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.only(
                                right: d != 'SUN' ? 1.w : 0),
                            padding:
                                EdgeInsets.symmetric(vertical: 1.2.h),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  d.substring(0, 1),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w800,
                                    color: sel
                                        ? Colors.white
                                        : Colors.grey[400],
                                  ),
                                ),
                                SizedBox(height: 0.3.h),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? Colors.white70
                                        : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    );
                  }),

                  SizedBox(height: 3.h),

                  // ── Start date ───────────────────────────────────────────
                  _sectionTitle('plan_start_date_label'.tr(context)),
                  SizedBox(height: 1.h),
                  GestureDetector(
                    onTap: _pickStartDate,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: 4.w, vertical: 1.8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(3.w),
                        border:
                            Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 16.sp,
                              color: const Color(0xFF1C1C1E)),
                          SizedBox(width: 3.w),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy')
                                .format(_startDate),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: Colors.grey, size: 16.sp),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // ── Save ─────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 6.5.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : Text(
                              'save_training_plan_label'.tr(context),
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1C1C1E),
      ),
    );
  }
}

