import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/layout/main_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../providers/study_plan_provider.dart';

class StudyPlanScreen extends ConsumerStatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  ConsumerState<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends ConsumerState<StudyPlanScreen> {
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTaskDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(date.year, date.month, date.day);
    final diff = taskDay.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1 && diff <= 6) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(studyPlanProvider);

    return MainLayout(
      currentIndex: 1,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Study Schedule', style: AppTypography.heading2),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
              tooltip: 'Refresh Plan',
              onPressed: () => ref.invalidate(studyPlanProvider),
            ),
            planAsync.maybeWhen(
              data: (plan) {
                if (plan == null) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                  tooltip: 'Create New Plan',
                  onPressed: () => _showCreatePlanBottomSheet(context),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: planAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading your study schedule...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Failed to load schedule', style: AppTypography.heading3),
                  const SizedBox(height: 8),
                  Text('$err', textAlign: TextAlign.center, style: AppTypography.bodySmall),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(studyPlanProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (plan) {
            if (plan == null || (plan['tasks'] as List? ?? []).isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildActivePlanView(context, plan);
          },
        ),
      ),
    );
  }

  // ── EMPTY STATE VIEW ────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Illustration circle
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_note_rounded, size: 48, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No Active Study Plan',
            style: AppTypography.heading2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Let AI build a personalized 7-day revision roadmap based on your exam deadline and course materials.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          // "How It Works" Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
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
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('How AI Study Planning Works', style: AppTypography.heading3.copyWith(fontSize: 16)),
                  ],
                ),
                const Divider(height: 24),
                _buildHowItWorksItem(
                  icon: Icons.flag_rounded,
                  color: const Color(0xFF2563EB),
                  title: '1. Set Your Target',
                  description: 'Choose your upcoming exam date or completion target and daily available study hours.',
                ),
                const SizedBox(height: 14),
                _buildHowItWorksItem(
                  icon: Icons.library_books_rounded,
                  color: const Color(0xFF7C3AED),
                  title: '2. Select Your Material',
                  description: 'Type your topics or select from your uploaded PDF notes to ground the curriculum.',
                ),
                const SizedBox(height: 14),
                _buildHowItWorksItem(
                  icon: Icons.shuffle_rounded,
                  color: const Color(0xFF059669),
                  title: '3. Auto-Balanced Routine',
                  description: 'The AI interleaves Concept Reading, Spaced Revision, and Practice Quizzes to maximize retention.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Prominent CTA Button
          Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showCreatePlanBottomSheet(context),
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Generate Study Plan with AI',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildHowItWorksItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  // ── ACTIVE PLAN VIEW ────────────────────────────────────────────────────────
  Widget _buildActivePlanView(BuildContext context, Map<String, dynamic> plan) {
    final tasks = (plan['tasks'] as List).cast<Map<String, dynamic>>();
    final completedCount = tasks.where((t) => t['isCompleted'] == true).length;
    final totalCount = tasks.length;
    final progressPercent = totalCount == 0 ? 0.0 : completedCount / totalCount;

    DateTime? targetDate;
    if (plan['targetDate'] != null) {
      targetDate = DateTime.tryParse(plan['targetDate']);
    }

    final daysLeft = targetDate?.difference(DateTime.now()).inDays;
    final subjects = (plan['subjects'] as List? ?? []).map((e) => e.toString()).toList();

    return RefreshIndicator(
      onRefresh: () => ref.refresh(studyPlanProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Progress Overview Card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            daysLeft != null && daysLeft >= 0 ? '$daysLeft days remaining' : 'Target reached',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 20),
                      tooltip: 'Delete Plan',
                      onPressed: () => _confirmDeletePlan(context, plan['id']),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '7-Day Study Roadmap',
                  style: AppTypography.heading2.copyWith(color: Colors.white, fontSize: 22),
                ),
                if (targetDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Exam Target: ${_formatDate(targetDate)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                // Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$completedCount of $totalCount tasks completed',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${(progressPercent * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                  ),
                ),
                if (subjects.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: subjects.take(3).map((sub) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sub,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Quick Action Shortcuts ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/focus-timer'),
                  icon: const Icon(Icons.timer_rounded, size: 18, color: AppColors.primary),
                  label: const Text('Focus Timer', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.primaryLight),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/quizzes'),
                  icon: const Icon(Icons.quiz_rounded, size: 18, color: Color(0xFF2563EB)),
                  label: const Text('Practice Quiz', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Tasks Header ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Tasks', style: AppTypography.heading3),
              Text(
                'Tap checkmark to complete',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Tasks List ──────────────────────────────────────────────────────
          ...tasks.map((task) => _buildTaskCard(task)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isCompleted = task['isCompleted'] == true;
    final type = (task['type'] ?? 'READING').toString().toUpperCase();
    final duration = task['durationMinutes'] ?? 30;
    final title = task['title'] ?? 'Study Session';
    final taskDate = task['date'] != null ? DateTime.tryParse(task['date']) : null;

    Color badgeColor;
    IconData badgeIcon;
    switch (type) {
      case 'QUIZ':
        badgeColor = const Color(0xFF7C3AED);
        badgeIcon = Icons.quiz_rounded;
        break;
      case 'REVISION':
        badgeColor = const Color(0xFFD97706);
        badgeIcon = Icons.sync_rounded;
        break;
      default: // READING
        badgeColor = const Color(0xFF2563EB);
        badgeIcon = Icons.menu_book_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? Colors.grey.shade200 : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: isCompleted
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: GestureDetector(
          onTap: () async {
            try {
              await ref.read(studyPlanNotifierProvider.notifier).toggleTask(task['id']);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted ? const Color(0xFF10B981) : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey.shade400 : AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              // Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      type,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Duration Pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text('$duration m', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              if (taskDate != null) ...[
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: Colors.grey.shade400)),
                const SizedBox(width: 8),
                Text(_formatTaskDate(taskDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ],
          ),
        ),
        trailing: type == 'QUIZ' && !isCompleted
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                tooltip: 'Take Quiz',
                onPressed: () => context.push('/quizzes'),
              )
            : null,
      ),
    );
  }

  // ── CREATE PLAN MODAL BOTTOM SHEET ──────────────────────────────────────────
  void _showCreatePlanBottomSheet(BuildContext context) {
    DateTime selectedTargetDate = DateTime.now().add(const Duration(days: 7));
    final subjectController = TextEditingController();
    double hoursPerDay = 2.0;
    bool isGenerating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final docsAsync = ref.watch(documentsProvider);

          return PopScope(
            canPop: !isGenerating,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.sm,
                    bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 12),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Create AI Study Plan', style: AppTypography.heading3),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: isGenerating ? null : () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Set your target deadline and subjects. Gemini will architect a balanced 7-day study routine.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      const Divider(height: 24),

                      // 1. Target Date Selector
                      Text('Target Exam / Completion Date', style: AppTypography.heading3.copyWith(fontSize: 14)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: isGenerating
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedTargetDate,
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    selectedTargetDate = picked;
                                  });
                                }
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _formatDate(selectedTargetDate),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const Spacer(),
                              Text(
                                '${selectedTargetDate.difference(DateTime.now()).inDays} days from now',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 2. Subjects / Topics
                      Text('Subjects or Topics to Cover', style: AppTypography.heading3.copyWith(fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: subjectController,
                        enabled: !isGenerating,
                        decoration: InputDecoration(
                          hintText: 'e.g. Cellular Biology, Genetics, Mitosis',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      // Uploaded docs chips
                      docsAsync.maybeWhen(
                        data: (docs) {
                          final readyDocs = docs.where((d) => d.status == 'READY').toList();
                          if (readyDocs.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tap to add uploaded PDF:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: readyDocs.map((d) {
                                    final cleanName = d.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                                    return ActionChip(
                                      label: Text(cleanName, style: const TextStyle(fontSize: 11)),
                                      avatar: const Icon(Icons.add, size: 14),
                                      backgroundColor: const Color(0xFFF3E8FF),
                                      onPressed: isGenerating
                                          ? null
                                          : () {
                                              final current = subjectController.text.trim();
                                              if (current.isEmpty) {
                                                subjectController.text = cleanName;
                                              } else if (!current.contains(cleanName)) {
                                                subjectController.text = '$current, $cleanName';
                                              }
                                              setModalState(() {});
                                            },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 3. Daily Available Hours
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Daily Study Availability', style: AppTypography.heading3.copyWith(fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${hoursPerDay.toInt()} hrs / day',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: hoursPerDay,
                        min: 1,
                        max: 8,
                        divisions: 7,
                        activeColor: AppColors.primary,
                        onChanged: isGenerating
                            ? null
                            : (val) {
                                setModalState(() => hoursPerDay = val);
                              },
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // 4. Generate Button
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isGenerating
                              ? null
                              : () async {
                                  final rawSubjects = subjectController.text.trim();
                                  final subjectsList = rawSubjects.isEmpty
                                      ? ['General Coursework']
                                      : rawSubjects.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

                                  // Immediately trigger loading state on the button
                                  setModalState(() {
                                    isGenerating = true;
                                  });

                                  final messenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(ctx);

                                  try {
                                    await ref.read(studyPlanNotifierProvider.notifier).generatePlan(
                                          targetDate: selectedTargetDate,
                                          subjects: subjectsList,
                                          hoursPerDay: hoursPerDay.toInt(),
                                        );
                                    navigator.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('🎉 Your AI Study Plan has been created!'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  } catch (e) {
                                    setModalState(() {
                                      isGenerating = false;
                                    });
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Failed to generate plan: $e')),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.65),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isGenerating
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Architecting Schedule with AI...',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Generate 7-Day Plan',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

  void _confirmDeletePlan(BuildContext context, String planId) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Study Plan?'),
        content: const Text('This will remove your current tasks. You can generate a new schedule anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(studyPlanNotifierProvider.notifier).deletePlan(planId);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
