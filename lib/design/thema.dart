/// Tages- und Nachtausgabe als Flutter-Theme.
///
/// Die Farben kommen aus `tokens.dart` und damit aus der Web-Oberflaeche; hier
/// werden sie nur zugeordnet. Zwei Wege stehen bereit, und die Unterscheidung
/// ist wichtig:
///
/// * **`Blatt`** — die Farben des Blattes unter ihren eigenen Namen: Papier,
///   Tinte, Linie, Lager. Das ist die Wahrheit fuer alles, was dieses Projekt
///   selbst zeichnet.
/// * **`ColorScheme`** — die Zuordnung fuer Materials eigene Widgets
///   (Dialoge, Schalter, Auswahlfelder). Sie ist eine Uebersetzung, kein
///   Ersatz: Material kennt kein „Papier" und keine „Linie", und wer die
///   Kachel eines Blattes aus `surfaceContainerHighest` baut, hat am Ende ein
///   Material-Design mit Serifen.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typografie.dart';

/// Die Farben des Blattes. Zugriff ueber `Blatt.of(context)`.
@immutable
class Blatt extends ThemeExtension<Blatt> {
  const Blatt({
    required this.papier,
    required this.papierGehoben,
    required this.papierVertieft,
    required this.tinte,
    required this.tinteGedaempft,
    required this.tinteBlass,
    required this.linie,
    required this.linieStark,
    required this.akzent,
    required this.akzentSanft,
    required this.verweis,
    required this.gut,
    required this.warnung,
    required this.schlecht,
    required this.lagerLinks,
    required this.lagerMitte,
    required this.lagerRechts,
    required this.aufLagerMitte,
    required this.stufeLinks,
    required this.stufeMitteLinks,
    required this.stufeMitte,
    required this.stufeMitteRechts,
    required this.stufeRechts,
    required this.stufeUnbekannt,
  });

  /// Der Blatthintergrund.
  final Color papier;

  /// Eine Flaeche darueber — Karten, Blaetter, Leisten.
  final Color papierGehoben;

  /// Eine Flaeche darunter — Eingabefelder, Ruhezonen.
  final Color papierVertieft;

  /// Die Druckfarbe.
  final Color tinte;

  /// Meta, Nebensaechliches.
  final Color tinteGedaempft;

  /// Noch eine Stufe leiser: Platzhalter, abgeschaltete Elemente.
  final Color tinteBlass;

  /// Die Haarlinie des Blattlayouts.
  final Color linie;

  /// Die staerkere Trennung zwischen Abschnitten.
  final Color linieStark;

  /// Redaktionsrot.
  final Color akzent;

  /// Redaktionsrot als Flaeche hinter Text.
  final Color akzentSanft;

  final Color verweis;
  final Color gut;
  final Color warnung;
  final Color schlecht;

  /// Die drei Lager. **Links rot, rechts blau** — die deutsche Zuordnung,
  /// nicht das US-Schema (Ansage vom 16.8.2026).
  final Color lagerLinks;
  final Color lagerMitte;
  final Color lagerRechts;

  /// Schrift auf dem Mittelbalken. Der ist in **beiden** Ausgaben hell, also
  /// ist die Schrift darauf in beiden dunkel — `tinte` waere nachts hell und
  /// damit unlesbar.
  final Color aufLagerMitte;

  /// Die fuenf Stufen, wie sie in Bestand und API stehen. Zusammengefasst wird
  /// nur in der Anzeige.
  final Color stufeLinks;
  final Color stufeMitteLinks;
  final Color stufeMitte;
  final Color stufeMitteRechts;
  final Color stufeRechts;
  final Color stufeUnbekannt;

  static Blatt of(BuildContext context) =>
      Theme.of(context).extension<Blatt>()!;

