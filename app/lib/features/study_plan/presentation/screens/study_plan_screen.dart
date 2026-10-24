import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/layout/main_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
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
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          elevation: 0,
          title: Text('Study Plan', style: AppTypography.heading2),
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
                  icon: const Icon(Icons.add_rounded, color: AppColors.ink),
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
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading your study schedule...', style: AppTypography.bodyMedium),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('NO ACTIVE PLAN', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Plan the week before the week plans you.',
            style: AppTypography.heading1,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Let AI build a personalized 7-day revision roadmap based on your exam deadline and course materials.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          // "How It Works" Card
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOW IT WORKS', style: AppTypography.label),
                const SizedBox(height: AppSpacing.sm),
                _buildHowItWorksItem(
                  step: '01',
                  color: AppColors.tagSlate,
                  title: 'Set your target',
                  description: 'Choose your upcoming exam date or completion target and daily available study hours.',
                ),
                _buildHowItWorksItem(
                  step: '02',
                  color: AppColors.tagClay,
                  title: 'Select your material',
                  description: 'Type your topics or select from your uploaded PDF notes to ground the curriculum.',
                ),
                _buildHowItWorksItem(
                  step: '03',
                  color: AppColors.tagSage,
                  title: 'Follow a balanced routine',
                  description: 'The AI interleaves Concept Reading, Spaced Revision, and Practice Quizzes to maximize retention.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Prominent CTA Button
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _showCreatePlanBottomSheet(context),
              icon: const Icon(Icons.edit_calendar_rounded, color: AppColors.highlighter, size: 20),
              label: const Text('Build my 7-day plan'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildHowItWorksItem({
    required String step,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(step, style: AppTypography.mono.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.title.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(description, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
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
      color: AppColors.ink,
      onRefresh: () => ref.refresh(studyPlanProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── Progress Overview Card (ink hero) ─────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.highlighter,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        daysLeft != null && daysLeft >= 0 ? '$daysLeft DAYS LEFT' : 'TARGET REACHED',
                        style: AppTypography.label.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: AppColors.onInk.withValues(alpha: 0.7), size: 20),
                      tooltip: 'Delete Plan',
                      onPressed: () => _confirmDeletePlan(context, plan['id']),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '7-Day Study Roadmap',
                  style: AppTypography.heading2.copyWith(color: AppColors.onInk),
                ),
                if (targetDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'EXAM · ${_formatDate(targetDate).toUpperCase()}',
                    style: AppTypography.label.copyWith(color: AppColors.onInk.withValues(alpha: 0.7)),
                  ),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(progressPercent * 100).toInt()}%',
                            style: AppTypography.heading1.copyWith(color: AppColors.highlighter, height: 1),
                          ),
                          const Spacer(),
                          Text(
                            '$completedCount / $totalCount TASKS',
                            style: AppTypography.label.copyWith(color: AppColors.onInk.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 6,
                          backgroundColor: AppColors.onInk.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.highlighter),
                        ),
                      ),
                      if (subjects.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: subjects.take(3).map((sub) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.onInk.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              sub,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.onInk),
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Quick Action Shortcuts ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/focus-timer'),
                  icon: const Icon(Icons.timer_outlined, size: 18, color: AppColors.accent),
                  label: const Text('Focus Timer'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/quizzes'),
                  icon: const Icon(Icons.quiz_outlined, size: 18, color: AppColors.primary),
                  label: const Text('Practice Quiz'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Tasks Header ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Your tasks', style: AppTypography.heading3),
              Text('TAP BOX TO COMPLETE', style: AppTypography.label.copyWith(fontSize: 10)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Tasks List ──────────────────────────────────────────────────────
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < tasks.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.line),
                  _buildTaskCard(tasks[i]),
                ],
              ],
            ),
          ),
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
        badgeColor = AppColors.primary;
        badgeIcon = Icons.quiz_outlined;
        break;
      case 'REVISION':
        badgeColor = AppColors.tagOchre;
        badgeIcon = Icons.sync_rounded;
        break;
      default: // READING
        badgeColor = AppColors.tagSlate;
        badgeIcon = Icons.menu_book_outlined;
        break;
    }
    final metaStyle = AppTypography.label.copyWith(fontSize: 10, letterSpacing: 0.6);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subject-colored left bar
          Container(width: 3, color: isCompleted ? AppColors.line : badgeColor),
          // Checkbox with a 44px tap target
          Semantics(
            checked: isCompleted,
            label: 'Mark task complete',
            child: InkWell(
              onTap: () async {
                try {
                  await ref.read(studyPlanNotifierProvider.notifier).toggleTask(task['id']);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
                  }
                }
              },
              child: SizedBox(
                width: 52,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.ink, width: 1.5),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, size: 16, color: AppColors.highlighter)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTypography.title.copyWith(
                      fontSize: 15,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textMuted,
                      color: isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: isCompleted ? AppColors.textMuted : badgeColor),
                          const SizedBox(width: 4),
                          Text(type, style: metaStyle.copyWith(color: isCompleted ? AppColors.textMuted : badgeColor)),
                        ],
                      ),
                      Text('$duration MIN', style: metaStyle),
                      if (taskDate != null) Text(_formatTaskDate(taskDate).toUpperCase(), style: metaStyle),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (type == 'QUIZ' && !isCompleted)
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.ink),
              tooltip: 'Take Quiz',
              onPressed: () => context.push('/quizzes'),
            )
          else
            const SizedBox(width: AppSpacing.md),
        ],
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
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                              color: AppColors.lineStrong,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('New study plan', style: AppTypography.heading2),
                            IconButton(
                              tooltip: 'Close',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: isGenerating ? null : () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Set your target deadline and subjects. Gemini will architect a balanced 7-day study routine.',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                      const Divider(height: 32),

                      // 1. Target Date Selector
                      Text('TARGET EXAM / COMPLETION DATE', style: AppTypography.label),
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
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _formatDate(selectedTargetDate),
                                style: AppTypography.title.copyWith(fontSize: 15),
                              ),
                              const Spacer(),
                              Text(
                                'IN ${selectedTargetDate.difference(DateTime.now()).inDays} DAYS',
                                style: AppTypography.label,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // 2. Subjects / Topics
                      Text('SUBJECTS OR TOPICS TO COVER', style: AppTypography.label),
                      const SizedBox(height: 8),
                      TextField(
                        controller: subjectController,
                        enabled: !isGenerating,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Cellular Biology, Genetics, Mitosis',
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
                                Text('Tap to add an uploaded PDF', style: AppTypography.bodySmall),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: readyDocs.map((d) {
                                    final cleanName = d.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                                    return ActionChip(
                                      label: Text(cleanName, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary)),
                                      avatar: const Icon(Icons.add, size: 14, color: AppColors.primary),
                                      backgroundColor: AppColors.surface,
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
                          Text('DAILY STUDY AVAILABILITY', style: AppTypography.label),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.highlighterSoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '${hoursPerDay.toInt()} H / DAY',
                              style: AppTypography.mono.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: hoursPerDay,
                        min: 1,
                        max: 8,
                        divisions: 7,
                        activeColor: AppColors.ink,
                        inactiveColor: AppColors.surfaceSunken,
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
                                        content: Text('Your study plan is ready.'),
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
                            disabledBackgroundColor: AppColors.inkSoft.withValues(alpha: 0.65),
                          ),
                          child: isGenerating
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: AppColors.highlighter, strokeWidth: 2.5),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Building your schedule...',
                                      style: TextStyle(color: AppColors.onInk, fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ],
                                )
                              : const Text('Generate 7-Day Plan'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onInk,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(studyPlanNotifierProvider.notifier).deletePlan(planId);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
