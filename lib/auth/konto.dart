/// Die Anmeldung — gegen Convex, mit E-Mail und Passwort.
///
/// **Kein Google-Login, keine Selbstregistrierung.** Beides ist eine
/// ausdrückliche Ansage: Konten legt der Betreiber an (A152, die Sperre sitzt
/// in `frontend/convex/auth.ts` in `profile()` und greift bei jedem `signUp`,
/// egal woher er kommt — auch aus dieser App).
///
/// **Wie es abläuft**, geprüft am echten Deployment am 17.8.2026:
///
/// 1. Die App ruft die Convex-Action `auth:signIn` mit
///    `{provider: "password", params: {email, password, flow: "signIn"}}`.
/// 2. Zurück kommt `{tokens: {token, refreshToken}}`. `token` ist das JWT
///    (RS256, 15 Minuten), `refreshToken` hält die Sitzung (14 Tage).
/// 3. Das JWT geht als `Authorization: Bearer …` an `news.chuk.dev/api`, wo
///    `newsdb/auth.py` es gegen das JWKS des Deployments prüft.
///
/// Belegt ist der Ablauf über die Fehlerform: ein Aufruf mit unbekannter
/// Adresse kommt bis `retrieveAccount` und scheitert mit `InvalidAccountId` —
/// also ist alles davor (Pfad, Argumentform) richtig.
///
/// **Warum das JWT nur 15 Minuten gilt und wir es trotzdem nicht ständig
/// erneuern:** ein JWT ist ein Inhaberpapier, der Server kann es nicht
/// widerrufen. Die kurze Laufzeit ist der Preis dafür, dass ein Abmelden
/// spätestens nach 15 Minuten überall wirkt. Erneuert wird deshalb **vor** dem
/// Ablauf und nicht nach einem 401 — ein 401 mitten im Blättern wäre eine leere
/// Titelseite, obwohl alles in Ordnung ist.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/konfiguration.dart';
import 'convex.dart';

/// Was beim Anmelden schiefgehen kann — in der Form, in der es dem Leser
/// gesagt werden darf.
enum AnmeldeFehler {
  /// Adresse oder Passwort falsch. **Bewusst nicht unterschieden:** „diese
  /// Adresse kennen wir nicht" verrät, welche Adressen ein Konto haben.
  falsch,

  /// Convex bremst nach 8 Fehlversuchen je Konto und Stunde — danach wird auch
  /// das richtige Passwort abgewiesen. Ohne eigene Meldung sähe das aus wie
  /// „mein Passwort stimmt plötzlich nicht mehr".
  gebremst,

  /// Kein Netz, oder Convex nicht erreichbar.
  netz,

  /// Alles andere. Wird protokolliert, nicht ausgedeutet.
  unbekannt,
}

class AnmeldeAusnahme implements Exception {
  const AnmeldeAusnahme(this.art, [this.details]);

  final AnmeldeFehler art;
  final String? details;

  String get text => switch (art) {
        AnmeldeFehler.falsch => 'E-Mail oder Passwort stimmt nicht.',
        AnmeldeFehler.gebremst =>
          'Zu viele Versuche. Convex sperrt das Konto für eine Stunde — '
              'danach geht es wieder, auch mit dem richtigen Passwort.',
        AnmeldeFehler.netz => 'Keine Verbindung zur Anmeldung.',
        AnmeldeFehler.unbekannt => 'Die Anmeldung ist fehlgeschlagen.',
      };

  @override
  String toString() => 'AnmeldeAusnahme($art): $details';
}

/// Ein angemeldetes Konto, so wie es die App braucht.
@immutable
class Konto {
  const Konto({
    required this.token,
    required this.gueltigBis,
    this.email,
    this.rolle = 'user',
    this.abo = false,
  });

  /// Das JWT für `news.chuk.dev/api`.
  final String token;

  /// Wann das JWT abläuft — aus dem `exp`-Feld, nicht aus einer eigenen Uhr.
  final DateTime gueltigBis;

  final String? email;

  /// `admin` oder `user`. Steht als Claim im Token; der Leitstand ist in der
  /// App nicht gebaut, aber die Rolle entscheidet, was die API erlaubt.
  final String rolle;

  /// Läuft das Abo? Auch ein Claim. **Anzeige, nicht Schranke** — die sitzt in
  /// `newsdb/api.py` und ist von hier aus nicht zu beeinflussen.
  final bool abo;

  bool get istAdmin => rolle == 'admin';

  /// Läuft in weniger als einer Minute ab? Dann lieber vorher erneuern, als
  /// mitten in einem Abruf ungültig zu werden.
  bool get laeuftAb =>
      gueltigBis.difference(DateTime.now()) < const Duration(minutes: 1);
}

