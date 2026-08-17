/// Die Schriftstile des Blattes, aus der Web-Oberflaeche uebernommen.
///
/// Quelle jeder Zahl hier ist `news/frontend/src/index.css` (die Klassen
/// `.kicker`, `.meta`, `.headline`, `.prose-news`) und
/// `components/reader/home/teasers.tsx` (die vier Kachelgroessen). Es ist
/// nichts geschaetzt: die Werte im Web stehen fuer die **Handy-Breite** schon
/// dort, weil die Groessenklassen erst ab `sm:` wachsen — `text-[2.1rem]` ist
/// die Schlagzeile des Aufmachers auf dem Telefon, `sm:text-[2.6rem]` erst ab
/// 640 px.
///
/// Zwei Dinge macht Flutter anders als der Browser, und beide sind hier
/// ausgeschrieben statt weggelassen:
///
/// **1. Schriftgewicht 620 gibt es in `FontWeight` nicht.** Die Klasse kennt
/// nur Hunderterschritte, `.headline` und `.kicker` stehen aber auf 620. Bei
/// einer variablen Schrift ist das kein Rundungsproblem, sondern eine Achse:
/// `FontVariation('wght', 620)` trifft den Wert genau, `FontWeight.w600`
/// waere ein anderer Schnitt.
///
/// **2. Optische Groesse muss man selbst setzen.** Der Browser macht
/// `font-optical-sizing: auto` von allein, Flutter nicht. Newsreader
/// (opsz 6–72) und Source Serif 4 (opsz 8–60) haben die Achse, und sie ist
/// der Grund, warum eine Schlagzeile in 34 px enger und feiner wirkt als
/// derselbe Schnitt hochskaliert. Ohne `opsz` sieht die Ueberschrift aus wie
/// vergroesserter Lesetext — genau der Eindruck, den ein Blatt nicht haben
/// darf.
library;

import 'package:flutter/material.dart';

/// Die Familiennamen, wie sie in `pubspec.yaml` stehen.
abstract final class Schrift {
  /// Display und Schlagzeilen.
  static const display = 'Newsreader';

  /// Lesetext.
  static const serif = 'SourceSerif4';

  /// Meta, Navigation, Bedienelemente.
  static const sans = 'Archivo';

  /// Zahlen, URLs, Hashes.
  static const mono = 'JetBrainsMono';
}

/// Die opsz-Grenzen der beiden Serifenschriften. Wird `opsz` ausserhalb
/// gesetzt, klemmt die Schrift-Engine still — dann waere die Achse wirkungslos
/// und niemand saehe, warum.
const _opszDisplay = (min: 6.0, max: 72.0);
const _opszSerif = (min: 8.0, max: 60.0);

double _klemm(double wert, ({double min, double max}) grenzen) =>
    wert.clamp(grenzen.min, grenzen.max);

/// Ziffern im Blattstil: Mediaevalziffern mit proportionaler Breite, so wie
/// `body` es im CSS setzt (`oldstyle-nums proportional-nums`). Sie sind der
/// Grund, warum eine Jahreszahl im Fliesstext nicht heraussticht.
const zifferBlatt = <FontFeature>[
  FontFeature.oldstyleFigures(),
  FontFeature.proportionalFigures(),
];

/// Ziffern fuer Zahlen, die untereinander stehen sollen: Versalziffern,
/// gleiche Breite. Im CSS sind das `.num`, `.tnum` und `.meta`.
const zifferTabelle = <FontFeature>[
  FontFeature.tabularFigures(),
  FontFeature.liningFigures(),
];

