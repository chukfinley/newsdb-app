/// Der Zugang zu `news.chuk.dev/api`.
///
/// Ein schmaler Client, absichtlich ohne Zwischenschicht: die API liefert JSON,
/// die Modelle lesen JSON, dazwischen gehört nichts.
///
/// **Das Token kommt aus der Anmeldung, nicht aus einem eigenen Vorrat.** Der
/// Client fragt vor jedem Abruf `Anmeldung.tokenFuerAbruf()` — dort wird
/// erneuert, wenn das JWT in weniger als einer Minute abläuft. So kann ein
/// Abruf nicht daran scheitern, dass zwischen Aufbau und Absenden 15 Minuten
/// vergangen sind.
///
/// **Ohne Token wird trotzdem gefragt.** In der geschlossenen Beta antwortet
/// die API dann mit 401 (`NEWSDB_BETA`), und genau das soll die App sehen und
/// als „bitte anmelden" zeigen — nicht selbst vorab entscheiden, dass es sich
/// nicht lohnt. Die Freiliste (`/api/me`, `/api/stufe`) antwortet auch ohne.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/konto.dart';
import 'konfiguration.dart';
import 'modelle.dart';

/// Ein Abruf ist schiefgegangen — in der Form, die die Oberfläche braucht.
class ApiFehler implements Exception {
  const ApiFehler(this.status, this.pfad, [this.meldung]);

  /// HTTP-Status, oder 0 wenn die Anfrage nie ankam.
  final int status;
  final String pfad;
  final String? meldung;

  /// Nicht angemeldet oder Token abgelaufen. Die Oberfläche zeigt darauf die
  /// Anmeldung, nicht eine Fehlermeldung.
  bool get brauchtAnmeldung => status == 401;

  /// Kein Netz. Unterschieden von „Server sagt nein", weil der Leser darauf
  /// anders reagiert: einmal warten, einmal weitersuchen.
  bool get keinNetz => status == 0;

  String get text {
    if (keinNetz) return 'Keine Verbindung zu newsdb.';
    if (brauchtAnmeldung) return 'Dafür braucht es eine Anmeldung.';
    if (status == 404) return 'Das gibt es nicht (mehr).';
    if (status >= 500) return 'newsdb hat gerade ein Problem.';
    return 'Abruf fehlgeschlagen ($status).';
  }

  @override
  String toString() => 'ApiFehler($status, $pfad): $meldung';
}

class NewsdbApi {
  NewsdbApi({required this.anmeldung, http.Client? client})
      : _client = client ?? http.Client();

  final Anmeldung anmeldung;
  final http.Client _client;

  /// 15 Sekunden. Die Titelseite kommt in gut 200 ms; wer länger als 15
  /// Sekunden wartet, wartet auf etwas, das nicht mehr kommt — und ein
  /// hängender Abruf ohne Frist ist ein Ladekringel, der nie aufhört.
  static const _frist = Duration(seconds: 15);

  Future<Map<String, dynamic>> _holen(
    String pfad, [
    Map<String, String>? parameter,
  ]) async {
    final ziel = Uri.parse('${Adressen.api}$pfad').replace(
      queryParameters: parameter?.isEmpty ?? true ? null : parameter,
    );
    final token = await anmeldung.tokenFuerAbruf();

    http.Response antwort;
    try {
      antwort = await _client
          .get(ziel, headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          })
          .timeout(_frist);
    } on Object catch (fehler) {
      throw ApiFehler(0, pfad, fehler.toString());
    }

