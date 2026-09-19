import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(quizGenerationProvider).isLoading;
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Generate Quiz', style: AppTypography.heading3),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/quizzes'),
            icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
            label: const Text('Past Quizzes', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Source Material Selection ────────────────────────────────
            Text('Source Material', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose whether to quiz from a specific uploaded PDF or general AI knowledge.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            docsAsync.when(
              data: (docs) {
                final readyDocs = docs.where((d) => d.status == 'READY').toList();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedDocumentId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              Icon(Icons.public, size: 18, color: Colors.blue),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text('General Topic (AI Generates from Subject)',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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

            Text('Quiz Details', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Quiz Title',
                hintText: 'e.g., Cellular Biology Ch. 2',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Subject / Topic',
                hintText: 'e.g., Biology',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            Text('Difficulty', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _buildDifficultyCard(
                  value: 'Easy',
                  label: 'Easy',
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  activeColor: AppColors.success,
                ),
                const SizedBox(width: 12),
                _buildDifficultyCard(
                  value: 'Medium',
                  label: 'Medium',
                  icon: Icons.tune_rounded,
                  activeColor: AppColors.warning,
                ),
                const SizedBox(width: 12),
                _buildDifficultyCard(
                  value: 'Hard',
                  label: 'Hard',
                  icon: Icons.local_fire_department_rounded,
                  activeColor: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Number of Questions: ${_numQuestions.toInt()}', style: AppTypography.heading3),
            Slider(
              value: _numQuestions,
              min: 5,
              max: 20,
              divisions: 3,
              label: _numQuestions.round().toString(),
              activeColor: AppColors.primary,
              onChanged: (double value) {
                setState(() => _numQuestions = value);
              },
            ),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Generate with AI', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
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
      child: InkWell(
        onTap: () {
          setState(() {
            _difficulty = value;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : Colors.grey.shade400,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  color: isSelected ? activeColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
