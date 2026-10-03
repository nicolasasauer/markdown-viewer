import 'package:flutter/material.dart';

/// Store name, shown in the app bar and the about dialog. The launcher label
/// (AndroidManifest.xml) is the shorter "Markdown Viewer".
const appName = 'Basic Markdown Viewer';

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
      return AlertDialog(
        icon: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset('assets/icon.png', width: 64, height: 64),
        ),
        title: const Text(appName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Version $appVersion',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'A simple app for reading and editing Markdown files. '
              'No account, no ads, no tracking: your files never leave '
              'your device. Free and open source under the MIT License.',
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code),
              title: const Text('Source code'),
              subtitle: const Text('github.com/nicolasasauer/markdown-viewer'),
              onTap: () => onOpenUrl(sourceCodeUrl),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Open-source licenses'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: appName,
                applicationVersion: appVersion,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
