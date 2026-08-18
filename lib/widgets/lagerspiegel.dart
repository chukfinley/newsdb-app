/// Der Lagerspiegel — die Anzeige, die eine Verlagsstartseite nicht haben kann.
///
/// Nachbau von `news/frontend/src/components/bias.tsx`, mit derselben
/// Aufteilung in zwei Modi:
///
/// * **kompakt** (Vorgabe) — drei Balken: links, Mitte, rechts. Fuer Kacheln
///   und Listen, wo der Balken nur ein Signal neben einer Schlagzeile ist.
/// * **ausfuehrlich** — die fuenf Stufen, wie sie im Bestand stehen. Fuer die
///   Story-Ansicht, wo der Leser Zeit hat.
///
/// Uebergeben wird **immer** die Fuenf-Stufen-Verteilung aus der API
/// (`story.bias_spread`); zusammengefasst wird hier, nicht beim Aufrufer — und
/// **nur in der Anzeige**. Datenbank und API fuehren weiter fuenf Stufen.
library;

import 'package:flutter/material.dart';

import '../design/thema.dart';
import '../design/typografie.dart';

/// Die Reihenfolge der fuenf Stufen im Balken, links nach rechts.
const stufenFolge = ['left', 'center-left', 'center', 'center-right', 'right'];

/// Die drei Lager in derselben Richtung.
const lagerFolge = ['left', 'center', 'right'];

const lagerKurz = {'left': 'links', 'center': 'Mitte', 'right': 'rechts'};

const lagerLang = {
  'left': 'linkes Lager',
  'center': 'Mitte',
  'right': 'rechtes Lager',
};

/// Fuenf Stufen zu drei Lagern addieren.
///
/// Was keine Einordnung hat, faellt heraus — es steht in keinem Lager und darf
/// keines aufblaehen. Genau diese Regel steht auch in `newsdb/bias.py`; wer sie
/// hier anders schreibt, bekommt eine App, die andere Anteile anzeigt als die
/// API berechnet.
Map<String, int> lagerVerteilung(Map<String, dynamic>? verteilung) {
  final raus = {'left': 0, 'center': 0, 'right': 0};
  if (verteilung == null) return raus;
  for (final eintrag in verteilung.entries) {
    final lager = Blatt.lagerVon(eintrag.key);
    final n = (eintrag.value as num?)?.toInt() ?? 0;
    if (lager != null && n > 0) raus[lager] = raus[lager]! + n;
  }
  return raus;
}

/// Welche Lager fehlen — die Grundlage des Blindspots.
///
/// Fehlen **alle drei**, ist nichts eingeordnet; dann wird nichts als fehlend
/// gemeldet, denn „unbekannt" ist keine Luecke im Spektrum, sondern fehlendes
/// Wissen ueber die Haeuser.
List<String> fehlendeLager(Map<String, dynamic>? verteilung) {
  final v = lagerVerteilung(verteilung);
  final fehlt = lagerFolge.where((l) => v[l] == 0).toList();
  return fehlt.length == 3 ? const [] : fehlt;
}

enum Spiegelmodus { kompakt, ausfuehrlich }

/// Die Verteilung als durchgehender Balken.
class Lagerspiegel extends StatelessWidget {
  const Lagerspiegel({
    required this.verteilung,
    this.hoehe = 6,
    this.modus = Spiegelmodus.kompakt,
    this.zahlen = false,
    this.buchstaben = false,
    super.key,
  });

  /// Die Fuenf-Stufen-Verteilung aus der API.
  final Map<String, dynamic>? verteilung;

  /// Hoehe in logischen Pixeln. Die Kachelraenge bringen ihre eigene mit
  /// (`Kachelrang.balken`): 10 px beim Aufmacher, 4 px bei der Zeile.
  final double hoehe;

  final Spiegelmodus modus;

  /// Anzahl in die Segmente schreiben. Erst ab etwa 24 px Hoehe sinnvoll —
  /// darunter passt keine Ziffer hinein, und eine abgeschnittene Ziffer ist
  /// schlimmer als keine.
  final bool zahlen;

