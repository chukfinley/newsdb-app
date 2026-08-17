# newsdb — die App

Nachrichten aus vielen Häusern, mit dem Lagerspiegel dazu. Die mobile Fassung
von [news.chuk.dev](https://news.chuk.dev), gebaut mit Flutter.

Das Backend liegt in einem eigenen Repo (`news`); hier liegt ausschließlich die
App. Aufgabennummern in Kommentaren (A160, A161, …) verweisen auf
`docs/aufgaben.md` dort.

## Woher was kommt

Die Regel ist dieselbe wie im Web (A148) und der Grund, warum nichts
synchronisiert werden muss:

> Was der **Nutzer** erzeugt, liegt in Convex.
> Was der **Crawler** erzeugt, liegt auf dem Server.

Die App redet deshalb mit genau **zwei** Gegenstellen:

| Gegenstelle | Was | Wie |
|---|---|---|
| Convex | Konto, Anmeldung, Rolle, Abo, Interessen | `convex_flutter`, Action `auth:signIn` |
| `news.chuk.dev/api` | Titelseite, Stories, Artikel, Suche, Bilder | HTTPS mit dem Convex-JWT im `Authorization`-Kopf |

Kein Sonderweg für Mobile, keine zweite API. Das Token gilt 15 Minuten und wird
selbst erneuert; die Sitzung hält 14 Tage.

## Das Design ist übernommen, nicht nachempfunden

Die Wahrheit über Farben und Schriften steht im Web-Frontend, in
`news/frontend/src/index.css`, und zwar in OKLCH. Abgetippte Hex-Werte wären
zwei Designs, die beim nächsten Feinschliff auseinanderlaufen — deshalb erzeugt
`tools/farben.py` die Dart-Konstanten daraus:

```bash
python3 tools/farben.py ../news/frontend/src/index.css
python3 tools/farben.py --pruefe   # nur die Selbstprobe
```

Die Selbstprobe rechnet 4.096 Farben hin und zurück (sRGB → OKLCH → sRGB) und
verlangt eine Abweichung von null Stufen; ohne sie wäre die Umrechnung
neunzehn Koeffizienten Vertrauen. Fünf Tokens liegen außerhalb des sRGB-Raums
und werden geklemmt **und gemeldet** — auf einem P3-Bildschirm zeigt der
Browser dort satteres Grün als die App.

`lib/design/tokens.dart` ist erzeugt und wird nicht von Hand geändert.

Was sonst übernommen ist: die vier Schriften als gebündelte Assets (kein CDN
zur Laufzeit), die vier Kachelränge der Titelseite samt Bildformaten und
Balkenhöhen, die Papierstruktur, und die **deutsche** Lager-Kodierung — links
rot, rechts blau.

## Bauen

Es braucht Flutter 3.47 oder neuer, ein Android SDK und Java 17+.

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

## Push

Ein Kanal-Fan-out auf dem Server, mehrere Ausgänge in der App — die Einheit ist
die **Story**, nicht der Artikel, und es gehen nur Metadaten raus (~300 Byte:
Kicker, Überschrift, kurze Zusammenfassung, Bild-URL, Story-ID). Volltext und
Bild holt die App erst beim Antippen.

Der Grund steht in A161: bei 281.977 Artikeln in 24 Stunden kostet es 42 MB je
Tag und Gerät, alles zu senden und im Client zu filtern.

Geplant, in dieser Reihenfolge:

1. **Regelfall** — alle 30 Minuten abholen (`WorkManager`). Kein Dienst, keine
   Dauerverbindung, kein Eintrag unter „Aktive Apps".
2. **Play-Variante** — FCM.
3. **Ohne Google** (A162) — UnifiedPush, und ein eigener WebSocket im
   Foreground Service als Rückfall. Dafür sitzt die Push-Schicht hinter einer
   Schnittstelle und das Firebase-Plugin nur am `play`-Flavor: ein Bündel für
   F-Droid darf Firebase nicht *enthalten*, nicht nur nicht benutzen.

## Stand

Musterseite mit allen Design-Bausteinen, `flutter analyze` sauber. Titelseite
mit echten Daten und Anmeldung kommen als nächstes.

## Lizenzen

Die Schriften stehen unter der SIL Open Font License; die Lizenztexte liegen
neben den Dateien in `assets/fonts/`.
