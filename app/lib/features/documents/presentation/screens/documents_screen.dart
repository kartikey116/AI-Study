import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/components/empty_state.dart';
import '../providers/documents_provider.dart';
import '../../../flashcard/presentation/providers/flashcard_provider.dart';
import '../../data/models/document_model.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        await ref.read(documentsProvider.notifier).uploadDocument(file, fileName);
        if (context.mounted) {
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully. Processing started.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsState = ref.watch(documentsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Documents', style: AppTypography.heading2),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: docsState.when(
        data: (docs) {
          if (docs.isEmpty) {
            return EmptyState(
              icon: Icons.upload_file_rounded,
              title: 'No documents yet',
              message: 'Upload a PDF of your notes or textbook to ask questions, build quizzes and make flashcards from it.',
              buttonText: 'Upload a PDF',
              onAction: () => _pickAndUpload(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(documentsProvider.notifier).fetchDocuments(),
            color: AppColors.ink,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              itemCount: docs.length + 1,
              separatorBuilder: (_, index) => SizedBox(height: index == 0 ? AppSpacing.sm : AppSpacing.md),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final ready = docs.where((d) => d.status == 'READY').length;
                  return Text(
                    'LIBRARY · ${docs.length} PDF${docs.length == 1 ? '' : 'S'} · $ready READY',
                    style: AppTypography.label,
                  );
                }
                final doc = docs[index - 1];
                return _DocumentCard(document: doc);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Error: $e', style: AppTypography.bodyMedium, textAlign: TextAlign.center),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickAndUpload(context, ref),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.onInk,
        icon: const Icon(Icons.upload_file_rounded, color: AppColors.highlighter),
        label: Text('Upload PDF', style: AppTypography.button),
      ),
    );
  }
}

class _DocumentCard extends ConsumerWidget {
  final Document document;

  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title & Info + Status Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.lineStrong),
                ),
                child: Text(
                  'PDF',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: AppTypography.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(document.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB · ${document.pageCount ?? 0} pp',
                      style: AppTypography.mono.copyWith(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(document.status),
            ],
          ),

          // Action Buttons: Spanned evenly across card width when READY
          if (document.status == 'READY') ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _DocActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Ask',
                    color: AppColors.onInk,
                    bgColor: AppColors.ink,
                    onTap: () => context.push('/chat?documentId=${document.id}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DocActionButton(
                    icon: Icons.quiz_outlined,
                    label: 'Quiz',
                    color: AppColors.primary,
                    bgColor: AppColors.primarySoft,
                    onTap: () => context.push('/quiz-setup?documentId=${document.id}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DocActionButton(
                    icon: Icons.style_outlined,
                    label: 'Cards',
                    color: AppColors.ink,
                    bgColor: AppColors.highlighterSoft,
                    onTap: () => _handleFlashcards(context, ref, document),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleFlashcards(BuildContext context, WidgetRef ref, Document document) async {
    final cleanName = document.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate flashcards'),
        content: Text('Generate 10 spaced-repetition flashcards from "${document.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.ink),
                  SizedBox(height: 16),
                  Text('Writing your flashcards…'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final res = await ref.read(flashcardRepositoryProvider).generateDeck(
          '$cleanName Deck',
          document.id,
          10,
        );
        ref.invalidate(decksProvider);
        if (context.mounted) {
          Navigator.pop(context); // close loading
          context.push('/flashcard/${res['deckId']}');
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to generate flashcards: $e')),
          );
        }
      }
    }
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'READY':
        bgColor = AppColors.successSoft;
        textColor = AppColors.success;
        break;
      case 'PROCESSING':
        bgColor = AppColors.warningSoft;
        textColor = AppColors.warning;
        break;
      case 'FAILED':
        bgColor = AppColors.errorSoft;
        textColor = AppColors.error;
        break;
      default: // UPLOADING
        bgColor = AppColors.infoSoft;
        textColor = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        status,
        style: AppTypography.label.copyWith(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DocActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _DocActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color == AppColors.onInk ? AppColors.highlighter : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
