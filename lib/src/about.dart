import 'package:flutter/material.dart';

import 'l10n.dart';

/// Keep in sync with `version` in pubspec.yaml (checked by a test).
const appVersion = '1.0.0';

const sourceCodeUrl = 'https://github.com/nicolasasauer/markdown-viewer';

/// ⋮ → About: version, what the app does with data, source code, licenses.
Future<void> showAboutAppDialog(
  BuildContext context, {
  required void Function(String url) onOpenUrl,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final l = context.l10n;
      return AlertDialog(
        icon: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset('assets/icon.png', width: 64, height: 64),
        ),
        title: Text(l.appTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.version(appVersion),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(l.aboutText),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code),
              title: Text(l.sourceCode),
              subtitle: const Text('github.com/nicolasasauer/markdown-viewer'),
              onTap: () => onOpenUrl(sourceCodeUrl),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(l.licenses),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l.appTitle,
                applicationVersion: appVersion,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.close),
          ),
        ],
      );
    },
  );
}
