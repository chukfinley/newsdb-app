/// Ein einzelner Artikel.
///
/// **Was wir nicht ganz haben, geben wir nicht als ganz aus.** Die Ansicht
/// unterscheidet deshalb zwei Dinge, die leicht durcheinandergehen:
///
/// * `schranke` / `abgeschnitten` — was **wir** vom Artikel haben. Steht der
///   Text hinter einer Bezahlschranke des Verlags, ist ein Anriss ein Anriss
///   und wird als solcher benannt.
/// * `textGekuerzt` — was **diese Lesestufe** zeigen darf (A150). Da fehlt
///   nichts, es ist nur noch nicht freigeschaltet.
///
/// Beide Fälle sehen im Text gleich aus und brauchen verschiedene Sätze: einmal
/// „mehr steht beim Verlag", einmal „mehr steht hinter dem Abo".
library;

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/modelle.dart';
import '../design/papier.dart';
import '../design/thema.dart';
import '../design/typografie.dart';
import '../widgets/bild.dart';
import '../widgets/zeit.dart';
import '../widgets/zustaende.dart';

class Artikelansicht extends StatefulWidget {
  const Artikelansicht({
    required this.api,
    required this.artikelId,
    super.key,
  });

  final NewsdbApi api;
  final String artikelId;

  @override
  State<Artikelansicht> createState() => _ArtikelansichtState();
}

class _ArtikelansichtState extends State<Artikelansicht> {
  late Future<Artikel> _laden;

  @override
  void initState() {
    super.initState();
    _laden = widget.api.artikel(widget.artikelId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artikel')),
      body: Papier(
        child: FutureBuilder<Artikel>(
          future: _laden,
          builder: (context, stand) {
            if (stand.connectionState == ConnectionState.waiting) {
              return const Ladeanzeige();
            }
            final fehler = stand.error;
            if (fehler != null) {
              return Fehleranzeige(
                fehler: fehler,
                nochmal: () async => setState(
                  () => _laden = widget.api.artikel(widget.artikelId),
                ),
              );
            }
            return _Inhalt(artikel: stand.data!, api: widget.api);
          },
        ),
      ),
    );
  }
}

class _Inhalt extends StatelessWidget {
  const _Inhalt({required this.artikel, required this.api});

