import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/src/print_html.dart';

void main() {
  test('renders a complete HTML page with an escaped title', () {
    final html = markdownToPrintHtml(
      '# Notes\n\n- [x] done\n\n| a | b |\n|---|---|\n| 1 | 2 |',
      title: 'Tom & Jerry <3',
    );
    expect(html, startsWith('<!doctype html>'));
    expect(html, contains('<title>Tom &amp; Jerry &lt;3</title>'));
    expect(html, contains('<h1>Notes</h1>'));
    expect(html, contains('<table>'));
    expect(html, contains('type="checkbox"'));
  });

  test('replaces images by their alt text (no network access)', () {
    final html = markdownToPrintHtml(
      '![Logo](https://example.com/logo.png)',
      title: 'x',
    );
    expect(html, isNot(contains('<img')));
    expect(html, contains('🖼 Logo'));
  });
}
