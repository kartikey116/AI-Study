import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../providers/quiz_provider.dart';

class QuizSetupScreen extends ConsumerStatefulWidget {
  final String? documentId;
  const QuizSetupScreen({super.key, this.documentId});

  @override
  ConsumerState<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends ConsumerState<QuizSetupScreen> {
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  String _difficulty = 'Medium';
  double _numQuestions = 5;
  String? _selectedDocumentId;

  @override
  void initState() {
    super.initState();
    _selectedDocumentId = widget.documentId;
    if (_selectedDocumentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final docsAsync = ref.read(documentsProvider);
        docsAsync.whenData((docs) {
          final doc = docs.where((d) => d.id == _selectedDocumentId).firstOrNull;
          if (doc != null && mounted) {
            final cleanName = doc.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
            if (_titleController.text.isEmpty) _titleController.text = '$cleanName Quiz';
            if (_subjectController.text.isEmpty) _subjectController.text = cleanName;
            setState(() {});
          }
        });
      });
    }
  }

  Widget _sectionLabel(String number, String text) {
    return Row(
      children: [
        Text(number, style: AppTypography.label.copyWith(color: AppColors.primary)),
        const SizedBox(width: 8),
        Text(text.toUpperCase(), style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(quizGenerationProvider).isLoading;
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('New quiz', style: AppTypography.heading3),
        backgroundColor: AppColors.paper,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/quizzes'),
            icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
            label: Text(
              'Past quizzes',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Build a practice set', style: AppTypography.heading1.copyWith(fontSize: 28)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pick a source, set the difficulty, and get a fresh set of questions.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Source Material Selection ────────────────────────────────
            _sectionLabel('01', 'Source material'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Quiz from one of your uploaded PDFs, or from general knowledge on a subject.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            docsAsync.when(
              data: (docs) {
                final readyDocs = docs.where((d) => d.status == 'READY').toList();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedDocumentId,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              const Icon(Icons.public_rounded, size: 18, color: AppColors.info),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('General topic (from subject)',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                              ),
                            ],
                          ),
                        ),
                        ...readyDocs.map((doc) => DropdownMenuItem<String?>(
                              value: doc.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.description_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text('PDF: ${doc.name} (${doc.pageCount ?? 0}p)',
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedDocumentId = val);
                        if (val != null) {
                          final doc = readyDocs.where((d) => d.id == val).firstOrNull;
                          if (doc != null) {
                            final cleanName = doc.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                            _titleController.text = '$cleanName Quiz';
                            _subjectController.text = cleanName;
                          }
                        }
                      },
                    ),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.xl),

            _sectionLabel('02', 'Quiz details'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Quiz title',
                hintText: 'e.g., Cellular Biology Ch. 2',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject / topic',
                hintText: 'e.g., Biology',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            _sectionLabel('03', 'Difficulty'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _buildDifficultyCard(
                  value: 'Easy',
                  label: 'Easy',
                  icon: Icons.spa_outlined,
                  activeColor: AppColors.success,
                ),
                const SizedBox(width: 10),
                _buildDifficultyCard(
                  value: 'Medium',
                  label: 'Medium',
                  icon: Icons.tune_rounded,
                  activeColor: AppColors.warning,
                ),
                const SizedBox(width: 10),
                _buildDifficultyCard(
                  value: 'Hard',
                  label: 'Hard',
                  icon: Icons.local_fire_department_outlined,
                  activeColor: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            _sectionLabel('04', 'Length'),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${_numQuestions.toInt()}', style: AppTypography.heading1),
                const SizedBox(width: 8),
                Text('questions', style: AppTypography.bodyMedium),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.ink,
                inactiveTrackColor: AppColors.surfaceSunken,
                thumbColor: AppColors.highlighter,
                overlayColor: AppColors.highlighter.withValues(alpha: 0.2),
                activeTickMarkColor: AppColors.highlighter,
                inactiveTickMarkColor: AppColors.lineStrong,
                valueIndicatorColor: AppColors.ink,
                valueIndicatorTextStyle: AppTypography.mono.copyWith(color: AppColors.onInk),
              ),
              child: Slider(
                value: _numQuestions,
                min: 5,
                max: 20,
                divisions: 3,
                label: _numQuestions.round().toString(),
                onChanged: (double value) {
                  setState(() => _numQuestions = value);
                },
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _generate,
                icon: isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.bolt_rounded, color: AppColors.highlighter),
                label: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: AppColors.highlighter, strokeWidth: 2.5),
                      )
                    : Text('Generate quiz', style: AppTypography.button.copyWith(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (_titleController.text.isEmpty || _subjectController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      final res = await ref.read(quizGenerationProvider.notifier).generate(
        _titleController.text,
        _subjectController.text,
        _difficulty,
        _selectedDocumentId,
        _numQuestions.toInt()
      );
      ref.invalidate(quizzesProvider);
      ref.invalidate(activeQuizIdsProvider);
      if (mounted) {
        context.pushReplacement('/quiz/${res['quizId']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildDifficultyCard({
    required String value,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _difficulty == value;
    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: () {
            setState(() {
              _difficulty = value;
            });
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.highlighterSoft : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isSelected ? AppColors.ink : AppColors.line,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected ? AppShadows.hardSmall : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? activeColor : AppColors.textMuted,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.ink : AppColors.textSecondary,
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