    if (antwort.statusCode != 200) {
      throw ApiFehler(antwort.statusCode, pfad, antwort.body);
    }
    // `utf8.decode` von Hand: `antwort.body` rät die Kodierung aus dem
    // Content-Type, und wenn der keine nennt, wird daraus Latin-1 — dann
    // stehen in jeder Überschrift „Ã¼" statt „ü".
    final gelesen = jsonDecode(utf8.decode(antwort.bodyBytes));
    if (gelesen is! Map<String, dynamic>) {
      throw ApiFehler(200, pfad, 'kein Objekt zurückgekommen');
    }
    return gelesen;
  }

  /// Die Titelseite. `limit` ist gedeckelt auf 60 (Server), Vorgabe dort 24.
  ///
  /// `detail: true` liefert die Filterzahlen mit — für die App uninteressant,
  /// deshalb nicht gesetzt.
  Future<Titelseite> titelseite({int anzahl = 24}) async =>
      Titelseite.vonJson(await _holen('/api/frontpage', {
        'limit': '$anzahl',
        // Der Aufmacher bekommt Artikel mitgeliefert; die braucht der
        // Dreiklang (eine Überschrift je Lager). Ohne diesen Wert kämen vier,
        // und mit vier Artikeln aus vier Häusern ist die Chance klein, dass
        // alle drei Lager dabei sind.
        'lead_articles': '8',
      }));

  Future<Story> story(String id) async =>
      Story.vonJson(await _holen('/api/stories/$id'));

  Future<Artikel> artikel(String id) async =>
      Artikel.vonJson(await _holen('/api/articles/$id'));

  /// Alle Häuser, einmal geholt und behalten.
  ///
  /// Die Kacheln zeigen Häusernamen, die API liefert Kennungen wie `spiegel`.
  /// Ein Abruf je Kachel wäre absurd — die Liste ändert sich in Wochen nicht.
  Future<Map<String, Haus>> haeuser() async {
    final vorhanden = _haeuser;
    if (vorhanden != null) return vorhanden;
    final antwort = await _holen('/api/sources');
    final liste = (antwort['items'] ?? antwort['sources']) as List?;
    final karte = {
      for (final eintrag in liste?.whereType<Map>() ?? const <Map>[])
        (eintrag['id'] as String): Haus.vonJson(eintrag.cast<String, dynamic>()),
    };
    // Nur behalten, wenn wirklich etwas kam: eine leere Karte im Zwischen-
    // speicher wäre für den Rest der Sitzung „es gibt keine Häuser".
    if (karte.isNotEmpty) _haeuser = karte;
    return karte;
  }

  Map<String, Haus>? _haeuser;

  /// **Absichtlich nicht vorhanden: ein Weg über `/api/images/{id}`.**
  ///
  /// Er wäre naheliegend, weil ein Artikel `lead_image_id` trägt. Gemessen am
  /// 17.8.2026: die Route verlangt ein Token (ohne: 401) und antwortet dann
  /// mit `307` auf die Adresse **beim Verlag**. Dart entfernt beim Verfolgen
  /// einer Weiterleitung den `Authorization`-Kopf nicht — unser JWT ginge also
  /// an jedes Haus, dessen Bild jemand ansieht.
  ///
  /// Gebraucht wird die Route auch nicht: die Antworten tragen die
  /// Verlagsadresse schon (`images[].url`, bei den Kacheln `image`). Siehe
  /// `_aufmacherbild` in `modelle.dart`.

  /// Was darf dieses Gerät gerade sehen (`/api/stufe`)?
  ///
  /// Antwortet **auch ohne Token** — „Gast" ist die Antwort, nicht der Fehler.
  /// Dieselbe Route sagt außerdem, ob die geschlossene Beta läuft; ohne sie
  /// würde die App ihre Hinweise auf Stufen beziehen, die gerade nicht gelten.
  Future<({String stufe, bool angemeldet, bool abo, bool beta})> stufe() async {
    final antwort = await _holen('/api/stufe');
    return (
      stufe: antwort['stufe'] as String? ?? 'gast',
      angemeldet: antwort['angemeldet'] == true,
      abo: antwort['abo'] == true,
      beta: antwort['beta'] == true,
    );
  }

  void dispose() => _client.close();
}
