/// Eine Story — dieselbe Meldung, wie sie verschiedene Häuser erzählen.
///
/// Das ist der Grund, warum diese App existiert, und deshalb steht hier der
/// **ausführliche** Lagerspiegel mit allen fünf Stufen: auf der Kachel war er
/// ein Signal neben der Schlagzeile, hier hat der Leser Zeit.
///
/// Die Berichte sind nach Lager gruppiert und nicht nach Zeit. Nach Zeit
/// sortiert wäre es eine Liste von Meldungen; nach Lager gruppiert ist es ein
/// Vergleich — und der Blick fällt auf die Gruppe, die fehlt.
library;

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/modelle.dart';
import '../design/papier.dart';
import '../design/thema.dart';
import '../design/typografie.dart';
import '../widgets/lagerspiegel.dart';
import '../widgets/zeit.dart';
import '../widgets/zustaende.dart';

class Storyansicht extends StatefulWidget {
  const Storyansicht({
    required this.api,
    required this.storyId,
    required this.artikelOeffnen,
    super.key,
  });

  final NewsdbApi api;
  final String storyId;
  final void Function(String artikelId) artikelOeffnen;

  @override
  State<Storyansicht> createState() => _StoryansichtState();
}

class _StoryansichtState extends State<Storyansicht> {
  late Future<(Story, Map<String, Haus>)> _laden;

  @override
  void initState() {
    super.initState();
    _laden = _holen();
  }

  Future<(Story, Map<String, Haus>)> _holen() async {
    final story = await widget.api.story(widget.storyId);
    Map<String, Haus> haeuser = const {};
    try {
      haeuser = await widget.api.haeuser();
    } on ApiFehler catch (fehler) {
      debugPrint('Häuserliste nicht geladen: $fehler');
    }
    return (story, haeuser);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thema')),
      body: Papier(
        child: FutureBuilder<(Story, Map<String, Haus>)>(
          future: _laden,
          builder: (context, stand) {
            if (stand.connectionState == ConnectionState.waiting) {
              return const Ladeanzeige();
            }
            final fehler = stand.error;
            if (fehler != null) {
              return Fehleranzeige(
                fehler: fehler,
                nochmal: () async => setState(() => _laden = _holen()),
              );
            }
            final (story, haeuser) = stand.data!;
            return _Inhalt(
              story: story,
              haeuser: haeuser,
              artikelOeffnen: widget.artikelOeffnen,
            );
          },
        ),
      ),
    );
  }
}

class _Inhalt extends StatelessWidget {
  const _Inhalt({
    required this.story,
    required this.haeuser,
    required this.artikelOeffnen,
  });

