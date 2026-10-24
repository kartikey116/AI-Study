import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/components/message_bubbles.dart';
import '../../../../core/layout/main_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../documents/data/models/document_model.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../providers/chat_provider.dart';

enum ChatContextMode { general, allDocs, specificDoc }

class AiAssistantScreen extends ConsumerStatefulWidget {
  final String? initialDocumentId;
  const AiAssistantScreen({super.key, this.initialDocumentId});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatContextMode _contextMode = ChatContextMode.general;
  Document? _selectedDocument;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocumentId != null) {
      _contextMode = ChatContextMode.specificDoc;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final docsAsync = ref.read(documentsProvider);
        docsAsync.whenData((docs) {
          final found = docs.where((d) => d.id == widget.initialDocumentId).firstOrNull;
          if (found != null && mounted) {
            setState(() {
              _selectedDocument = found;
              _contextMode = ChatContextMode.specificDoc;
            });
          }
        });
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage([String? suggestedPrompt]) {
    final text = suggestedPrompt ?? _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    String? docId;
    if (_contextMode == ChatContextMode.specificDoc) {
      docId = _selectedDocument?.id;
    } else if (_contextMode == ChatContextMode.allDocs) {
      docId = 'ALL';
    } else {
      docId = 'GENERAL';
    }

    ref.read(chatProvider.notifier).sendMessage(text, documentId: docId);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _confirmNewChat(BuildContext context) {
    final chatState = ref.read(chatProvider);
    if (chatState.messages.isEmpty) {
      ref.read(chatProvider.notifier).startNewChat();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new chat?'),
        content: const Text('Your current conversation is saved in history. Start a fresh chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatProvider.notifier).startNewChat();
            },
            child: const Text('New chat'),
          ),
        ],
      ),
    );
  }

  void _showHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('History', style: AppTypography.heading3),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmNewChat(context);
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New chat'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: FutureBuilder<List<dynamic>>(
                  future: ref.read(chatRepositoryProvider).getConversations(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No previous conversations yet.\nAsk a question to start your study history.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final conv = snapshot.data![index];
                        final title = conv['title'] ?? 'Study Session';
                        final count = conv['_count']?['messages'] ?? 0;
                        return ListTile(
                          minVerticalPadding: 12,
                          leading: const _IconBadge(
                            icon: Icons.chat_bubble_outline_rounded,
                            color: AppColors.primary,
                            bgColor: AppColors.primarySoft,
                          ),
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.title),
                          subtitle: Text(
                            '$count messages',
                            style: AppTypography.mono.copyWith(fontSize: 12, color: AppColors.textMuted),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
                          onTap: () {
                            Navigator.pop(ctx);
                            ref.read(chatProvider.notifier).loadConversation(conv['id']);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final docsAsync = ref.watch(documentsProvider);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Study context', style: AppTypography.heading3),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _contextMode = ChatContextMode.general;
                            _selectedDocument = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Option 1: General Study
                ListTile(
                  minVerticalPadding: 12,
                  leading: const _IconBadge(
                    icon: Icons.public_rounded,
                    color: AppColors.info,
                    bgColor: AppColors.infoSoft,
                  ),
                  title: Text('General study', style: AppTypography.title),
                  subtitle: Text(
                    'Any topic, formula or concept — e.g. "What is SQL?"',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: _contextMode == ChatContextMode.general
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.ink)
                      : null,
                  onTap: () {
                    setState(() {
                      _contextMode = ChatContextMode.general;
                      _selectedDocument = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
                // Option 2: All Documents
                ListTile(
                  minVerticalPadding: 12,
                  leading: const _IconBadge(
                    icon: Icons.library_books_rounded,
                    color: AppColors.primary,
                    bgColor: AppColors.primarySoft,
                  ),
                  title: Text('All my documents', style: AppTypography.title),
                  subtitle: Text('Search across every PDF you uploaded', style: AppTypography.bodySmall),
                  trailing: _contextMode == ChatContextMode.allDocs
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.ink)
                      : null,
                  onTap: () {
                    setState(() {
                      _contextMode = ChatContextMode.allDocs;
                      _selectedDocument = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Text('OR PICK ONE PDF', style: AppTypography.label),
                ),
                // Option 3: Specific Docs
                Flexible(
                  child: docsAsync.when(
                    data: (docs) {
                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Text(
                            'No uploaded documents yet. Upload PDFs in the Docs tab.',
                            style: AppTypography.bodyMedium,
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final isSelected = _contextMode == ChatContextMode.specificDoc && _selectedDocument?.id == doc.id;
                          final isReady = doc.status == 'READY';

                          return ListTile(
                            leading: _IconBadge(
                              icon: Icons.description_rounded,
                              color: isReady ? AppColors.success : AppColors.warning,
                              bgColor: isReady ? AppColors.successSoft : AppColors.warningSoft,
                            ),
                            title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.title),
                            subtitle: Text(
                              '${doc.status} · ${doc.pageCount ?? 0} pp',
                              style: AppTypography.mono.copyWith(fontSize: 12, color: AppColors.textMuted),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.ink)
                                : (!isReady
                                    ? Text(
                                        'PROCESSING',
                                        style: AppTypography.label.copyWith(color: AppColors.warning, fontSize: 10),
                                      )
                                    : null),
                            enabled: isReady,
                            onTap: () {
                              setState(() {
                                _contextMode = ChatContextMode.specificDoc;
                                _selectedDocument = doc;
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error: $e', style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final String firstName = user?.profile?.firstName?.isNotEmpty == true
        ? user!.profile!.firstName!
        : (user?.email.split('@').first ?? 'kartikey');

    final chatState = ref.watch(chatProvider);

    // Auto-scroll when new messages arrive or while streaming
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    final isAllDocs = _contextMode == ChatContextMode.allDocs;
    final isSpecificDoc = _contextMode == ChatContextMode.specificDoc;

    final String contextTitle = isSpecificDoc
        ? (_selectedDocument?.name ?? 'Selected PDF')
        : (isAllDocs ? 'All documents' : 'General study');

    return MainLayout(
      currentIndex: 2,
      child: Container(
        color: AppColors.paper,
        child: Column(
          children: [
            // ── 1. Header: Back + Monogram + Title/Status + Actions ─────────
            Container(
              padding: EdgeInsets.fromLTRB(
                8,
                MediaQuery.of(context).padding.top + 6,
                4,
                10,
              ),
              decoration: const BoxDecoration(
                color: AppColors.paper,
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                  ),

                  const SizedBox(width: 2),
                  const AssistantMonogram(size: 38),
                  const SizedBox(width: 12),

                  // Title & Status (Online / Writing)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Study Assistant', style: AppTypography.heading3.copyWith(fontSize: 19)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: chatState.isLoading ? AppColors.highlighter : AppColors.success,
                                shape: BoxShape.circle,
                                border: chatState.isLoading ? Border.all(color: AppColors.ink, width: 0.8) : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              chatState.isLoading ? 'WRITING…' : 'ONLINE',
                              style: AppTypography.label.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions: History, New Chat, More Options
                  IconButton(
                    tooltip: 'Chat history',
                    onPressed: () => _showHistorySheet(context),
                    icon: const Icon(Icons.history_rounded, color: AppColors.ink, size: 22),
                  ),
                  IconButton(
                    tooltip: 'New chat',
                    onPressed: () => _confirmNewChat(context),
                    icon: const Icon(Icons.add_comment_outlined, color: AppColors.ink, size: 21),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink, size: 22),
                    color: AppColors.surface,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    onSelected: (val) {
                      if (val == 'clear') {
                        ref.read(chatProvider.notifier).startNewChat();
                      } else if (val == 'context') {
                        _showDocumentSelector(context);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                            const SizedBox(width: 10),
                            Text(
                              'Clear conversation',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'context',
                        child: Row(
                          children: [
                            const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 10),
                            Text(
                              'Change context',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 2. Context Selector Bar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Text('CONTEXT', style: AppTypography.label),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Change study context, currently $contextTitle',
                      excludeSemantics: true,
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: InkWell(
                          onTap: () => _showDocumentSelector(context),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSpecificDoc
                                      ? Icons.description_rounded
                                      : (isAllDocs ? Icons.library_books_rounded : Icons.public_rounded),
                                  size: 16,
                                  color: isSpecificDoc
                                      ? AppColors.success
                                      : (isAllDocs ? AppColors.primary : AppColors.info),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    contextTitle,
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.unfold_more_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error Banner
            if (chatState.error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: const Border(left: BorderSide(color: AppColors.error, width: 3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatState.error!,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(chatProvider.notifier).retryLastMessage(documentId: _selectedDocument?.id),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),

            // ── 3. Chat Messages Area ───────────────────────────────────────
            Expanded(
              child: chatState.messages.isEmpty
                  ? ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      children: [
                        AiMessageBubble(
                          text: "Hi $firstName.\nI'm your study assistant. I can explain concepts, summarise your notes, write practice questions and more. What are you working on today?",
                          timestamp: TimeOfDay.now().format(context),
                        ),
                        if (chatState.isLoading && (chatState.streamingText?.isEmpty ?? true))
                          const AiTypingIndicator()
                        else if (chatState.streamingText != null && chatState.streamingText!.isNotEmpty)
                          AiMessageBubble(
                            text: chatState.streamingText!,
                            isStreaming: true,
                          ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: chatState.messages.length +
                          ((chatState.streamingText != null && chatState.streamingText!.isNotEmpty) ? 1 : 0) +
                          ((chatState.isLoading && (chatState.streamingText?.isEmpty ?? true)) ? 1 : 0),
                      itemBuilder: (context, index) {
                        // 1. Check if streaming bubble at end
                        if (index == chatState.messages.length &&
                            chatState.streamingText != null &&
                            chatState.streamingText!.isNotEmpty) {
                          return AiMessageBubble(
                            text: chatState.streamingText!,
                            isStreaming: true,
                          );
                        }

                        // 2. Check if typing indicator dots at end
                        if (index == chatState.messages.length + ((chatState.streamingText != null && chatState.streamingText!.isNotEmpty) ? 1 : 0)) {
                          return const AiTypingIndicator();
                        }

                        final msg = chatState.messages[index];
                        if (!msg.isUser) {
                          return AiMessageBubble(
                            text: msg.content,
                            isStreaming: false,
                          );
                        } else {
                          return UserMessageBubble(
                            text: msg.content,
                          );
                        }
                      },
                    ),
            ),

            // ── 4. Suggested Prompts Row ────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Row(
                children: [
                  _SuggestedPromptChip(
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Explain this simply',
                    onTap: () => _sendMessage('Can you explain this simply?'),
                  ),
                  const SizedBox(width: 8),
                  _SuggestedPromptChip(
                    icon: Icons.menu_book_outlined,
                    label: 'Give me an example',
                    onTap: () => _sendMessage('Can you give me a clear real-world example?'),
                  ),
                  const SizedBox(width: 8),
                  _SuggestedPromptChip(
                    icon: Icons.quiz_outlined,
                    label: 'Test me',
                    onTap: () => _sendMessage('Test me with a quick practice question!'),
                  ),
                ],
              ),
            ),

            // ── 5. Composer: Attach + Field + Send ──────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Choose documents for context',
                    onPressed: () => _showDocumentSelector(context),
                    icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary, size: 22),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: TextField(
                        controller: _controller,
                        enabled: !chatState.isLoading,
                        onSubmitted: (_) => _sendMessage(),
                        minLines: 1,
                        maxLines: 4,
                        textAlignVertical: TextAlignVertical.center,
                        style: AppTypography.bodyLarge.copyWith(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: chatState.isLoading
                              ? 'Writing a reply…'
                              : 'Ask a study question…',
                          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: false,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Ink square send button
                  Semantics(
                    button: true,
                    enabled: !chatState.isLoading,
                    label: 'Send message',
                    child: Material(
                      color: chatState.isLoading ? AppColors.lineStrong : AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        onTap: chatState.isLoading ? null : () => _sendMessage(),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: chatState.isLoading ? AppColors.textMuted : AppColors.highlighter,
                            size: 22,
                          ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-sheet drag handle
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.lineStrong,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rounded-square icon badge used in sheet list rows
// ─────────────────────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _IconBadge({required this.icon, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggested Prompt Chip
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestedPromptChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestedPromptChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
