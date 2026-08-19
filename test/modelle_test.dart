/// Tests für das Lesen der API-Antworten.
///
/// Der Grund, warum es diese Tests gibt und nicht nur die Modelle: die API
/// beschneidet ihre Antworten **je Lesestufe** (A150). Dasselbe `/api/frontpage`
/// liefert einem Gast andere Felder als einem Abonnenten, und die Ansicht darf
/// in keinem der drei Fälle abstürzen. Genau das wird hier geprüft, mit den
/// Antwortformen aus `news/frontend/src/lib/types.ts`.
///
/// Der zweite Block prüft die Zusammenfassung von fünf Stufen auf drei Lager.
/// Sie steht an drei Stellen — `newsdb/bias.py`, `components/bias.tsx` und hier
/// — und wenn eine davon abweicht, zeigt die App andere Anteile als der Server
/// berechnet. Das würde niemandem auffallen, weil beide plausibel aussehen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:newsdb_app/api/modelle.dart';
import 'package:newsdb_app/design/thema.dart';
import 'package:newsdb_app/widgets/lagerspiegel.dart';

void main() {
  group('Kachel je Lesestufe', () {
    /// Was ein **Gast** bekommt: Überschrift, Balken, Häuserzahl, Zeitpunkt.
    /// Kein Anriss, kein Blindspot, keine Artikel.
    const gast = {
      'id': 's1',
      'title': 'Der Bundestag streitet über den Haushalt',
      'score': 12.5,
      'n_sources': 12,
      'n_articles': 19,
      'sources': ['spiegel', 'welt'],
      'last_published': '2026-08-17T14:20:00Z',
      'image': null,
      'frontpage_share': 0.4,
      'bias_spread': {'left': 4, 'center': 6, 'right': 2},
      'articles': <Map<String, dynamic>>[],
    };

    test('Gast: fehlende Felder brechen nichts', () {
      final kachel = Kachel.vonJson(gast);
      expect(kachel.id, 's1');
      expect(kachel.anzahlHaeuser, 12);
      expect(kachel.anriss, isNull);
      expect(kachel.blindspot, isEmpty);
      expect(kachel.artikel, isEmpty);
      expect(kachel.bild, isNull);
      expect(kachel.zuletzt, isNotNull);
    });

    test('Konto: Anriss samt Quelle wird gelesen', () {
      final kachel = Kachel.vonJson({
        ...gast,
        'anriss': 'Die Koalition hat sich in der Nacht geeinigt',
        'anriss_gekuerzt': true,
        'anriss_quelle': 'Der Spiegel',
        'articles': [
          {'id': 'a1', 'title': 'Einigung in der Nacht', 'source_id': 'spiegel'},
        ],
      });
      expect(kachel.anriss, startsWith('Die Koalition'));
      expect(kachel.anrissGekuerzt, isTrue);
      expect(kachel.anrissQuelle, 'Der Spiegel');
      expect(kachel.artikel.single.hausId, 'spiegel');
    });

    test('Abo: Blindspot kommt als verschachtelte Liste', () {
      final kachel = Kachel.vonJson({
        ...gast,
        'blindspot': {
          'for': ['right'],
          'absent': ['right'],
          'low_factuality_share': 0.0,
        },
      });
      expect(kachel.blindspot, ['right']);
    });

    test('blindspot: null ist erlaubt und heißt „keiner"', () {
      final kachel = Kachel.vonJson({...gast, 'blindspot': null});
      expect(kachel.blindspot, isEmpty);
    });

    test('Zeitangaben: null, leer und Unsinn ergeben null statt Ausnahme', () {
      for (final wert in [null, '', 'gestern', 42]) {
        final kachel = Kachel.vonJson({...gast, 'last_published': wert});
        expect(kachel.zuletzt, isNull, reason: 'bei $wert');
      }
    });
  });

  group('Artikel je Lesestufe', () {
    const grund = {
      'schema_version': 1,
      'id': 'a1',
      'source_id': 'heise',
      'domain': 'heise.de',
      'url': 'https://heise.de/x',
      'canonical_url': 'https://heise.de/x',
      'title': 'Ein Test',
      'section': null,
      'published_at': null,
      'lead_image_id': null,
      'paywall': 'none',
      'truncated': false,
      'word_count': 420,
      'reading_seconds': 110,
      'extractor': 'generic',
      'quality': 0.9,
      'http_status': 200,
      'language': 'de',
      'modified_at': null,
      'fetched_at': null,
      'source_name': 'heise online',
    };

    test('ohne Text: `lesbar` ist null, nicht leer', () {
      expect(Artikel.vonJson(grund).lesbar, isNull);
    });

    test('Reihenfolge: Volltext schlägt Anriss schlägt Zusammenfassung', () {
      expect(
        Artikel.vonJson({
          ...grund,
          'text': 'ganz',
          'text_anriss': 'anfang',
          'ai_summary': 'kurz',
        }).lesbar,
        'ganz',
      );
      expect(
        Artikel.vonJson({...grund, 'text_anriss': 'anfang', 'ai_summary': 'kurz'})
            .lesbar,
        'anfang',
      );
      expect(Artikel.vonJson({...grund, 'ai_summary': 'kurz'}).lesbar, 'kurz');
    });

    test('`truncated` kommt als bool **und** als 0/1', () {
      expect(Artikel.vonJson({...grund, 'truncated': 1}).abgeschnitten, isTrue);
      expect(Artikel.vonJson({...grund, 'truncated': 0}).abgeschnitten, isFalse);
      expect(
        Artikel.vonJson({...grund, 'truncated': true}).abgeschnitten,
        isTrue,
      );
    });

    test('Schranke: unbekannte Werte gelten als unbekannt, nicht als „keine"',
        () {
      expect(Artikel.vonJson({...grund, 'paywall': 'none'}).schranke,
          Schranke.keine);
      expect(Artikel.vonJson({...grund, 'paywall': 'hard'}).schranke,
          Schranke.hart);
      expect(Artikel.vonJson({...grund, 'paywall': 'quatsch'}).schranke,
          Schranke.unbekannt);
      // Die Unterscheidung entscheidet, ob die App „Anriss, kein Artikel"
      // schreibt oder „weiter mit Abo" — zwei verschiedene Aussagen.
      expect(Schranke.unbekannt.gesperrt, isFalse);
      expect(Schranke.gezaehlt.gesperrt, isTrue);
    });

    test('Aufmacherbild kommt aus images[].url, nie aus lead_image_id', () {
      // Der Fallstrick, gemessen am 17.8.2026 an einem echten Artikel:
      // `lead_image_id` ist eine Kennung, keine Adresse. Wer sie an ein
      // Bild-Widget gibt, bekommt stumm „kein Bild".
      final a = Artikel.vonJson({
        ...grund,
        'lead_image_id': 'ea1ba24c1c7171b5af644af6',
        'images': [
          {'id': 'zzz', 'role': 'inline', 'url': 'https://haus.de/klein.jpg'},
          {
            'id': 'ea1ba24c1c7171b5af644af6',
            'role': 'lead',
            'url': 'https://haus.de/gross.jpg',
          },
        ],
      });
      expect(a.bild, 'https://haus.de/gross.jpg');
    });

    test('ohne images bleibt die Kennung draussen', () {
      final a = Artikel.vonJson({...grund, 'lead_image_id': 'abc123'});
      // Lieber kein Bild als eine Kennung, die als Adresse ins Netz geht.
      expect(a.bild, isNull);
    });

    test('der Listenweg liefert lead_image als fertige Adresse', () {
      final a =
          Artikel.vonJson({...grund, 'lead_image': 'https://haus.de/t.jpg'});
      expect(a.bild, 'https://haus.de/t.jpg');
    });

    test('mehrDahinter unterscheidet Lesestufe von Bezahlschranke', () {
      // Volltext da: nichts dahinter, egal was `truncated` sagt.
      expect(
        Artikel.vonJson({...grund, 'text': 'alles', 'truncated': true})
            .mehrDahinter,
        isFalse,
      );
      // Nur Anriss, und die Stufe hat gekürzt.
      expect(
        Artikel.vonJson({...grund, 'text_anriss': 'x', 'text_gekuerzt': true})
            .mehrDahinter,
        isTrue,
      );
    });
  });

  group('Fünf Stufen zu drei Lagern — identisch zu newsdb/bias.py', () {
    test('mitte-links zählt zu links, mitte-rechts zu rechts', () {
      expect(Blatt.lagerVon('left'), 'left');
      expect(Blatt.lagerVon('center-left'), 'left');
      expect(Blatt.lagerVon('center'), 'center');
      expect(Blatt.lagerVon('center-right'), 'right');
      expect(Blatt.lagerVon('right'), 'right');
    });

    test('ohne Einordnung ist kein Lager — auch nicht die Mitte', () {
      expect(Blatt.lagerVon(null), isNull);
      expect(Blatt.lagerVon('unknown'), isNull);
      expect(Blatt.lagerVon(''), isNull);
    });

    test('Verteilung addiert die Stufen und lässt Unbekanntes draußen', () {
      final v = lagerVerteilung({
        'left': 2,
        'center-left': 3,
        'center': 1,
        'center-right': 4,
        'right': 5,
        'unknown': 9,
      });
      expect(v['left'], 5);
      expect(v['center'], 1);
      expect(v['right'], 9);
      // Die 9 unbekannten sind nirgends eingerechnet: sie würden sonst ein
      // Lager aufblähen, in dem sie nicht stehen.
      expect(v.values.reduce((a, b) => a + b), 15);
    });

    test('fehlende Lager: eines fehlt', () {
      expect(fehlendeLager({'left': 3, 'center': 1}), ['right']);
    });

    test('fehlen alle drei, wird keines gemeldet', () {
      // Nichts eingeordnet heißt fehlendes Wissen über die Häuser, nicht eine
      // Lücke im Spektrum. Ein Blindspot-Hinweis wäre hier eine Behauptung.
      expect(fehlendeLager({'unknown': 12}), isEmpty);
      expect(fehlendeLager(const {}), isEmpty);
      expect(fehlendeLager(null), isEmpty);
    });

    test('Nullwerte gelten als nicht vorhanden', () {
      expect(fehlendeLager({'left': 3, 'center': 0, 'right': 2}), ['center']);
    });
  });

  group('Artikel-Bausteine (blocks)', () {
    test('Block-Arten werden aus der API-Kennung gelesen', () {
      const grund = {
        'id': 'a1', 'source_id': 'x', 'title': 'T', 'paywall': 'none',
        'section': null, 'published_at': null, 'lead_image_id': null,
        'truncated': false, 'word_count': 1,
      };
      final a = Artikel.vonJson({
        ...grund,
        'images': [
          {'id': 'img1', 'url': 'https://haus.de/1.jpg'},
        ],
        'blocks': [
          {'type': 'heading', 'level': 2, 'text': 'Zwischentitel'},
          {'type': 'paragraph', 'text': 'Ein Absatz.'},
          {'type': 'image', 'image_id': 'img1', 'text': 'Bildunterschrift'},
          {'type': 'list', 'items': ['eins', 'zwei']},
          {'type': 'quote', 'text': 'Ein Zitat.'},
          {'type': 'zapf', 'text': 'unbekannter Typ'},
        ],
      });
      expect(a.bloecke, hasLength(6));
      expect(a.bloecke[0].art, Blockart.ueberschrift);
      expect(a.bloecke[0].stufe, 2);
      expect(a.bloecke[1].art, Blockart.absatz);
      expect(a.bloecke[2].art, Blockart.bild);
      expect(a.bloecke[3].punkte, ['eins', 'zwei']);
      expect(a.bloecke[4].art, Blockart.zitat);
      // Unbekannter Typ bricht nichts, wird zu `unbekannt`.
      expect(a.bloecke[5].art, Blockart.unbekannt);
    });

    test('Bild-Blocks lösen ihre Kennung über die Bilder-Map auf', () {
      final a = Artikel.vonJson({
        'id': 'a1', 'source_id': 'x', 'title': 'T', 'paywall': 'none',
        'section': null, 'published_at': null, 'lead_image_id': null,
        'truncated': false, 'word_count': 1,
        'images': [
          {'id': 'abc', 'url': 'https://haus.de/gross.jpg'},
        ],
        'blocks': [
          {'type': 'image', 'image_id': 'abc'},
        ],
      });
      // Die Kennung ist im Block, die Adresse in der Map — nie über /api/images.
      expect(a.bloecke.single.bildId, 'abc');
      expect(a.bilder['abc'], 'https://haus.de/gross.jpg');
    });

    test('ohne blocks bleibt die Liste leer, Fließtext trägt', () {
      final a = Artikel.vonJson({
        'id': 'a1', 'source_id': 'x', 'title': 'T', 'paywall': 'none',
        'section': null, 'published_at': null, 'lead_image_id': null,
        'truncated': false, 'word_count': 1, 'text': 'Nur Fließtext.',
      });
      expect(a.bloecke, isEmpty);
      expect(a.lesbar, 'Nur Fließtext.');
    });
  });
}
