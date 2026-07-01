import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'dart:ui';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        context.go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
          // Background Glow
          Positioned(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value * 0.5,
                  child: Container(
                    width: 60.w,
                    height: 60.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1C1C1E).withOpacity(0.08),
                          blurRadius: 100,
                          spreadRadius: 40,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Logo
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/nexus_logo.png',
                        width: 40.w,
                        height: 40.w,
                        color: const Color(0xFF1C1C1E), // Black logo
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'NEXUS',
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1E),
                          letterSpacing: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      ),
    );
  }
}
