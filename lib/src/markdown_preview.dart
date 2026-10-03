import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'markdown_blocks.dart';

/// The rendered document (read-only), GitHub Flavored Markdown.
///
/// Each top-level block is rendered on its own so it can be mapped back to
/// the source: [onTapSource] reports where a tapped block starts, and
/// [revealOffset] scrolls to the block containing that source offset.
class MarkdownPreview extends StatefulWidget {
  const MarkdownPreview({
    super.key,
    required this.data,
    required this.fontSize,
    required this.onTapLink,
    this.onTapSource,
    this.scrollController,
    this.searchQuery = '',
    this.revealOffset,
    this.revealRequest = 0,
    this.maxWidth = 800,
  });

  final String data;
  final double fontSize;
  final void Function(String href) onTapLink;
  final void Function(int offset)? onTapSource;
  final ScrollController? scrollController;

  /// Occurrences are highlighted in the rendered text.
  final String searchQuery;

  /// The block containing this source offset is tinted and, whenever
  /// [revealRequest] changes, scrolled into view.
  final int? revealOffset;
  final int revealRequest;

  /// Lines longer than this are hard to read; wider screens get side margins.
  final double maxWidth;

  @override
  State<MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<MarkdownPreview> {
  List<MarkdownBlock> _blocks = const [];
  String _definitions = '';
  String? _parsed;
  final List<GlobalKey> _keys = [];

  // Kept between builds so unchanged blocks are not parsed again.
  MarkdownStyleSheet? _style;
  (ThemeData, double)? _styleFor;

  void _split() {
    if (_parsed == widget.data) return;
    _parsed = widget.data;
    _blocks = splitBlocks(widget.data);
    _definitions = linkDefinitions(widget.data);
    while (_keys.length < _blocks.length) {
      _keys.add(GlobalKey());
    }
  }

  int _blockAt(int offset) {
    for (var i = 0; i < _blocks.length; i++) {
      if (offset < _blocks[i].end) return i;
    }
    return _blocks.length - 1;
  }

  @override
  void didUpdateWidget(MarkdownPreview old) {
    super.didUpdateWidget(old);
    if (widget.revealRequest != old.revealRequest &&
        widget.revealOffset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal() {
    final offset = widget.revealOffset;
    if (!mounted || offset == null || _blocks.isEmpty) return;
    final target = _keys[_blockAt(offset)].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.2,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.data.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nothing to show yet.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    _split();
    if (_styleFor != (theme, widget.fontSize)) {
      _styleFor = (theme, widget.fontSize);
      _style = markdownStyle(theme, widget.fontSize);
    }
    final query = widget.searchQuery;
    final current = widget.revealOffset == null
        ? -1
        : _blockAt(widget.revealOffset!);
    final onTapSource = widget.onTapSource;
    final highlight = theme.colorScheme.primaryContainer.withValues(alpha: 0.5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = ((constraints.maxWidth - widget.maxWidth) / 2).clamp(
          16.0,
          double.infinity,
        );
        return SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(side - 8, 16, side - 8, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _blocks.length; i++)
                GestureDetector(
                  key: _keys[i],
                  behavior: HitTestBehavior.translucent,
                  onTap: onTapSource == null
                      ? null
                      : () => onTapSource(_blocks[i].start),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    margin: EdgeInsets.only(bottom: widget.fontSize * 0.75),
                    decoration: BoxDecoration(
                      color: i == current && query.isNotEmpty
                          ? highlight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildBlock(theme, _blocks[i], query, onTapSource),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlock(
    ThemeData theme,
    MarkdownBlock block,
    String query,
    void Function(int offset)? onTapSource,
  ) {
    final fontSize = widget.fontSize;
    return MarkdownBody(
      // The widget only re-parses when data or style change; a new query
      // needs a fresh parse for the highlight syntax.
      key: ValueKey(query),
      data: _definitions.isEmpty
          ? block.text
          : '${block.text}\n\n$_definitions',
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: _style,
      inlineSyntaxes: [if (query.isNotEmpty) _HighlightSyntax(query)],
      builders: {
        if (query.isNotEmpty)
          'mark': _HighlightBuilder(theme.colorScheme.tertiaryContainer),
      },
      onTapText: onTapSource == null ? null : () => onTapSource(block.start),
      onTapLink: (text, href, title) {
        if (href != null) widget.onTapLink(href);
      },
      checkboxBuilder: (checked) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Icon(
          checked ? Icons.check_box : Icons.check_box_outline_blank,
          size: fontSize * 1.25,
          color: checked
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      imageBuilder: (uri, title, alt) => _ImagePlaceholder(
        label: (alt?.isNotEmpty ?? false) ? alt! : uri.toString(),
        fontSize: fontSize,
      ),
    );
  }
}

/// Marks search hits as `<mark>` elements in the rendered text.
class _HighlightSyntax extends md.InlineSyntax {
  _HighlightSyntax(String query)
    : super(RegExp.escape(query), caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('mark', match[0]!));
    return true;
  }
}

class _HighlightBuilder extends MarkdownElementBuilder {
  _HighlightBuilder(this.color);

  final Color color;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Text.rich(
    TextSpan(
      text: element.textContent,
      style: (parentStyle ?? const TextStyle()).copyWith(
        backgroundColor: color,
      ),
    ),
  );
}

/// Styles derived from the app theme, scaled with the user's text size.
MarkdownStyleSheet markdownStyle(ThemeData theme, double fontSize) {
  final scheme = theme.colorScheme;
  final body = theme.textTheme.bodyLarge!.copyWith(
    fontSize: fontSize,
    height: 1.6,
    color: scheme.onSurface,
  );
  TextStyle heading(double scale, {FontWeight weight = FontWeight.w700}) => body
      .copyWith(fontSize: fontSize * scale, height: 1.3, fontWeight: weight);
  const mono = 'monospace';
  final codeBackground = scheme.surfaceContainerHighest;

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: body,
    a: body.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    ),
    h1: heading(1.75),
    h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
    h2: heading(1.45),
    h2Padding: const EdgeInsets.only(top: 16, bottom: 2),
    h3: heading(1.2),
    h3Padding: const EdgeInsets.only(top: 12),
    h4: heading(1.05),
    h5: heading(1.0),
    h6: heading(0.95).copyWith(color: scheme.onSurfaceVariant),
    strong: const TextStyle(fontWeight: FontWeight.w700),
    em: const TextStyle(fontStyle: FontStyle.italic),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    code: body.copyWith(
      fontFamily: mono,
      fontSize: fontSize * 0.9,
      height: 1.4,
      backgroundColor: codeBackground,
    ),
    codeblockDecoration: BoxDecoration(
      color: codeBackground,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquote: body.copyWith(color: scheme.onSurfaceVariant),
    blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainer,
      border: Border(left: BorderSide(color: scheme.primary, width: 4)),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
    listBullet: body,
    listIndent: fontSize * 1.75,
    blockSpacing: fontSize * 0.75,
    tableHead: body.copyWith(fontWeight: FontWeight.w700),
    tableBody: body,
    tableBorder: TableBorder.all(color: scheme.outlineVariant),
    tableHeadCellsDecoration: BoxDecoration(color: scheme.surfaceContainer),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    tableColumnWidth: const IntrinsicColumnWidth(),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: scheme.outlineVariant, width: 1)),
    ),
  );
}

/// Images are not loaded (the app has no network access and cannot read
/// files next to the document); show where they would be instead.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.label, required this.fontSize});

  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: fontSize * 1.1,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