/// Hält die Anmeldung und erneuert sie.
///
/// Ein `ChangeNotifier` und kein Zustandspaket: die App hat genau einen
/// globalen Zustand, und der ist „angemeldet oder nicht". Dafür eine Bibliothek
/// einzuziehen wäre Aufwand ohne Gegenwert.
class Anmeldung extends ChangeNotifier {
  Anmeldung({FlutterSecureStorage? ablage})
      : _ablage = ablage ?? const FlutterSecureStorage();

  /// Der Refresh-Token liegt im Keystore (Android) beziehungsweise in der
  /// Keychain (iOS) — **nicht** in `shared_preferences`. Dort läge er im
  /// Klartext im App-Verzeichnis, und er ist 14 Tage lang eine ganze Sitzung.
  final FlutterSecureStorage _ablage;
  static const _schluessel = 'convex-refresh';

  Convex? _client;
  Konto? _konto;
  Timer? _erneuerung;

  Konto? get konto => _konto;
  bool get angemeldet => _konto != null;

  /// Der Client steht auch ohne Anmeldung — Convex braucht ihn für den
  /// `signIn`-Aufruf selbst.
  ///
  /// Kein SDK, sondern die HTTP-Schnittstelle von Convex — der Grund steht in
  /// `convex.dart`: das SDK ist mit Gradle 9 nicht baubar.
  Convex _clientHolen() =>
      _client ??= Convex(deployment: Adressen.convex);

  /// A259. Das im Konto gespeicherte Farbthema lesen (`light`/`dark`/`system`),
  /// oder null wenn nichts gespeichert ist oder niemand angemeldet ist. Nutzt
  /// den authentifizierten Convex-Client (`benutzer:aktuell`). Ein Fehler ist
  /// kein Drama — dann bleibt es bei der lokalen bzw. hellen Wahl.
  Future<String?> themaHolen() async {
    if (_konto == null) return null;
    try {
      final antwort = await _clientHolen().query('benutzer:aktuell');
      if (antwort is Map) return antwort['theme'] as String?;
    } on Object catch (fehler) {
      debugPrint('Thema holen: $fehler');
    }
    return null;
  }

  /// A259. Das Farbthema im Konto speichern, damit es dem Konto über Geräte
  /// folgt (`konto:themeSetzen`). Ohne Anmeldung ein No-op.
  Future<void> themaSpeichern(String thema) async {
    if (_konto == null) return;
    try {
      await _clientHolen().mutation('konto:themeSetzen', {'theme': thema});
    } on Object catch (fehler) {
      debugPrint('Thema speichern: $fehler');
    }
  }

  /// Beim Start: liegt ein Refresh-Token vor, wird daraus eine Sitzung
  /// wiederhergestellt.
  ///
  /// Schlägt das fehl, ist das **kein Fehlerfall** — die Sitzung war 14 Tage
  /// alt oder wurde abgemeldet. Dann einfach nicht angemeldet, ohne Meldung.
  Future<void> wiederherstellen() async {
    final gespeichert = await _ablage.read(key: _schluessel);
    if (gespeichert == null) return;
    try {
      await _tokenHolen({'refreshToken': gespeichert});
    } on Object catch (fehler) {
      debugPrint('Sitzung nicht wiederherstellbar: $fehler');
      await _ablage.delete(key: _schluessel);
    }
  }

  Future<void> anmelden({
    required String email,
    required String passwort,
  }) async {
    await _tokenHolen({
      'provider': 'password',
      'params': {
        'email': email.trim().toLowerCase(),
        'password': passwort,
        // Ausdrücklich `signIn`. Ein `signUp` würde von `profile()` in Convex
        // abgewiesen (A152) — aber es hier gar nicht erst zu senden ist die
        // ehrlichere Fassung derselben Entscheidung.
        'flow': 'signIn',
      },
    });
  }

  /// Der eine Aufruf, der beides macht: erste Anmeldung und Erneuerung.
  /// Convex nimmt für beides dieselbe Action, nur mit anderen Argumenten.
  Future<void> _tokenHolen(Map<String, dynamic> args) async {
    final client = _clientHolen();
    final Object? antwort;
    try {
      antwort = await client.action('auth:signIn', args);
    } on Object catch (fehler) {
      throw AnmeldeAusnahme(_deuten(fehler.toString()), fehler.toString());
    }

    final tokens = (antwort is Map ? antwort['tokens'] : null) as Map?;
    final token = tokens?['token'] as String?;
    if (token == null) {
      throw AnmeldeAusnahme(AnmeldeFehler.unbekannt, 'kein Token in $antwort');
    }

    final nutzlast = _jwtLesen(token);
    _konto = Konto(
      token: token,
      gueltigBis: DateTime.fromMillisecondsSinceEpoch(
        ((nutzlast['exp'] as num?)?.toInt() ?? 0) * 1000,
      ),
      email: nutzlast['email'] as String?,
      rolle: nutzlast['rolle'] as String? ?? 'user',
      abo: nutzlast['abo'] == true,
    );

    final refresh = tokens?['refreshToken'] as String?;
    if (refresh != null) await _ablage.write(key: _schluessel, value: refresh);

    client.token = token;
    _erneuerungPlanen();
    notifyListeners();
  }

