import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

// ──────────────────────────────────────────────────────────────────────────────
// LaTeX pre-processor
// Converts $$…$$ / \[…\] and $…$ / \(…\) into inline-code markers that
// _MathBuilder renders with flutter_math. Block math deliberately does NOT use
// a fenced code block: flutter_markdown always wraps `pre` in the code-block
// decoration, which showed up as an empty dark box around the equation.
// ──────────────────────────────────────────────────────────────────────────────

const _blockPrefix = 'blockmath:';
const _inlinePrefix = 'inlinemath:';

String _codeSafe(String formula) => formula.replaceAll('`', "'").replaceAll('\n', ' ').trim();

String preprocessLatex(String text) {
  String out = text.replaceAllMapped(
    RegExp(r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]'),
    (m) => '\n\n`$_blockPrefix${_codeSafe(m.group(1) ?? m.group(2)!)}`\n\n',
  );
  out = out.replaceAllMapped(
    RegExp(r'\\\(([\s\S]+?)\\\)|\$([^\$\n]+?)\$'),
    (m) => '`$_inlinePrefix${_codeSafe(m.group(1) ?? m.group(2)!)}`',
  );
  return out;
}

class _MathBuilder extends MarkdownElementBuilder {
  final TextStyle textStyle;
  _MathBuilder(this.textStyle);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'code') return null;
    final text = element.textContent.trim();

    if (text.startsWith(_inlinePrefix)) {
      final formula = text.substring(_inlinePrefix.length);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Math.tex(
          formula,
          textStyle: textStyle,
          onErrorFallback: (_) => Text('\$$formula\$', style: AppTypography.mono),
        ),
      );
    }

    if (text.startsWith(_blockPrefix)) {
      final formula = text.substring(_blockPrefix.length);
      return SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Math.tex(
            formula,
            mathStyle: MathStyle.display,
            textStyle: textStyle.copyWith(fontSize: (textStyle.fontSize ?? 15) + 2),
            onErrorFallback: (_) => Text('\$\$$formula\$\$', style: AppTypography.mono),
          ),
        ),
      );
    }

    return null; // regular inline / fenced code
  }
}

final _richContent = RegExp(r'\$|\\\(|\\\[|\*\*|`');
final _hasDelimiters = RegExp(r'\$|\\\(|\\\[');
// A token is "mathy" if it has a LaTeX command, an exponent glued to its base
// (2^12, x^{n}, 2^-1), or a single-letter subscript (a_1, x_{i}). Spaced-out
// "a ^ b" (XOR) and identifiers like page_table are deliberately not matched.
final _mathyToken = RegExp(r'\\[a-zA-Z]+|[\w)\]}]\^(\{|-?\w)|\b[a-zA-Z]_(\{|\d)');
final _operatorToken = RegExp(r'^[=+\-*/<>≤≥×÷·]+$');
final _trailingPunct = RegExp(r'[.,;:?!]+$');

/// Wraps undelimited maths such as "2^20 entries" or "\frac{a}{b}" in `$…$`
/// and braces multi-character exponents so "2^12" renders as 2¹², not 2¹2.
/// Strings that already use delimiters are returned unchanged.
String wrapBareMath(String text) {
  if (_hasDelimiters.hasMatch(text) || !_mathyToken.hasMatch(text)) return text;

  final tokens = text.split(' ');
  final out = <String>[];
  final run = <String>[];
  var depth = 0;

  void flush() {
    if (run.isEmpty) return;
    var math = run.join(' ');
    final tail = _trailingPunct.firstMatch(math)?.group(0) ?? '';
    math = math.substring(0, math.length - tail.length);
    math = math
        .replaceAllMapped(RegExp(r'\^(-?[A-Za-z0-9]{2,}|-[A-Za-z0-9])'), (m) => '^{${m[1]}}')
        .replaceAllMapped(RegExp(r'_(\d{2,})'), (m) => '_{${m[1]}}');
    out.add('\$$math\$$tail');
    run.clear();
    depth = 0;
  }

  for (var i = 0; i < tokens.length; i++) {
    final tok = tokens[i];
    final joinsOperator = run.isNotEmpty &&
        _operatorToken.hasMatch(tok) &&
        i + 1 < tokens.length &&
        _mathyToken.hasMatch(tokens[i + 1]);
    if (_mathyToken.hasMatch(tok) || (run.isNotEmpty && depth > 0) || joinsOperator) {
      run.add(tok);
      depth += '{'.allMatches(tok).length - '}'.allMatches(tok).length;
    } else {
      flush();
      out.add(tok);
    }
  }
  flush();
  return out.join(' ');
}

/// Plain [Text] for ordinary strings; [MathMarkdown] only when the string
/// contains LaTeX (delimited or bare, see [wrapBareMath]) or inline markdown.
/// Keeps short labels (quiz options) from being misread as markdown lists.
class MathText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const MathText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final prepared = wrapBareMath(text);
    if (!_richContent.hasMatch(prepared)) return Text(text, style: style);
    return MathMarkdown(data: prepared, style: style);
  }
}

/// Markdown + LaTeX renderer shared by chat replies and quiz content.
class MathMarkdown extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final bool selectable;

  const MathMarkdown({
    super.key,
    required this.data,
    this.style,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = style ??
        AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary, fontSize: 15, height: 1.55);

    return MarkdownBody(
      data: preprocessLatex(data.isEmpty ? ' ' : data),
      selectable: selectable,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: {'code': _MathBuilder(body)},
      styleSheet: MarkdownStyleSheet(
        p: body,
        h1: AppTypography.heading3.copyWith(fontSize: 21, height: 1.3),
        h2: AppTypography.heading3.copyWith(fontSize: 18, height: 1.3),
        h3: body.copyWith(fontWeight: FontWeight.w700, height: 1.4),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
        ),
        code: AppTypography.mono.copyWith(
          fontSize: 13,
          color: AppColors.primaryDark,
          backgroundColor: AppColors.surfaceSunken,
        ),
        blockquote: body.copyWith(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.highlighter, width: 3)),
          color: AppColors.paper,
        ),
        listBullet: body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        strong: body.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
