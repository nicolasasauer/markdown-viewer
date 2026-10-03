// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Basic Markdown Viewer';

  @override
  String get modePreview => 'Preview';

  @override
  String get modeEdit => 'Edit';

  @override
  String get modeSplit => 'Split view';

  @override
  String get save => 'Save';

  @override
  String get saveAs => 'Save as…';

  @override
  String get saveAsShort => 'Save as';

  @override
  String get cancel => 'Cancel';

  @override
  String get discard => 'Discard';

  @override
  String get discardTitle => 'Discard changes?';

  @override
  String unsavedChanges(String name) {
    return '\"$name\" has unsaved changes.';
  }

  @override
  String saved(String name) {
    return 'Saved $name';
  }

  @override
  String couldNotOpen(String error) {
    return 'Could not open file: $error';
  }

  @override
  String couldNotSave(String error) {
    return 'Could not save file: $error';
  }

  @override
  String cannotOpenLink(String link) {
    return 'Cannot open link: $link';
  }

  @override
  String noAppForLink(String link) {
    return 'No app can open $link';
  }

  @override
  String get documentCopied => 'Document copied';

  @override
  String get search => 'Search';

  @override
  String get previousMatch => 'Previous match';

  @override
  String get nextMatch => 'Next match';

  @override
  String get closeSearch => 'Close search';

  @override
  String get smallerText => 'Smaller text';

  @override
  String get largerText => 'Larger text';

  @override
  String get openFile => 'Open file';

  @override
  String get lightTheme => 'Light theme';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get newDocument => 'New';

  @override
  String get copyAll => 'Copy all';

  @override
  String get syncScrolling => 'Sync scrolling';

  @override
  String get sample => 'Sample';

  @override
  String get more => 'More';

  @override
  String get welcomeText =>
      'Open a .md file, start a new one or look at the sample.';

  @override
  String get nothingToShow => 'Nothing to show yet.';

  @override
  String get editorHint => 'Start writing Markdown…';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get heading => 'Heading';

  @override
  String get bold => 'Bold';

  @override
  String get italic => 'Italic';

  @override
  String get strikethrough => 'Strikethrough';

  @override
  String get code => 'Code';

  @override
  String get link => 'Link';

  @override
  String get bulletedList => 'Bulleted list';

  @override
  String get numberedList => 'Numbered list';

  @override
  String get checklist => 'Checklist';

  @override
  String get quote => 'Quote';

  @override
  String get codeBlock => 'Code block';

  @override
  String get table => 'Table';

  @override
  String get horizontalLine => 'Horizontal line';

  @override
  String get tableColumn1 => 'Column 1';

  @override
  String get tableColumn2 => 'Column 2';

  @override
  String get linkText => 'text';

  @override
  String get about => 'About';

  @override
  String get aboutText =>
      'A simple app for reading and editing Markdown files. No account, no ads, no tracking: your files never leave your device. Free and open source under the MIT License.';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get sourceCode => 'Source code';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get close => 'Close';
}
