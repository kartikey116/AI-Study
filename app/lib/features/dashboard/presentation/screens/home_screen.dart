import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/layout/main_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../quiz/presentation/providers/quiz_provider.dart';
import '../../../flashcard/presentation/providers/flashcard_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final String firstName = user?.profile?.firstName?.isNotEmpty == true
        ? user!.profile!.firstName!
        : (user?.email.split('@').first ?? 'kartikey');

    final dashboardAsync = ref.watch(dashboardProvider);

    return MainLayout(
      currentIndex: 0,
      child: Container(
        color: const Color(0xFFF7F6FD),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Bar: Avatar + Greeting + Notification Bell ───────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar + Greeting
                    Expanded(
                      child: Row(
                        children: [
                          // User Avatar Circle
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(23),
                              child: Container(
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF64748B),
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Name & Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, $firstName! 👋',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: const TextSpan(
                                    text: 'Level up your skills with ',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'StudyAI',
                                        style: TextStyle(
                                          color: Color(0xFF7C3AED),
                                          fontWeight: FontWeight.w700,
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
                    ),

                    // Notification Bell Button with Red Badge Dot
                    GestureDetector(
                      onTap: () => _showQuickNavigationSheet(context, ref),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_rounded,
                              color: Color(0xFF1E293B),
                              size: 22,
                            ),
                            // Red Badge Dot
                            Positioned(
                              top: 9,
                              right: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── 2. 4-Card Stats Row ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: dashboardAsync.when(
                  data: (data) {
                    final studyTime = data['studyTime']?.toString() ?? '12h 30m';
                    final tasksDone = data['tasksCompleted']?.toString() ?? '8';
                    final streak = data['streakDays']?.toString() ?? '12 Days';
                    final level = data['userLevel']?.toString() ?? 'Level 3';

                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.access_time_filled_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            iconBgColor: const Color(0xFFEDE9FE),
                            value: studyTime,
                            label: 'Study Time',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.check_box_rounded,
                            iconColor: const Color(0xFF10B981),
                            iconBgColor: const Color(0xFFDCFCE7),
                            value: tasksDone,
                            label: 'Tasks Done',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: const Color(0xFFF97316),
                            iconBgColor: const Color(0xFFFFEDD5),
                            value: streak.contains('Day') ? streak : '$streak Days',
                            label: 'Streak',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.bar_chart_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            iconBgColor: const Color(0xFFEDE9FE),
                            value: level,
                            label: 'Learner',
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.access_time_filled_rounded,
                          iconColor: Color(0xFF7C3AED),
                          iconBgColor: Color(0xFFEDE9FE),
                          value: '12h 30m',
                          label: 'Study Time',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_box_rounded,
                          iconColor: Color(0xFF10B981),
                          iconBgColor: Color(0xFFDCFCE7),
                          value: '8',
                          label: 'Tasks Done',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Color(0xFFF97316),
                          iconBgColor: Color(0xFFFFEDD5),
                          value: '12 Days',
                          label: 'Streak',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.bar_chart_rounded,
                          iconColor: Color(0xFF7C3AED),
                          iconBgColor: Color(0xFFEDE9FE),
                          value: 'Level 3',
                          label: 'Learner',
                        ),
                      ),
                    ],
                  ),
                  error: (_, __) => const Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.access_time_filled_rounded,
                          iconColor: Color(0xFF7C3AED),
                          iconBgColor: Color(0xFFEDE9FE),
                          value: '12h 30m',
                          label: 'Study Time',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_box_rounded,
                          iconColor: Color(0xFF10B981),
                          iconBgColor: Color(0xFFDCFCE7),
                          value: '8',
                          label: 'Tasks Done',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Color(0xFFF97316),
                          iconBgColor: Color(0xFFFFEDD5),
                          value: '12 Days',
                          label: 'Streak',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.bar_chart_rounded,
                          iconColor: Color(0xFF7C3AED),
                          iconBgColor: Color(0xFFEDE9FE),
                          value: 'Level 3',
                          label: 'Learner',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── 3. AI Hero Card with Mascot ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AiHeroCard(
                  onTap: () => context.push('/quiz-setup'),
                ),
              ),

              const SizedBox(height: 22),

              // ── 4. Quick Actions Header & 2x2 Grid ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showQuickNavigationSheet(context, ref),
                      child: const Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.smart_toy_rounded,
                            iconColor: const Color(0xFF6366F1),
                            iconBgColor: const Color(0xFFEDE9FE),
                            title: 'AI Tutor',
                            subtitle: 'Ask, learn, explore',
                            onTap: () => context.go('/chat'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.timer_rounded,
                            iconColor: const Color(0xFF10B981),
                            iconBgColor: const Color(0xFFDCFCE7),
                            title: 'Focus Timer',
                            subtitle: 'Start a 25-min session',
                            onTap: () => context.push('/timer'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.quiz_rounded,
                            iconColor: const Color(0xFF9333EA),
                            iconBgColor: const Color(0xFFF3E8FF),
                            title: 'Quizzes & Tests',
                            subtitle: 'Test your knowledge',
                            onTap: () => context.push('/quizzes'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.style_rounded,
                            iconColor: const Color(0xFFEA580C),
                            iconBgColor: const Color(0xFFFFEDD5),
                            title: 'Flashcard Decks',
                            subtitle: 'Spaced repetition',
                            onTap: () => _showFlashcardsBottomSheet(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── 5. Recent Quizzes Header & List ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Quizzes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/quizzes'),
                      child: const Text(
                        'View All →',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _RecentQuizzesSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Stats Card (Study Time, Tasks Done, Streak, Learner)
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. AI Hero Card with Cute 3D Mascot Robot
// ─────────────────────────────────────────────────────────────────────────────

class _AiHeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AiHeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6D28D9),
            Color(0xFF9333EA),
            Color(0xFFC084FC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background soft decorative glow circles
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              left: 40,
              top: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
              child: Row(
                children: [
                  // Text & Button on Left
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Try generating a quiz from your uploaded documents to test your knowledge!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F0728),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Start with AI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Mascot on Right
                  const _CuteRobotMascot(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Cute 3D Robot Mascot Widget
// ─────────────────────────────────────────────────────────────────────────────

class _CuteRobotMascot extends StatelessWidget {
  const _CuteRobotMascot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sparkle ✦ on top left
          const Positioned(
            left: 2,
            top: 6,
            child: Text(
              '✦',
              style: TextStyle(color: Color(0xFFFDE047), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          // Sparkle ✦ on bottom right
          const Positioned(
            right: 4,
            bottom: 8,
            child: Text(
              '✦',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),

          // Robot Outer Body / Head
          Container(
            width: 82,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFEDE9FE)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top Little Antenna
                Positioned(
                  top: 2,
                  child: Container(
                    width: 6,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Dark Screen / Visor
                Container(
                  width: 66,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E1065),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cute Eyes: >   <
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '>',
                              style: TextStyle(
                                color: Color(0xFFE0E7FF),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(width: 4),
                            // Smiling Mouth v
                            Text(
                              'v',
                              style: TextStyle(
                                color: Color(0xFFF472B6),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '<',
                              style: TextStyle(
                                color: Color(0xFFE0E7FF),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// 4. Quick Action Card
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon on left, Chevron on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                Icon(Icons.chevron_right_rounded, color: iconColor.withValues(alpha: 0.7), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Recent Quizzes Section
// ─────────────────────────────────────────────────────────────────────────────

class _RecentQuizzesSection extends ConsumerWidget {
  const _RecentQuizzesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(quizzesProvider);

    return quizzesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildMockQuizzesList(context),
      data: (quizzes) {
        if (quizzes.isEmpty) {
          return _buildMockQuizzesList(context);
        }

        // Display user's actual recent quizzes using the exact design
        return Column(
          children: quizzes.take(3).map((quiz) {
            final id = quiz['id']?.toString() ?? '';
            final title = quiz['title']?.toString() ?? 'Quiz';
            final questionsCount = (quiz['questions'] as List?)?.length ?? 10;
            final attempts = quiz['attempts'] as List? ?? [];
            final hasAttempt = attempts.isNotEmpty;
            final score = hasAttempt ? (attempts.first['score'] as num?)?.round() : null;
            final isCompleted = hasAttempt;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecentQuizItemCard(
                title: title,
                subtitle: '$questionsCount Questions • ⭐ ${score ?? 80}%',
                icon: Icons.storage_rounded,
                statusText: isCompleted ? 'Completed' : 'In Progress',
                statusBgColor: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                statusTextColor: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                onTap: () => context.push('/quiz/$id'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMockQuizzesList(BuildContext context) {
    return Column(
      children: [
        _RecentQuizItemCard(
          title: 'DBMS – Normalization',
          subtitle: '10 Questions • ⭐ 85%',
          icon: Icons.storage_rounded,
          statusText: 'Completed',
          statusBgColor: const Color(0xFFDCFCE7),
          statusTextColor: const Color(0xFF16A34A),
          onTap: () => context.push('/quizzes'),
        ),
        const SizedBox(height: 10),
        _RecentQuizItemCard(
          title: 'Operating Systems',
          subtitle: '15 Questions • ⭐ 60%',
          icon: Icons.settings_suggest_rounded,
          statusText: 'In Progress',
          statusBgColor: const Color(0xFFFEF3C7),
          statusTextColor: const Color(0xFFD97706),
          onTap: () => context.push('/quizzes'),
        ),
      ],
    );
  }
}

class _RecentQuizItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String statusText;
  final Color statusBgColor;
  final Color statusTextColor;
  final VoidCallback onTap;

  const _RecentQuizItemCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.statusText,
    required this.statusBgColor,
    required this.statusTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left circular icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF7C3AED), size: 20),
            ),
            const SizedBox(width: 12),
            // Middle Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: statusTextColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets: Quick Navigation & Flashcards
// ─────────────────────────────────────────────────────────────────────────────

void _showQuickNavigationSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Quick Navigation Menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 14),
            _QuickNavItem(
              icon: Icons.auto_awesome,
              color: const Color(0xFF8B5CF6),
              title: 'AI Tutor Chat',
              subtitle: 'Chat, ask doubts & get instant explanations',
              onTap: () {
                Navigator.pop(ctx);
                context.go('/chat');
              },
            ),
            _QuickNavItem(
              icon: Icons.quiz_rounded,
              color: const Color(0xFFEC4899),
              title: 'Quizzes & Practice Tests',
              subtitle: 'Take tests, view history & practice',
              onTap: () {
                Navigator.pop(ctx);
                context.push('/quizzes');
              },
            ),
            _QuickNavItem(
              icon: Icons.style_rounded,
              color: const Color(0xFFEA580C),
              title: 'Flashcard Decks',
              subtitle: 'Review cards with spaced repetition',
              onTap: () {
                Navigator.pop(ctx);
                _showFlashcardsBottomSheet(context, ref);
              },
            ),
            _QuickNavItem(
              icon: Icons.timer_rounded,
              color: const Color(0xFF10B981),
              title: 'Focus Timer',
              subtitle: 'Pomodoro focus study sessions',
              onTap: () {
                Navigator.pop(ctx);
                context.push('/timer');
              },
            ),
            _QuickNavItem(
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF3B82F6),
              title: 'Study Schedule',
              subtitle: 'Structured study planner',
              onTap: () {
                Navigator.pop(ctx);
                context.go('/study-plan');
              },
            ),
            _QuickNavItem(
              icon: Icons.description_rounded,
              color: const Color(0xFF6366F1),
              title: 'Documents & Notes',
              subtitle: 'Upload PDFs & study materials',
              onTap: () {
                Navigator.pop(ctx);
                context.go('/documents');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickNavItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickNavItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 3),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}

void _showFlashcardsBottomSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Flashcard Decks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/documents');
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Deck'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final decksAsync = ref.watch(decksProvider);
                  return decksAsync.when(
                    data: (decks) {
                      if (decks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.style_outlined, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text(
                                  'No flashcard decks yet',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Go to Documents and tap "Cards" on any PDF to generate flashcards!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    context.go('/documents');
                                  },
                                  icon: const Icon(Icons.upload_file, size: 18),
                                  label: const Text('View Documents'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.45,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: decks.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final deck = decks[index];
                            final dueCount = deck['dueCards'] ?? 0;
                            final totalCount = deck['totalCards'] ?? 0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEDD5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.style_rounded, color: Color(0xFFEA580C), size: 22),
                              ),
                              title: Text(deck['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('$totalCount cards total • $dueCount due for review'),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEA580C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  context.push('/flashcard/${deck['id']}');
                                },
                                child: const Text('Review', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text('Error loading decks: $e'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
