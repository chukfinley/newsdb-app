/// „vor 20 Minuten" — die Zeitangabe der Metazeile.
///
/// Warum von Hand und nicht mit `intl`: `Intl` kann Datumsformate, aber keine
/// deutschen Relativangaben in der Form, die ein Blatt benutzt. Und die Grenzen
/// sind eine redaktionelle Entscheidung, keine technische: eine Meldung von
/// vorgestern bekommt ein Datum, keine „vor 41 Stunden" — diese Zahl kann
/// niemand einordnen.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/thema.dart';
import '../design/typografie.dart';

/// Die Zeitangabe als Text.
String zeitText(DateTime? wann, {DateTime? jetzt}) {
  if (wann == null) return '';
  final bezug = jetzt ?? DateTime.now();
  final alter = bezug.difference(wann);

  // Zukunft. Kommt vor: manche Häuser datieren vor, und `zukunft_im_bestand`
  // in `/api/frontpage` zählt genau das. Eine Meldung „in 3 Stunden" wäre
  // richtig gerechnet und trotzdem Unsinn auf einer Titelseite.
  if (alter.isNegative) return 'gerade eben';

  if (alter.inMinutes < 1) return 'gerade eben';
  if (alter.inMinutes < 60) return 'vor ${alter.inMinutes} Minuten';
  if (alter.inHours < 24) {
    final h = alter.inHours;
    return h == 1 ? 'vor einer Stunde' : 'vor $h Stunden';
  }
  if (alter.inDays == 1) return 'gestern';
  // Ab hier das Datum. Bis eine Woche mit Wochentag, danach nur Datum — der
  // Wochentag hilft beim Einordnen, solange er in der eigenen Woche liegt.
  if (alter.inDays < 7) return DateFormat('EEEE, HH:mm', 'de').format(wann);
  if (wann.year == bezug.year) return DateFormat('d. MMMM', 'de').format(wann);
  return DateFormat('d. MMMM yyyy', 'de').format(wann);
}

/// Die Zeitangabe in der Metazeile.
class Zeit extends StatelessWidget {
  const Zeit(this.wann, {this.stil, super.key});

  final DateTime? wann;
  final TextStyle? stil;

  @override
  Widget build(BuildContext context) {
    if (wann == null) return const SizedBox.shrink();
    final blatt = Blatt.of(context);
    return Text(
      zeitText(wann),
      style: stil ?? Stil.meta.copyWith(color: blatt.tinteGedaempft),
    );
  }
}
