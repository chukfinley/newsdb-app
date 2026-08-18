/// Der visuelle Beleg — ohne Gerät, ohne Emulator.
///
/// Dieser Test rendert die Design-Bausteine in beiden Ausgaben und schreibt sie
/// als PNG nach `test/bilder/`. Das ist die Abnahme von A160: „Design aus der
/// Web-Oberfläche übernommen" lässt sich nur ansehen, nicht behaupten — und ein
/// Bild, das bei jedem Testlauf neu entsteht, veraltet nicht.
///
/// **Warum die Schriften hier von Hand geladen werden:** in einem Widget-Test
/// gibt es kein Asset-Bündel wie in der App. Ohne `FontLoader` zeichnet Flutter
/// alles in „Ahem", einer Testschrift aus schwarzen Kästen — das Bild sähe
/// zwar aus wie ein Layout, würde aber über Typografie nichts aussagen. Und
/// genau die Typografie ist hier die halbe Sache.
///
/// Erzeugen:
///
/// ```bash
/// flutter test --update-goldens test/musterseite_test.dart
/// ```
///
/// Ohne `--update-goldens` vergleicht der Test gegen die abgelegten Bilder und
/// schlägt an, wenn sich das Design ungewollt verändert.
library;

import 'dart:io';

import 'package:flutter/material.dart';
// `FontLoader` steht in `services`, nicht in `material` — ohne diesen Import
// fehlt genau die Klasse, die den Unterschied zwischen echtem Schriftbild und
// schwarzen Testkästen macht.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newsdb_app/api/modelle.dart';
import 'package:newsdb_app/design/papier.dart';
import 'package:newsdb_app/design/thema.dart';
import 'package:newsdb_app/design/typografie.dart';
import 'package:newsdb_app/widgets/kachel.dart';
import 'package:newsdb_app/widgets/lagerspiegel.dart';

/// Die vier Familien aus `pubspec.yaml`, in derselben Zuordnung.
Future<void> _schriftenLaden() async {
  const dateien = {
    'Newsreader': ['assets/fonts/Newsreader-VF.ttf'],
    'SourceSerif4': ['assets/fonts/SourceSerif4-VF.ttf'],
    'Archivo': ['assets/fonts/Archivo-VF.ttf'],
    'JetBrainsMono': ['assets/fonts/JetBrainsMono-VF.ttf'],
  };
  for (final eintrag in dateien.entries) {
    final lader = FontLoader(eintrag.key);
    for (final pfad in eintrag.value) {
      lader.addFont(
        File(pfad).readAsBytes().then((b) => b.buffer.asByteData()),
      );
    }
    await lader.load();
  }
}

/// Eine Story mit breiter Berichterstattung.
const _breit = Kachel(
  id: 's1',
  titel: 'Der Bundestag streitet über den Haushalt, und jedes Haus '
      'formuliert es anders',
  anzahlHaeuser: 12,
  anzahlArtikel: 19,
  lagerVerteilung: {
    'left': 4,
    'center-left': 3,
    'center': 6,
    'center-right': 2,
    'right': 1,
  },
  zuletzt: null,
);

/// Eine mit Blindspot: aus dem rechten Lager berichtet niemand.
const _schief = Kachel(
  id: 's2',
  titel: 'Die Länder bremsen beim Klimageld',
  anzahlHaeuser: 7,
  anzahlArtikel: 9,
  lagerVerteilung: {'left': 7, 'center-left': 4, 'center': 2},
  zuletzt: null,
);

void main() {
  setUpAll(_schriftenLaden);

  for (final (name, thema) in [
    ('tagesausgabe', tagesausgabe),
    ('nachtausgabe', nachtausgabe),
  ]) {
    testWidgets('Musterseite — $name', (tester) async {
      // Ein Telefon in Hochkant: 412 × 915 logische Pixel sind die verbreitete
      // Android-Größe. Die Höhe ist absichtlich großzügig, damit alles auf ein
      // Bild passt und niemand scrollen muss, um zu vergleichen.
      tester.view.physicalSize = const Size(412 * 2, 1900 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: thema,
          debugShowCheckedModeBanner: false,
          home: const _Muster(),
        ),
      );
      // Die Papierstruktur entsteht asynchron (ein Bild, einmal gebaut). Ohne
      // diesen Durchlauf wäre sie auf dem Golden nicht drauf — und das ist
      // genau eine der Sachen, die geprüft werden soll.
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_Muster),
        matchesGoldenFile('bilder/muster-$name.png'),
      );
    });
  }
}

class _Muster extends StatelessWidget {
  const _Muster();

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Scaffold(
      body: Papier(
        child: Padding(
          padding: const EdgeInsets.all(Mass.rand),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('newsdb', style: Stil.schlagzeile(30)),
              Text(
                'MUSTERSEITE · DESIGN AUS DER WEB-OBERFLÄCHE',
                style: Stil.kicker.copyWith(color: blatt.akzent),
              ),
              const SizedBox(height: Mass.normal),
              Divider(color: blatt.linieStark, height: 1),
              const SizedBox(height: Mass.kachel),

              // Aufmacher und die drei kleineren Ränge — die Rangfolge muss man
              // auf einen Blick sehen.
              Storykachel(
                kachel: _breit,
                rang: Kachelrang.aufmacher,
                oeffnen: () {},
              ),
              const SizedBox(height: Mass.kachel),
              Storykachel(
                kachel: _schief,
                rang: Kachelrang.doppel,
                oeffnen: () {},
              ),
              const SizedBox(height: Mass.kachel),
              const FehlendeLager(
                verteilung: {'left': 7, 'center-left': 4, 'center': 2},
              ),
              const SizedBox(height: Mass.kachel),

              Text(
                'DER LAGERSPIEGEL, AUSFÜHRLICH',
                style: Stil.kicker.copyWith(color: blatt.tinteGedaempft),
              ),
              const SizedBox(height: Mass.knapp),
              Lagerspiegel(
                verteilung: _breit.lagerVerteilung,
                hoehe: 26,
                modus: Spiegelmodus.ausfuehrlich,
                zahlen: true,
              ),
              const SizedBox(height: Mass.knapp),
              Lagerkuerzel(verteilung: _breit.lagerVerteilung),
              const SizedBox(height: Mass.block),
              Text('L/M/R IM BALKEN (AUFMACHER, 18 PX)',
                  style: Stil.kicker.copyWith(color: blatt.tinteGedaempft)),
              const SizedBox(height: Mass.knapp),
              Lagerspiegel(
                verteilung: _breit.lagerVerteilung,
                hoehe: 18,
                buchstaben: true,
              ),
              const SizedBox(height: Mass.kachel),

              Text(
                'Newsreader für die Schlagzeile, Source Serif 4 für den '
                'Lesetext, Archivo für die Metazeile. Die Ziffern im '
                'Fließtext sind Mediävalziffern: 1975, 2026, 138 Häuser.',
                style: Stil.lesetext.copyWith(color: blatt.tinte),
              ),
              const SizedBox(height: Mass.block),
              Text(
                'article/9f3c1a · 47 Wörter · 0.89',
                style: Stil.technisch.copyWith(color: blatt.tinteGedaempft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
