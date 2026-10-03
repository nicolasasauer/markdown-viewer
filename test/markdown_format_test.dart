import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/src/markdown_format.dart';

TextEditingValue v(String text, int start, [int? end]) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
);

String selected(TextEditingValue value) =>
    value.selection.textInside(value.text);

void main() {
  group('toggleInline', () {
    test('wraps and unwraps the selection', () {
      final bold = toggleInline(v('a word b', 2, 6), '**');
      expect(bold.text, 'a **word** b');
      expect(selected(bold), 'word');
      expect(toggleInline(bold, '**').text, 'a word b');
    });

    test('inserts an empty pair and removes it again', () {
      final pair = toggleInline(v('ab', 1), '`');
      expect(pair.text, 'a``b');
      expect(pair.selection.baseOffset, 2);
      expect(toggleInline(pair, '`').text, 'ab');
    });

    test('unwraps when the markers are part of the selection', () {
      expect(toggleInline(v('~~x~~', 0, 5), '~~').text, 'x');
    });
  });

  group('toggleLinePrefix', () {
    test('numbers all selected lines', () {
      final r = toggleLinePrefix(
        v('one\ntwo\nthree', 0, 9),
        LinePrefix.numbered,
      );
      expect(r.text, '1. one\n2. two\n3. three');
    });

    test('removes the prefix when every line has it', () {
      final r = toggleLinePrefix(v('- a\n- b', 0, 7), LinePrefix.bullet);
      expect(r.text, 'a\nb');
    });

    test('switches between list kinds', () {
      final r = toggleLinePrefix(v('- a', 3), LinePrefix.checklist);
      expect(r.text, '- [ ] a');
      expect(r.selection.baseOffset, 7);
    });

    test('keeps blank lines in a multi-line selection', () {
      final r = toggleLinePrefix(v('a\n\nb', 0, 4), LinePrefix.quote);
      expect(r.text, '> a\n\n> b');
    });
  });

  test('cycleHeading goes # → ## → ### → none', () {
    var value = v('Title', 2);
    value = cycleHeading(value);
    expect(value.text, '# Title');
    expect(value.selection.baseOffset, 4);
    value = cycleHeading(cycleHeading(value));
    expect(value.text, '### Title');
    expect(cycleHeading(value).text, 'Title');
  });

  test('insertLink selects the text placeholder or puts cursor at the URL', () {
    final empty = insertLink(v('', 0));
    expect(empty.text, '[text](https://)');
    expect(selected(empty), 'text');
    final wrapped = insertLink(v('see docs', 4, 8));
    expect(wrapped.text, 'see [docs](https://)');
    expect(wrapped.selection.baseOffset, wrapped.text.length - 1);
  });

  test('blocks go on lines of their own', () {
    final code = insertCodeBlock(v('ab', 1));
    expect(code.text, 'a\n```\n\n```\nb');
    final rule = insertRule(v('para', 4));
    expect(rule.text, 'para\n\n---\n');
    final table = insertTable(v('', 0));
    expect(selected(table), 'Column 1');
  });
}
