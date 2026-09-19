import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

// ──────────────────────────────────────────────────────────────────────────────
// LaTeX pre-processor
// Converts $...$ and $$...$$ into custom code-fence markers so that a single
// MarkdownBody call can handle ALL markdown syntax (headings, code-blocks,
// blockquotes, HR, etc.) without any fragmentation.
// ──────────────────────────────────────────────────────────────────────────────

String _preprocessLatex(String text) {
  // Block math:  $$...$$  →  ```blockmath\n...\n```
  String out = text.replaceAllMapped(
    RegExp(r'\$\$([\s\S]*?)\$\$'),
    (m) => '\n\n```blockmath\n${m.group(1)!.trim()}\n```\n\n',
  );
  // Inline math: $...$ → `inlinemath:...`
  out = out.replaceAllMapped(
    RegExp(r'\$([^\$\n]+?)\$'),
    (m) => '`inlinemath:${m.group(1)}`',
  );
  return out;
}

// ──────────────────────────────────────────────────────────────────────────────
// Custom MarkdownElementBuilder – intercepts our math code fences
// ──────────────────────────────────────────────────────────────────────────────

class _MathCodeBuilder extends MarkdownElementBuilder {
  final TextStyle? textStyle;
  _MathCodeBuilder({this.textStyle});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent.trim();

    // Inline math: `inlinemath:...`
    if (element.tag == 'code' && text.startsWith('inlinemath:')) {
      final formula = text.substring('inlinemath:'.length);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Math.tex(
          formula,
          textStyle: textStyle ?? const TextStyle(fontSize: 14),
          onErrorFallback: (_) =>
              Text(r'$' + formula + r'$', style: textStyle?.copyWith(fontFamily: 'monospace')),
        ),
      );
    }

    // Block math: ```blockmath\n...\n```
    if (element.tag == 'code' &&
        element.attributes['class'] == 'language-blockmath') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Math.tex(
            text,
            textStyle: (textStyle ?? const TextStyle(fontSize: 14)).copyWith(fontSize: 18),
            onErrorFallback: (_) =>
                Text(r'$$' + text + r'$$', style: textStyle?.copyWith(fontFamily: 'monospace')),
          ),
        ),
      );
    }

    return null; // Let flutter_markdown handle everything else normally
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Main AI message bubble
// ──────────────────────────────────────────────────────────────────────────────

class AiMessageBubble extends StatelessWidget {
  final String text;
  final bool isStreaming;
  final String? timestamp;

  const AiMessageBubble({
    super.key,
    required this.text,
    this.isStreaming = false,
    this.timestamp,
  });

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final processed = _preprocessLatex(text.isEmpty ? ' ' : text);
    final bodyStyle = AppTypography.bodyLarge;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, right: 36.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Robot Avatar
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFF3E8FF),
            child: Icon(Icons.smart_toy_rounded, color: Color(0xFF8B5CF6), size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clean White Message Bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: processed,
                    selectable: true,
                    extensionSet: md.ExtensionSet.gitHubFlavored,
                    builders: {
                      'code': _MathCodeBuilder(textStyle: bodyStyle),
                    },
                    styleSheet: MarkdownStyleSheet(
                      p: bodyStyle.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                        fontSize: 14.5,
                      ),
                      h1: bodyStyle.copyWith(
                          fontSize: 20, fontWeight: FontWeight.bold, height: 1.4, color: AppColors.textPrimary),
                      h2: bodyStyle.copyWith(
                          fontSize: 18, fontWeight: FontWeight.bold, height: 1.4, color: AppColors.textPrimary),
                      h3: bodyStyle.copyWith(
                          fontSize: 15, fontWeight: FontWeight.w700, height: 1.4, color: AppColors.textPrimary),
                      codeblockPadding: const EdgeInsets.all(12),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      code: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        color: Color(0xFF38BDF8),
                      ),
                      blockquote: bodyStyle.copyWith(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                      blockquoteDecoration: BoxDecoration(
                        border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      listBullet: bodyStyle.copyWith(color: AppColors.primary),
                      strong: bodyStyle.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                ),

                // Timestamp below bubble
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timestamp ?? '9:41 AM',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                      if (!isStreaming && text.isNotEmpty)
                        GestureDetector(
                          onTap: () => _copy(context),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.copy_outlined, size: 12, color: Colors.grey.shade400),
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
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Pulsing typing indicator dots
// ──────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final int delay;
  const _PulsingDot({required this.delay});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.delay > 0) {
      _ctrl.stop();
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _ctrl.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Typing / Thinking Indicator Bubble
// ──────────────────────────────────────────────────────────────────────────────

class AiTypingIndicator extends StatelessWidget {
  const AiTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, right: 48.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFF3E8FF),
            child: Icon(Icons.smart_toy_rounded, color: Color(0xFF8B5CF6), size: 19),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(delay: 0),
                SizedBox(width: 5),
                _PulsingDot(delay: 200),
                SizedBox(width: 5),
                _PulsingDot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// User message bubble
// ──────────────────────────────────────────────────────────────────────────────

class UserMessageBubble extends StatelessWidget {
  final String text;
  final String? timestamp;

  const UserMessageBubble({
    super.key,
    required this.text,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 48.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDE9FE), // Soft Lavender
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Text(
                    timestamp ?? '9:42 AM',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            child: Icon(Icons.person_rounded, size: 18, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
