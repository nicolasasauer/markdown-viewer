import 'package:flutter/material.dart';

/// The raw Markdown source, editable.
class MarkdownEditor extends StatelessWidget {
  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fontSize,
    this.scrollController,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double fontSize;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      scrollController: scrollController,
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
        fontSize: fontSize,
        height: 1.5,
        color: theme.colorScheme.onSurface,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Start writing Markdown…',
        contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 48),
      ),
    );
  }
}
