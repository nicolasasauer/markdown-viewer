import 'dart:convert' show HtmlEscape;

import 'package:markdown/markdown.dart' as md;

/// Turns [markdown] into a standalone, print-friendly HTML page. Android
/// renders it in a WebView and hands it to the system print dialog, which
/// also offers "Save as PDF".
String markdownToPrintHtml(String markdown, {required String title}) {
  var body = md.markdownToHtml(
    markdown,
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  // The app has no network access, so images are shown as their alt text
  // (like in the preview).
  final alt = RegExp(r'\balt="([^"]*)"', caseSensitive: false);
  body = body.replaceAllMapped(
    RegExp(r'<img\b[^>]*>', caseSensitive: false),
    (m) => '<span class="img">🖼 ${alt.firstMatch(m[0]!)?[1] ?? ''}</span>',
  );
  final escapedTitle = const HtmlEscape().convert(title);
  return '''<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$escapedTitle</title>
<style>$_css</style>
</head><body>
$body
</body></html>''';
}

const _css = '''
@page { margin: 18mm 16mm; }
body { font-family: Roboto, "Noto Sans", sans-serif; font-size: 11pt; line-height: 1.5;
       color: #1c1b1f; margin: 0;
       /* Keep code, quote and table backgrounds (dropped by default when printing). */
       -webkit-print-color-adjust: exact; print-color-adjust: exact; }
h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.2em 0 0.4em; break-after: avoid; }
h1 { font-size: 22pt; margin-top: 0; }
h2 { font-size: 16pt; }
h3 { font-size: 13pt; }
h4, h5, h6 { font-size: 11pt; }
p, ul, ol, pre, table, blockquote { margin: 0 0 0.8em; }
a { color: #4b44c9; }
code { font-family: "Roboto Mono", "DejaVu Sans Mono", monospace; font-size: 0.9em;
       background: #f1eef6; padding: 0.1em 0.3em; border-radius: 3px; }
pre { background: #f1eef6; padding: 10px 12px; border-radius: 6px;
      white-space: pre-wrap; word-wrap: break-word; break-inside: avoid; }
pre code { background: none; padding: 0; }
blockquote { border-left: 4px solid #6e66f2; background: #f6f3fa; margin-left: 0;
             padding: 6px 12px; color: #49454f; break-inside: avoid; }
blockquote p { margin: 0; }
table { border-collapse: collapse; break-inside: avoid; }
th, td { border: 1px solid #cac4d0; padding: 4px 10px; text-align: left; }
th { background: #f1eef6; }
hr { border: none; border-top: 1px solid #cac4d0; margin: 1.2em 0; }
li.task-list-item { list-style: none; }
li.task-list-item input { margin: 0 0.4em 0 -1.3em; }
.img { color: #79747e; border: 1px solid #cac4d0; border-radius: 4px; padding: 0 4px; }
''';