/// Die Stile des Blattes. Farben kommen **nicht** von hier, sondern aus dem
/// Theme — derselbe Stil gilt in Tag- und Nachtausgabe, nur die Tinte wechselt.
abstract final class Stil {
  /// Dachzeile: Versalien, gesperrt, klein. Das klassische Zeitungssignal.
  /// CSS: 0.6875rem = 11 px, Gewicht 620, `letter-spacing: 0.13em`.
  ///
  /// Flutter rechnet `letterSpacing` in logischen Pixeln, CSS in `em` — also
  /// 0.13 × 11 = 1.43. Wer den em-Wert direkt einsetzt, bekommt Text, der
  /// aussieht wie zusammengeklebt.
  static const kicker = TextStyle(
    fontFamily: Schrift.sans,
    fontSize: 11,
    letterSpacing: 0.13 * 11,
    height: 1.2,
    fontVariations: [FontVariation('wght', 620)],
    fontFeatures: zifferTabelle,
  );

  /// Metazeile: Haus, Zeit, Anzahl. CSS: 0.75rem = 12 px, Gewicht 450.
  static const meta = TextStyle(
    fontFamily: Schrift.sans,
    fontSize: 12,
    letterSpacing: 0.005 * 12,
    height: 1.35,
    fontVariations: [FontVariation('wght', 450)],
    fontFeatures: zifferTabelle,
  );

  /// Fliesstext im Artikel. CSS `.prose-news`: 1.1875rem = 19 px, Zeilenhoehe
  /// 1.68. Die 19 px sind kein Zufall und werden nicht „fuers Handy" geaendert:
  /// die Lesespalte im Web ist auf 39 rem und damit auf etwa 68 Zeichen je
  /// Zeile gerechnet, und auf einem Telefon in Hochkant kommt dieselbe
  /// Schriftgroesse auf gut 40 Zeichen — beides im lesbaren Bereich.
  static final lesetext = TextStyle(
    fontFamily: Schrift.serif,
    fontSize: 19,
    height: 1.68,
    fontVariations: [
      const FontVariation('wght', 400),
      FontVariation('opsz', _klemm(19, _opszSerif)),
    ],
    fontFeatures: zifferBlatt,
  );

  /// Eine Zeile im Dreiklang (dieselbe Meldung je Lager). CSS: `font-serif`,
  /// 14 px, `leading-snug` = 1.375.
  static final lagerZeile = TextStyle(
    fontFamily: Schrift.serif,
    fontSize: 14,
    height: 1.375,
    fontVariations: [
      const FontVariation('wght', 400),
      FontVariation('opsz', _klemm(14, _opszSerif)),
    ],
    fontFeatures: zifferBlatt,
  );

  /// Eine Schlagzeile in freier Groesse.
  ///
  /// `.headline` im CSS: Gewicht 620, `letter-spacing: -0.018em`,
  /// Zeilenhoehe 1.08 — die Kacheln ueberschreiben die Zeilenhoehe je Groesse,
  /// deshalb ist sie hier ein Parameter mit dem CSS-Wert als Vorgabe.
  ///
  /// Die negative Laufweite ist der Punkt, an dem eine Schlagzeile nach
  /// Zeitung aussieht statt nach Webseite: -0.018em sind bei 34 px gut ein
  /// halbes Pixel je Zeichen, und genau das nimmt der Zeile die Luft.
  static TextStyle schlagzeile(double groesse, {double zeilenhoehe = 1.08}) =>
      TextStyle(
        fontFamily: Schrift.display,
        fontSize: groesse,
        height: zeilenhoehe,
        letterSpacing: -0.018 * groesse,
        fontVariations: [
          const FontVariation('wght', 620),
          FontVariation('opsz', _klemm(groesse, _opszDisplay)),
        ],
        fontFeatures: zifferBlatt,
      );

  /// Zahlen, die gezaehlt werden — Haeuserzahl, Prozente, Ereigniszaehler.
  static const zahl = TextStyle(
    fontFamily: Schrift.sans,
    fontSize: 13,
    fontVariations: [FontVariation('wght', 550)],
    fontFeatures: zifferTabelle,
  );

