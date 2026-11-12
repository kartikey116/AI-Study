import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import 'math_markdown.dart';

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
    // No bubble: the reply reads like notes on the page, using the full width.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssistantHeader(timestamp: timestamp),
          const SizedBox(height: 8),
          MathMarkdown(data: text, selectable: true),
          if (!isStreaming && text.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => _copy(context),
                tooltip: 'Copy reply',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// "S" monogram + "STUDYAI · 3:32 PM" above each assistant reply.
class _AssistantHeader extends StatelessWidget {
  final String? timestamp;
  const _AssistantHeader({this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AssistantMonogram(size: 28),
        const SizedBox(width: 10),
        Text(
          timestamp == null ? 'STUDYAI' : 'STUDYAI · $timestamp',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// "3:32 PM" for today, "24 Oct · 3:32 PM" for older messages.
String formatMessageTime(BuildContext context, DateTime time) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final local = time.toLocal();
  final now = DateTime.now();
  final clock = TimeOfDay.fromDateTime(local).format(context);
  final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
  return sameDay ? clock : '${local.day} ${months[local.month - 1]} · $clock';
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
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AssistantHeader(),
          const SizedBox(height: 12),
          Semantics(
            label: 'Assistant is writing',
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
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: Text(
                      timestamp!,
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
