/// Die Titelseite.
///
/// Die Rangfolge ist die des Webs (`routes/reader/home.tsx`): Platz 1 wird
/// Aufmacher, die naechsten zwei Doppelkacheln, dann vier Kacheln, danach
/// Zeilen. Im Browser stehen Doppel und Kacheln ab 640 px zu zweit
/// nebeneinander — **unter** 640 px, also auf jedem Telefon, ist das Web
/// ebenfalls einspaltig. Die App macht es deshalb nicht anders, sie kopiert es.
///
/// Was hier noch fehlt und in `home.tsx` steht: das Lagerspiegel-Band aus der
/// schiefsten der naechsten vier Meldungen, und die Themenblöcke am Fuss.
library;

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/modelle.dart';
import '../auth/konto.dart';
import '../design/papier.dart';
import '../design/thema.dart';
import '../design/typografie.dart';
import '../widgets/kachel.dart';
import '../widgets/zustaende.dart';

class Titelseiteansicht extends StatefulWidget {
  const Titelseiteansicht({
    required this.api,
    required this.anmeldung,
    required this.storyOeffnen,
    required this.artikelOeffnen,
    super.key,
  });

  final NewsdbApi api;
  final Anmeldung anmeldung;
  final void Function(String storyId) storyOeffnen;
  final void Function(String artikelId) artikelOeffnen;

  @override
  State<Titelseiteansicht> createState() => _TitelseiteansichtState();
}

class _TitelseiteansichtState extends State<Titelseiteansicht> {
  /// Beide Abrufe zusammen in **einem** Future: die Häuserliste wird für die
  /// Namen im Dreiklang gebraucht, und eine Titelseite, die erst erscheint und
  /// dann die Häusernamen nachträgt, springt beim Lesen.
  late Future<(Titelseite, Map<String, Haus>)> _laden;

  @override
  void initState() {
    super.initState();
    _laden = _holen();
  }

  Future<(Titelseite, Map<String, Haus>)> _holen() async {
    final seite = await widget.api.titelseite();
    // Die Häuserliste darf scheitern, ohne die Titelseite mitzunehmen: ohne sie
    // fehlen Namen im Dreiklang, mit einem Fehler fehlt die ganze Seite.
    Map<String, Haus> haeuser = const {};
    try {
      haeuser = await widget.api.haeuser();
    } on ApiFehler catch (fehler) {
      debugPrint('Häuserliste nicht geladen: $fehler');
    }
    return (seite, haeuser);
  }

  Future<void> _neuLaden() async {
    final neu = _holen();
    setState(() => _laden = neu);
    await neu.catchError((Object _) => (
          const Titelseite(kacheln: [], erzeugtAm: null),
          const <String, Haus>{},
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Papier(
      child: RefreshIndicator(
        onRefresh: _neuLaden,
        child: FutureBuilder<(Titelseite, Map<String, Haus>)>(
          future: _laden,
          builder: (context, stand) {
            if (stand.connectionState == ConnectionState.waiting) {
              return const Ladeanzeige(text: 'Die Titelseite wird gesetzt …');
            }
            final fehler = stand.error;
            if (fehler != null) {
              return Fehleranzeige(
                fehler: fehler,
                nochmal: _neuLaden,
              );
            }
            final (seite, haeuser) = stand.data!;
            if (seite.kacheln.isEmpty) {
              return const Leeranzeige(
                titel: 'Keine Meldungen',
                hinweis: 'Die Titelseite ist gerade leer. '
                    'Nach unten ziehen holt sie neu.',
              );
            }
            return _Seite(
              seite: seite,
              haeuser: haeuser,
              storyOeffnen: widget.storyOeffnen,
              artikelOeffnen: widget.artikelOeffnen,
            );
          },
        ),
      ),
    );
  }
}

class _Seite extends StatelessWidget {
  const _Seite({
    required this.seite,
    required this.haeuser,
    required this.storyOeffnen,
    required this.artikelOeffnen,
  });

  final Titelseite seite;
  final Map<String, Haus> haeuser;
  final void Function(String) storyOeffnen;
  final void Function(String) artikelOeffnen;

  /// Der Name eines Hauses. Fehlt die Liste, wird die Kennung gezeigt — das ist
  /// häßlich, aber ehrlich, und besser als eine leere Zeile.
  String _name(String id) => haeuser[id]?.name ?? id;

  /// Die Fünf-Stufen-Einordnung eines Hauses, oder `null`. `null` heißt „nicht
  /// eingeordnet" und **nicht** „Mitte".
  String? _stufe(String id) => haeuser[id]?.stufe;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final kacheln = seite.kacheln;
    final aufmacher = kacheln.first;
    final rest = kacheln.skip(1).toList();
    final doppel = rest.take(2).toList();
    final mittel = rest.skip(2).take(4).toList();
    final zeilen = rest.skip(6).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Mass.rand,
        vertical: Mass.kachel,
      ),
      children: [
        Aufmacher(
          kachel: aufmacher,
          hausName: _name,
          hausStufe: _stufe,
          oeffnen: () => storyOeffnen(aufmacher.id),
          artikelOeffnen: artikelOeffnen,
        ),
        for (final kachel in doppel) ...[
          const _Trenner(),
          Storykachel(
            kachel: kachel,
            rang: Kachelrang.doppel,
            oeffnen: () => storyOeffnen(kachel.id),
          ),
        ],
        for (final kachel in mittel) ...[
          const _Trenner(),
          Storykachel(
            kachel: kachel,
            oeffnen: () => storyOeffnen(kachel.id),
          ),
        ],
        if (zeilen.isNotEmpty) ...[
          const SizedBox(height: Mass.kachel),
          Divider(color: blatt.tinte, thickness: 2, height: 2),
          const SizedBox(height: Mass.block),
          Text(
            'WEITER IM BLATT',
            style: Stil.kicker.copyWith(color: blatt.tinteGedaempft),
          ),
          const SizedBox(height: Mass.block),
          for (final kachel in zeilen) ...[
            Storykachel(
              kachel: kachel,
              rang: Kachelrang.zeile,
              oeffnen: () => storyOeffnen(kachel.id),
            ),
            const SizedBox(height: Mass.kachel),
          ],
        ],
        if (seite.erzeugtAm != null)
          Padding(
            padding: const EdgeInsets.only(top: Mass.block, bottom: Mass.kachel),
            child: Text(
              'Diese Seite wurde ${_uhrzeit(seite.erzeugtAm!)} gesetzt.',
              style: Stil.meta.copyWith(color: blatt.tinteBlass),
            ),
          ),
      ],
    );
  }

  String _uhrzeit(DateTime wann) =>
      '${wann.hour.toString().padLeft(2, '0')}:'
      '${wann.minute.toString().padLeft(2, '0')} Uhr';
}

/// Die Haarlinie zwischen zwei Kacheln — im Blatt trennt eine Linie, kein
/// Schatten und kein Abstand allein.
class _Trenner extends StatelessWidget {
  const _Trenner();

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Mass.kachel),
      child: Divider(color: blatt.linie, height: 1),
    );
  }
}
