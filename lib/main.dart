import 'package:flutter/material.dart';

import 'src/about.dart';
import 'src/viewer_page.dart';

void main() => runApp(const MarkdownViewerApp());

class MarkdownViewerApp extends StatefulWidget {
  const MarkdownViewerApp({super.key});

  @override
  State<MarkdownViewerApp> createState() => _MarkdownViewerAppState();
}

class _MarkdownViewerAppState extends State<MarkdownViewerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6E66F2),
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    ),
    appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      home: Builder(
        builder: (context) => ViewerPage(
          onToggleTheme: () => setState(() {
            final dark = Theme.of(context).brightness == Brightness.dark;
            _themeMode = dark ? ThemeMode.light : ThemeMode.dark;
          }),
        ),
      ),
    );
  }
}
