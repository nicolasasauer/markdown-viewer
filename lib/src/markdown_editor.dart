import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;

import 'l10n.dart';
import 'markdown_format.dart';

/// Editor text controller that highlights search hits.
class MarkdownEditingController extends TextEditingController {
  String _query = '';
  int? _current;

  /// Highlights all occurrences of [query]; the one starting at [current]
  /// stands out.
  void setSearch(String query, int? current) {
    if (query == _query && current == _current) return;
    _query = query;
    _current = current;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_query.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final hit = TextStyle(backgroundColor: scheme.tertiaryContainer);
    final currentHit = TextStyle(
      backgroundColor: scheme.tertiary,
      color: scheme.onTertiary,
    );
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in RegExp(
      RegExp.escape(_query),
      caseSensitive: false,
    ).allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(text: m[0], style: m.start == _current ? currentHit : hit),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: style, children: spans);
  }
}

/// The raw Markdown source, editable, with a formatting bar below.
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fontSize,
    required this.undoController,
    this.scrollController,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double fontSize;
  final UndoHistoryController undoController;
  final ScrollController? scrollController;

  @override
  State<MarkdownEditor> createState() => MarkdownEditorState();
}

class MarkdownEditorState extends State<MarkdownEditor> {
  final _fieldKey = GlobalKey();
  ScrollController? _ownScroll;

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  @override
  void dispose() {
    _ownScroll?.dispose();
    super.dispose();
  }

  RenderEditable? _findRenderEditable() {
    RenderEditable? result;
    void visit(Element e) {
      if (result != null) return;
      if (e is RenderObjectElement && e.renderObject is RenderEditable) {
        result = e.renderObject as RenderEditable;
        return;
      }
      e.visitChildElements(visit);
    }

    final root = _fieldKey.currentContext;
    if (root is Element) root.visitChildElements(visit);
    return result;
  }

  /// Scrolls so the text at [offset] is visible (about a third from the top).
  void reveal(int offset) {
    final editable = _findRenderEditable();
    if (editable == null || !editable.hasSize || !_scroll.hasClients) return;
    final rect = editable.getLocalRectForCaret(TextPosition(offset: offset));
    final viewport = editable.size.height;
    final position = _scroll.position;
    final target = (position.pixels + rect.top - viewport / 3).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _apply(TextEditingValue Function(TextEditingValue) edit) {
    widget.controller.value = edit(widget.controller.value)
        .copyWith(composing: TextRange.empty);
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: TextField(
            key: _fieldKey,
            controller: widget.controller,
            focusNode: widget.focusNode,
            undoController: widget.undoController,
            scrollController: _scroll,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            // Smart quotes and dashes would silently change Markdown syntax.
            smartQuotesType: SmartQuotesType.disabled,
            smartDashesType: SmartDashesType.disabled,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: widget.fontSize,
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: context.l10n.editorHint,
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            ),
          ),
        ),
        const Divider(height: 1),
        // Tapping the bar must not count as tapping outside the text field.
        TextFieldTapRegion(
          child: _FormatBar(onEdit: _apply, undo: widget.undoController),
        ),
      ],
    );
  }
}

class _FormatBar extends StatelessWidget {
  const _FormatBar({required this.onEdit, required this.undo});

  final void Function(TextEditingValue Function(TextEditingValue)) onEdit;
  final UndoHistoryController undo;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget button(
      IconData icon,
      String tooltip,
      TextEditingValue Function(TextEditingValue) edit,
    ) => IconButton(
      tooltip: tooltip,
      icon: Icon(icon, semanticLabel: tooltip),
      onPressed: () => onEdit(edit),
    );

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              ValueListenableBuilder<UndoHistoryValue>(
                valueListenable: undo,
                builder: (context, value, _) => Row(
                  children: [
                    IconButton(
                      tooltip: l.undo,
                      icon: Icon(Icons.undo, semanticLabel: l.undo),
                      onPressed: value.canUndo ? undo.undo : null,
                    ),
                    IconButton(
                      tooltip: l.redo,
                      icon: Icon(Icons.redo, semanticLabel: l.redo),
                      onPressed: value.canRedo ? undo.redo : null,
                    ),
                  ],
                ),
              ),
              const VerticalDivider(indent: 12, endIndent: 12),
              button(Icons.title, l.heading, cycleHeading),
              button(Icons.format_bold, l.bold, (v) => toggleInline(v, '**')),
              button(
                Icons.format_italic,
                l.italic,
                (v) => toggleInline(v, '*'),
              ),
              button(
                Icons.format_strikethrough,
                l.strikethrough,
                (v) => toggleInline(v, '~~'),
              ),
              button(Icons.code, l.code, (v) => toggleInline(v, '`')),
              button(
                Icons.link,
                l.link,
                (v) => insertLink(v, label: l.linkText),
              ),
              const VerticalDivider(indent: 12, endIndent: 12),
              button(
                Icons.format_list_bulleted,
                l.bulletedList,
                (v) => toggleLinePrefix(v, LinePrefix.bullet),
              ),
              button(
                Icons.format_list_numbered,
                l.numberedList,
                (v) => toggleLinePrefix(v, LinePrefix.numbered),
              ),
              button(
                Icons.checklist,
                l.checklist,
                (v) => toggleLinePrefix(v, LinePrefix.checklist),
              ),
              button(
                Icons.format_quote_outlined,
                l.quote,
                (v) => toggleLinePrefix(v, LinePrefix.quote),
              ),
              const VerticalDivider(indent: 12, endIndent: 12),
              button(Icons.data_object, l.codeBlock, insertCodeBlock),
              button(
                Icons.table_chart_outlined,
                l.table,
                (v) => insertTable(
                  v,
                  column1: l.tableColumn1,
                  column2: l.tableColumn2,
                ),
              ),
              button(Icons.horizontal_rule, l.horizontalLine, insertRule),
            ],
          ),
        ),
      ),
    );
  }
}