  /// Rechtzeitig vorher erneuern: eine Minute vor Ablauf.
  ///
  /// Nicht beim 401 nachfassen — dann hätte der Leser einmal eine leere Seite
  /// gesehen, bevor die App merkt, dass nur das Token alt war.
  void _erneuerungPlanen() {
    _erneuerung?.cancel();
    final konto = _konto;
    if (konto == null) return;
    var frist = konto.gueltigBis.difference(DateTime.now()) -
        const Duration(minutes: 1);
    // Eine Uhr, die falsch geht, oder ein Token, das schon fast abgelaufen
    // ankommt: dann in 10 Sekunden erneuern statt in der Vergangenheit.
    if (frist < const Duration(seconds: 10)) {
      frist = const Duration(seconds: 10);
    }
    _erneuerung = Timer(frist, () async {
      final refresh = await _ablage.read(key: _schluessel);
      if (refresh == null) return;
      try {
        await _tokenHolen({'refreshToken': refresh});
      } on Object catch (fehler) {
        debugPrint('Erneuerung fehlgeschlagen: $fehler');
        await abmelden();
      }
    });
  }

  Future<void> abmelden() async {
    _erneuerung?.cancel();
    _erneuerung = null;
    try {
      final client = _clientHolen();
      // Erst bei Convex abmelden, **dann** lokal aufräumen: Convex löscht die
      // Sitzung, und nur das macht das Abmelden auch für die API wirksam
      // (`benutzer:sitzungAktiv`). Nur lokal zu vergessen hieße, dass das
      // Token weitere 15 Minuten gültig bleibt.
      await client.action('auth:signOut');
      client.token = null;
    } on Object catch (fehler) {
      debugPrint('Abmelden bei Convex fehlgeschlagen: $fehler');
    }
    await _ablage.delete(key: _schluessel);
    _konto = null;
    notifyListeners();
  }

  /// Ein gültiges Token für einen Abruf. Erneuert, wenn es knapp wird.
  Future<String?> tokenFuerAbruf() async {
    final konto = _konto;
    if (konto == null) return null;
    if (!konto.laeuftAb) return konto.token;
    final refresh = await _ablage.read(key: _schluessel);
    if (refresh == null) return konto.token;
    try {
      await _tokenHolen({'refreshToken': refresh});
    } on Object catch (fehler) {
      debugPrint('Erneuerung vor Abruf fehlgeschlagen: $fehler');
    }
    return _konto?.token;
  }

  /// Aus der Fehlermeldung von Convex das machen, was dem Leser hilft.
  ///
  /// Convex schickt bei einem Fehler in der Action den Stapel mit; darin stehen
  /// `InvalidAccountId` (Adresse unbekannt) und `InvalidSecret` (Passwort
  /// falsch). Beide werden hier **zusammengeworfen** — die Unterscheidung wäre
  /// eine Auskunft darüber, welche Adressen ein Konto haben.
  AnmeldeFehler _deuten(String meldung) {
    if (meldung.contains('InvalidAccountId') ||
        meldung.contains('InvalidSecret')) {
      return AnmeldeFehler.falsch;
    }
    if (meldung.contains('Too many failed attempts') ||
        meldung.contains('TooManyFailedAttempts')) {
      return AnmeldeFehler.gebremst;
    }
    if (meldung.contains('SocketException') ||
        meldung.contains('TimeoutException') ||
        meldung.contains('Failed host lookup')) {
      return AnmeldeFehler.netz;
    }
    return AnmeldeFehler.unbekannt;
  }

  /// Die Nutzlast eines JWT lesen — **ohne** Signaturprüfung, und das ist
  /// Absicht.
  ///
  /// Geprüft wird das Token dort, wo es etwas schützt: in `newsdb/auth.py`
  /// gegen das JWKS von Convex. Hier wird es nur ausgelesen, um `exp`, Rolle
  /// und Abo für die Anzeige zu kennen. Eine Prüfung im Client wäre
  /// Sicherheitstheater: wer die App verändern kann, verändert auch die
  /// Prüfung.
  Map<String, dynamic> _jwtLesen(String token) {
    final teile = token.split('.');
    if (teile.length < 2) return const {};
    var nutzlast = teile[1].replaceAll('-', '+').replaceAll('_', '/');
    // base64url ohne Füllzeichen — `base64.decode` verlangt sie aber.
    nutzlast = nutzlast.padRight((nutzlast.length + 3) & ~3, '=');
    try {
      final json = utf8.decode(base64.decode(nutzlast));
      final gelesen = jsonDecode(json);
      return gelesen is Map<String, dynamic> ? gelesen : const {};
    } on Object catch (fehler) {
      debugPrint('JWT nicht lesbar: $fehler');
      return const {};
    }
  }

  @override
  void dispose() {
    _erneuerung?.cancel();
    super.dispose();
  }
}
