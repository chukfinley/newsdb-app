/// Die Antwortformen von `news.chuk.dev/api`, so wie sie wirklich kommen.
///
/// Vorlage ist `news/frontend/src/lib/types.ts` — dieselbe Datei, die das Web
/// benutzt, und die einzige Wahrheit über die Form. Was dort steht, steht hier;
/// erfunden wird nichts.
///
/// **Fast alles ist nullbar, und das ist keine Nachlässigkeit.** Die API
/// beschneidet ihre Antworten je Lesestufe (A150): ein Gast bekommt die
/// Visitenkarte, ein Angemeldeter die Einleitung, ein Abonnent alles. Ein
/// Modell mit `required String text` wäre ein Modell, das lügt — und eine
/// Ansicht, die beim Gast auf einem `null` abstürzt. Deshalb: jedes Feld, das
/// die Stufe wegnehmen kann, ist hier nullbar, und die Ansicht entscheidet, was
/// sie ohne dieses Feld zeigt.
library;

/// Ein Eintrag der Titelseite (`GET /api/frontpage`).
class Kachel {
  const Kachel({
    required this.id,
    required this.titel,
    required this.anzahlHaeuser,
    required this.anzahlArtikel,
    required this.lagerVerteilung,
    this.bild,
    this.zuletzt,
    this.punkte = 0,
    this.blindspot = const [],
    this.anriss,
    this.anrissGekuerzt = false,
    this.anrissQuelle,
    this.artikel = const [],
  });

