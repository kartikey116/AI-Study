import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Start New Chat?'),
        content: const Text('Your current conversation is automatically saved in history. Start a fresh chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatProvider.notifier).startNewChat();
            },
            child: const Text('New Chat'),
          ),
        ],
      ),
    );
  }

  void _showHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chat History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmNewChat(context);
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Chat'),
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
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No previous conversations found.\nAsk questions to build your study history!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final conv = snapshot.data![index];
                        final title = conv['title'] ?? 'Study Session';
                        final count = conv['_count']?['messages'] ?? 0;
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF3E8FF),
                            child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 18),
                          ),
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('$count messages'),
                          trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final docsAsync = ref.watch(documentsProvider);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Study Context',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _contextMode = ChatContextMode.general;
                            _selectedDocument = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset to General'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Option 1: General Study
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.public_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  title: const Text('General Study (AI Knowledge)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Ask any topic, formula, or concept (e.g. What is SQL?)'),
                  trailing: _contextMode == ChatContextMode.general ? const Icon(Icons.check_circle, color: Color(0xFF2563EB)) : null,
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
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEDE9FE),
                    child: Icon(Icons.library_books_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: const Text('All Uploaded Documents', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Search across all your uploaded PDFs'),
                  trailing: _contextMode == ChatContextMode.allDocs ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() {
                      _contextMode = ChatContextMode.allDocs;
                      _selectedDocument = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    'OR SELECT A SPECIFIC PDF',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                // Option 3: Specific Docs
                Flexible(
                  child: docsAsync.when(
                    data: (docs) {
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No uploaded documents found. Upload PDFs in the Documents tab.'),
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
                            leading: CircleAvatar(
                              backgroundColor: isReady ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                              child: Icon(
                                Icons.description_rounded,
                                color: isReady ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${doc.status} • ${doc.pageCount ?? 0} pages'),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : (!isReady ? const Text('Processing', style: TextStyle(color: Colors.orange, fontSize: 11)) : null),
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
                    error: (e, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Error: $e')),
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
        : (isAllDocs ? 'All Documents' : 'General Study (AI)');

    return MainLayout(
      currentIndex: 2,
      child: Container(
        color: const Color(0xFFF7F6FD),
        child: Column(
          children: [
            // ── 1. Gradient Header: Back + AI Tutor + Online Dot + Actions ─
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 8,
                16,
                14,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7C3AED),
                    Color(0xFFB06EF5),
                    Color(0xFFF472B6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // Circular Back Button
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF1E1B4B),
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Circular Sparkle Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Title & Status (Online / Typing)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Tutor',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: chatState.isLoading ? Colors.amberAccent : const Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              chatState.isLoading ? 'Typing...' : 'Online',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions: History, New Chat, More Options
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _showHistorySheet(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () => _confirmNewChat(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.add_comment_outlined, color: Colors.white, size: 21),
                        ),
                      ),
                      const SizedBox(width: 2),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                        padding: EdgeInsets.zero,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val == 'clear') {
                            ref.read(chatProvider.notifier).startNewChat();
                          } else if (val == 'context') {
                            _showDocumentSelector(context);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'clear',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                SizedBox(width: 8),
                                Text('Clear Conversation', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'context',
                            child: Row(
                              children: [
                                Icon(Icons.tune_rounded, size: 18, color: Color(0xFF475569)),
                                SizedBox(width: 8),
                                Text('Change Context', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
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
                  const Icon(Icons.tune_rounded, size: 17, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  const Text(
                    'Context:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showDocumentSelector(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSpecificDoc
                                  ? Icons.description_rounded
                                  : (isAllDocs ? Icons.library_books_rounded : Icons.public_rounded),
                              size: 14,
                              color: isSpecificDoc
                                  ? const Color(0xFF059669)
                                  : (isAllDocs ? const Color(0xFF7C3AED) : const Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                contextTitle,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A8A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: Color(0xFF2563EB),
                            ),
                          ],
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatState.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(chatProvider.notifier).retryLastMessage(documentId: _selectedDocument?.id),
                      child: const Text('Retry', style: TextStyle(color: Colors.red, fontSize: 12)),
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
                        // Initial welcome bubble matching the design screenshot
                        AiMessageBubble(
                          text: "Hi $firstName! 👋\nI'm your AI study assistant. I can help you understand concepts, create notes, generate quizzes, and more. What would you like to learn today?",
                          timestamp: '9:41 AM',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SuggestedPromptChip(
                      icon: '💡',
                      label: 'Explain this simply',
                      onTap: () => _sendMessage('Can you explain this simply?'),
                    ),
                    const SizedBox(width: 8),
                    _SuggestedPromptChip(
                      icon: '📄',
                      label: 'Give me an example',
                      onTap: () => _sendMessage('Can you give me a clear real-world example?'),
                    ),
                    const SizedBox(width: 8),
                    _SuggestedPromptChip(
                      icon: '❓',
                      label: 'Test me',
                      onTap: () => _sendMessage('Test me with a quick practice question!'),
                    ),
                  ],
                ),
              ),
            ),

            // ── 5. Input Bar: Paperclip + Pill Input with Mic + Send Button ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              color: Colors.transparent,
              child: Row(
                children: [
                  // Attachment Paperclip Icon
                  GestureDetector(
                    onTap: () => _showDocumentSelector(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: const Icon(
                        Icons.attach_file_rounded,
                        color: Color(0xFF64748B),
                        size: 24,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Input Pill - Full Width Container
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: TextField(
                        controller: _controller,
                        enabled: !chatState.isLoading,
                        onSubmitted: (_) => _sendMessage(),
                        minLines: 1,
                        maxLines: 4,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: chatState.isLoading
                              ? 'Thinking...'
                              : 'Ask any study question...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          isDense: false,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Circular Purple Gradient Send Button
                  GestureDetector(
                    onTap: chatState.isLoading ? null : () => _sendMessage(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF7C3AED),
                            Color(0xFF9333EA),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: chatState.isLoading ? Colors.white54 : Colors.white,
                          size: 19,
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
// Suggested Prompt Pill Chip
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestedPromptChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestedPromptChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
