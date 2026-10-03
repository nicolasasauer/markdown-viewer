import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

import 'package:markdown_viewer/main.dart';
import 'package:markdown_viewer/src/about.dart';
import 'package:markdown_viewer/src/markdown_preview.dart';

void main() {
  const channel = MethodChannel('markdown_viewer/file');
  final saved = <Map<Object?, Object?>>[];
  final opened = <String>[];
  const sample =
      '# Notes\n\nSome **bold** text and a [link](https://example.com).\n';
  Object? initialFile;

  setUp(() {
    saved.clear();
    opened.clear();
    initialFile = {
      'name': 'notes.md',
      'content': sample,
      'uri': 'content://test/notes.md',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getInitialFile':
              return initialFile;
            case 'saveFile':
              saved.add(call.arguments as Map<Object?, Object?>);
              return null;
            case 'createDocument':
              final args = call.arguments as Map<Object?, Object?>;
              saved.add(args);
              return {'name': args['name'], 'uri': 'content://test/new.md'};
            case 'openUrl':
              opened.add(
                (call.arguments as Map<Object?, Object?>)['url'] as String,
              );
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void useWideScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('opens the initial file in the preview', (tester) async {
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();

    expect(find.text('notes.md'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget); // heading without "#"
    // The preview fills the screen (the hidden editor must not shrink it).
    expect(
      tester.getSize(find.byType(MarkdownPreview)).height,
      greaterThan(300),
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('edit and save back to the file', (tester) async {
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    final editor = tester.widget<TextField>(find.byType(TextField));
    expect(editor.controller!.text, sample);

    await tester.enterText(find.byType(TextField), '# Changed\n');
    await tester.pump();
    expect(find.text('•'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    expect(saved.single['content'], '# Changed\n');
    expect(saved.single['uri'], 'content://test/notes.md');
    expect(find.text('•'), findsNothing);

    await tester.tap(find.byTooltip('Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Changed'), findsOneWidget);
  });

  testWidgets('split view shows editor and live preview', (tester) async {
    useWideScreen(tester);
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Split view'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '## Live\n');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Live'), findsOneWidget);
  });

  testWidgets('phone: no split view, actions move into the menu', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Split view'), findsNothing);
    expect(find.byTooltip('Larger text'), findsNothing);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Larger text'), findsOneWidget);
    expect(find.text('Open file'), findsOneWidget);
  });

  testWidgets('asks before discarding unsaved changes', (tester) async {
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'draft');
    await tester.pump();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('notes.md'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Untitled.md'), findsOneWidget);
  });

  testWidgets('welcome screen, sample and save as', (tester) async {
    initialFile = null;
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();
    expect(find.text(appName), findsWidgets);

    await tester.tap(find.text('Sample'));
    await tester.pumpAndSettle();
    expect(find.text('Sample.md'), findsOneWidget);
    expect(find.text('Welcome 👋'), findsOneWidget);

    // Never saved, so Save asks for a location.
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    expect(saved.single['name'], 'Sample.md');
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    final save = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.save_outlined),
    );
    expect(save.onPressed, isNull);
  });

  /// The rendered span with exactly [text] (preview text is selectable).
  TextSpan findSpan(WidgetTester tester, String text) {
    TextSpan? match;
    for (final widget in tester.widgetList<SelectableText>(
      find.byType(SelectableText),
    )) {
      widget.textSpan?.visitChildren((span) {
        if (span is TextSpan && span.text == text) match ??= span;
        return match == null;
      });
    }
    return match ?? (throw StateError('No span "$text"'));
  }

  testWidgets('links open in another app', (tester) async {
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();

    final link = findSpan(tester, 'link');
    (link.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(opened, ['https://example.com']);
  });

  testWidgets('text size buttons change the preview font', (tester) async {
    useWideScreen(tester);
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();

    final before = findSpan(tester, 'Notes').style!.fontSize!;
    await tester.tap(find.byTooltip('Larger text'));
    await tester.pumpAndSettle();
    expect(findSpan(tester, 'Notes').style!.fontSize!, greaterThan(before));
  });

  testWidgets('about dialog links to the source code', (tester) async {
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Version $appVersion'), findsOneWidget);

    await tester.tap(find.text('Source code'));
    await tester.pumpAndSettle();
    expect(opened, [sourceCodeUrl]);
  });

  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: ([^+\s]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });

  testWidgets('formatting bar makes the selection bold; undo survives modes', (
    tester,
  ) async {
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 1)); // undo history throttle
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 7,
    ); // "Notes"
    await tester.tap(find.byTooltip('Bold'));
    await tester.pumpAndSettle();
    expect(field.controller!.text, startsWith('# **Notes**'));
    await tester.pump(const Duration(seconds: 1)); // undo history throttle

    // Undo still works after a round trip through the preview.
    await tester.tap(find.byTooltip('Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      sample,
    );
  });

  testWidgets('search counts matches and highlights them', (tester) async {
    initialFile = {
      'name': 'notes.md',
      'content': '# Apple\n\nOne apple.\n\nNo fruit.\n\nAPPLE pie.',
      'uri': null,
    };
    useWideScreen(tester);
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'apple');
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.byTooltip('Next match'));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    // The hit is highlighted inside the rendered paragraph.
    final hit = findSpan(tester, 'apple');
    expect(hit.style?.backgroundColor, isNotNull);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsNothing);
  });

  testWidgets('split view: tapping the preview moves the editor cursor', (
    tester,
  ) async {
    initialFile = {
      'name': 'notes.md',
      'content': '# Title\n\nFirst paragraph.\n\nSecond paragraph.',
      'uri': null,
    };
    useWideScreen(tester);
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Split view'));
    await tester.pumpAndSettle();

    final preview = find.byType(SelectableText);
    final second = preview.evaluate().firstWhere(
      (e) =>
          (e.widget as SelectableText).textSpan!.toPlainText() ==
          'Second paragraph.',
    );
    await tester.tap(find.byWidget(second.widget));
    await tester.pumpAndSettle();

    final editor = tester.widget<TextField>(find.byType(TextField));
    expect(editor.controller!.selection.baseOffset, 27);
  });

  testWidgets('split view scrolls both panes together', (tester) async {
    initialFile = {
      'name': 'long.md',
      'content': List.generate(120, (i) => 'Paragraph $i').join('\n\n'),
      'uri': null,
    };
    useWideScreen(tester);
    await tester.pumpWidget(const MarkdownViewerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Split view'));
    await tester.pumpAndSettle();

    final previewScroll = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    );
    double previewPixels() =>
        tester.state<ScrollableState>(previewScroll.first).position.pixels;

    expect(previewPixels(), 0);
    await tester.drag(find.byType(TextField), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(previewPixels(), greaterThan(0));
  });
}
