/// A top-level chunk of the document (paragraph, heading, list, table, code
/// block, ...) and where it is in the source.
///
/// The preview renders each block separately, so a tap or a search hit in
/// the preview can be mapped back to a position in the editor.
class MarkdownBlock {
  const MarkdownBlock(this.start, this.end, this.text);

  /// Offsets in the source; [end] is exclusive.
  final int start;
  final int end;
  final String text;

  bool contains(int offset) => offset >= start && offset < end;

  @override
  String toString() => 'MarkdownBlock($start-$end: $text)';
}

final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})');
final _listItem = RegExp(r'^ {0,3}([-*+]|\d{1,9}[.)])( |$)');
final _linkDefinition = RegExp(r'^ {0,3}\[[^\]]+\]:\s*\S');

/// Splits [source] at blank lines, keeping fenced code blocks, loose lists
/// and indented continuations together.
List<MarkdownBlock> splitBlocks(String source) {
  final blocks = <MarkdownBlock>[];
  var blockStart = -1; // start of the open block, -1 if none
  var blockEnd = 0; // end of its last line
  var blockIsList = false;
  var sawBlank = false;
  String? fence;

  void close() {
    if (blockStart >= 0) {
      blocks.add(
        MarkdownBlock(
          blockStart,
          blockEnd,
          source.substring(blockStart, blockEnd),
        ),
      );
    }
    blockStart = -1;
  }

  var pos = 0;
  while (pos <= source.length) {
    final nl = source.indexOf('\n', pos);
    final lineEnd = nl == -1 ? source.length : nl;
    final line = source.substring(pos, lineEnd);

    if (fence != null) {
      blockEnd = lineEnd;
      final m = _fence.firstMatch(line);
      if (m != null &&
          m[1]![0] == fence[0] &&
          m[1]!.length >= fence.length &&
          line.trim() == m[1]) {
        fence = null;
      }
    } else if (line.trim().isEmpty) {
      sawBlank = blockStart >= 0;
    } else {
      final indented = line.startsWith(' ') || line.startsWith('\t');
      final isList = _listItem.hasMatch(line);
      final continues =
          blockStart >= 0 &&
          (!sawBlank ||
              (indented && !_fence.hasMatch(line)) ||
              (blockIsList && isList));
      if (!continues) {
        close();
        blockStart = pos;
        blockIsList = isList;
      }
      blockEnd = lineEnd;
      sawBlank = false;
      final m = _fence.firstMatch(line);
      if (m != null) fence = m[1];
    }

    if (nl == -1) break;
    pos = nl + 1;
  }
  close();
  return blocks;
}

/// Reference-style link definitions (`[id]: https://...`). They are appended
/// to every block when rendering, so `[text][id]` works in any block.
String linkDefinitions(String source) => source
    .split('\n')
    .where((line) => _linkDefinition.hasMatch(line))
    .join('\n');

/// All case-insensitive occurrences of [query] in [text], as start offsets.
List<int> findAll(String text, String query) {
  if (query.isEmpty) return const [];
  return [
    for (final m in RegExp(
      RegExp.escape(query),
      caseSensitive: false,
    ).allMatches(text))
      m.start,
  ];
}