  static const hell = Blatt(
    papier: TokensHell.paper,
    papierGehoben: TokensHell.paperRaised,
    papierVertieft: TokensHell.paperSunken,
    tinte: TokensHell.ink,
    tinteGedaempft: TokensHell.inkMuted,
    tinteBlass: TokensHell.inkFaint,
    linie: TokensHell.rule,
    linieStark: TokensHell.ruleStrong,
    akzent: TokensHell.accent,
    akzentSanft: TokensHell.accentSoft,
    verweis: TokensHell.link,
    gut: TokensHell.ok,
    warnung: TokensHell.warn,
    schlecht: TokensHell.bad,
    lagerLinks: TokensHell.campLeft,
    lagerMitte: TokensHell.campCenter,
    lagerRechts: TokensHell.campRight,
    aufLagerMitte: TokensHell.onCampCenter,
    stufeLinks: TokensHell.biasLeft,
    stufeMitteLinks: TokensHell.biasCenterLeft,
    stufeMitte: TokensHell.biasCenter,
    stufeMitteRechts: TokensHell.biasCenterRight,
    stufeRechts: TokensHell.biasRight,
    stufeUnbekannt: TokensHell.biasUnknown,
  );

  static const dunkel = Blatt(
    papier: TokensDunkel.paper,
    papierGehoben: TokensDunkel.paperRaised,
    papierVertieft: TokensDunkel.paperSunken,
    tinte: TokensDunkel.ink,
    tinteGedaempft: TokensDunkel.inkMuted,
    tinteBlass: TokensDunkel.inkFaint,
    linie: TokensDunkel.rule,
    linieStark: TokensDunkel.ruleStrong,
    akzent: TokensDunkel.accent,
    akzentSanft: TokensDunkel.accentSoft,
    verweis: TokensDunkel.link,
    gut: TokensDunkel.ok,
    warnung: TokensDunkel.warn,
    schlecht: TokensDunkel.bad,
    lagerLinks: TokensDunkel.campLeft,
    lagerMitte: TokensDunkel.campCenter,
    lagerRechts: TokensDunkel.campRight,
    aufLagerMitte: TokensDunkel.onCampCenter,
    stufeLinks: TokensDunkel.biasLeft,
    stufeMitteLinks: TokensDunkel.biasCenterLeft,
    stufeMitte: TokensDunkel.biasCenter,
    stufeMitteRechts: TokensDunkel.biasCenterRight,
    stufeRechts: TokensDunkel.biasRight,
    stufeUnbekannt: TokensDunkel.biasUnknown,
  );

  /// Die Farbe einer der fuenf Stufen, wie die API sie liefert
  /// (`left`, `center-left`, `center`, `center-right`, `right`).
  Color stufe(String? name) => switch (name) {
        'left' => stufeLinks,
        'center-left' => stufeMitteLinks,
        'center' => stufeMitte,
        'center-right' => stufeMitteRechts,
        'right' => stufeRechts,
        _ => stufeUnbekannt,
      };

  /// Fuenf Stufen zu drei Lagern — **identisch zu `CAMP_OF` in
  /// `newsdb/bias.py`**: mitte-links zaehlt zu links, mitte-rechts zu rechts.
  /// Was keine Einordnung hat, gehoert in kein Lager.
  static String? lagerVon(String? stufe) => switch (stufe) {
        'left' || 'center-left' => 'left',
        'center' => 'center',
        'center-right' || 'right' => 'right',
        _ => null,
      };

  Color lager(String name) => switch (name) {
        'left' => lagerLinks,
        'center' => lagerMitte,
        _ => lagerRechts,
      };

  /// Lesbare Schrift auf einem Lagerbalken.
  Color aufLager(String name) =>
      name == 'center' ? aufLagerMitte : const Color(0xFFFFFFFF);

  @override
  Blatt copyWith() => this;

  /// Zwischen zwei Ausgaben wird nicht ueberblendet: der Wechsel von Tag auf
  /// Nacht ist ein Umschalten, kein Verlauf. Ein halb ueberblendetes
  /// Zeitungspapier ist eine Farbe, die in keinem der beiden Themes vorkommt.
  @override
  Blatt lerp(ThemeExtension<Blatt>? other, double t) =>
      t < 0.5 ? this : (other as Blatt? ?? this);
}

