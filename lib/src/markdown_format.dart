import 'package:flutter/services.dart';

/// Text edits behind the formatting bar. Each takes the editor's current
/// value and returns the new one (text and selection).

TextSelection _selectionOf(TextEditingValue value) => value.selection.isValid
    ? value.selection
    : TextSelection.collapsed(offset: value.text.length);

TextEditingValue _replace(
  TextEditingValue value,
  int start,
  int end,
  String insert,
  TextSelection selection,
) => TextEditingValue(
  text: value.text.replaceRange(start, end, insert),
  selection: selection,
);

/// Toggles an inline marker like `**` (bold) around the selection, or inserts
/// an empty pair with the cursor in between.
TextEditingValue toggleInline(TextEditingValue value, String marker) {
  final text = value.text;
  final sel = _selectionOf(value);
  final s = sel.start, e = sel.end, m = marker.length;

  bool markerAt(int i) =>
      i >= 0 && i + m <= text.length && text.substring(i, i + m) == marker;

  if (s == e) {
    if (markerAt(s - m) && markerAt(s)) {
      // Empty pair around the cursor: remove it again.
      return _replace(
        value,
        s - m,
        s + m,
        '',
        TextSelection.collapsed(offset: s - m),
      );
    }
    return _replace(
      value,
      s,
      e,
      marker + marker,
      TextSelection.collapsed(offset: s + m),
    );
  }

  final selected = text.substring(s, e);
  if (selected.length >= 2 * m &&
      selected.startsWith(marker) &&
      selected.endsWith(marker)) {
    final inner = selected.substring(m, selected.length - m);
    return _replace(
      value,
      s,
      e,
      inner,
      TextSelection(baseOffset: s, extentOffset: s + inner.length),
    );
  }
  if (markerAt(s - m) && markerAt(e)) {
    return _replace(
      value,
      s - m,
      e + m,
      selected,
      TextSelection(baseOffset: s - m, extentOffset: e - m),
    );
  }
  return _replace(
    value,
    s,
    e,
    '$marker$selected$marker',
    TextSelection(baseOffset: s + m, extentOffset: e + m),
  );
}

/// The kinds of line prefixes the bar can toggle.
enum LinePrefix { bullet, numbered, checklist, quote }

final _prefixPatterns = {
  LinePrefix.bullet: RegExp(r'^(\s*)[-*+] (?!\[[ xX]\] )'),
  LinePrefix.numbered: RegExp(r'^(\s*)\d+[.)] '),
  LinePrefix.checklist: RegExp(r'^(\s*)[-*+] \[[ xX]\] '),
  LinePrefix.quote: RegExp(r'^(\s*)> ?'),
};

String _prefixText(LinePrefix kind, int index) => switch (kind) {
  LinePrefix.bullet => '- ',
  LinePrefix.numbered => '${index + 1}. ',
  LinePrefix.checklist => '- [ ] ',
  LinePrefix.quote => '> ',
};

/// Start offsets of the lines touched by the selection, plus the end of the
/// last one.
(int, int) _lineRange(String text, TextSelection sel) {
  final start = sel.start == 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
  // A selection ending right after a newline does not include the next line.
  final endProbe = sel.end > sel.start && text[sel.end - 1] == '\n'
      ? sel.end - 1
      : sel.end;
  final nl = text.indexOf('\n', endProbe);
  return (start, nl == -1 ? text.length : nl);
}

/// Adds [kind] to every selected line, or removes it if all of them have it.
TextEditingValue toggleLinePrefix(TextEditingValue value, LinePrefix kind) {
  final text = value.text;
  final sel = _selectionOf(value);
  final (start, end) = _lineRange(text, sel);
  final lines = text.substring(start, end).split('\n');
  final pattern = _prefixPatterns[kind]!;
  final relevant = lines.where((l) => l.trim().isNotEmpty).toList();
  final remove =
      relevant.isNotEmpty && relevant.every((l) => pattern.hasMatch(l));

  var index = 0;
  final changed = [
    for (final line in lines)
      if (line.trim().isEmpty && lines.length > 1)
        line
      else if (remove)
        line.replaceFirstMapped(pattern, (m) => m[1]!)
      else
        _addPrefix(line, _prefixText(kind, index++)),
  ];
  final replacement = changed.join('\n');

  final TextSelection selection;
  if (sel.isCollapsed && lines.length == 1) {
    final delta = replacement.length - lines.first.length;
    selection = TextSelection.collapsed(
      offset: (sel.start + delta).clamp(start, start + replacement.length),
    );
  } else {
    selection = TextSelection(
      baseOffset: start,
      extentOffset: start + replacement.length,
    );
  }
  return _replace(value, start, end, replacement, selection);
}

