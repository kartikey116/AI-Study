import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

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
          const AssistantMonogram(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clean White Message Bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                    border: Border.all(color: AppColors.line),
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
                        height: 1.55,
                        fontSize: 15,
                      ),
                      h1: AppTypography.heading3.copyWith(fontSize: 21, height: 1.3),
                      h2: AppTypography.heading3.copyWith(fontSize: 18, height: 1.3),
                      h3: bodyStyle.copyWith(
                          fontSize: 15, fontWeight: FontWeight.w700, height: 1.4, color: AppColors.textPrimary),
                      codeblockPadding: const EdgeInsets.all(12),
                      codeblockDecoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      code: AppTypography.mono.copyWith(
                        fontSize: 12.5,
                        color: AppColors.highlighter,
                        backgroundColor: Colors.transparent,
                      ),
                      blockquote: bodyStyle.copyWith(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                      blockquoteDecoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: AppColors.highlighter, width: 3)),
                        color: AppColors.paper,
                      ),
                      listBullet: bodyStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                      strong: bodyStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        backgroundColor: AppColors.highlighterSoft,
                      ),
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
                        style: AppTypography.label.copyWith(fontSize: 10, letterSpacing: 0.4),
                      ),
                      if (!isStreaming && text.isNotEmpty)
                        IconButton(
                          onPressed: () => _copy(context),
                          tooltip: 'Copy reply',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
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
          color: AppColors.ink,
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
          const AssistantMonogram(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.line),
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
                    color: AppColors.ink,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.lg),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Text(
                    text,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.onInk,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Text(
                    timestamp ?? '9:42 AM',
                    style: AppTypography.label.copyWith(fontSize: 10, letterSpacing: 0.4),
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
// Assistant monogram — a serif "S" stamp instead of a robot icon
// ──────────────────────────────────────────────────────────────────────────────

class AssistantMonogram extends StatelessWidget {
  final double size;
  const AssistantMonogram({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.highlighter,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Text(
        'S',
        style: AppTypography.heading3.copyWith(fontSize: size * 0.55, height: 1),
      ),
    );
  }
}
