/// Die beiden Gegenstellen, mit denen die App redet — und nur diese zwei.
///
/// Die Aufteilung ist die Regel aus A148: Convex für Identität, der VPS für
/// Inhalte. Beide Adressen sind **öffentlich** — sie stehen genauso im
/// gebauten Web-Bündel, weil ein Browser sie kennen muss. Deshalb dürfen sie
/// hier als Vorgabe stehen; ein Geheimnis wäre an dieser Stelle ohnehin keins,
/// weil jede App entpackbar ist.
///
/// Über `--dart-define` austauschbar, damit ein Testlauf gegen ein anderes
/// Deployment kein Codeänderung braucht:
///
/// ```bash
/// flutter run \
///   --dart-define=NEWSDB_API=https://news.chuk.dev \
///   --dart-define=CONVEX_URL=https://…convex.cloud
/// ```
library;

abstract final class Adressen {
  /// Die Python-API auf dem VPS. Alles Redaktionelle kommt von hier.
  ///
  /// Ohne `/api` am Ende: die Pfade in `client.dart` bringen es mit, und ein
  /// doppeltes `/api/api/` ist ein Fehler, den man erst am 404 sieht.
  static const api = String.fromEnvironment(
    'NEWSDB_API',
    defaultValue: 'https://news.chuk.dev',
  );

  /// Das Convex-Deployment. Konten, Sitzungen, Rollen, Abo.
  static const convex = String.fromEnvironment(
    'CONVEX_URL',
    defaultValue: 'https://necessary-mastiff-647.eu-west-1.convex.cloud',
  );

  /// Kennung dieses Clients gegenüber Convex. Landet in dessen Protokoll und
  /// ist der einzige Weg, später App-Zugriffe von Web-Zugriffen zu
  /// unterscheiden.
  static const clientId = 'newsdb-app';
}
