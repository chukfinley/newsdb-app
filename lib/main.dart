/// newsdb — die App.
///
/// Was hier gerade steht, ist die **Musterseite**: alle uebernommenen
/// Design-Bausteine auf einem Bildschirm, zum Nebeneinanderhalten mit
/// https://news.65.109.85.231.sslip.io. Sie ist mit Absicht der erste
/// lauffaehige Zustand — das Design ist die Abnahme von A160, und eine Abnahme
/// braucht etwas, das man ansehen kann.
///
/// Die Titelseite mit echten Daten kommt als naechstes und ersetzt sie.
library;

import 'package:flutter/material.dart';

import 'design/papier.dart';
import 'design/thema.dart';
import 'design/typografie.dart';
import 'widgets/lagerspiegel.dart';

void main() => runApp(const NewsdbApp());

class NewsdbApp extends StatefulWidget {
  const NewsdbApp({super.key});

  @override
  State<NewsdbApp> createState() => _NewsdbAppState();
}

class _NewsdbAppState extends State<NewsdbApp> {
  /// Vorgabe ist die Einstellung des Geraets — dieselbe Haltung wie im Web,
  /// wo `useTheme` mit `prefers-color-scheme` anfaengt.
  ThemeMode _modus = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'newsdb',
      debugShowCheckedModeBanner: false,
      theme: tagesausgabe,
      darkTheme: nachtausgabe,
      themeMode: _modus,
      home: Musterseite(
        umschalten: () => setState(() {
          final dunkel =
              MediaQuery.platformBrightnessOf(context) == Brightness.dark;
          _modus = switch (_modus) {
            ThemeMode.system => dunkel ? ThemeMode.light : ThemeMode.dark,
            ThemeMode.light => ThemeMode.dark,
            ThemeMode.dark => ThemeMode.light,
          };
        }),
      ),
    );
  }
}

/// Beispielverteilungen. Bewusst keine erfundenen Schlagzeilen mit echten
/// Namen: die Musterseite prueft Groessen und Farben, nicht Inhalte.
const _breit = {
  'left': 4,
  'center-left': 3,
  'center': 6,
  'center-right': 2,
  'right': 1,
};
const _schief = {'left': 7, 'center-left': 4, 'center': 2};

class Musterseite extends StatelessWidget {
  const Musterseite({required this.umschalten, super.key});

  final VoidCallback umschalten;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Scaffold(
      body: Papier(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: Mass.rand,
              vertical: Mass.kachel,
            ),
            children: [
              _Kopf(umschalten: umschalten),
              const SizedBox(height: Mass.kachel),

              const _Abschnitt('Die vier Kachelraenge'),
              for (final rang in Kachelrang.values) ...[
                _Kachelprobe(rang: rang),
                const SizedBox(height: Mass.kachel),
              ],

              const _Abschnitt('Der Lagerspiegel, ausfuehrlich'),
              const Lagerspiegel(
                verteilung: _breit,
                hoehe: 26,
                modus: Spiegelmodus.ausfuehrlich,
                zahlen: true,
              ),
              const SizedBox(height: Mass.knapp),
              const Lagerlegende(),
              const SizedBox(height: Mass.block),
              Text(
                'Kein Bericht von: rechts',
                style: Stil.meta.copyWith(color: blatt.warnung),
              ),
              const SizedBox(height: Mass.knapp),
              const Lagerspiegel(
                verteilung: _schief,
                hoehe: 26,
                modus: Spiegelmodus.ausfuehrlich,
                zahlen: true,
              ),
              const SizedBox(height: Mass.kachel),

              const _Abschnitt('Lesetext'),
              Text(
                'Newsreader fuer die Schlagzeile, Source Serif 4 fuer den '
                'Lesetext, Archivo fuer die Metazeile, JetBrains Mono fuer '
                'Zahlen und Kennungen. Die Ziffern im Fliesstext sind '
                'Mediaevalziffern: 1975, 2026, 138 Haeuser — sie stehen in der '
                'Zeile und stechen nicht heraus.',
                style: Stil.lesetext.copyWith(color: blatt.tinte),
              ),
              const SizedBox(height: Mass.block),
              Text(
                'article/9f3c1a  ·  47 Woerter  ·  0.89',
                style: Stil.technisch.copyWith(color: blatt.tinteGedaempft),
              ),
              const SizedBox(height: Mass.kachel),

              const _Abschnitt('Die Tokens'),
              const _Farbleiste(),
              const SizedBox(height: Mass.kachel * 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kopf extends StatelessWidget {
  const _Kopf({required this.umschalten});

  final VoidCallback umschalten;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final dunkel = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('newsdb', style: Stil.schlagzeile(30)),
            IconButton(
              onPressed: umschalten,
              icon: Icon(dunkel ? Icons.light_mode : Icons.dark_mode),
              color: blatt.tinteGedaempft,
              tooltip: dunkel ? 'Tagesausgabe' : 'Nachtausgabe',
            ),
          ],
        ),
        Text(
          'MUSTERSEITE · DESIGN AUS DER WEB-OBERFLAECHE',
          style: Stil.kicker.copyWith(color: blatt.akzent),
        ),
        const SizedBox(height: Mass.normal),
        Divider(color: blatt.linieStark, height: 1),
      ],
    );
  }
}

