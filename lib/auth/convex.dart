/// Der Zugang zu Convex — über dessen HTTP-Schnittstelle, ohne SDK.
///
/// **Warum nicht `convex_flutter`**, obwohl es genau dafür gedacht ist: das
/// Paket (3.0.1, letzte Fassung vom 23.2.2026) baut seinen Rust-Kern über
/// *cargokit*, und dessen Gradle-Plugin ruft `Project.exec()` — eine Methode,
/// die **Gradle 9 entfernt hat**. Gemessen am 17.8.2026 mit Flutter 3.47 und
/// Gradle 9.3.1:
///
///     Execution failed for task ':convex_flutter:cargokitCargoBuildConvex_flutterDebug'
///     > Could not find method exec() for arguments […] on project ':convex_flutter'
///
/// Der Build bricht ab, bevor eine Zeile eigener Code übersetzt wird. Zwei Wege
/// standen offen: Gradle auf 8.x zurückdrehen — dann hängt die ganze App an
/// einem Paket mit veraltetem Build-System — oder die Schnittstelle direkt
/// benutzen. Sie ist der zweite Weg, und sie hat drei Vorteile, die bleiben:
///
/// * **Kein Rust im Bündel.** Für die Fassung ohne Google (A162) ist das nicht
///   Zierde: jedes native Stück ist eine Architektur mehr, die gebaut,
///   signiert und reproduzierbar gehalten werden muss.
/// * **Web läuft mit.** Derselbe Code, kein FFI-Sonderfall.
/// * **Nachvollziehbar.** Was hier passiert, ist ein POST mit JSON.
///
/// **Was fehlt:** Convex-Subscriptions, also live aktualisierte Abfragen über
/// dessen eigenen WebSocket. Gebraucht werden sie nicht — in Convex liegt nur
/// Identität (A148), und Konto, Rolle und Abo ändern sich nicht im Sekundentakt.
/// Der Live-Feed hängt an den Artikeln, und die liegen auf dem VPS.
///
/// Die Aufrufform ist am echten Deployment geprüft (17.8.2026): ein `signIn`
/// mit unbekannter Adresse kommt bis `retrieveAccount` durch und scheitert dort
/// mit `InvalidAccountId` — also stimmen Pfad, Argumente und Kodierung.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Convex hat geantwortet, aber mit einem Fehler.
class ConvexFehler implements Exception {
  const ConvexFehler(this.meldung, {this.status});

  /// Die Meldung von Convex, mit Stapel. Sie **wird nicht** einem Leser
  /// gezeigt — daraus deutet `Anmeldung._deuten` einen Satz, den man zeigen
  /// kann.
  final String meldung;

  /// HTTP-Status, falls es an der Übertragung lag.
  final int? status;

  @override
  String toString() => 'ConvexFehler${status == null ? '' : '($status)'}: '
      '$meldung';
}

/// Ein schmaler Convex-Client: Actions, Queries, Mutations.
class Convex {
  Convex({required this.deployment, http.Client? client})
      : _client = client ?? http.Client();

  /// Die `.convex.cloud`-Adresse des Deployments.
  final String deployment;

  final http.Client _client;

  /// Das Token, mit dem authentifizierte Aufrufe laufen. Wird von der
  /// `Anmeldung` gesetzt und ist hier absichtlich veränderbar: es wechselt alle
  /// 15 Minuten, und ein neuer Client je Erneuerung wäre eine neue Verbindung
  /// für dieselbe Sitzung.
  String? token;

  static const _frist = Duration(seconds: 20);

  Future<Object?> action(String pfad, [Map<String, dynamic> args = const {}]) =>
      _rufen('action', pfad, args);

  Future<Object?> query(String pfad, [Map<String, dynamic> args = const {}]) =>
      _rufen('query', pfad, args);

  Future<Object?> mutation(String pfad,
          [Map<String, dynamic> args = const {}]) =>
      _rufen('mutation', pfad, args);

  Future<Object?> _rufen(
    String art,
    String pfad,
    Map<String, dynamic> args,
  ) async {
    final ziel = Uri.parse('$deployment/api/$art');
    http.Response antwort;
    try {
      antwort = await _client
          .post(
            ziel,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            // `format: json` verlangt die einfache JSON-Darstellung. Ohne den
            // Wert antwortet Convex in seiner eigenen Kodierung, in der eine
            // Zahl als `{"$integer": "…"}` steht — richtig, aber hier unnötig
            // umzurechnen.
            body: jsonEncode({
              'path': pfad,
              'args': args,
              'format': 'json',
            }),
          )
          .timeout(_frist);
    } on Object catch (fehler) {
      throw ConvexFehler('$fehler');
    }

    if (antwort.statusCode != 200) {
      throw ConvexFehler(antwort.body, status: antwort.statusCode);
    }

    final gelesen = jsonDecode(utf8.decode(antwort.bodyBytes));
    if (gelesen is! Map) {
      throw ConvexFehler('unerwartete Antwort: $gelesen');
    }
    // Convex antwortet **mit HTTP 200 auch dann**, wenn die Funktion geworfen
    // hat — der Fehler steht im Rumpf. Wer nur den Status prüft, hält eine
    // gescheiterte Anmeldung für eine erfolgreiche.
    if (gelesen['status'] == 'error') {
      throw ConvexFehler(
        '${gelesen['errorMessage'] ?? gelesen['errorData'] ?? gelesen}',
      );
    }
    return gelesen['value'];
  }

  void dispose() => _client.close();
}
