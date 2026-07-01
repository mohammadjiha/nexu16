import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'dart:ui';

import '../../../../core/localization/app_localizations.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Unleash Your Potential',
      'subtitle': 'Achieve your fitness goals with AI-driven insights and premium tracking.',
      'icon': 'fitness_center',
    },
    {
      'title': 'Track Every Move',
      'subtitle': 'Log workouts seamlessly and monitor your daily progress like a pro.',
      'icon': 'bar_chart',
    },
    {
      'title': 'Stay Connected',
      'subtitle': 'Interact with your coach and gym in real-time. Reach your peak with NEXUS.',
      'icon': 'bolt',
    },
  ];

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'bar_chart':
        return Icons.bar_chart;
      case 'bolt':
        return Icons.bolt;
      default:
        return Icons.star;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Glow effect
          Positioned(
            top: -10.h,
            right: -10.w,
            child: Container(
              width: 70.w,
              height: 70.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1C1C1E).withOpacity(0.05),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Logo Header
                Padding(
                  padding: EdgeInsets.only(top: 4.h, bottom: 2.h),
                  child: Image.asset(
                    'assets/images/nexus_logo.png',
                    width: 15.w,
                    height: 15.w,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                
                // Page View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _onboardingData.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD1D1D6),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _getIcon(_onboardingData[index]['icon']!),
                                size: 24.w,
                                color: const Color(0xFF1C1C1E),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _onboardingData[index]['title']!,
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1C1C1E),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              _onboardingData[index]['subtitle']!,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: const Color(0xFF6E6E73), // Grey
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Controls
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  child: Column(
                    children: [
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: EdgeInsets.symmetric(horizontal: 1.w),
                            width: _currentPage == index ? 8.w : 2.5.w,
                            height: 1.h,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFFD1D1D6),
                              borderRadius: BorderRadius.circular(1.h),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 5.h),
                      
                      // Next / Get Started Button
                      SizedBox(
                        width: double.infinity,
                        height: 7.h,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1C1E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.w),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (_currentPage == _onboardingData.length - 1) {
                              context.push('/onboarding_gym'); // Next step from original flow
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Text(
                            _currentPage == _onboardingData.length - 1
                                ? 'onboarding_get_started'.tr(context)
                                : 'Next',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