/// Die Vorgabe fuer alles, was Text zeichnet, ohne selbst einen Stil zu nennen.
TextTheme _textTheme(Blatt blatt) => TextTheme(
      displayLarge: Kachelrang.aufmacher.stil,
      displayMedium: Kachelrang.doppel.stil,
      headlineLarge: Kachelrang.kachel.stil,
      headlineMedium: Kachelrang.zeile.stil,
      titleMedium: Stil.schlagzeile(17, zeilenhoehe: 1.2),
      bodyLarge: Stil.lesetext,
      bodyMedium: Stil.lagerZeile,
      bodySmall: Stil.meta.copyWith(color: blatt.tinteGedaempft),
      labelLarge: Stil.zahl,
      labelSmall: Stil.kicker,
    );

ThemeData _bauen(Blatt blatt, Brightness helligkeit) {
  final schema = ColorScheme(
    brightness: helligkeit,
    primary: blatt.akzent,
    onPrimary: blatt.papierGehoben,
    primaryContainer: blatt.akzentSanft,
    onPrimaryContainer: blatt.tinte,
    secondary: blatt.verweis,
    onSecondary: blatt.papierGehoben,
    error: blatt.schlecht,
    onError: blatt.papierGehoben,
    surface: blatt.papier,
    onSurface: blatt.tinte,
    surfaceContainerLowest: blatt.papierVertieft,
    surfaceContainer: blatt.papier,
    surfaceContainerHighest: blatt.papierGehoben,
    onSurfaceVariant: blatt.tinteGedaempft,
    outline: blatt.linieStark,
    outlineVariant: blatt.linie,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: helligkeit,
    colorScheme: schema,
    extensions: [blatt],
    scaffoldBackgroundColor: blatt.papier,
    canvasColor: blatt.papier,
    dividerColor: blatt.linie,
    textTheme: _textTheme(blatt),
    fontFamily: Schrift.serif,
    dividerTheme: DividerThemeData(
      color: blatt.linie,
      // Die Haarlinie des Blattlayouts ist genau ein Pixel. Materials Vorgabe
      // von 1.0 plus 16 px Einzug daneben macht daraus eine Trennung, die im
      // Blatt nirgends vorkommt.
      thickness: 1,
      space: 1,
      indent: 0,
      endIndent: 0,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: blatt.papier,
      foregroundColor: blatt.tinte,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: Stil.schlagzeile(20).copyWith(color: blatt.tinte),
    ),
    // Keine Schatten. Ein Blatt hat Linien, keine Erhebungen — deshalb steht
    // die Trennung als Rand in den Widgets und nicht als `elevation`.
    cardTheme: CardThemeData(
      color: blatt.papierGehoben,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Mass.rundung),
        side: BorderSide(color: blatt.linie),
      ),
    ),
    // Bewusst kein `splashColor: transparent`: die Rueckmeldung auf eine
    // Beruehrung ist keine Zierde, sondern der einzige Hinweis auf einem
    // Touchscreen, dass der Griff angekommen ist.
    splashColor: blatt.akzentSanft.withValues(alpha: 0.4),
    highlightColor: blatt.akzentSanft.withValues(alpha: 0.25),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: blatt.akzent,
      selectionColor: blatt.akzent.withValues(alpha: 0.28),
      selectionHandleColor: blatt.akzent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: blatt.tinte,
      contentTextStyle: Stil.meta.copyWith(color: blatt.papier),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Mass.rundung),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: blatt.akzent,
      linearTrackColor: blatt.papierVertieft,
      circularTrackColor: blatt.papierVertieft,
    ),
  );
}

ThemeData get tagesausgabe => _bauen(Blatt.hell, Brightness.light);
ThemeData get nachtausgabe => _bauen(Blatt.dunkel, Brightness.dark);
