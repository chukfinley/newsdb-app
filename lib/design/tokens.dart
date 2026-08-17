// ACHTUNG: erzeugt von tools/farben.py aus der Web-Oberflaeche.
// Nicht von Hand aendern — der naechste Lauf ueberschreibt es.
// Quelle: news/frontend/src/index.css (OKLCH), umgerechnet nach sRGB.
//
// Warum ueberhaupt Konstanten und kein OKLCH zur Laufzeit: Flutter
// rechnet in sRGB, und die Tokens sind fest. Eine Umrechnung bei jedem
// Aufbau kostet Rechenzeit fuer ein Ergebnis, das sich nie aendert.

import 'dart:ui';

/// Die Tokens der Tagesausgabe.
abstract final class TokensHell {
  static const paper = Color(0xFFFBF9F5);
  static const paperRaised = Color(0xFFFFFFFF);
  static const paperSunken = Color(0xFFF3F1EC);
  static const ink = Color(0xFF18130E);
  static const inkMuted = Color(0xFF645C56);
  static const inkFaint = Color(0xFF8F8882);
  static const rule = Color(0xFFDCD8D3);
  static const ruleStrong = Color(0xFFBCB6B1);
  static const accent = Color(0xFFB51F1F);
  static const accentSoft = Color(0xFFFFE4DF);
  static const link = Color(0xFF0E4F86);
  static const ok = Color(0xFF007E46);
  static const warn = Color(0xFFB37903);
  static const bad = Color(0xFFC2272D);
  static const insBg = Color(0xFFC8F6D0);
  static const insFg = Color(0xFF00411A);
  static const delBg = Color(0xFFFFDFDA);
  static const delFg = Color(0xFF902828);
  static const biasLeft = Color(0xFFC1133A);
  static const biasCenterLeft = Color(0xFFDB6C67);
  static const biasCenter = Color(0xFFA39E92);
  static const biasCenterRight = Color(0xFF5590CC);
  static const biasRight = Color(0xFF1F58B6);
  static const biasUnknown = Color(0xFFBFBEBA);
  static const campLeft = Color(0xFFC1133A);
  static const campCenter = Color(0xFFA39E92);
  static const campRight = Color(0xFF1F58B6);
  static const onCampCenter = Color(0xFF1A1511);
}

/// Die Tokens der Nachtausgabe.
abstract final class TokensDunkel {
  static const paper = Color(0xFF100D0A);
  static const paperRaised = Color(0xFF1A1713);
  static const paperSunken = Color(0xFF0A0805);
  static const ink = Color(0xFFEAE7E2);
  static const inkMuted = Color(0xFFA29E98);
  static const inkFaint = Color(0xFF78746E);
  static const rule = Color(0xFF2E2B27);
  static const ruleStrong = Color(0xFF4B4742);
  static const accent = Color(0xFFEA6B5E);
  static const accentSoft = Color(0xFF421C18);
  static const link = Color(0xFF80B7E7);
  static const ok = Color(0xFF4EBE7D);
  static const warn = Color(0xFFE3AD4B);
  static const bad = Color(0xFFEF6661);
  static const insBg = Color(0xFF003C1D);
  static const insFg = Color(0xFF8DE9AE);
  static const delBg = Color(0xFF551918);
  static const delFg = Color(0xFFFFB4AD);
  static const biasLeft = Color(0xFFE94E5A);
  static const biasCenterLeft = Color(0xFFEE857C);
  static const biasCenter = Color(0xFF9C988C);
  static const biasCenterRight = Color(0xFF70AAE0);
  static const biasRight = Color(0xFF427FD8);
  static const biasUnknown = Color(0xFF565552);
  static const campLeft = Color(0xFFE94E5A);
  static const campCenter = Color(0xFF9C988C);
  static const campRight = Color(0xFF427FD8);
  static const onCampCenter = Color(0xFF1A1511);
}