  final Artikel artikel;
  final NewsdbApi api;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final text = artikel.lesbar;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Mass.rand,
        vertical: Mass.kachel,
      ),
      children: [
        Text(
          (artikel.hausName ?? artikel.hausId).toUpperCase(),
          style: Stil.kicker.copyWith(color: blatt.akzent),
        ),
        const SizedBox(height: Mass.knapp),
        Text(
          artikel.titel,
          style: Stil.schlagzeile(28, zeilenhoehe: 1.1)
              .copyWith(color: blatt.tinte),
        ),
        if (artikel.untertitel != null && artikel.untertitel!.isNotEmpty) ...[
          const SizedBox(height: Mass.normal),
          Text(
            artikel.untertitel!,
            style: Stil.lesetext.copyWith(
              fontSize: 17,
              color: blatt.tinteGedaempft,
            ),
          ),
        ],
        const SizedBox(height: Mass.normal),

        // Die Metazeile. `Wrap` und nicht `Row`: mit zwei Autoren und einem
        // Ressort reicht die Breite eines Telefons nicht, und ein abgeschnittener
        // Autorenname ist schlechter als eine zweite Zeile.
        Wrap(
          spacing: Mass.normal,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Zeit(artikel.veroeffentlicht),
            if (artikel.autoren.isNotEmpty)
              Text(
                'von ${artikel.autoren.join(', ')}',
                style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
              ),
            if (artikel.ressort != null)
              Text(
                artikel.ressort!,
                style: Stil.meta.copyWith(color: blatt.tinteBlass),
              ),
            if (artikel.lesesekunden > 0)
              Text(
                '${(artikel.lesesekunden / 60).ceil()} Min. Lesezeit',
                style: Stil.meta.copyWith(color: blatt.tinteBlass),
              ),
          ],
        ),

        // Das Aufmacherbild nur zeigen, wenn die Bausteine die Bilder NICHT
        // ohnehin tragen — sonst stünde dasselbe Bild zweimal da, einmal oben
        // und einmal als erster Bild-Block.
        if (artikel.bild != null &&
            !_zeigbareBloecke(artikel).any((b) => b.art == Blockart.bild)) ...[
          const SizedBox(height: Mass.block),
          Bild(adresse: artikel.bild, format: 3 / 2, beschreibung: artikel.titel),
        ],

        if (artikel.kiZusammenfassung != null &&
            artikel.kiZusammenfassung!.isNotEmpty) ...[
          const SizedBox(height: Mass.kachel),
          Container(
            padding: const EdgeInsets.all(Mass.normal),
            decoration: BoxDecoration(
              color: blatt.papierVertieft,
              border: Border(left: BorderSide(color: blatt.akzent, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ausdrücklich gekennzeichnet. Eine maschinelle Zusammenfassung
                // ohne Kennzeichnung wäre eine Behauptung im Namen der
                // Redaktion, die sie nicht geschrieben hat.
                Text(
                  'MASCHINELL ZUSAMMENGEFASST',
                  style: Stil.kicker.copyWith(color: blatt.tinteGedaempft),
                ),
                const SizedBox(height: Mass.eng),
                Text(
                  artikel.kiZusammenfassung!,
                  style: Stil.lagerZeile.copyWith(color: blatt.tinte),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: Mass.kachel),
        Divider(color: blatt.linie, height: 1),
        const SizedBox(height: Mass.block),

        // Wenn die API Bausteine liefert (`blocks`), werden sie gezeigt —
        // Bilder an ihrer Stelle, Zwischenüberschriften, Listen. Sonst der
        // Fließtext als Absätze, sonst der Hinweis, dass es keinen Text gibt.
        if (_zeigbareBloecke(artikel).isNotEmpty)
          for (final block in _zeigbareBloecke(artikel))
            _BlockWidget(block: block, artikel: artikel)
        else if (text == null || text.isEmpty)
          Text(
            'Von diesem Artikel haben wir keinen Text — nur die Überschrift '
            'und woher sie kommt.',
            style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
          )
        else
          // Absätze von Hand: die API liefert den Text mit Zeilenumbrüchen, und
          // ein einziger `Text` mit 800 Wörtern ist eine Wand.
          for (final absatz in text
              .split(RegExp(r'\n{2,}'))
              .map((a) => a.trim())
              .where((a) => a.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: Mass.block),
              child: Text(
                absatz,
                style: Stil.lesetext.copyWith(color: blatt.tinte),
              ),
            ),

        if (artikel.mehrDahinter) _Hinweis(artikel: artikel),

        const SizedBox(height: Mass.block),
        Text(
          '${artikel.woerter} Wörter · ${artikel.id}',
          style: Stil.technisch.copyWith(color: blatt.tinteBlass),
        ),
        const SizedBox(height: Mass.kachel * 2),
      ],
    );
  }
}

/// Der Satz, der sagt, warum hier nicht mehr steht — und der unterscheidet, ob
/// der Verlag oder die Lesestufe der Grund ist.
class _Hinweis extends StatelessWidget {
  const _Hinweis({required this.artikel});

  final Artikel artikel;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final verlagSchuld = artikel.schranke.gesperrt || artikel.abgeschnitten;
    return Container(
      padding: const EdgeInsets.all(Mass.normal),
      decoration: BoxDecoration(
        color: blatt.akzentSanft,
        borderRadius: BorderRadius.circular(Mass.rundung),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: blatt.akzent),
              const SizedBox(width: Mass.eng),
              Text(
                verlagSchuld ? 'ANRISS, KEIN ARTIKEL' : 'WEITER MIT ABO',
                style: Stil.kicker.copyWith(color: blatt.akzent),
              ),
            ],
          ),
          const SizedBox(height: Mass.eng),
          Text(
            verlagSchuld
                ? 'Dieser Text steht hinter der Bezahlschranke von '
                    '${artikel.hausName ?? artikel.hausId}. Mehr als diesen '
                    'Anfang haben wir nicht — den ganzen Artikel gibt es beim '
                    'Verlag.'
                : 'Den ganzen Text zeigt newsdb mit einem Abo. Der Artikel '
                    'liegt vollständig vor.',
            style: Stil.lagerZeile.copyWith(color: blatt.tinte),
          ),
        ],
      ),
    );
  }
}