  /// Technisches: URLs, Kennungen, Hashes.
  static const technisch = TextStyle(
    fontFamily: Schrift.mono,
    fontSize: 12,
    height: 1.45,
    fontVariations: [FontVariation('wght', 400)],
  );
}

/// Die vier Kachelgroessen der Titelseite.
///
/// **Der Rang bestimmt die Flaeche** — das ist die Entscheidung aus
/// `teasers.tsx` vom 16.8.2026, und sie ist der Grund, warum die Titelseite
/// eine Rangfolge hat und nicht nur eine Liste. Die Werte sind eins zu eins
/// die des Webs, umgerechnet von rem in logische Pixel (1 rem = 16 px):
///
/// | Groesse   | Web                    | hier                  |
/// |-----------|------------------------|-----------------------|
/// | Aufmacher | `text-[2.1rem]/1.05`   | 33.6 px, Hoehe 1.05   |
/// | Doppel    | `text-[1.55rem]/1.1`   | 24.8 px, Hoehe 1.1    |
/// | Kachel    | `text-[1.2rem]/1.16`   | 19.2 px, Hoehe 1.16   |
/// | Zeile     | `text-[1.05rem]/1.2`   | 16.8 px, Hoehe 1.2    |
enum Kachelrang {
  /// Die wichtigste Meldung, Bild im Format 3:2, Lagerbalken 10 px.
  aufmacher(schrift: 33.6, hoehe: 1.05, bildformat: 3 / 2, balken: 10),

  /// Zu zweit unter dem Aufmacher, 16:9, Balken 8 px.
  doppel(schrift: 24.8, hoehe: 1.1, bildformat: 16 / 9, balken: 8),

  /// Der Regelfall, 16:10, Balken 6 px.
  kachel(schrift: 19.2, hoehe: 1.16, bildformat: 16 / 10, balken: 6),

  /// Der Kopf eines Themenblocks. Flach mit Absicht: mit 16:10 bekaeme er in
  /// halber Breite ein groesseres Bild als die hoeherrangigen Kacheln darueber
  /// und wuerde die Rangfolge umdrehen.
  zeile(schrift: 16.8, hoehe: 1.2, bildformat: 21 / 9, balken: 4);

  const Kachelrang({
    required this.schrift,
    required this.hoehe,
    required this.bildformat,
    required this.balken,
  });

  final double schrift;
  final double hoehe;
  final double bildformat;

  /// Hoehe des Lagerbalkens in logischen Pixeln.
  final double balken;

  TextStyle get stil => Stil.schlagzeile(schrift, zeilenhoehe: hoehe);
}

/// Abstaende, wie das Web sie setzt. Tailwind rechnet in Vierteln: `gap-6`
/// sind 24 px, `mt-3` sind 12 px. Hier stehen sie mit Namen, damit in den
/// Widgets keine nackten Zahlen liegen.
abstract final class Mass {
  /// `mb-1.5` / `space-y-1.5` — zwischen Zeilen einer Aufzaehlung.
  static const eng = 6.0;

  /// `mt-2` — Legende unter dem Balken.
  static const knapp = 8.0;

  /// `mb-2.5` — zwischen Abzeichenreihe und Schlagzeile.
  static const abzeichen = 10.0;

  /// `mt-3` / `mb-3` — Standardabstand innerhalb einer Kachel.
  static const normal = 12.0;

  /// `mt-4` — zwischen Bloecken einer Kachel.
  static const block = 16.0;

  /// `gap-6` — zwischen Kacheln.
  static const kachel = 24.0;

  /// Der Seitenrand. Im Web `px-4`.
  static const rand = 16.0;

  /// Die Lesespalte: `.column` ist 39 rem. Auf dem Telefon nie erreicht, auf
  /// einem Tablet der Grund, warum der Text nicht ueber die ganze Breite laeuft.
  static const lesespalte = 624.0;

  /// `--radius: 0.3rem`.
  static const rundung = 4.8;
}
