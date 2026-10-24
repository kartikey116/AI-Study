import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go('/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.ink, width: 1.5),
                      boxShadow: AppShadows.hard,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/appIcon.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 28),
                  // Wordmark with a highlighter swipe behind "AI"
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Study', style: AppTypography.display),
                      Stack(
                        children: [
                          Positioned(
                            left: -2,
                            right: -4,
                            bottom: 6,
                            height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.highlighter,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Text('AI', style: AppTypography.display),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Text(
                'YOUR STUDY NOTEBOOK',
                textAlign: TextAlign.center,
                style: AppTypography.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
