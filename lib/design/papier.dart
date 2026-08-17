/// Die Papierstruktur unter dem Blatt.
///
/// Im Web ist das `body::before`: ein `radial-gradient` mit einem Punkt je
/// 4 × 4 Pixel, Deckkraft 4,5 % mal Ebenendeckkraft 50 %, also **2,25 %** in
/// der Tagesausgabe und 0,84 % in der Nachtausgabe. Das ist so wenig, dass man
/// es einzeln nicht sieht und im Ganzen sofort merkt, wenn es fehlt: es nimmt
/// der Flaeche das Digitale.
///
/// **Warum ein gekachelter Shader und keine gezeichneten Punkte:** ein Telefon
/// mit 412 × 900 logischen Pixeln braucht bei 4-px-Raster ueber **23.000**
/// Punkte. Als `drawCircle`-Schleife waeren das 23.000 Zeichenbefehle **je
/// Bild** — 60 mal je Sekunde, fuer eine Struktur, die sich nie aendert. Der
/// Shader ist ein einziger Befehl: ein 4 × 4 grosses Bild, einmal erzeugt,
/// endlos gekachelt.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Die Punktfarben, aus `index.css` umgerechnet (OKLCH → sRGB), Deckkraft
/// schon eingerechnet:
///
/// * hell: `oklch(0.5 0.02 70 / 0.045)` bei Ebenendeckkraft 0.5 → `#6b6157`
///   mit 2,25 %
/// * dunkel: `oklch(0.8 0.02 70 / 0.03)` bei 0.28 → `#c6bcb0` mit 0,84 %
const _punktHell = Color(0x066B6157);
const _punktDunkel = Color(0x02C6BCB0);

/// Kantenlaenge einer Kachel in logischen Pixeln (`background-size: 4px 4px`).
const _kachel = 4.0;

/// Die erzeugten Kacheln, je Farbe und Geraeteauflösung eine.
///
/// Der Zwischenspeicher ist noetig, weil `Image` asynchron entsteht und ein
/// `CustomPainter` synchron malt. Ohne ihn waere die Struktur bei jedem
/// Neuaufbau einen Bildlauf lang unsichtbar — und genau dieses Flackern faellt
/// auf, obwohl die Struktur selbst es nicht tut.
final Map<(Color, double), ui.Image> _kacheln = {};

/// Erzeugt die Kachel fuer eine Farbe und eine Geraeteauflösung.
///
/// Das Bild ist `4 * dpr` gross, nicht 4: auf einem Telefon mit dreifacher
/// Auflösung waere ein 4 × 4 grosses Bild auf 12 physische Pixel gestreckt, und
/// aus dem scharfen Punkt wuerde ein Fleck.
Future<ui.Image> _kachelBauen(Color farbe, double dpr) async {
  final kante = (_kachel * dpr).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // Der Punkt sitzt im CSS auf (1px, 1px) mit Radius 1px.
  canvas.drawCircle(
    Offset(1 * dpr, 1 * dpr),
    1 * dpr,
    Paint()..color = farbe,
  );
  final bild = await recorder.endRecording().toImage(kante, kante);
  return bild;
}

/// Legt die Papierstruktur unter ein Kind.
///
/// Bewusst **hinter** dem Inhalt und nicht darueber: im Web liegt
/// `body::before` bei `z-index: 0` mit `pointer-events: none`. Eine Ebene
/// darueber wuerde Bilder und Text ueberpudern.
class Papier extends StatefulWidget {
  const Papier({required this.child, super.key});

  final Widget child;

  @override
  State<Papier> createState() => _PapierState();
}

class _PapierState extends State<Papier> {
  ui.Image? _bild;
  (Color, double)? _schluessel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dunkel = Theme.of(context).brightness == Brightness.dark;
    final schluessel = (
      dunkel ? _punktDunkel : _punktHell,
      MediaQuery.devicePixelRatioOf(context),
    );
    if (schluessel == _schluessel) return;
    _schluessel = schluessel;

    final fertig = _kacheln[schluessel];
    if (fertig != null) {
      _bild = fertig;
      return;
    }
    _kachelBauen(schluessel.$1, schluessel.$2).then((bild) {
      _kacheln[schluessel] = bild;
      // Der Aufbau kann laenger dauern als das Widget lebt — wer hier ohne
      // Pruefung `setState` ruft, bekommt beim schnellen Zurueckblaettern eine
      // Ausnahme aus einem entsorgten Zustand.
      if (mounted && _schluessel == schluessel) setState(() => _bild = bild);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bild = _bild;
    return Stack(
      children: [
        if (bild != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _Struktur(bild, MediaQuery.devicePixelRatioOf(context)),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _Struktur extends CustomPainter {
  const _Struktur(this.kachel, this.dpr);

  final ui.Image kachel;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    // Die Kachel ist in physischen Pixeln gebaut, gemalt wird in logischen —
    // also zurueckskalieren, sonst waere das Raster auf einem hochauflösenden
    // Geraet dreimal zu grob.
    final matrix = Matrix4.diagonal3Values(1 / dpr, 1 / dpr, 1).storage;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ImageShader(
          kachel,
          TileMode.repeated,
          TileMode.repeated,
          matrix,
        ),
    );
  }

  @override
  bool shouldRepaint(_Struktur alt) =>
      alt.kachel != kachel || alt.dpr != dpr;
}
