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
        Lagerkuerzel(verteilung: story.lagerVerteilung),

        // Wer besitzt die berichtenden Häuser? Die Zahl, die eine einzelne
        // Zeitung nie zeigt — und die eine laute Meldung entlarvt, hinter der
        // nur wenige Konzerne stehen.
        _Eigentuemer(story: story),

        // Seit wann läuft die Story, wie lange schon? Ein Ereignis, über das
        // seit drei Tagen berichtet wird, ist eine andere Lage als eins von
        // heute Morgen.
        _Zeitspanne(story: story),

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

/// Die Eigentümerkonzentration — wer hinter den Häusern steht.
///
/// Ein Nachbau der Idee aus dem Web (`story-insights.tsx`): 38 Häuser klingen
/// nach Vielfalt, aber wenn dahinter nur drei Konzerne stehen, ist es eine
/// Meldung, die nur laut ist. Die App rechnet nichts — die Zahlen kommen aus
/// `ownership_spread` der API.
class _Eigentuemer extends StatelessWidget {
  const _Eigentuemer({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final eig = story.eigentuemer;
    final haeuser = story.haeuserGesamt;
    if (eig == null || haeuser == null || haeuser == 0) {
      return const SizedBox.shrink();
    }
    final blatt = Blatt.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Mass.block),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            story.konzentriert ? Icons.account_balance : Icons.groups_outlined,
            size: 16,
            color: story.konzentriert ? blatt.warnung : blatt.tinteGedaempft,
          ),
          const SizedBox(width: Mass.knapp),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
                children: [
                  TextSpan(text: '$haeuser Häuser aus '),
                  TextSpan(
                    text: '$eig ${eig == 1 ? "Eigentümer" : "Eigentümern"}',
                    style: Stil.zahl.copyWith(
                      color: blatt.tinte,
                      fontSize: 12,
                    ),
                  ),
                  if (story.konzentriert && story.groessteGruppe != null)
                    TextSpan(
                      text: ' — vor allem ${story.groessteGruppe}'
                          '${story.groessterAnteil != null ? " (${story.groessterAnteil!.round()} %)" : ""}',
                      style: TextStyle(color: blatt.warnung),
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

/// Die Zeitspanne der Berichterstattung.
///
/// „Seit gestern, zuletzt vor zwei Stunden" sagt mehr als ein einzelner
/// Zeitpunkt: es unterscheidet ein laufendes Ereignis von einer Momentmeldung.
class _Zeitspanne extends StatelessWidget {
  const _Zeitspanne({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final von = story.zuerst;
    final bis = story.zuletzt;
    if (von == null && bis == null) return const SizedBox.shrink();
    final blatt = Blatt.of(context);
    final teile = <String>[];
    if (von != null) teile.add('seit ${zeitText(von)}');
    if (bis != null) teile.add('zuletzt ${zeitText(bis)}');
    return Padding(
      padding: const EdgeInsets.only(top: Mass.eng),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: blatt.tinteGedaempft),
          const SizedBox(width: Mass.knapp),
          Expanded(
            child: Text(
              teile.join(' · '),
              style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
            ),
          ),
        ],
      ),
    );
  }
}
