import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/src/markdown_blocks.dart';

List<String> texts(String source) =>
    splitBlocks(source).map((b) => b.text).toList();

void main() {
  test('splits at blank lines and keeps offsets', () {
    const source = '# Title\n\nFirst para\nstill first\n\nSecond';
    final blocks = splitBlocks(source);
    expect(blocks.map((b) => b.text), [
      '# Title',
      'First para\nstill first',
      'Second',
    ]);
    for (final b in blocks) {
      expect(source.substring(b.start, b.end), b.text);
    }
  });

  test('keeps fenced code with blank lines together', () {
    expect(texts('```\na\n\nb\n```\n\nafter'), ['```\na\n\nb\n```', 'after']);
  });

  test('keeps loose lists and indented continuations together', () {
    expect(texts('- a\n\n- b\n\n  more b\n\nend'), [
      '- a\n\n- b\n\n  more b',
      'end',
    ]);
  });

  test('link definitions are collected', () {
    expect(
      linkDefinitions('[a][x]\n\n[x]: https://example.com'),
      '[x]: https://example.com',
    );
  });

  test('findAll is case-insensitive', () {
    expect(findAll('Foo foo FOO', 'foo'), [0, 4, 8]);
    expect(findAll('a.b', '.'), [1]);
    expect(findAll('abc', ''), isEmpty);
  });
}