  final Story story;
  final Map<String, Haus> haeuser;
  final void Function(String) artikelOeffnen;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);

    // Nach Lager gruppieren. Was nicht eingeordnet ist, kommt unter `null` und
    // wird **gezeigt** statt weggelassen: ein Bericht, den wir haben, darf
    // nicht verschwinden, nur weil das Haus keine Einordnung hat.
    final gruppen = <String?, List<Artikel>>{};
    for (final artikel in story.artikel) {
      final lager = Blatt.lagerVon(haeuser[artikel.hausId]?.stufe);
      gruppen.putIfAbsent(lager, () => []).add(artikel);
    }

    final text = story.zusammenfassung ?? story.anriss;
    final fehlt = fehlendeLager(story.lagerVerteilung);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Mass.rand,
        vertical: Mass.kachel,
      ),
      children: [
        Text(
          story.titel,
          style: Stil.schlagzeile(28, zeilenhoehe: 1.1)
              .copyWith(color: blatt.tinte),
        ),
        const SizedBox(height: Mass.normal),
        Row(
          children: [
            Text(
              '${story.haeuser.length} Häuser · ${story.anzahlArtikel} Berichte',
              style: Stil.zahl.copyWith(color: blatt.tinteGedaempft),
            ),
            const SizedBox(width: Mass.normal),
            Zeit(story.zuletzt),
          ],
        ),
        const SizedBox(height: Mass.kachel),

        // Der Lagerspiegel, ausführlich: fünf Stufen mit Zahlen.
        Lagerspiegel(
          verteilung: story.lagerVerteilung,
          hoehe: 26,
          modus: Spiegelmodus.ausfuehrlich,
          zahlen: true,
        ),
        const SizedBox(height: Mass.knapp),
        const Lagerlegende(),

        if (fehlt.isNotEmpty) ...[
          const SizedBox(height: Mass.block),
          Container(
            padding: const EdgeInsets.all(Mass.normal),
            decoration: BoxDecoration(
              color: blatt.papierVertieft,
              border: Border(left: BorderSide(color: blatt.warnung, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BLINDSPOT',
                  style: Stil.kicker.copyWith(color: blatt.warnung),
                ),
                const SizedBox(height: Mass.eng),
                Text(
                  fehlt.length == 1
                      ? 'Aus dem ${lagerLang[fehlt.first]} berichtet '
                          'niemand über diese Meldung.'
                      : 'Es berichtet niemand aus: '
                          '${fehlt.map((l) => lagerLang[l]).join(' und ')}.',
                  style: Stil.lagerZeile.copyWith(color: blatt.tinte),
                ),
              ],
            ),
          ),
        ],

        if (text != null && text.isNotEmpty) ...[
          const SizedBox(height: Mass.kachel),
          Divider(color: blatt.linie, height: 1),
          const SizedBox(height: Mass.block),
          Text(
            text + (story.zusammenfassung == null && story.anrissGekuerzt
                ? ' …'
                : ''),
            style: Stil.lesetext.copyWith(color: blatt.tinte),
          ),
          if (story.zusammenfassung == null && story.anrissQuelle != null) ...[
            const SizedBox(height: Mass.knapp),
            Text(
              'Vorspann: ${story.anrissQuelle}',
              style: Stil.meta.copyWith(color: blatt.tinteBlass),
            ),
          ],
          if (story.zusammenfassung == null && story.anrissGekuerzt) ...[
            const SizedBox(height: Mass.normal),
            Text(
              'Die ganze Zusammenfassung gibt es mit einem Abo.',
              style: Stil.meta.copyWith(color: blatt.akzent),
            ),
          ],
        ],

        const SizedBox(height: Mass.kachel),
        Divider(color: blatt.tinte, thickness: 2, height: 2),
        const SizedBox(height: Mass.block),
        Text(
          'DIE BERICHTE',
          style: Stil.kicker.copyWith(color: blatt.tinteGedaempft),
        ),
        const SizedBox(height: Mass.block),

        if (story.artikel.isEmpty)
          Text(
            'Die Berichte kommen erst mit einer Anmeldung.',
            style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
          ),

        // Feste Reihenfolge links, Mitte, rechts, dann das Unbekannte — dieselbe
        // Richtung wie im Balken darüber, damit niemand umdenken muss.
        for (final lager in [...lagerFolge, null])
          if (gruppen[lager]?.isNotEmpty ?? false) ...[
            Row(
              children: [
                Lagerpunkt(lager: lager),
                const SizedBox(width: Mass.knapp),
                Text(
                  lager == null
                      ? 'ohne Einordnung'
                      : lagerLang[lager]!.toUpperCase(),
                  style: Stil.kicker.copyWith(color: blatt.tinteGedaempft),
                ),
              ],
            ),
            const SizedBox(height: Mass.normal),
            for (final artikel in gruppen[lager]!)
              _Bericht(
                artikel: artikel,
                haus: haeuser[artikel.hausId]?.name ??
                    artikel.hausName ??
                    artikel.hausId,
                oeffnen: () => artikelOeffnen(artikel.id),
              ),
            const SizedBox(height: Mass.block),
          ],
        const SizedBox(height: Mass.kachel),
      ],
    );
  }
}

/// Eine Überschrift mit ihrem Haus. Die Überschrift **ist** hier der Inhalt:
/// der Vergleich der Formulierungen ist die Sache, um die es geht.
class _Bericht extends StatelessWidget {
  const _Bericht({
    required this.artikel,
    required this.haus,
    required this.oeffnen,
  });

  final Artikel artikel;
  final String haus;
  final VoidCallback oeffnen;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return InkWell(
      onTap: oeffnen,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Mass.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(haus, style: Stil.meta.copyWith(color: blatt.akzent)),
                if (artikel.schranke.gesperrt) ...[
                  const SizedBox(width: Mass.eng),
                  Icon(Icons.lock_outline, size: 11, color: blatt.tinteBlass),
                ],
                const Spacer(),
                Zeit(artikel.veroeffentlicht),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              artikel.titel,
              style: Stil.schlagzeile(17, zeilenhoehe: 1.25)
                  .copyWith(color: blatt.tinte),
            ),
          ],
        ),
      ),
    );
  }
}
