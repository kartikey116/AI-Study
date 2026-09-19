import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('My Documents', style: AppTypography.heading3),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: docsState.when(
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: AppSpacing.md),
                  Text('No documents yet', style: AppTypography.bodyLarge),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(documentsProvider.notifier).fetchDocuments(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _DocumentCard(document: doc);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickAndUpload(context, ref),
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Upload PDF'),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title & Info + Status Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${(document.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB • ${document.pageCount ?? 0} Pages',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 12),
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
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _DocActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Ask AI',
                    color: const Color(0xFF6366F1),
                    bgColor: const Color(0xFFEEF2FF),
                    onTap: () => context.push('/chat?documentId=${document.id}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DocActionButton(
                    icon: Icons.quiz_outlined,
                    label: 'Quiz',
                    color: AppColors.primary,
                    bgColor: const Color(0xFFF3E8FF),
                    onTap: () => context.push('/quiz-setup?documentId=${document.id}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DocActionButton(
                    icon: Icons.style_outlined,
                    label: 'Cards',
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Generate Flashcards'),
        content: Text('Generate 10 spaced-repetition flashcards from "${document.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
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
                  CircularProgressIndicator(color: Color(0xFFD97706)),
                  SizedBox(height: 16),
                  Text('Generating Flashcards with AI...'),
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
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'PROCESSING':
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'FAILED':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      default: // UPLOADING
        bgColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