  /// L/M/R direkt ins Farbfeld schreiben, statt in eine Legende darunter
  /// (Ansage vom 18.8.2026, aus dem Web uebernommen). Der Balken beschriftet
  /// dann seine Farbe selbst. Braucht Hoehe fuer die Buchstaben — sinnvoll ab
  /// etwa 18 px. Nur im kompakten Modus (drei Lager); die fuenf Stufen tragen
  /// keine sinnvollen Einbuchstaben.
  final bool buchstaben;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final kompakt = modus == Spiegelmodus.kompakt;

    final teile = <(String, int, Color)>[];
    if (kompakt) {
      final v = lagerVerteilung(verteilung);
      for (final lager in lagerFolge) {
        teile.add((lager, v[lager]!, blatt.lager(lager)));
      }
    } else {
      for (final stufe in stufenFolge) {
        final n = (verteilung?[stufe] as num?)?.toInt() ?? 0;
        teile.add((stufe, n, blatt.stufe(stufe)));
      }
    }

    final summe = teile.fold<int>(0, (s, t) => s + t.$2);
    if (summe == 0) {
      // Kein Balken ohne Zahlen: eine leere Flaeche in Lagerfarben wuerde
      // behaupten, es sei ausgewogen berichtet worden.
      return SizedBox(
        height: hoehe,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: blatt.stufeUnbekannt,
            borderRadius: BorderRadius.circular(hoehe / 2),
          ),
        ),
      );
    }

    return Semantics(
      label: _vorlesen(teile, summe, kompakt),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(hoehe / 2),
        // Zwei Masse, die beide noetig sind, und beide aus demselben Grund:
        // ohne sie ist der Balken **unsichtbar**, ohne dass irgendetwas
        // schiefgeht.
        //
        // * `width: double.infinity` — in einer `Column` mit
        //   `crossAxisAlignment.start` bekommt das Kind lockere Breitenmasse,
        //   und eine `SizedBox` ohne Breite nimmt sich davon die kleinste.
        // * `CrossAxisAlignment.stretch` — eine `Row` gibt ihren Kindern
        //   standardmaessig lockere **Hoehe**, und `ColoredBox` **ohne Kind**
        //   nimmt sich davon ebenfalls die kleinste, also null. Im
        //   ausfuehrlichen Modus faellt das nicht auf: dort steht eine Ziffer
        //   im Segment, und mit Kind hat die Flaeche eine Hoehe.
        //
        // Gefunden am 17.8.2026 im Golden-Test — auf jeder Kachel fehlte der
        // Balken, im ausfuehrlichen Modus war er da.
        child: SizedBox(
          height: hoehe,
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (name, n, farbe) in teile)
                if (n > 0)
                  Expanded(
                    flex: n,
                    child: ColoredBox(
                      color: farbe,
                      child: _segmentschrift(blatt, name, n, summe, kompakt),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  /// Was im Farbfeld steht: der Buchstabe (L/M/R), die Zahl, oder nichts.
  ///
  /// Der Buchstabe erscheint nur, wenn das Segment breit genug ist — ein
  /// abgeschnittenes "L" auf einem Zwei-Prozent-Streifen ist schlechter als
  /// keins. Dieselbe Schwelle wie im Web (rund 6 Prozent Anteil).
  Widget? _segmentschrift(
      Blatt blatt, String name, int n, int summe, bool kompakt) {
    final aufFarbe = kompakt
        ? blatt.aufLager(name)
        : (name == 'center' ? blatt.aufLagerMitte : const Color(0xFFFFFFFF));
    if (buchstaben && kompakt && summe > 0 && n / summe > 0.06) {
      return Center(
        child: Text(
          lagerBuchstabe[name] ?? '',
          style: Stil.kicker.copyWith(
            color: aufFarbe,
            fontSize: (hoehe * 0.55).clamp(9.0, 13.0),
          ),
        ),
      );
    }
    if (zahlen) {
      return Center(
        child: Text(
          '$n',
          style: Stil.zahl.copyWith(color: aufFarbe, fontSize: hoehe * 0.5),
        ),
      );
    }
    return null;
  }

  /// Fuer die Vorlesefunktion. Ein Balken ohne Beschriftung ist fuer jemanden,
  /// der die App vorlesen laesst, sonst gar nicht vorhanden — und der
  /// Lagerspiegel ist der Grund, warum diese App existiert.
  String _vorlesen(List<(String, int, Color)> teile, int summe, bool kompakt) {
    final stuecke = teile
        .where((t) => t.$2 > 0)
        .map((t) => '${t.$2} aus ${kompakt ? lagerLang[t.$1]! : t.$1}')
        .join(', ');
    return 'Lagerspiegel: $summe Berichte — $stuecke';
  }
}

/// Ein Punkt in der Farbe eines Lagers, fuer Zeilen und Aufzaehlungen.
class Lagerpunkt extends StatelessWidget {
  const Lagerpunkt({required this.lager, this.groesse = 8, super.key});

  final String? lager;
  final double groesse;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Container(
      width: groesse,
      height: groesse,
      decoration: BoxDecoration(
        color: lager == null ? blatt.stufeUnbekannt : blatt.lager(lager!),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Die Kuerzel je Lager mit ihrer Zahl: **l 3 · m 26 · r 18**, jedes in seiner
/// Farbe.
///
/// Loest die alte Legende ab, die nur „links Mitte rechts" mit drei Punkten
/// zeigte. Ansage vom 17.8.2026: „r fuer rechts, m fuer Mitte, l fuer links in
/// den Farben" und mehr Angaben schon auf der Titelseite.
///
/// **Der Gewinn ist die Zahl, nicht der Buchstabe.** Ein Balken zeigt
/// Verhaeltnisse; ob dahinter 3 Haeuser stehen oder 300, sieht man ihm nicht
/// an. Genau das entscheidet aber, wie ernst eine Schieflage zu nehmen ist:
/// zwei zu eins ist Zufall, zwanzig zu eins ist ein Befund.
///
/// **Ein Lager mit null Berichten wird gezeigt, nicht weggelassen** — als
/// blasse Null. Das Fehlen ist die Aussage, um die es geht; ein weggelassenes
/// Kuerzel waere genau die Luecke, die niemand bemerkt.
class Lagerkuerzel extends StatelessWidget {
  const Lagerkuerzel({
    required this.verteilung,
    this.klein = false,
    super.key,
  });

  /// Die Fuenf-Stufen-Verteilung aus der API.
  final Map<String, dynamic>? verteilung;

  /// Fuer die kleineren Kachelraenge: enger gesetzt, kleinere Schrift.
  final bool klein;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final v = lagerVerteilung(verteilung);
    final summe = v.values.fold<int>(0, (a, b) => a + b);
    if (summe == 0) return const SizedBox.shrink();

    return Wrap(
      spacing: klein ? Mass.knapp : Mass.normal,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final lager in lagerFolge)
          Semantics(
            label: '${v[lager]} aus ${lagerLang[lager]}',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lagerBuchstabe[lager]!,
                  style: Stil.kicker.copyWith(
                    // Der Buchstabe traegt die Farbe des Lagers. Die Mitte ist
                    // in beiden Ausgaben ein helles Grau — als Schrift auf
                    // Papier waere sie kaum zu lesen, deshalb dort die
                    // gedaempfte Tinte statt der Balkenfarbe.
                    color: lager == 'center'
                        ? blatt.tinteGedaempft
                        : blatt.lager(lager),
                    fontSize: klein ? 10 : 11,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '${v[lager]}',
                  style: Stil.zahl.copyWith(
                    fontSize: klein ? 11 : 12,
                    color: v[lager] == 0 ? blatt.tinteBlass : blatt.tinte,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Die Buchstaben, mit denen die Lager beschriftet werden.
const lagerBuchstabe = {'left': 'L', 'center': 'M', 'right': 'R'};
