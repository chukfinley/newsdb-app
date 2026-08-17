/// Die Kacheln der Titelseite.
///
/// Nachbau von `news/frontend/src/components/reader/home/teasers.tsx`, mit
/// derselben Entscheidung im Zentrum: **der Rang bestimmt die Fläche.** Eine
/// Titelseite, auf der Platz 2 und Platz 29 gleich groß sind, behauptet, sie
/// seien gleich wichtig — und die Relevanz, die der Server rechnet, wäre
/// unsichtbar.
///
/// **In der Vorschau weniger, nicht mehr** (Ansage vom 16.8.2026): Bild,
/// Häuserzahl, Schlagzeile, der Balken aus **drei** Lagern, die Zeit. Die fünf
/// Stufen und die Belege gehören auf die Seite dahinter. Deshalb steht hier
/// überall der kompakte Lagerspiegel; eine zweite Bias-Anzeige wird nicht
/// gebaut.
library;

import 'package:flutter/material.dart';

import '../api/modelle.dart';
import '../design/thema.dart';
import '../design/typografie.dart';
import 'bild.dart';
import 'lagerspiegel.dart';
import 'zeit.dart';

/// Das Abzeichen mit der Häuserzahl — die Zahl, die eine Story trägt.
class Haeuserzahl extends StatelessWidget {
  const Haeuserzahl({required this.kachel, this.voll = false, super.key});

  final Kachel kachel;

  /// Nur der Aufmacher hat Platz für die Zahl der Berichte daneben.
  final bool voll;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: blatt.akzentSanft,
        borderRadius: BorderRadius.circular(Mass.rundung - 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: 12, color: blatt.akzent),
          const SizedBox(width: 4),
          Text(
            voll
                ? '${kachel.anzahlHaeuser} Häuser · ${kachel.anzahlArtikel} Berichte'
                : '${kachel.anzahlHaeuser} Häuser',
            style: Stil.zahl.copyWith(color: blatt.akzent, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// „Kein Bericht aus dem rechten Lager" — der Blindspot in einer Zeile.
///
/// Nur wenn wirklich eines fehlt, und nie wenn **alle** fehlen: dann ist nichts
/// eingeordnet, und das ist kein Blindspot, sondern fehlendes Wissen über die
/// Häuser.
class FehlendeLager extends StatelessWidget {
  const FehlendeLager({required this.verteilung, super.key});

  final Map<String, dynamic> verteilung;

  @override
  Widget build(BuildContext context) {
    final fehlt = fehlendeLager(verteilung);
    if (fehlt.isEmpty) return const SizedBox.shrink();
    final blatt = Blatt.of(context);
    return Text(
      'Kein Bericht von: ${fehlt.map((l) => lagerKurz[l]).join(', ')}',
      style: Stil.meta.copyWith(color: blatt.warnung),
    );
  }
}

/// Die wichtigste Meldung, über die ganze Breite.
///
/// Die einzige Kachel mit Legende unter dem Balken, mit Anriss und mit den
/// fremden Überschriften — alles drei kostet Platz, und Platz hat hier nur der
/// Aufmacher.
class Aufmacher extends StatelessWidget {
  const Aufmacher({
    required this.kachel,
    required this.hausName,
    required this.hausStufe,
    required this.oeffnen,
    required this.artikelOeffnen,
    super.key,
  });

  final Kachel kachel;
  final String Function(String hausId) hausName;

  /// Die Fünf-Stufen-Einordnung eines Hauses, oder `null` — daraus wird das
  /// Lager für den Punkt in der Zeile.
  final String? Function(String hausId) hausStufe;

  final VoidCallback oeffnen;
  final void Function(String artikelId) artikelOeffnen;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    const rang = Kachelrang.aufmacher;

    return InkWell(
      onTap: oeffnen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Bild(
            adresse: kachel.bild,
            format: rang.bildformat,
            beschreibung: kachel.titel,
          ),
          const SizedBox(height: Mass.normal),
          Haeuserzahl(kachel: kachel, voll: true),
          const SizedBox(height: Mass.abzeichen),
          Text(kachel.titel, style: rang.stil.copyWith(color: blatt.tinte)),
          const SizedBox(height: Mass.block),
          Lagerspiegel(verteilung: kachel.lagerVerteilung, hoehe: rang.balken),
          const SizedBox(height: Mass.knapp),
          const Lagerlegende(),
          const SizedBox(height: Mass.knapp),
          FehlendeLager(verteilung: kachel.lagerVerteilung),
          _Dreiklang(
            kachel: kachel,
            hausName: hausName,
            hausStufe: hausStufe,
            oeffnen: artikelOeffnen,
          ),
          if (kachel.anriss != null && kachel.anriss!.isNotEmpty) ...[
            const SizedBox(height: Mass.block),
            _Anriss(kachel: kachel),
          ],
          const SizedBox(height: Mass.normal),
          Zeit(kachel.zuletzt),
        ],
      ),
    );
  }
}

