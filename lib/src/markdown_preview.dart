import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// The rendered document (read-only), GitHub Flavored Markdown.
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    super.key,
    required this.data,
    required this.fontSize,
    required this.onTapLink,
    this.scrollController,
    this.maxWidth = 800,
  });

  final String data;
  final double fontSize;
  final void Function(String href) onTapLink;
  final ScrollController? scrollController;

  /// Lines longer than this are hard to read; wider screens get side margins.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.trim().isEmpty) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = ((constraints.maxWidth - maxWidth) / 2).clamp(
          16.0,
          double.infinity,
        );
        return Markdown(
          data: data,
          controller: scrollController,
          selectable: true,
          padding: EdgeInsets.fromLTRB(side, 16, side, 48),
          extensionSet: md.ExtensionSet.gitHubFlavored,
          styleSheet: markdownStyle(theme, fontSize),
          onTapLink: (text, href, title) {
            if (href != null) onTapLink(href);
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
      },
    );
  }
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
