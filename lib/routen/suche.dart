/// Die Volltextsuche.
///
/// Absichtlich schlicht: ein Feld, eine Liste. Die API trägt die Last
/// (`/api/articles?q=…`, FTS über den Bestand). Die App zeigt die Trefferzahl
/// ehrlich mit — „3 von 29.074", nicht so, als wären es nur drei.
///
/// **Erst suchen, wenn der Leser fertig getippt hat.** Jeder Tastendruck einen
/// Abruf zu starten wäre bei einer serverseitigen Volltextsuche eine
/// Abruf-Lawine und ein Flackern aus halben Ergebnissen. Deshalb eine kurze
/// Wartezeit (Entprellung) nach dem letzten Tastendruck.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/modelle.dart';
import '../design/papier.dart';
import '../design/thema.dart';
import '../design/typografie.dart';
import '../widgets/bild.dart';
import '../widgets/zeit.dart';
import '../widgets/zustaende.dart';

class Suchseite extends StatefulWidget {
  const Suchseite({
    required this.api,
    required this.artikelOeffnen,
    super.key,
  });

  final NewsdbApi api;
  final void Function(String artikelId) artikelOeffnen;

  @override
  State<Suchseite> createState() => _SuchseiteState();
}

class _SuchseiteState extends State<Suchseite> {
  final _feld = TextEditingController();
  final _fokus = FocusNode();
  Timer? _entprellung;

  Map<String, Haus> _haeuser = const {};
  String _frage = '';
  bool _laedt = false;
  int _gesamt = 0;
  List<Suchtreffer> _treffer = const [];
  Object? _fehler;

  @override
  void initState() {
    super.initState();
    // Das Suchfeld bekommt den Fokus beim Öffnen: wer auf Suche tippt, will
    // tippen, nicht erst noch das Feld antippen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fokus.requestFocus());
    // Die Häusernamen einmal holen — für „SPIEGEL" statt „spiegel" in der
    // Zeile. Scheitert das, bleiben die Kennungen; die Suche funktioniert
    // trotzdem.
    widget.api.haeuser().then((h) {
      if (mounted) setState(() => _haeuser = h);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _entprellung?.cancel();
    _feld.dispose();
    _fokus.dispose();
    super.dispose();
  }

  void _getippt(String text) {
    _entprellung?.cancel();
    final frage = text.trim();
    if (frage.length < 2) {
      setState(() {
        _frage = frage;
        _treffer = const [];
        _gesamt = 0;
        _fehler = null;
      });
      return;
    }
    // 350 ms nach dem letzten Tastendruck. Kurz genug, dass es sich sofort
    // anfühlt, lang genug, dass „Bundestag" nicht neun Abrufe auslöst.
    _entprellung = Timer(const Duration(milliseconds: 350), () => _suchen(frage));
  }

  Future<void> _suchen(String frage) async {
    setState(() {
      _laedt = true;
      _frage = frage;
      _fehler = null;
    });
    try {
      final ergebnis = await widget.api.suche(frage);
      // Zwischenzeitlich weitergetippt? Dann ist dieses Ergebnis veraltet.
      if (!mounted || frage != _feld.text.trim()) return;
      setState(() {
        _treffer = ergebnis.treffer;
        _gesamt = ergebnis.gesamt;
        _laedt = false;
      });
    } on Object catch (fehler) {
      if (!mounted) return;
      setState(() {
        _fehler = fehler;
        _laedt = false;
      });
    }
  }

  String _hausName(String id) => _haeuser[id]?.name ?? id;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _feld,
          focusNode: _fokus,
          onChanged: _getippt,
          textInputAction: TextInputAction.search,
          onSubmitted: (t) => _suchen(t.trim()),
          style: Stil.lesetext.copyWith(fontSize: 17, color: blatt.tinte),
          decoration: InputDecoration(
            hintText: 'Im Bestand suchen …',
            hintStyle: Stil.lesetext
                .copyWith(fontSize: 17, color: blatt.tinteBlass),
            border: InputBorder.none,
            suffixIcon: _feld.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, color: blatt.tinteGedaempft),
                    onPressed: () {
                      _feld.clear();
                      _getippt('');
                      _fokus.requestFocus();
                    },
                  ),
          ),
        ),
      ),
      body: Papier(child: _koerper(blatt)),
    );
  }

  Widget _koerper(Blatt blatt) {
    if (_fehler != null) {
      return Fehleranzeige(
        fehler: _fehler!,
        nochmal: () async => _suchen(_frage),
      );
    }
    if (_frage.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Mass.kachel),
          child: Text(
            'Tippe einen Begriff — die Suche geht über alle Häuser und den '
            'ganzen Bestand.',
            textAlign: TextAlign.center,
            style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
          ),
        ),
      );
    }
    if (_laedt && _treffer.isEmpty) {
      return const Ladeanzeige();
    }
    if (_treffer.isEmpty) {
      return Leeranzeige(
        titel: 'Nichts gefunden',
        hinweis: 'Zu „$_frage" steht nichts im Bestand.',
      );
    }
    return Column(
      children: [
        // Die ehrliche Trefferzahl. „30 von 29.074" statt so zu tun, als wäre
        // die Liste vollständig.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
              Mass.rand, Mass.normal, Mass.rand, Mass.knapp),
          child: Text(
            _gesamt > _treffer.length
                ? '${_treffer.length} von $_gesamt Treffern'
                : '$_gesamt Treffer',
            style: Stil.kicker.copyWith(color: blatt.tinteGedaempft),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: Mass.kachel),
            itemCount: _treffer.length,
            separatorBuilder: (_, _) =>
                Divider(color: blatt.linie, height: 1, indent: Mass.rand),
            itemBuilder: (context, i) => _Trefferzeile(
              treffer: _treffer[i],
              haus: _hausName(_treffer[i].hausId),
              oeffnen: () => widget.artikelOeffnen(_treffer[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

/// Eine Trefferzeile: Bild links, Haus/Titel/Zeit rechts. Kompakt, weil eine
/// Suchliste zum Überfliegen da ist, nicht zum Lesen.
class _Trefferzeile extends StatelessWidget {
  const _Trefferzeile({
    required this.treffer,
    required this.haus,
    required this.oeffnen,
  });

  final Suchtreffer treffer;
  final String haus;
  final VoidCallback oeffnen;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return InkWell(
      onTap: oeffnen,
      child: Padding(
        padding: const EdgeInsets.all(Mass.rand),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Bild(adresse: treffer.bild, format: 4 / 3),
            ),
            const SizedBox(width: Mass.normal),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        haus.toUpperCase(),
                        style: Stil.kicker.copyWith(color: blatt.akzent),
                      ),
                      if (treffer.schranke.gesperrt) ...[
                        const SizedBox(width: Mass.eng),
                        Icon(Icons.lock_outline,
                            size: 11, color: blatt.tinteBlass),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    treffer.titel,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Stil.schlagzeile(16, zeilenhoehe: 1.2)
                        .copyWith(color: blatt.tinte),
                  ),
                  const SizedBox(height: Mass.eng),
                  Row(
                    children: [
                      Zeit(treffer.veroeffentlicht),
                      if (treffer.ressort != null) ...[
                        const SizedBox(width: Mass.knapp),
                        Text('·',
                            style:
                                Stil.meta.copyWith(color: blatt.tinteBlass)),
                        const SizedBox(width: Mass.knapp),
                        Flexible(
                          child: Text(
                            treffer.ressort!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Stil.meta
                                .copyWith(color: blatt.tinteGedaempft),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
