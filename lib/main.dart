/// newsdb — die App.
///
/// Der Aufbau ist absichtlich klein: **ein** globaler Zustand (angemeldet oder
/// nicht), und die App baut sich neu, sobald er sich ändert. Kein
/// Zustandspaket, kein Router mit Pfaden — die Navigation dieser App ist ein
/// Stapel aus vier Ansichten.
///
/// **A152, Beta-Modus: ohne Anmeldung nichts.** Das Tor liegt hier, über allem
/// anderen, aus demselben Grund wie im Web: eine Umleitung *innerhalb* der
/// Zeitung würde erst die Titelseite bauen, und die holt sofort ihre Daten — in
/// der Beta drei Abrufe mit 401, bevor überhaupt jemand ein Anmeldeformular
/// sieht. **Sicherheit ist es nicht:** die Sperre sitzt in `newsdb/api.py` und
/// ist von hier aus nicht zu umgehen. Dieses Tor erspart dem Nichtangemeldeten
/// nur den Anblick leerer Kästen.
library;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api/client.dart';
import 'auth/konto.dart';
import 'design/thema.dart';
import 'design/typografie.dart';
import 'routen/anmelden.dart';
import 'routen/artikel.dart';
import 'routen/story.dart';
import 'routen/suche.dart';
import 'routen/titelseite.dart';

void main() {
  // Ohne diesen Aufruf wirft `DateFormat('EEEE', 'de')` eine
  // `LocaleDataException` — `intl` bringt die Daten mit, lädt sie aber nicht
  // von allein. Der Fehler tritt erst auf, wenn eine Meldung drei Tage alt ist,
  // also nicht beim Ausprobieren: genau die Sorte Fehler, die in Betrieb geht.
  initializeDateFormatting('de');
  runApp(const NewsdbApp());
}

class NewsdbApp extends StatefulWidget {
  const NewsdbApp({super.key});

  @override
  State<NewsdbApp> createState() => _NewsdbAppState();
}

class _NewsdbAppState extends State<NewsdbApp> {
  final _anmeldung = Anmeldung();
  late final NewsdbApi _api = NewsdbApi(anmeldung: _anmeldung);

  /// Vorgabe ist die Einstellung des Geräts — dieselbe Haltung wie im Web, wo
  /// `useTheme` mit `prefers-color-scheme` anfängt.
  ThemeMode _modus = ThemeMode.system;

  /// Solange die gespeicherte Sitzung geprüft wird, ist weder „angemeldet" noch
  /// „nicht angemeldet" wahr. Ohne diesen dritten Zustand blitzt bei jedem
  /// Start das Anmeldeformular auf, obwohl das Konto längst besteht.
  bool _laedt = true;

  @override
  void initState() {
    super.initState();
    _anmeldung.addListener(_geaendert);
    _anmeldung.wiederherstellen().whenComplete(() {
      if (mounted) setState(() => _laedt = false);
    });
  }

  void _geaendert() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _anmeldung.removeListener(_geaendert);
    _api.dispose();
    _anmeldung.dispose();
    super.dispose();
  }

  void _umschalten() {
    final dunkel =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    setState(() {
      _modus = switch (_modus) {
        ThemeMode.system => dunkel ? ThemeMode.light : ThemeMode.dark,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.light,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'newsdb',
      debugShowCheckedModeBanner: false,
      theme: tagesausgabe,
      darkTheme: nachtausgabe,
      themeMode: _modus,
      home: _laedt
          ? const _Vorhang()
          : _anmeldung.angemeldet
              ? Zeitung(
                  api: _api,
                  anmeldung: _anmeldung,
                  themaUmschalten: _umschalten,
                )
              : Anmeldeseite(anmeldung: _anmeldung),
    );
  }
}

/// Der Moment zwischen Start und Entscheidung. Ein Satz, kein leerer
/// Bildschirm — schwarz ist nicht „lädt", schwarz ist „kaputt".
class _Vorhang extends StatelessWidget {
  const _Vorhang();

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('newsdb', style: Stil.schlagzeile(26)),
            const SizedBox(height: Mass.knapp),
            Text(
              'einen Moment …',
              style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
            ),
          ],
        ),
      ),
    );
  }
}

/// Die Zeitung: Kopf, Titelseite, und der Weg zu Story und Artikel.
class Zeitung extends StatelessWidget {
  const Zeitung({
    required this.api,
    required this.anmeldung,
    required this.themaUmschalten,
    super.key,
  });

  final NewsdbApi api;
  final Anmeldung anmeldung;
  final VoidCallback themaUmschalten;

  void _story(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Storyansicht(
          api: api,
          storyId: id,
          artikelOeffnen: (artikelId) => _artikel(context, artikelId),
        ),
      ),
    );
  }

  void _artikel(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Artikelansicht(api: api, artikelId: id),
      ),
    );
  }

  void _suche(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Suchseite(
          api: api,
          artikelOeffnen: (id) => _artikel(context, id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final dunkel = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('newsdb', style: Stil.schlagzeile(22)),
        // Die Kopfzeile trägt die Haarlinie des Blattlayouts, nicht einen
        // Schatten: ein Schatten wäre Material, eine Linie ist Zeitung.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: blatt.linieStark, height: 1, thickness: 1),
        ),
        actions: [
          IconButton(
            onPressed: () => _suche(context),
            icon: const Icon(Icons.search),
            color: blatt.tinteGedaempft,
            tooltip: 'Suchen',
          ),
          IconButton(
            onPressed: themaUmschalten,
            icon: Icon(dunkel ? Icons.light_mode : Icons.dark_mode),
            color: blatt.tinteGedaempft,
            tooltip: dunkel ? 'Tagesausgabe' : 'Nachtausgabe',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: blatt.tinteGedaempft),
            color: blatt.papierGehoben,
            onSelected: (wahl) {
              if (wahl == 'abmelden') anmeldung.abmelden();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  anmeldung.konto?.email ?? 'angemeldet',
                  style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
                ),
              ),
              PopupMenuItem(
                value: 'abmelden',
                child: Text('Abmelden', style: Stil.zahl),
              ),
            ],
          ),
        ],
      ),
      body: Titelseiteansicht(
        api: api,
        anmeldung: anmeldung,
        storyOeffnen: (id) => _story(context, id),
        artikelOeffnen: (id) => _artikel(context, id),
      ),
    );
  }
}
