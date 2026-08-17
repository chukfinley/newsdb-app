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
        child: SizedBox(
          height: hoehe,
          child: Row(
            children: [
              for (final (name, n, farbe) in teile)
                if (n > 0)
                  Expanded(
                    flex: n,
                    child: ColoredBox(
                      color: farbe,
                      child: !zahlen
                          ? null
                          : Center(
                              child: Text(
                                '$n',
                                style: Stil.zahl.copyWith(
                                  color: kompakt
                                      ? blatt.aufLager(name)
                                      : (name == 'center'
                                          ? blatt.aufLagerMitte
                                          : const Color(0xFFFFFFFF)),
                                  fontSize: hoehe * 0.5,
                                ),
                              ),
                            ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
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

/// Die Legende unter dem Balken — nur beim Aufmacher, wo Platz dafuer ist.
class Lagerlegende extends StatelessWidget {
  const Lagerlegende({super.key});

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Row(
      children: [
        for (final lager in lagerFolge) ...[
          Lagerpunkt(lager: lager, groesse: 7),
          const SizedBox(width: 5),
          Text(
            lagerKurz[lager]!,
            style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
          ),
          if (lager != 'right') const SizedBox(width: Mass.normal),
        ],
      ],
    );
  }
}