/// Adds [prefix] after the indentation, replacing another list or quote marker.
String _addPrefix(String line, String prefix) {
  for (final p in _prefixPatterns.values) {
    final m = p.firstMatch(line);
    if (m != null) return '${m[1]}$prefix${line.substring(m.end)}';
  }
  final indent = RegExp(r'^\s*').firstMatch(line)![0]!;
  return '$indent$prefix${line.substring(indent.length)}';
}

/// Cycles the current line through no heading → # → ## → ### → no heading.
TextEditingValue cycleHeading(TextEditingValue value) {
  final text = value.text;
  final sel = _selectionOf(value);
  final (start, end) = _lineRange(
    text,
    TextSelection.collapsed(offset: sel.start),
  );
  final line = text.substring(start, end);
  final match = RegExp(r'^(#{1,6}) ').firstMatch(line);
  final level = match == null ? 0 : match[1]!.length;
  final body = match == null ? line : line.substring(match.end);
  final next = level >= 3 ? 0 : level + 1;
  final replacement = next == 0 ? body : '${'#' * next} $body';
  final delta = replacement.length - line.length;
  return _replace(
    value,
    start,
    end,
    replacement,
    TextSelection.collapsed(
      offset: (sel.start + delta).clamp(start, start + replacement.length),
    ),
  );
}

/// Turns the selection into a link and selects the URL part, or inserts a
/// link template with "text" selected.
TextEditingValue insertLink(TextEditingValue value, {String label = 'text'}) {
  final sel = _selectionOf(value);
  final s = sel.start;
  if (sel.isCollapsed) {
    return _replace(
      value,
      s,
      s,
      '[$label](https://)',
      TextSelection(baseOffset: s + 1, extentOffset: s + 1 + label.length),
    );
  }
  final selected = value.text.substring(s, sel.end);
  final link = '[$selected](https://)';
  return _replace(
    value,
    s,
    sel.end,
    link,
    TextSelection.collapsed(offset: s + link.length - 1),
  );
}

/// Inserts [block] on lines of its own; [cursor] is the offset inside
/// [block] where the cursor goes (or the start of a selection of
/// [selectLength] characters).
TextEditingValue insertBlock(
  TextEditingValue value,
  String block, {
  required int cursor,
  int selectLength = 0,
}) {
  final text = value.text;
  final sel = _selectionOf(value);
  final before = sel.start > 0 && text[sel.start - 1] != '\n' ? '\n' : '';
  final after = sel.end < text.length && text[sel.end] != '\n' ? '\n' : '';
  final offset = sel.start + before.length + cursor;
  return _replace(
    value,
    sel.start,
    sel.end,
    '$before$block$after',
    TextSelection(baseOffset: offset, extentOffset: offset + selectLength),
  );
}

/// Wraps the selection in a fenced code block (or inserts an empty one).
TextEditingValue insertCodeBlock(TextEditingValue value) {
  final sel = _selectionOf(value);
  final selected = value.text.substring(sel.start, sel.end);
  return insertBlock(
    value,
    '```\n$selected\n```',
    cursor: 4,
    selectLength: selected.length,
  );
}

TextEditingValue insertTable(
  TextEditingValue value, {
  String column1 = 'Column 1',
  String column2 = 'Column 2',
}) => insertBlock(
  value,
  '| $column1 | $column2 |\n| --- | --- |\n|  |  |',
  cursor: 2,
  selectLength: column1.length,
);

TextEditingValue insertRule(TextEditingValue value) =>
    insertBlock(value, '\n---\n', cursor: 5);