  factory Kachel.vonJson(Map<String, dynamic> json) => Kachel(
        id: json['id'] as String,
        titel: json['title'] as String? ?? '',
        anzahlHaeuser: (json['n_sources'] as num?)?.toInt() ?? 0,
        anzahlArtikel: (json['n_articles'] as num?)?.toInt() ?? 0,
        lagerVerteilung:
            (json['bias_spread'] as Map?)?.cast<String, dynamic>() ?? const {},
        bild: json['image'] as String?,
        zuletzt: _zeit(json['last_published']),
        punkte: (json['score'] as num?)?.toDouble() ?? 0,
        // `blindspot` ist selbst nullbar **und** enthält eine Liste — beides
        // kann fehlen, je Stufe. Nur mit Abo.
        blindspot: ((json['blindspot'] as Map?)?['for'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        anriss: json['anriss'] as String?,
        anrissGekuerzt: json['anriss_gekuerzt'] == true,
        anrissQuelle: json['anriss_quelle'] as String?,
        artikel: (json['articles'] as List?)
                ?.whereType<Map>()
                .map((a) => Kurzartikel.vonJson(a.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  final String id;
  final String titel;

  /// Wie viele Häuser tragen die Meldung — die Zahl, die eine Story trägt.
  final int anzahlHaeuser;
  final int anzahlArtikel;

  /// Die **Fünf-Stufen**-Verteilung. Zusammengefasst wird erst in der Anzeige.
  final Map<String, dynamic> lagerVerteilung;

  final String? bild;
  final DateTime? zuletzt;
  final double punkte;

  /// Lager, die diese Meldung praktisch nicht berichten. Nur mit Abo.
  final List<String> blindspot;

  /// Der Anfang der Zusammenfassung, ab Stufe `konto`.
  final String? anriss;
  final bool anrissGekuerzt;

  /// Das Haus, dessen Vorspann der Anriss ist — der Text gehört ihm, und
  /// deshalb wird er nie ohne diese Angabe gezeigt.
  final String? anrissQuelle;

  /// Nur beim Aufmacher besetzt, und nur ab Stufe `konto`.
  final List<Kurzartikel> artikel;
}

/// Eine Überschrift mit ihrem Haus — die Zeilen des Dreiklangs.
class Kurzartikel {
  const Kurzartikel({
    required this.id,
    required this.titel,
    required this.hausId,
  });

  factory Kurzartikel.vonJson(Map<String, dynamic> json) => Kurzartikel(
        id: json['id'] as String,
        titel: json['title'] as String? ?? '',
        hausId: json['source_id'] as String? ?? '',
      );

  final String id;
  final String titel;
  final String hausId;
}

/// Die ganze Titelseite.
class Titelseite {
  const Titelseite({
    required this.kacheln,
    required this.erzeugtAm,
    this.stufe,
  });

  factory Titelseite.vonJson(Map<String, dynamic> json) => Titelseite(
        kacheln: (json['items'] as List?)
                ?.whereType<Map>()
                .map((k) => Kachel.vonJson(k.cast<String, dynamic>()))
                .toList() ??
            const [],
        erzeugtAm: _zeit(json['generated_at']),
        stufe: json['stufe'] as String?,
      );

  final List<Kachel> kacheln;
  final DateTime? erzeugtAm;

  /// Mit welcher Lesestufe diese Antwort gebaut wurde — `gast`, `konto`, `abo`.
  /// Die App liest sie, statt sie aus der Rolle im Token abzuleiten: sonst
  /// hätte sie eine zweite Meinung darüber, und die wäre irgendwann die
  /// falsche.
  final String? stufe;
}

/// Ein Suchtreffer aus `GET /api/articles?q=…` — ein Listeneintrag, keine
/// volle Ausgabe. Genug, um die Trefferliste zu zeichnen; der Volltext kommt
/// erst beim Öffnen (`Artikel`).
class Suchtreffer {
  const Suchtreffer({
    required this.id,
    required this.titel,
    required this.hausId,
    this.hausDomain,
    this.anriss,
    this.ressort,
    this.veroeffentlicht,
    this.bild,
    this.woerter = 0,
    this.schranke = Schranke.unbekannt,
  });

  factory Suchtreffer.vonJson(Map<String, dynamic> json) => Suchtreffer(
        id: json['id'] as String,
        titel: json['title'] as String? ?? '',
        hausId: json['source_id'] as String? ?? '',
        hausDomain: json['domain'] as String?,
        // `summary` ist bei der Liste schon ein Anriss, kein Volltext — und
        // fällt für Gäste weg (A150). Beides ist hier in Ordnung.
        anriss: json['summary'] as String?,
        ressort: json['section'] as String?,
        veroeffentlicht: _zeit(json['published_at']),
        bild: json['lead_image'] as String?,
        woerter: (json['word_count'] as num?)?.toInt() ?? 0,
        schranke: Schranke.vonJson(json['paywall']),
      );

  final String id;
  final String titel;
  final String hausId;
  final String? hausDomain;
  final String? anriss;
  final String? ressort;
  final DateTime? veroeffentlicht;
  final String? bild;
  final int woerter;
  final Schranke schranke;
}

/// Ein Haus (`GET /api/sources`). Gebraucht wird fast nur der Name — die
/// Kacheln zeigen Häusernamen, die API liefert Kennungen.
class Haus {
  const Haus({
    required this.id,
    required this.name,
    required this.domain,
    this.stufe,
    this.ort,
  });

  factory Haus.vonJson(Map<String, dynamic> json) => Haus(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        domain: json['domain'] as String? ?? '',
        stufe: json['bias'] as String?,
        ort: json['city'] as String?,
      );

  final String id;
  final String name;
  final String domain;

  /// Die politische Einordnung in **fünf** Stufen, oder `null` wenn das Haus
  /// nicht eingeordnet ist. `null` heißt „wir wissen es nicht" und **nicht**
  /// „Mitte" — der Unterschied entscheidet, ob ein Lagerbalken lügt.
  final String? stufe;

  final String? ort;
}

/// Eine Story (`GET /api/stories/{id}`).
class Story {
  const Story({
    required this.id,
    required this.titel,
    required this.lagerVerteilung,
    required this.haeuser,
    this.anzahlArtikel = 0,
    this.zuerst,
    this.zuletzt,
    this.anriss,
    this.anrissGekuerzt = false,
    this.anrissQuelle,
    this.zusammenfassung,
    this.blindspot = const [],
    this.artikel = const [],
    this.eigentuemer,
    this.haeuserGesamt,
    this.konzentriert = false,
    this.groessteGruppe,
    this.groessterAnteil,
  });

  factory Story.vonJson(Map<String, dynamic> json) => Story(
        id: json['id'] as String,
        titel: json['title'] as String? ?? '',
        lagerVerteilung:
            (json['bias_spread'] as Map?)?.cast<String, dynamic>() ?? const {},
        haeuser: (json['sources'] as List?)?.whereType<String>().toList() ??
            const [],
        anzahlArtikel: (json['n_articles'] as num?)?.toInt() ??
            (json['size'] as num?)?.toInt() ??
            0,
        zuerst: _zeit(json['first_published']),
        zuletzt: _zeit(json['last_published']),
        anriss: json['anriss'] as String?,
        anrissGekuerzt: json['anriss_gekuerzt'] == true,
        anrissQuelle: json['anriss_quelle'] as String?,
        zusammenfassung: json['zusammenfassung'] as String?,
        blindspot: ((json['blindspot'] as Map?)?['for'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        artikel: (json['articles'] as List?)
                ?.whereType<Map>()
                .map((a) => Artikel.vonJson(a.cast<String, dynamic>()))
                .toList() ??
            const [],
        // A175/Ground-News-Idee: nicht nur wie viele Häuser berichten, sondern
        // wie viele **verschiedene Eigentümer** dahinterstehen. 38 Häuser aus
        // 32 Eigentümern ist Vielfalt; 38 Häuser aus 3 Konzernen ist eine
        // Meldung, die nur laut klingt. Die API rechnet das schon
        // (`ownership_spread`), die App zeigt es bisher nicht.
        eigentuemer:
            ((json['ownership_spread'] as Map?)?['distinct_owners'] as num?)
                ?.toInt(),
        haeuserGesamt:
            ((json['ownership_spread'] as Map?)?['outlets'] as num?)?.toInt(),
        konzentriert:
            (json['ownership_spread'] as Map?)?['concentrated'] == true,
        groessteGruppe: _groessteGruppe(json['ownership_spread']),
        groessterAnteil:
            ((json['ownership_spread'] as Map?)?['largest_share'] as num?)
                ?.toDouble(),
      );

  final String id;
  final String titel;
  final Map<String, dynamic> lagerVerteilung;
  final List<String> haeuser;
  final int anzahlArtikel;
  final DateTime? zuerst;
  final DateTime? zuletzt;

  /// Wie viele **verschiedene** Eigentümer hinter den berichtenden Häusern
  /// stehen. `null`, solange die API es nicht liefert.
  final int? eigentuemer;

  /// Die Zahl der Häuser aus Sicht der Eigentümer-Auswertung — kann von
  /// `haeuser.length` abweichen, wenn ein Haus keinem Eigentümer zugeordnet ist.
  final int? haeuserGesamt;

  /// Liegt die Berichterstattung in wenigen Händen? Die API entscheidet das
  /// (HHI-Schwelle), die App zeichnet nur die Warnung.
  final bool konzentriert;

  /// Der Name der größten Eigentümergruppe — für den Satz „vor allem …".
  final String? groessteGruppe;

  /// Ihr Anteil in Prozent.
  final double? groessterAnteil;
  final String? anriss;
  final bool anrissGekuerzt;
  final String? anrissQuelle;

  /// Die ganze Zusammenfassung — nur mit Abo.
  final String? zusammenfassung;
  final List<String> blindspot;
  final List<Artikel> artikel;
}

/// Wie eine Seite hinter der Bezahlschranke steht.
enum Schranke {
  keine,
  gezaehlt,
  hart,
  unbekannt;

  static Schranke vonJson(Object? wert) => switch (wert) {
        'none' => Schranke.keine,
        'metered' => Schranke.gezaehlt,
        'hard' => Schranke.hart,
        _ => Schranke.unbekannt,
      };

  bool get gesperrt => this == Schranke.hart || this == Schranke.gezaehlt;
}

/// Ein Artikel (`GET /api/articles/{id}`).
class Artikel {
  const Artikel({
    required this.id,
    required this.titel,
    required this.hausId,
    required this.url,
    this.hausName,
    this.untertitel,
    this.vorspann,
    this.kiZusammenfassung,
    this.text,
    this.textAnriss,
    this.textGekuerzt = false,
    this.autoren = const [],
    this.ressort,
    this.veroeffentlicht,
    this.bild,
    this.schranke = Schranke.unbekannt,
    this.abgeschnitten = false,
    this.woerter = 0,
    this.lesesekunden = 0,
  });

  factory Artikel.vonJson(Map<String, dynamic> json) => Artikel(
        id: json['id'] as String,
        titel: json['title'] as String? ?? '',
        hausId: json['source_id'] as String? ?? '',
        url: json['url'] as String? ?? json['canonical_url'] as String? ?? '',
        hausName: json['source_name'] as String?,
        untertitel: json['subtitle'] as String?,
        vorspann: json['summary'] as String?,
        kiZusammenfassung: json['ai_summary'] as String?,
        text: json['text'] as String?,
        textAnriss: json['text_anriss'] as String?,
        textGekuerzt: json['text_gekuerzt'] == true,
        autoren:
            (json['authors'] as List?)?.whereType<String>().toList() ?? const [],
        ressort: json['section'] as String?,
        veroeffentlicht: _zeit(json['published_at']),
        bild: _aufmacherbild(json),
        schranke: Schranke.vonJson(json['paywall']),
        abgeschnitten: json['truncated'] == true || json['truncated'] == 1,
        woerter: (json['word_count'] as num?)?.toInt() ?? 0,
        lesesekunden: (json['reading_seconds'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String titel;
  final String hausId;
  final String url;
  final String? hausName;
  final String? untertitel;

  /// Der Vorspann des Hauses.
  final String? vorspann;

  /// Die Zusammenfassung aus dem Sprachmodell. Sie entsteht auf dem Server aus
  /// den Volltexten und liegt dort — die App zeigt sie nur.
  final String? kiZusammenfassung;

  /// Der Volltext. **Nur mit Abo.**
  final String? text;

  /// Die ersten Wörter des Volltexts, ab Stufe `konto`.
  final String? textAnriss;

  /// Sagt, ob hinter dem Anriss wirklich noch etwas steht.
  final bool textGekuerzt;

  final List<String> autoren;
  final String? ressort;
  final DateTime? veroeffentlicht;
  final String? bild;

  final Schranke schranke;

  /// Der Datensatz ist selbst angeschnitten — nicht dasselbe wie
  /// `textGekuerzt`, das die Lesestufe beschreibt. Hier geht es um das, was wir
  /// überhaupt haben: **ein Anriss ist kein Artikel.**
  final bool abgeschnitten;

  final int woerter;
  final int lesesekunden;

  /// Was von diesem Artikel gerade lesbar ist, in einem Feld — damit keine
  /// Ansicht die Reihenfolge selbst zusammenreimt.
  String? get lesbar => text ?? textAnriss ?? kiZusammenfassung ?? vorspann;

  /// Steht hinter dem, was wir zeigen, noch mehr?
  bool get mehrDahinter => text == null && (textGekuerzt || abgeschnitten);
}

/// Die Adresse des Aufmacherbilds eines Artikels.
///
/// **`lead_image_id` ist eine Kennung, keine Adresse** — anders als `image` bei
/// den Kacheln der Titelseite, wo eine fertige Verlags-URL steht. Wer die
/// Kennung an ein Bild-Widget gibt, bekommt „kein Bild", ohne dass etwas
/// meldet, dass es kaputt ist. Gemessen am 17.8.2026 an einem echten Artikel:
/// `lead_image_id: ea1ba24c1c7171b5af644af6`.
///
/// Die Kennung liesse sich über `/api/images/{id}` auflösen — **und genau das
/// tut diese App bewusst nicht.** Der Weg verlangt ein Token und antwortet mit
/// `307` auf die Adresse beim Verlag. Dart entfernt beim Verfolgen einer
/// Weiterleitung den `Authorization`-Kopf nicht, also ginge unser JWT an
/// merkur.de, spiegel.de und jedes andere Haus, dessen Bild jemand ansieht.
///
/// Die Antwort enthält die Adresse ohnehin schon: `images` trägt je Eintrag
/// `url` und `role`. Also von dort, ohne Umweg und ohne Token — genauso wie
/// das Web es macht.
/// Der Klarname der größten Eigentümergruppe aus `ownership_spread`.
///
/// Die API liefert `largest_group` als Kennung (`ippen`), der lesbare Name
/// steht in der `groups`-Liste. Wir suchen ihn dort und kürzen den Klammerzusatz
/// weg: „Ippen-Gruppe (Dirk Ippen)" wird zu „Ippen-Gruppe".
String? _groessteGruppe(Object? ownership) {
  if (ownership is! Map) return null;
  final kennung = ownership['largest_group'] as String?;
  if (kennung == null) return null;
  final gruppen = (ownership['groups'] as List?)?.whereType<Map>();
  final treffer = gruppen?.firstWhere(
    (g) => g['group'] == kennung,
    orElse: () => const {},
  );
  final name = treffer?['name'] as String?;
  if (name == null || name.isEmpty) return null;
  final klammer = name.indexOf(' (');
  return klammer > 0 ? name.substring(0, klammer) : name;
}

String? _aufmacherbild(Map<String, dynamic> json) {
  final bilder = (json['images'] as List?)?.whereType<Map>().toList();
  if (bilder == null || bilder.isEmpty) {
    // Der Listenweg (`/api/articles`) liefert statt `images` ein fertiges
    // `lead_image`. Das ist eine Adresse und darf direkt durch.
    return json['lead_image'] as String?;
  }
  final kennung = json['lead_image_id'] as String?;
  Map? treffer;
  for (final bild in bilder) {
    if (kennung != null && bild['id'] == kennung) {
      treffer = bild;
      break;
    }
    treffer ??= bild['role'] == 'lead' ? bild : null;
  }
  final url = (treffer ?? bilder.first)['url'];
  return url is String && url.isNotEmpty ? url : null;
}

/// Zeitangaben der API sind ISO-8601 in UTC, manchmal `null`, gelegentlich
/// leer. Alle drei Fälle kommen vor — und eine Ausnahme beim Lesen einer
/// Zeitangabe hat schon eine ganze Titelseite gekostet.
DateTime? _zeit(Object? wert) {
  if (wert is! String || wert.isEmpty) return null;
  return DateTime.tryParse(wert)?.toLocal();
}
