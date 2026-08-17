# Projektregeln — newsdb-app

Gilt für jede Sitzung in diesem Repo, für Menschen wie für Agenten. Das
Backend liegt daneben in `../news`; dessen `CLAUDE.md` gilt sinngemäß mit,
besonders die Abschnitte über Messen und Committen.

## Zuerst lesen

1. `README.md` — was die App ist und woher was kommt
2. `../news/docs/aufgaben.md`, Aufgaben **A160 bis A162** — die App, der Push,
   die Fassung ohne Google. Dort steht auch der Stand.
3. `../news/CLAUDE.md` — die Regeln des Backends

Aufgabennummern in Kommentaren (A148, A160, …) verweisen immer nach dort. Es
gibt **keine** eigene Aufgabenliste hier; zwei Listen wären zwei Wahrheiten.

## Bauen — Split-APK, niemals universal

**Ein universelles APK wird hier nicht ausgeliefert.** Es enthält denselben
Code dreimal, und jeder Leser lädt zwei Architekturen herunter, die sein Gerät
nie ausführt.

Gemessen am 17.8.2026 am universellen Bündel: von 54,3 MB waren **49,3 MB drei
Architekturen** — `x86_64` 18,2 MB (läuft nur auf Emulatoren), `arm64-v8a`
16,8 MB, `armeabi-v7a` 14,3 MB (Geräte von vor etwa 2015). Alles andere
zusammen, Schriften eingerechnet, waren 5 MB.

Der Bau geht deshalb so:

```bash
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=build/symbole
```

Ausgeliefert wird **`app-arm64-v8a-release.apk`**, dazu bei Bedarf
`armeabi-v7a`. `x86_64` gehört in kein Release; wer einen Emulator füttert,
baut selbst.

`--split-debug-info` nimmt die Dart-Symbole aus `libapp.so` heraus. Die
Symboldateien unter `build/symbole` **aufheben**, wer einen Absturzbericht
lesen will, braucht genau die Fassung, mit der gebaut wurde.

### Zwei Stellschrauben, die man nicht sieht

**`useLegacyPackaging = true`** in `android/app/build.gradle.kts`. Seit Android
6 legt Gradle die `.so`-Dateien unkomprimiert ins APK — schnellere Installation,
größerer Download. Bei Flutter ist der Unterschied erheblich, `libflutter.so`
misst unkomprimiert allein 11,2 MB. Für ein Bündel, das über GitHub geladen
wird, ist der Download das, was jemand merkt. Für den Play Store wäre die
Entscheidung umgekehrt.

**Die Schriften sind zurechtgeschnitten.** `tools/schriften.py` verkleinert die
Originale von Google Fonts auf Latein samt Erweiterungen — gemessen 3,77 MB →
2,28 MB. Dabei müssen zwei Dinge erhalten bleiben, und beide gehen leicht
verloren:

* die **Variable-Achsen** (`wght` trägt Gewicht 620 der Schlagzeile, `opsz` die
  optische Größe),
* die **OpenType-Merkmale** `onum`, `lnum`, `tnum` — die Mediävalziffern im
  Fließtext und die Versalziffern in der Metazeile. Die Vorgabe von
  `pyftsubset` wirft sie weg, und danach stehen überall dieselben Ziffern, ohne
  dass jemand den Grund findet.

Die Originale liegen unter `assets/fonts/original/` und werden nicht gelöscht.

## Signieren

Aktuell trägt das Release den **Debug-Schlüssel**. Das ist ein bewusster
Zwischenschritt und in `build.gradle.kts` begründet.

Der Weg dahin gehört zur Sache: zuerst stand dort ein wirklich unsigniertes
APK. Das ist der ehrlichste Zustand — und unbrauchbar, weil **Android ein
unsigniertes Paket nicht installiert**, meist ohne verwertbare Meldung.

Der echte Schlüssel liegt bereit unter `~/newsdb-keys/` (4096 Bit, 30 Jahre)
und ist absichtlich noch nicht in Gebrauch. Ab dem Moment, in dem eine App
damit verbreitet ist, ist er nicht mehr austauschbar: geht er verloren, kann
niemand mehr ein Update ausliefern. **Diese Datei sichern, bevor sie benutzt
wird.** Der Wechsel kostet später eine Deinstallation bei jedem, der die
Debug-signierte Fassung hat.

## Berechtigungen

