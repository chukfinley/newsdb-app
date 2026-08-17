/// Das Bild einer Kachel oder eines Artikels.
///
/// **Die Adressen zeigen zum Verlag, nicht zu uns** — genauso wie im Web
/// (`components/reader/image.tsx`). Deshalb braucht dieses Widget kein Token
/// und darf keins mitschicken: es würde ein Zugangstoken an einen Dritten
/// senden.
///
/// Scheitert das Laden — Hotlink-Sperre, tote Adresse —, bleibt eine ruhige
/// Fläche mit „kein Bild". Ein kaputtes Bildsymbol sieht wie ein Fehler der App
/// aus, obwohl der Verlag das Bild zurückgezogen hat.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design/thema.dart';
import '../design/typografie.dart';

class Bild extends StatelessWidget {
  const Bild({
    required this.adresse,
    required this.format,
    this.beschreibung,
    super.key,
  });

  final String? adresse;

  /// Seitenverhältnis, aus `Kachelrang.bildformat`.
  final double format;

  final String? beschreibung;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final leer = adresse == null || adresse!.isEmpty;

    return AspectRatio(
      aspectRatio: format,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Mass.rundung),
        child: ColoredBox(
          color: blatt.papierVertieft,
          child: leer
              ? _Leer(text: 'kein Bild')
              : CachedNetworkImage(
                  imageUrl: adresse!,
                  fit: BoxFit.cover,
                  // Kein Aufblitzen: die vertiefte Fläche steht schon dahinter,
                  // ein zweiter Platzhalter darüber wäre ein Wechsel von Grau
                  // auf Grau.
                  fadeInDuration: const Duration(milliseconds: 300),
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => _Leer(text: 'kein Bild'),
                ),
        ),
      ),
    );
  }
}

class _Leer extends StatelessWidget {
  const _Leer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Center(
      child: Text(
        text,
        style: Stil.kicker.copyWith(
          color: blatt.tinteBlass.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