/// **Dieselbe Meldung, eine Überschrift je Lager.** Die Bauart, die eine
/// Verlagsstartseite nicht haben kann — sie hat nur ihre eigene Überschrift.
///
/// Höchstens drei Zeilen, je Lager eine. Zeigt den **Unterschied**, nicht die
/// Belege.
///
/// Ehrlich bleiben: `/api/frontpage` liefert Artikel nur für den Aufmacher und
/// dort nur begrenzt viele. Fehlt hier ein Lager, heißt das **nicht**, dass
/// niemand aus diesem Lager berichtet — das steht im Balken darüber, der über
/// alle Berichte rechnet. Deshalb wird hier kein Lager als fehlend gezeichnet.
class _Dreiklang extends StatelessWidget {
  const _Dreiklang({
    required this.kachel,
    required this.hausName,
    required this.hausStufe,
    required this.oeffnen,
  });

  final Kachel kachel;
  final String Function(String) hausName;
  final String? Function(String) hausStufe;
  final void Function(String) oeffnen;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final gesehen = <String>{};
    final zeilen = <(Kurzartikel, String)>[];
    for (final artikel in kachel.artikel) {
      final lager = Blatt.lagerVon(hausStufe(artikel.hausId));
      if (lager == null || gesehen.contains(lager)) continue;
      gesehen.add(lager);
      zeilen.add((artikel, lager));
    }
    if (zeilen.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Mass.block),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: blatt.linie, height: 1),
          const SizedBox(height: Mass.normal),
          for (final (artikel, lager) in zeilen)
            Padding(
              padding: const EdgeInsets.only(bottom: Mass.eng),
              child: InkWell(
                onTap: () => oeffnen(artikel.id),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Lagerpunkt(lager: lager),
                    ),
                    const SizedBox(width: Mass.knapp),
                    SizedBox(
                      width: 80,
                      child: Text(
                        hausName(artikel.hausId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
                      ),
                    ),
                    const SizedBox(width: Mass.knapp),
                    Expanded(
                      child: Text(
                        artikel.titel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Stil.lagerZeile.copyWith(color: blatt.tinte),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Der Anfang der Zusammenfassung — **mit dem Haus, dem der Text gehört.**
///
/// Die Angabe ist nicht Zierde: der Anriss ist der Vorspann eines Verlags, und
/// ihn ohne Nennung zu zeigen wäre eine Übernahme fremden Textes.
class _Anriss extends StatelessWidget {
  const _Anriss({required this.kachel});

  final Kachel kachel;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kachel.anriss! + (kachel.anrissGekuerzt ? ' …' : ''),
          style: Stil.lesetext.copyWith(fontSize: 16, color: blatt.tinte),
        ),
        if (kachel.anrissQuelle != null) ...[
          const SizedBox(height: Mass.eng),
          Text(
            'Vorspann: ${kachel.anrissQuelle}',
            style: Stil.meta.copyWith(color: blatt.tinteBlass),
          ),
        ],
      ],
    );
  }
}

/// Bild, Häuserzahl, Schlagzeile, Balken, Zeit — dieselbe Kachel in drei
/// Größen.
class Storykachel extends StatelessWidget {
  const Storykachel({
    required this.kachel,
    required this.oeffnen,
    this.rang = Kachelrang.kachel,
    super.key,
  });

  final Kachel kachel;
  final Kachelrang rang;
  final VoidCallback oeffnen;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return InkWell(
      onTap: oeffnen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Bild(
            adresse: kachel.bild,
            format: rang.bildformat,
            beschreibung: kachel.titel,
          ),
          const SizedBox(height: Mass.normal),
          Haeuserzahl(kachel: kachel),
          const SizedBox(height: Mass.eng),
          Text(kachel.titel, style: rang.stil.copyWith(color: blatt.tinte)),
          const SizedBox(height: Mass.normal),
          Lagerspiegel(verteilung: kachel.lagerVerteilung, hoehe: rang.balken),
          const SizedBox(height: Mass.knapp),
          // Nur die Zeit. Der Hausname stand hier bis zum 16.8. daneben — bei
          // 24 berichtenden Häusern sagt „welches zuerst" nichts.
          Zeit(kachel.zuletzt),
        ],
      ),
    );
  }
}