class _Abschnitt extends StatelessWidget {
  const _Abschnitt(this.titel);

  final String titel;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Mass.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: blatt.linie, height: 1),
          const SizedBox(height: Mass.knapp),
          Text(titel.toUpperCase(),
              style: Stil.kicker.copyWith(color: blatt.tinteGedaempft)),
          const SizedBox(height: Mass.knapp),
        ],
      ),
    );
  }
}

/// Eine Kachel in einem der vier Raenge — Bildplatzhalter, Abzeichen,
/// Schlagzeile, Lagerbalken, Zeit. Genau die Bausteine, die `StoryKachel` im
/// Web zeigt, und ausdruecklich nicht mehr: die fuenf Stufen und die Belege
/// gehoeren auf die Seite dahinter.
class _Kachelprobe extends StatelessWidget {
  const _Kachelprobe({required this.rang});

  final Kachelrang rang;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: rang.bildformat,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: blatt.papierVertieft,
              border: Border.all(color: blatt.linie),
              borderRadius: BorderRadius.circular(Mass.rundung),
            ),
            child: Center(
              child: Text(
                '${rang.name} · ${rang.bildformat.toStringAsFixed(2)}',
                style: Stil.meta.copyWith(color: blatt.tinteBlass),
              ),
            ),
          ),
        ),
        const SizedBox(height: Mass.normal),
        const _Abzeichen(text: '12 Haeuser'),
        const SizedBox(height: Mass.eng),
        Text(
          'Der Bundestag streitet ueber den Haushalt, und jedes Haus '
          'formuliert es anders',
          style: rang.stil.copyWith(color: blatt.tinte),
        ),
        const SizedBox(height: Mass.normal),
        Lagerspiegel(verteilung: _breit, hoehe: rang.balken),
        if (rang == Kachelrang.aufmacher) ...[
          const SizedBox(height: Mass.knapp),
          const Lagerlegende(),
        ],
        const SizedBox(height: Mass.knapp),
        Text('vor 20 Minuten',
            style: Stil.meta.copyWith(color: blatt.tinteGedaempft)),
      ],
    );
  }
}

/// Das Abzeichen mit der Haeuserzahl — im Web `Badge variant="accent"`.
class _Abzeichen extends StatelessWidget {
  const _Abzeichen({required this.text});

  final String text;

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
          Text(text,
              style: Stil.zahl.copyWith(color: blatt.akzent, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Alle Flaechen- und Lagerfarben als Streifen — die schnellste Gegenprobe
/// gegen den Browser.
class _Farbleiste extends StatelessWidget {
  const _Farbleiste();

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final proben = <(String, Color)>[
      ('papier', blatt.papier),
      ('gehoben', blatt.papierGehoben),
      ('vertieft', blatt.papierVertieft),
      ('tinte', blatt.tinte),
      ('gedaempft', blatt.tinteGedaempft),
      ('blass', blatt.tinteBlass),
      ('linie', blatt.linie),
      ('akzent', blatt.akzent),
      ('sanft', blatt.akzentSanft),
      ('verweis', blatt.verweis),
      ('gut', blatt.gut),
      ('warnung', blatt.warnung),
      ('links', blatt.stufeLinks),
      ('m-links', blatt.stufeMitteLinks),
      ('mitte', blatt.stufeMitte),
      ('m-rechts', blatt.stufeMitteRechts),
      ('rechts', blatt.stufeRechts),
    ];
    return Wrap(
      spacing: Mass.knapp,
      runSpacing: Mass.knapp,
      children: [
        for (final (name, farbe) in proben)
          Column(
            children: [
              Container(
                width: 52,
                height: 32,
                decoration: BoxDecoration(
                  color: farbe,
                  border: Border.all(color: blatt.linie),
                  borderRadius: BorderRadius.circular(Mass.rundung - 2),
                ),
              ),
              const SizedBox(height: 3),
              Text(name,
                  style: Stil.meta
                      .copyWith(fontSize: 10, color: blatt.tinteGedaempft)),
              Text(
                '#${(farbe.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
                style: Stil.technisch
                    .copyWith(fontSize: 9, color: blatt.tinteBlass),
              ),
            ],
          ),
      ],
    );
  }
}
