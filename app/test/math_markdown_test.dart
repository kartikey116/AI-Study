import 'package:ai_study_companion/core/components/math_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('preprocessLatex', () {
    test('turns block math into an inline marker, not a fenced code block', () {
      final out = preprocessLatex(r'Sum: $$S = \frac{a}{1 - r}$$ done');
      expect(out, contains(r'`blockmath:S = \frac{a}{1 - r}`'));
      expect(out, isNot(contains('```')));
    });

    test('supports \\[ \\] and \\( \\) delimiters', () {
      expect(preprocessLatex(r'\[x^2\]'), contains('`blockmath:x^2`'));
      expect(preprocessLatex(r'where \(a = 100\)'), contains('`inlinemath:a = 100`'));
    });

    test('inline \$…\$ math', () {
      expect(preprocessLatex(r'ratio $|r| < 1$ holds'), contains('`inlinemath:|r| < 1`'));
    });
  });

  group('wrapBareMath (legacy quiz text without delimiters)', () {
    test('wraps and braces bare exponents from real quiz data', () {
      expect(wrapBareMath('2^20 entries'), r'$2^{20}$ entries');
      expect(wrapBareMath('a 4 KB (2^12 bytes) page size'), r'a 4 KB $(2^{12}$ bytes) page size');
      expect(wrapBareMath('its buddy block of size 2^k?'), r'its buddy block of size $2^k$?');
    });

    test('keeps operator runs together and handles LaTeX commands', () {
      expect(wrapBareMath(r'so x^2 = y^2 here'), r'so $x^2 = y^2$ here');
      expect(wrapBareMath(r'value \frac{a + b}{2} wins'), r'value $\frac{a + b}{2}$ wins');
    });

    test('leaves plain text, code-like strings and delimited math alone', () {
      expect(wrapBareMath('A XOR (1 << k)'), 'A XOR (1 << k)');
      expect(wrapBareMath('a ^ b flips bits'), 'a ^ b flips bits');
      expect(wrapBareMath('the page_table entry'), 'the page_table entry');
      expect(wrapBareMath(r'already $2^{20}$ fine'), r'already $2^{20}$ fine');
    });
  });

  testWidgets('MathText renders bare exponents as math', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MathText('2^20 entries', style: TextStyle(fontSize: 14))),
    ));
    await tester.pump();
    expect(find.byType(Math), findsOneWidget);
    expect(find.textContaining('2^20'), findsNothing);
  });

  testWidgets('block math renders as Math with no code-block container', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: MathMarkdown(
            data: 'Apply the formula:\n\n\$\$S_\\infty = \\frac{a}{1-r}\$\$\n\nwith \$a = 100\$.',
            style: TextStyle(fontSize: 15),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(Math), findsNWidgets(2));
    expect(find.textContaining('blockmath'), findsNothing);
    expect(find.textContaining('inlinemath'), findsNothing);
  });

  testWidgets('MathText keeps plain strings as plain Text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MathText('- 5 degrees', style: TextStyle(fontSize: 14))),
    ));
    expect(find.text('- 5 degrees'), findsOneWidget);
    expect(find.byType(Math), findsNothing);
  });
}
