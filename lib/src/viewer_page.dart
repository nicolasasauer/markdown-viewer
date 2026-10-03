import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'about.dart';
import 'file_bridge.dart';
import 'l10n.dart';
import 'markdown_blocks.dart';
import 'markdown_editor.dart';
import 'markdown_preview.dart';
import 'sample.dart';

/// The modes at the top. [split] is only offered on wide screens.
enum ViewMode { preview, edit, split }

enum _DiscardChoice { cancel, discard, save }

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.onToggleTheme, this.bridge});

  final VoidCallback onToggleTheme;
  final FileBridge? bridge;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final FileBridge _bridge = widget.bridge ?? FileBridge();
  AppLocalizations get _l => context.l10n;
  final _controller = MarkdownEditingController();
  final _editorFocus = FocusNode();
  final _editorScroll = ScrollController();
  final _previewScroll = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// Recreated per document, so undo never reaches into the previous file.
  var _undo = UndoHistoryController();

  /// The editor stays mounted (offstage in preview) so its undo history
  /// survives mode switches; the key moves it between layouts.
  var _editorKey = GlobalKey<MarkdownEditorState>();

  bool _hasDocument = false;
  String _fileName = 'Untitled.md';
  String? _uri;
  String _savedText = '';

  ViewMode _mode = ViewMode.preview;
  double _fontSize = 16;
  bool _syncScroll = true;

  /// The split-view pane the user last touched; only it drives the other one.
  ScrollController? _scrollLeader;

  bool _searching = false;
  List<int> _matches = const [];
  int _matchIndex = 0;

  /// Bumped to make the preview scroll to [_revealOffset].
  int _revealRequest = 0;
  int? _revealOffset;

  /// Whether the screen is wide enough for split view (set in build).
  bool _wide = false;

  /// The mode actually shown: split falls back to the editor on narrow screens.
  ViewMode get _shown =>
      _mode == ViewMode.split && !_wide ? ViewMode.edit : _mode;

  /// The text the preview renders. Lags slightly behind the editor while
  /// typing in split view, so long documents are not re-rendered per key.
  String _previewText = '';
  Timer? _previewTimer;

  bool get _dirty => _hasDocument && _controller.text != _savedText;

  /// The dirty state the app bar was last built with, so typing only
  /// rebuilds the page when the unsaved-changes marker changes.
  bool _shownDirty = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _bridge.setOnFileOpened(
      (file) => _openWithConfirm(file),
      onError: (e) => _snack(_l.couldNotOpen('$e')),
    );
    _loadInitialFile();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _controller.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    _previewScroll.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _undo.dispose();
    super.dispose();
  }

  // ---- Document state -------------------------------------------------------

  Future<void> _loadInitialFile() async {
    try {
      final file = await _bridge.getInitialFile();
      if (file != null && mounted) _load(file);
    } on MissingPluginException {
      // Not running on Android (e.g. tests); start empty.
    } catch (e) {
      _snack(_l.couldNotOpen(_errorText(e)));
    }
  }

  void _load(OpenedFile file, {ViewMode mode = ViewMode.preview}) {
    _previewTimer?.cancel();
    final oldUndo = _undo;
    WidgetsBinding.instance.addPostFrameCallback((_) => oldUndo.dispose());
    _undo = UndoHistoryController();
    _editorKey = GlobalKey<MarkdownEditorState>();
    // A valid selection, so the undo history records the loaded text as its
    // starting point.
    _controller.value = TextEditingValue(
      text: file.content,
      selection: const TextSelection.collapsed(offset: 0),
    );
    if (_previewScroll.hasClients) _previewScroll.jumpTo(0);
    setState(() {
      _closeSearch();
      _hasDocument = true;
      _fileName = file.name;
      _uri = file.uri;
      _savedText = file.content;
      _previewText = file.content;
      _mode = mode;
    });
  }

  void _onTextChanged() {
    if (_dirty != _shownDirty) setState(() {});
    if (_controller.text == _previewText) return;
    if (_searching) _updateMatches();
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _previewText = _controller.text);
    });
  }

  /// Brings the preview up to date immediately (mode switches).
  void _syncPreview() {
    _previewTimer?.cancel();
    _previewText = _controller.text;
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _open() async {
    if (!await _confirmDiscard()) return;
    try {
      final file = await _bridge.openDocument();
      if (file != null && mounted) _load(file);
    } catch (e) {
      _snack(_l.couldNotOpen(_errorText(e)));
    }
  }

  Future<void> _openWithConfirm(OpenedFile file) async {
    if (await _confirmDiscard() && mounted) _load(file);
  }

  Future<void> _create() async {
    if (!await _confirmDiscard() || !mounted) return;
    _load(
      const OpenedFile(name: 'Untitled.md', content: ''),
      mode: ViewMode.edit,
    );
    _editorFocus.requestFocus();
  }

  Future<void> _showSample() async {
    if (!await _confirmDiscard() || !mounted) return;
    _load(
      OpenedFile(
        name: 'Sample.md',
        content: Localizations.localeOf(context).languageCode == 'de'
            ? sampleMarkdownDe
            : sampleMarkdown,
      ),
    );
  }

  Future<bool> _save({bool saveAs = false}) async {
    if (!_hasDocument) return false;
    final text = _controller.text;
    try {
      final uri = _uri;
      if (!saveAs && uri != null) {
        await _bridge.saveFile(uri, text);
      } else {
        final created = await _bridge.createDocument(_fileName, text);
        if (created == null) return false;
        _fileName = created.name;
        _uri = created.uri;
      }
      if (!mounted) return true;
      setState(() => _savedText = text);
      _snack(_l.saved(_fileName));
      return true;
    } catch (e) {
      _snack(
        _l.couldNotSave(_errorText(e)),
        action: saveAs
            ? null
            : SnackBarAction(
                label: _l.saveAsShort,
                onPressed: () => _save(saveAs: true),
              ),
      );
      return false;
    }
  }

  /// Returns true if it is OK to replace or leave the current document.
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final choice = await showDialog<_DiscardChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l.discardTitle),
        content: Text(_l.unsavedChanges(_fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.cancel),
            child: Text(_l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.discard),
            child: Text(_l.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.save),
            child: Text(_l.save),
          ),
        ],
      ),
    );
    return switch (choice) {
      _DiscardChoice.discard => true,
      _DiscardChoice.save => await _save(),
      _ => false,
    };
  }

  void _setMode(ViewMode mode) {
    if (mode == ViewMode.preview) _editorFocus.unfocus();
    setState(() {
      _syncPreview();
      _mode = mode;
    });
  }

  Future<void> _openLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null || !uri.hasScheme) {
      // Relative links point at files next to the document, which the app
      // cannot reach; anchors (#heading) are not supported either.
      _snack(_l.cannotOpenLink(href));
      return;
    }
    try {
      if (!await _bridge.openUrl(href)) _snack(_l.noAppForLink(href));
    } catch (e) {
      _snack(_l.cannotOpenLink(_errorText(e)));
    }
  }

  // ---- Search ---------------------------------------------------------------

  void _openSearch() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  /// Only resets state; callers rebuild.
  void _closeSearch() {
    _searching = false;
    _searchController.clear();
    _matches = const [];
    _revealOffset = null;
    _controller.setSearch('', null);
  }

  void _updateMatches() {
    final query = _searchController.text;
    _matches = findAll(_controller.text, query);
    if (_matchIndex >= _matches.length) _matchIndex = 0;
    final current = _matches.isEmpty ? null : _matches[_matchIndex];
    _revealOffset = current;
    _controller.setSearch(query, current);
  }

  void _onQueryChanged(String _) {
    _syncPreview();
    _matchIndex = 0;
    setState(_updateMatches);
    _revealMatch();
  }

  void _step(int delta) {
    if (_matches.isEmpty) return;
    _syncPreview();
    setState(() {
      _matchIndex = (_matchIndex + delta) % _matches.length;
      _updateMatches();
    });
    _revealMatch();
  }

  /// Scrolls the visible panes to the current match.
  void _revealMatch() {
    final offset = _revealOffset;
    if (offset == null) return;
    _scrollLeader = null;
    setState(() => _revealRequest++);
    if (_shown != ViewMode.preview) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _editorKey.currentState?.reveal(offset),
      );
    }
  }

  /// Split view: tapping a block in the preview puts the cursor there.
  void _revealInEditor(int offset) {
    _scrollLeader = null;
    _controller.selection = TextSelection.collapsed(offset: offset);
    _editorFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _editorKey.currentState?.reveal(offset),
    );
  }

  void _changeFontSize(double delta) =>
      setState(() => _fontSize = (_fontSize + delta).clamp(10, 32));

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    _snack(_l.documentCopied);
  }

  void _snack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  String _errorText(Object e) =>
      e is PlatformException ? (e.message ?? e.code) : e.toString();

  Future<void> _handleBack() async {
    if (_searching) {
      setState(_closeSearch);
      return;
    }
    if (_hasDocument && _mode != ViewMode.preview) {
      _setMode(ViewMode.preview);
      return;
    }
    if (await _confirmDiscard()) {
      await SystemNavigator.pop();
    }
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    _wide = wide;
    _shownDirty = _dirty;
    return PopScope(
      canPop:
          !_dirty &&
          !_searching &&
          (!_hasDocument || _mode == ViewMode.preview),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyO, control: true): _open,
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
            if (_hasDocument) _openSearch();
          },
        },
        child: Scaffold(
          appBar: _buildAppBar(wide),
          body: SafeArea(top: false, child: _buildBody()),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool wide) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final canSave = _hasDocument && (_dirty || _uri == null);

    return AppBar(
      titleSpacing: 16,
      shape: Border(bottom: BorderSide(color: theme.dividerColor)),
      title: Row(
        children: [
          if (wide) ...[
            Icon(Icons.article_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              _hasDocument ? _fileName : _l.appTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '•',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
      actions: [
        if (_hasDocument)
          SegmentedButton<ViewMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              ButtonSegment(
                value: ViewMode.preview,
                icon: Icon(
                  Icons.visibility_outlined,
                  semanticLabel: _l.modePreview,
                ),
                tooltip: _l.modePreview,
              ),
              ButtonSegment(
                value: ViewMode.edit,
                icon: Icon(Icons.edit_outlined, semanticLabel: _l.modeEdit),
                tooltip: _l.modeEdit,
              ),
              if (wide)
                ButtonSegment(
                  value: ViewMode.split,
                  icon: Icon(
                    Icons.vertical_split_outlined,
                    semanticLabel: _l.modeSplit,
                  ),
                  tooltip: _l.modeSplit,
                ),
            ],
            selected: {_shown},
            onSelectionChanged: (s) => _setMode(s.first),
          ),
        const SizedBox(width: 4),
        if (_hasDocument)
          IconButton(
            tooltip: _l.save,
            icon: const Icon(Icons.save_outlined),
            onPressed: canSave ? _save : null,
          ),
        if (wide && _hasDocument)
          IconButton(
            tooltip: _l.search,
            icon: Icon(Icons.search, semanticLabel: _l.search),
            onPressed: _searching ? () => setState(_closeSearch) : _openSearch,
          ),
        if (wide) ...[
          IconButton(
            tooltip: _l.smallerText,
            icon: const Text('A−', style: TextStyle(fontSize: 18)),
            onPressed: _fontSize > 10 ? () => _changeFontSize(-1) : null,
          ),
          IconButton(
            tooltip: _l.largerText,
            icon: const Text('A+', style: TextStyle(fontSize: 18)),
            onPressed: _fontSize < 32 ? () => _changeFontSize(1) : null,
          ),
          IconButton(
            tooltip: _l.openFile,
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: _open,
          ),
          IconButton(
            tooltip: dark ? _l.lightTheme : _l.darkTheme,
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
        _buildMenu(wide, dark),
        const SizedBox(width: 4),
      ],
      bottom: _searching && _hasDocument ? _buildSearchBar() : null,
    );
  }

  Widget _buildMenu(bool wide, bool dark) {
    final items = <PopupMenuEntry<VoidCallback>>[
      PopupMenuItem(
        value: _create,
        child: ListTile(
          leading: Icon(Icons.note_add_outlined),
          title: Text(_l.newDocument),
        ),
      ),
      if (!wide)
        PopupMenuItem(
          value: _open,
          child: ListTile(
            leading: Icon(Icons.folder_open_outlined),
            title: Text(_l.openFile),
          ),
        ),
      if (_hasDocument)
        PopupMenuItem(
          value: () => _save(saveAs: true),
          child: ListTile(
            leading: Icon(Icons.save_as_outlined),
            title: Text(_l.saveAs),
          ),
        ),
      if (_hasDocument && !wide)
        PopupMenuItem(
          value: _openSearch,
          child: ListTile(leading: Icon(Icons.search), title: Text(_l.search)),
        ),
      if (_hasDocument)
        PopupMenuItem(
          value: _copyAll,
          child: ListTile(
            leading: Icon(Icons.content_copy),
            title: Text(_l.copyAll),
          ),
        ),
      if (_shown == ViewMode.split)
        CheckedPopupMenuItem(
          value: () => setState(() => _syncScroll = !_syncScroll),
          checked: _syncScroll,
          child: Text(_l.syncScrolling),
        ),
      PopupMenuItem(
        value: _showSample,
        child: ListTile(
          leading: Icon(Icons.auto_stories_outlined),
          title: Text(_l.sample),
        ),
      ),
      if (!wide) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: () => _changeFontSize(-1),
          child: ListTile(
            leading: Icon(Icons.text_decrease),
            title: Text(_l.smallerText),
          ),
        ),
        PopupMenuItem(
          value: () => _changeFontSize(1),
          child: ListTile(
            leading: Icon(Icons.text_increase),
            title: Text(_l.largerText),
          ),
        ),
        PopupMenuItem(
          value: widget.onToggleTheme,
          child: ListTile(
            leading: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            title: Text(dark ? _l.lightTheme : _l.darkTheme),
          ),
        ),
      ],
      const PopupMenuDivider(),
      PopupMenuItem(
        value: () => showAboutAppDialog(context, onOpenUrl: _openLink),
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text(_l.about),
        ),
      ),
    ];
    return PopupMenuButton<VoidCallback>(
      tooltip: _l.more,
      icon: Icon(Icons.more_vert, semanticLabel: _l.more),
      onSelected: (action) => action(),
      itemBuilder: (_) => items,
    );
  }

  PreferredSizeWidget _buildSearchBar() {
    final theme = Theme.of(context);
    final count = _searchController.text.isEmpty
        ? ''
        : _matches.isEmpty
        ? '0/0'
        : '${_matchIndex + 1}/${_matches.length}';
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onQueryChanged,
                onSubmitted: (_) {
                  _step(1);
                  _searchFocus.requestFocus();
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _l.search,
                  prefixIcon: const Icon(Icons.search),
                  suffixText: count,
                  suffixStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              tooltip: _l.previousMatch,
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: _matches.isEmpty ? null : () => _step(-1),
            ),
            IconButton(
              tooltip: _l.nextMatch,
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: _matches.isEmpty ? null : () => _step(1),
            ),
            IconButton(
              tooltip: _l.closeSearch,
              icon: const Icon(Icons.close),
              onPressed: () => setState(_closeSearch),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasDocument) return _buildWelcome();
    final editor = _buildEditor();
    switch (_shown) {
      case ViewMode.preview:
        return Stack(
          fit: StackFit.expand,
          children: [
            // Kept alive (but hidden) for its undo history.
            Offstage(child: editor),
            _buildPreview(),
          ],
        );
      case ViewMode.edit:
        return editor;
      case ViewMode.split:
        return Row(
          children: [
            Expanded(child: _syncedPane(_editorScroll, _previewScroll, editor)),
            const VerticalDivider(width: 1),
            Expanded(
              child: _syncedPane(
                _previewScroll,
                _editorScroll,
                _buildPreview(onTapSource: _revealInEditor),
              ),
            ),
          ],
        );
    }
  }

  /// Wraps a split-view pane so scrolling it scrolls the other pane to the
  /// same relative position.
  Widget _syncedPane(
    ScrollController own,
    ScrollController other,
    Widget child,
  ) {
    return Listener(
      onPointerDown: (_) => _scrollLeader = own,
      onPointerSignal: (_) => _scrollLeader = own,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          if (!_syncScroll ||
              _scrollLeader != own ||
              n.metrics.axis != Axis.vertical ||
              !other.hasClients) {
            return false;
          }
          final max = n.metrics.maxScrollExtent;
          final fraction = max <= 0 ? 0.0 : n.metrics.pixels / max;
          final target = other.position;
          target.jumpTo(
            (fraction * target.maxScrollExtent).clamp(
              target.minScrollExtent,
              target.maxScrollExtent,
            ),
          );
          return false;
        },
        child: child,
      ),
    );
  }

  Widget _buildPreview({void Function(int offset)? onTapSource}) =>
      MarkdownPreview(
        data: _previewText,
        fontSize: _fontSize,
        onTapLink: _openLink,
        onTapSource: onTapSource,
        scrollController: _previewScroll,
        searchQuery: _searching ? _searchController.text : '',
        revealOffset: _searching ? _revealOffset : null,
        revealRequest: _revealRequest,
      );

  Widget _buildEditor() => MarkdownEditor(
    key: _editorKey,
    controller: _controller,
    focusNode: _editorFocus,
    fontSize: _fontSize,
    undoController: _undo,
    scrollController: _editorScroll,
  );

  Widget _buildWelcome() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(_l.appTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _l.welcomeText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(_l.openFile),
                ),
                OutlinedButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.note_add_outlined),
                  label: Text(_l.newDocument),
                ),
                OutlinedButton.icon(
                  onPressed: _showSample,
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: Text(_l.sample),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
