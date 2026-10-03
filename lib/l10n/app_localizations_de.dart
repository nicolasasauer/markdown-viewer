// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Basic Markdown Viewer';

  @override
  String get modePreview => 'Vorschau';

  @override
  String get modeEdit => 'Bearbeiten';

  @override
  String get modeSplit => 'Geteilte Ansicht';

  @override
  String get save => 'Speichern';

  @override
  String get saveAs => 'Speichern unter…';

  @override
  String get saveAsShort => 'Speichern unter';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get discardTitle => 'Änderungen verwerfen?';

  @override
  String unsavedChanges(String name) {
    return '„$name“ hat ungespeicherte Änderungen.';
  }

  @override
  String saved(String name) {
    return '$name gespeichert';
  }

  @override
  String couldNotOpen(String error) {
    return 'Datei konnte nicht geöffnet werden: $error';
  }

  @override
  String couldNotSave(String error) {
    return 'Datei konnte nicht gespeichert werden: $error';
  }

  @override
  String cannotOpenLink(String link) {
    return 'Link kann nicht geöffnet werden: $link';
  }

  @override
  String noAppForLink(String link) {
    return 'Keine App kann $link öffnen';
  }

  @override
  String get documentCopied => 'Dokument kopiert';

  @override
  String get search => 'Suchen';

  @override
  String get previousMatch => 'Vorheriger Treffer';

  @override
  String get nextMatch => 'Nächster Treffer';

  @override
  String get closeSearch => 'Suche schließen';

  @override
  String get smallerText => 'Kleinere Schrift';

  @override
  String get largerText => 'Größere Schrift';

  @override
  String get openFile => 'Datei öffnen';

  @override
  String get lightTheme => 'Helles Design';

  @override
  String get darkTheme => 'Dunkles Design';

  @override
  String get newDocument => 'Neu';

  @override
  String get copyAll => 'Alles kopieren';

  @override
  String get syncScrolling => 'Synchron scrollen';

  @override
  String get sample => 'Beispiel';

  @override
  String get more => 'Mehr';

  @override
  String get welcomeText =>
      'Öffne eine .md-Datei, beginne eine neue oder sieh dir das Beispiel an.';

  @override
  String get nothingToShow => 'Noch nichts anzuzeigen.';

  @override
  String get editorHint => 'Markdown schreiben…';

  @override
  String get undo => 'Rückgängig';

  @override
  String get redo => 'Wiederholen';

  @override
  String get heading => 'Überschrift';

  @override
  String get bold => 'Fett';

  @override
  String get italic => 'Kursiv';

  @override
  String get strikethrough => 'Durchgestrichen';

  @override
  String get code => 'Code';

  @override
  String get link => 'Link';

  @override
  String get bulletedList => 'Aufzählung';

  @override
  String get numberedList => 'Nummerierte Liste';

  @override
  String get checklist => 'Checkliste';

  @override
  String get quote => 'Zitat';

  @override
  String get codeBlock => 'Code-Block';

  @override
  String get table => 'Tabelle';

  @override
  String get horizontalLine => 'Trennlinie';

  @override
  String get tableColumn1 => 'Spalte 1';

  @override
  String get tableColumn2 => 'Spalte 2';

  @override
  String get linkText => 'Text';

  @override
  String get about => 'Über die App';

  @override
  String get aboutText =>
      'Eine einfache App zum Lesen und Bearbeiten von Markdown-Dateien. Kein Konto, keine Werbung, kein Tracking: Deine Dateien verlassen nie dein Gerät. Kostenlos und Open Source unter der MIT-Lizenz.';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get sourceCode => 'Quellcode';

  @override
  String get licenses => 'Open-Source-Lizenzen';

  @override
  String get close => 'Schließen';
}