**Flutter trägt `INTERNET` nur in `debug/` und `profile/` ein, nicht ins
Hauptmanifest.** Beim Entwickeln fällt das nie auf, und erst das Release
startet sauber und scheitert danach an jedem Abruf. Die Zeile steht jetzt in
`android/app/src/main/AndroidManifest.xml` und bleibt dort.

Geprüft wird am **gebauten** Paket, nicht am Manifest:

```bash
apkanalyzer manifest permissions build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Jede weitere Berechtigung braucht einen Grund, der über „könnte man
gebrauchen" hinausgeht. `ACCESS_NETWORK_STATE` sagt nichts, was ein
fehlgeschlagener Abruf nicht auch sagt. `POST_NOTIFICATIONS` kommt mit A161,
wenn es etwas zu benachrichtigen gibt, und keinen Tag früher.

## Design — die Wahrheit steht im Web

Farben werden **erzeugt**, nicht abgetippt:

```bash
python3 tools/farben.py ../news/frontend/src/index.css
```

`lib/design/tokens.dart` ist eine erzeugte Datei. Wer sie von Hand ändert,
verliert die Änderung beim nächsten Lauf und hat bis dahin zwei Designs.

Bevor eine Ansicht gebaut wird, wird die entsprechende Stelle im Web gelesen —
`../news/frontend/src/components/reader/` und `routes/reader/`. Dort steht
nicht nur, wie es aussieht, sondern warum: die vier Kachelränge, der kompakte
gegen den ausführlichen Lagerspiegel, „in der Vorschau weniger, nicht mehr".
Diese Begründungen sind teuer erarbeitet und werden nicht neu erfunden.

**Links rot, rechts blau** — die deutsche Zuordnung, nicht das US-Schema.

## Prüfen

```bash
flutter analyze          # muss sauber sein
flutter test             # muss grün sein
```

**Der Golden-Test ist kein Beiwerk.** `test/musterseite_test.dart` rendert die
Design-Bausteine headless nach `test/bilder/` — und hat sofort einen Fehler
gefunden, den keine Zusicherung gezeigt hätte: der kompakte Lagerspiegel war
auf jeder Kachel null Pixel hoch, weil `ColoredBox` ohne Kind in einer `Row`
die kleinstmögliche Höhe nimmt. Im ausführlichen Modus steht eine Ziffer im
Segment, also war er dort sichtbar — sichtbar genau da, wo man hinsieht.

Bilder neu erzeugen:

```bash
flutter test --update-goldens test/musterseite_test.dart
```

Die Schriften werden im Test von Hand geladen (`FontLoader`). Ohne das zeichnet
Flutter Testkästen, und das Bild sagt über Typografie nichts.

## Was hier nicht hingehört

* **Kein Zustandspaket.** Die App hat einen globalen Zustand, „angemeldet oder
  nicht", und der ist ein `ChangeNotifier`.
* **Keine zweite API.** Convex für Identität, `news.chuk.dev/api` für Inhalte —
  die Grenze aus A148. Was der Nutzer erzeugt, liegt in Convex; was der Crawler
  erzeugt, auf dem Server.
* **Kein `convex_flutter`.** Das Paket baut seinen Rust-Kern über cargokit, und
  dessen Gradle-Plugin ruft `Project.exec()`, das Gradle 9 entfernt hat. Der
  Build bricht ab, bevor eine Zeile eigener Code übersetzt wird. `lib/auth/convex.dart`
  redet direkt mit der HTTP-Schnittstelle — dieselbe Funktion, kein natives
  Stück im Bündel, und Web läuft mit.
* **Keine Berechtigung auf Vorrat.** Siehe oben.

## Committen

Wie im Backend: **nach jeder abgeschlossenen Einheit**, mit ausdrücklicher
Dateiliste, Nachricht auf Deutsch, und die erste Zeile sagt den **Befund**,
nicht die Datei. Muster aus dem Verlauf dieses Repos: „Der Lagerbalken war auf
jeder Kachel null Pixel hoch — im ausführlichen Modus nicht".

## Deutsche Kommentare, die das Warum erklären

Wie im Backend. Ein Kommentar, der beschreibt, was die Zeile tut, ist
überflüssig; einer, der sagt, warum sie so und nicht anders dasteht, spart der
nächsten Sitzung einen halben Tag. Die Fallen in diesem Repo waren durchweg
Dinge, die nicht kaputtgehen, sondern still nichts tun: ein Balken ohne Höhe,
eine fehlende Berechtigung, ein Paket, das nicht baut.