/// Die Bausteine, die zu zeigen sind — der redundante Anfang gefiltert.
///
/// Die ersten Blöcke sind oft Wiederholung: ein Breadcrumb als Liste
/// („Startseite / Wirtschaft"), die Überschrift als heading Ebene 1 (die steht
/// schon oben), eine Datumszeile. Die zeigt die Ansicht nicht doppelt.
List<Block> _zeigbareBloecke(Artikel artikel) {
  final roh = artikel.bloecke;
  if (roh.isEmpty) return const [];
  final raus = <Block>[];
  for (final b in roh) {
    // Breadcrumb-Liste am Anfang: eine Liste, bevor irgendein Absatz kam.
    if (b.art == Blockart.liste && raus.isEmpty) continue;
    // Die Titel-Überschrift (Ebene 1): steht schon als Schlagzeile oben.
    if (b.art == Blockart.ueberschrift && (b.stufe ?? 1) <= 1) continue;
    // Leere Blöcke (Bild ohne auflösbare Kennung, leerer Absatz).
    if (b.art == Blockart.bild) {
      if (b.bildId == null || artikel.bilder[b.bildId] == null) continue;
    } else if (b.text.trim().isEmpty && b.punkte.isEmpty) {
      continue;
    }
    raus.add(b);
  }
  return raus;
}

/// Ein einzelner Baustein.
class _BlockWidget extends StatelessWidget {
  const _BlockWidget({required this.block, required this.artikel});

  final Block block;
  final Artikel artikel;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    switch (block.art) {
      case Blockart.ueberschrift:
        return Padding(
          padding: const EdgeInsets.only(top: Mass.knapp, bottom: Mass.normal),
          child: Text(
            block.text,
            style: Stil.schlagzeile(block.stufe == 2 ? 22 : 19, zeilenhoehe: 1.2)
                .copyWith(color: blatt.tinte),
          ),
        );
      case Blockart.bild:
        final adresse = artikel.bilder[block.bildId];
        return Padding(
          padding: const EdgeInsets.only(bottom: Mass.block),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Bild(adresse: adresse, format: 3 / 2, beschreibung: block.text),
              // Bildunterschrift, wenn der Block einen Text trägt.
              if (block.text.trim().isNotEmpty) ...[
                const SizedBox(height: Mass.eng),
                Text(
                  block.text,
                  style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
                ),
              ],
            ],
          ),
        );
      case Blockart.zitat:
        return Container(
          margin: const EdgeInsets.only(bottom: Mass.block),
          padding: const EdgeInsets.only(left: Mass.normal),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: blatt.akzent, width: 3)),
          ),
          child: Text(
            block.text,
            style: Stil.lesetext.copyWith(
              color: blatt.tinte,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case Blockart.liste:
        return Padding(
          padding: const EdgeInsets.only(bottom: Mass.block),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final punkt in block.punkte)
                Padding(
                  padding: const EdgeInsets.only(bottom: Mass.eng),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ',
                          style: Stil.lesetext.copyWith(color: blatt.akzent)),
                      Expanded(
                        child: Text(
                          punkt,
                          style: Stil.lesetext.copyWith(color: blatt.tinte),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case Blockart.code:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: Mass.block),
          padding: const EdgeInsets.all(Mass.normal),
          decoration: BoxDecoration(
            color: blatt.papierVertieft,
            borderRadius: BorderRadius.circular(Mass.rundung),
          ),
          child: Text(
            block.text,
            style: Stil.technisch.copyWith(color: blatt.tinte),
          ),
        );
      case Blockart.absatz:
      case Blockart.einbettung:
      case Blockart.unbekannt:
        // Einbettungen (Tweets, Videos) zeigt die App noch nicht als solche;
        // trägt der Block einen Text, kommt er als Absatz, sonst gar nicht.
        if (block.text.trim().isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: Mass.block),
          child: Text(
            block.text,
            style: Stil.lesetext.copyWith(color: blatt.tinte),
          ),
        );
    }
  }
}
