import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/services/force_update_service.dart';

/// Mandatory update wall. Shown whenever the installed app version is below
/// the 'min_supported_version' remote-config value. Blocks the back button
/// and offers no way in — the only action is to open the store listing.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  Future<void> _openStore(BuildContext context) async {
    final url = ForceUpdateGate.updateUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9FB),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(6.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 14.w,
                    color: const Color(0xFF007AFF),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'force_update_title'.tr(context),
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C1C1E),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2.h),
                Text(
                  'force_update_desc'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8E8E93),
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 6.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openStore(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3.w),
                      ),
                    ),
                    child: Text(
                      'force_update_button'.tr(context),
                      style: TextStyle(
                        fontSize: 14.sp,
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
      ),
    );
  }
}
