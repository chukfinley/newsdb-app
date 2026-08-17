#!/usr/bin/env python3
"""Die Farbtokens der Web-Oberflaeche nach Dart uebersetzen.

Warum ein Werkzeug und nicht abgetippte Hex-Werte: die Wahrheit ueber das
Design steht in `frontend/src/index.css` im news-Repo, in OKLCH. Wer die Werte
von Hand nach Hex traegt, hat beim naechsten Feinschliff am Web zwei Designs —
und der Unterschied faellt erst auf, wenn App und Webseite nebeneinander
liegen. Also: einmal parsen, exakt rechnen, Dart erzeugen.

OKLCH ist nicht optional huebsch, sondern der Grund, warum die Grautoene des
Blattes warm wirken: `--paper` ist `oklch(0.982 0.005 85)`, also ein Weiss mit
0,5 % Chroma bei Farbton 85. In Hex ist das #fdfcf9 — ein Wert, den niemand
raet.

Aufruf:
    uv run --project . tools/farben.py ../news/frontend/src/index.css
    python3 tools/farben.py ../news/frontend/src/index.css --pruefe
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------- Farbmathe
# Die Matrizen sind die von Bjoern Ottosson veroeffentlichten Koeffizienten
# (OKLab, 2020). Sie stehen hier ausgeschrieben und nicht in einer Bibliothek,
# weil das Projekt sonst eine Abhaengigkeit fuer neunzehn Zahlen einzieht.

# OKLab -> LMS' (nichtlinear, danach kubiert)
_LMS_VON_LAB = (
    (1.0, 0.3963377774, 0.2158037573),
    (1.0, -0.1055613458, -0.0638541728),
    (1.0, -0.0894841775, -1.2914855480),
)

# LMS -> lineares sRGB
_RGB_VON_LMS = (
    (4.0767416621, -3.3077115913, 0.2309699292),
    (-1.2684380046, 2.6097574011, -0.3413193965),
    (-0.0041960863, -0.7034186147, 1.7076147010),
)

# lineares sRGB -> LMS, und LMS' -> OKLab. Nur fuer die Gegenprobe (Rueckweg).
_LMS_VON_RGB = (
    (0.4122214708, 0.5363325363, 0.0514459929),
    (0.2119034982, 0.6806995451, 0.1073969566),
    (0.0883024619, 0.2817188376, 0.6299787005),
)
_LAB_VON_LMS = (
    (0.2104542553, 0.7936177850, -0.0040720468),
    (1.9779984951, -2.4285922050, 0.4505937099),
    (0.0259040371, 0.7827717662, -0.8086757660),
)


def _mal(m: tuple[tuple[float, ...], ...], v: tuple[float, float, float]) -> tuple[float, float, float]:
    return tuple(sum(z[i] * v[i] for i in range(3)) for z in m)  # type: ignore[return-value]


def _gamma(kanal: float) -> float:
    """Lineares sRGB -> sRGB. Die Uebertragungsfunktion, nicht 1/2.2 —
    der lineare Fuss unter 0,0031308 ist genau der Bereich, in dem die
    Tiefschwarztoene der Nachtausgabe liegen (`--paper-sunken` bei L=0,135)."""
    if kanal <= 0.0031308:
        return 12.92 * kanal
    return 1.055 * kanal ** (1 / 2.4) - 0.055


def _entgamma(kanal: float) -> float:
    if kanal <= 0.04045:
        return kanal / 12.92
    return ((kanal + 0.055) / 1.055) ** 2.4


def oklch_nach_srgb(L: float, C: float, H: float) -> tuple[tuple[int, int, int], bool]:
    """OKLCH -> 8-Bit-sRGB. Zweiter Rueckgabewert: lag die Farbe ausserhalb
    des sRGB-Raums?

    Ausserhalb wird **geklemmt und gemeldet**, nicht still verbogen. Ein
    Gamut-Mapping (Chroma reduzieren, bis es passt) waere die schoenere Loesung,
    aber es verschiebt die Farbe gegenueber dem Browser — und der Browser ist
    hier die Vorlage. Wer eine Meldung sieht, aendert lieber das Token.
    """
    a = C * math.cos(math.radians(H))
    b = C * math.sin(math.radians(H))
    lms_ = _mal(_LMS_VON_LAB, (L, a, b))
    lms = tuple(k**3 for k in lms_)
    linear = _mal(_RGB_VON_LMS, lms)  # type: ignore[arg-type]
    ausserhalb = any(k < -1e-6 or k > 1 + 1e-6 for k in linear)
    kanaele = []
    for k in linear:
        k = min(1.0, max(0.0, k))
        kanaele.append(round(_gamma(k) * 255))
    return (kanaele[0], kanaele[1], kanaele[2]), ausserhalb


def srgb_nach_oklch(r: int, g: int, b: int) -> tuple[float, float, float]:
    """Der Rueckweg — ausschliesslich fuer die Selbstprobe. Ohne ihn ist die
    Umrechnung eine Behauptung: neunzehn Koeffizienten, von denen ein
    Vorzeichen falsch sein kann, ohne dass das Ergebnis auffaellig aussieht."""
    linear = tuple(_entgamma(k / 255) for k in (r, g, b))
    lms = _mal(_LMS_VON_RGB, linear)  # type: ignore[arg-type]
    lms_ = tuple(math.copysign(abs(k) ** (1 / 3), k) for k in lms)
    L, a, bb = _mal(_LAB_VON_LMS, lms_)  # type: ignore[arg-type]
    C = math.hypot(a, bb)
    H = math.degrees(math.atan2(bb, a)) % 360
    return L, C, H


# ------------------------------------------------------------------ Parser
# Nur die Formen, die im Blatt wirklich vorkommen:
#   oklch(0.982 0.005 85)
#   oklch(0.5 0.02 70 / 0.045)
#   var(--bias-left)
_OKLCH = re.compile(
    r"oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*(?:/\s*([\d.]+)\s*)?\)"
)
_VAR = re.compile(r"var\(--([a-z0-9-]+)\)")
_ZUWEISUNG = re.compile(r"^\s*--([a-z0-9-]+)\s*:\s*(.+?)\s*;", re.MULTILINE)


def bloecke(css: str) -> dict[str, dict[str, str]]:
    """Die beiden Themes aus dem CSS holen: `:root` ist hell, `.dark` dunkel.

    Bewusst kein CSS-Parser als Abhaengigkeit. Gesucht sind zwei Bloecke mit
    flachen Zuweisungen; ein vollstaendiger Parser loeste ein Problem, das die
    Datei nicht hat.
    """
    ergebnis: dict[str, dict[str, str]] = {}
    for name, muster in (("hell", r":root\s*\{"), ("dunkel", r"\.dark\s*\{")):
        start = re.search(muster, css)
        if not start:
            raise SystemExit(f"Block fuer {name} nicht gefunden — hat sich index.css geaendert?")
        # Bis zur passenden schliessenden Klammer zaehlen: der Block enthaelt
        # selbst keine, aber `@theme inline` dahinter schon.
        tiefe, i = 1, start.end()
        while i < len(css) and tiefe:
            tiefe += (css[i] == "{") - (css[i] == "}")
            i += 1
        ergebnis[name] = dict(_ZUWEISUNG.findall(css[start.end() : i - 1]))
    return ergebnis


def aufloesen(wert: str, tokens: dict[str, str], tiefe: int = 0) -> str:
    """`var(--bias-left)` verfolgen. Die Lager-Aliasse (`--camp-left`) zeigen
    auf die Stufen, und die Stufen unterscheiden sich je Theme."""
    if tiefe > 8:
        raise SystemExit(f"Ringschluss in den Tokens bei: {wert}")
    treffer = _VAR.search(wert)
    if not treffer:
        return wert
    ziel = tokens.get(treffer.group(1))
    if ziel is None:
        raise SystemExit(f"Token --{treffer.group(1)} nicht gefunden")
    return aufloesen(_VAR.sub(ziel, wert, count=1), tokens, tiefe + 1)


def nach_dart(wert: str) -> str | None:
    """Ein aufgeloester Tokenwert als Dart-Farbliteral, oder None wenn es
    keine Farbe ist (`--radius: 0.3rem`)."""
    treffer = _OKLCH.search(wert)
    if not treffer:
        return None
    L, C, H = (float(treffer.group(i)) for i in (1, 2, 3))
    alpha = float(treffer.group(4)) if treffer.group(4) else 1.0
    (r, g, b), ausserhalb = oklch_nach_srgb(L, C, H)
    if ausserhalb:
        print(f"  Hinweis: oklch({L} {C} {H}) liegt ausserhalb sRGB, geklemmt "
              f"auf #{r:02x}{g:02x}{b:02x}", file=sys.stderr)
    a = round(alpha * 255)
    return f"Color(0x{a:02X}{r:02X}{g:02X}{b:02X})"


def dart_name(token: str) -> str:
    """`--paper-raised` -> `paperRaised`. Dart schreibt camelCase, und `lints`
    beschwert sich sonst bei jedem Feld."""
    kopf, *rest = token.split("-")
    return kopf + "".join(t.capitalize() for t in rest)


def erzeuge(css_pfad: Path) -> str:
    css = css_pfad.read_text(encoding="utf-8")
    themes = bloecke(css)
    zeilen = [
        "// ACHTUNG: erzeugt von tools/farben.py aus der Web-Oberflaeche.",
        "// Nicht von Hand aendern — der naechste Lauf ueberschreibt es.",
        "// Quelle: news/frontend/src/index.css (OKLCH), umgerechnet nach sRGB.",
        "//",
        "// Warum ueberhaupt Konstanten und kein OKLCH zur Laufzeit: Flutter",
        "// rechnet in sRGB, und die Tokens sind fest. Eine Umrechnung bei jedem",
        "// Aufbau kostet Rechenzeit fuer ein Ergebnis, das sich nie aendert.",
        "",
        "import 'dart:ui';",
        "",
    ]
    for theme, tokens in themes.items():
        klasse = "Hell" if theme == "hell" else "Dunkel"
        zeilen += [
            f"/// Die Tokens der {'Tagesausgabe' if theme == 'hell' else 'Nachtausgabe'}.",
            f"abstract final class Tokens{klasse} {{",
        ]
        for token, roh in tokens.items():
            farbe = nach_dart(aufloesen(roh, tokens))
            if farbe is None:
                continue
            zeilen.append(f"  static const {dart_name(token)} = {farbe};")
        zeilen += ["}", ""]
    return "\n".join(zeilen)


def selbstprobe() -> int:
    """Rechnet die Umrechnung gegen sich selbst und gegen bekannte Werte.

    Ohne diese Probe waere die Datei neunzehn Koeffizienten Vertrauen.
    """
    fehler = 0
    for name, (L, C, H), erwartet in (
        ("Weiss", (1.0, 0.0, 0.0), (255, 255, 255)),
        ("Schwarz", (0.0, 0.0, 0.0), (0, 0, 0)),
        # Mittelgrau: oklch(0.5 0 0) ist per Definition unbunt, also muessen
        # alle drei Kanaele gleich sein — das prueft die Matrizen gegeneinander.
        ("Grau", (0.5, 0.0, 0.0), None),
    ):
        (r, g, b), _ = oklch_nach_srgb(L, C, H)
        if erwartet and (r, g, b) != erwartet:
            print(f"FEHLER {name}: {(r, g, b)} statt {erwartet}")
            fehler += 1
        elif erwartet is None and not (r == g == b):
            print(f"FEHLER {name}: unbunt erwartet, bekam {(r, g, b)}")
            fehler += 1

    # Rundlauf ueber das ganze Gitter: jede Farbe hin und zurueck. Ein
    # verdrehtes Vorzeichen faellt hier auf, ein huebsch aussehender Farbstich
    # nicht.
    schlimmster = 0.0
    for r in range(0, 256, 17):
        for g in range(0, 256, 17):
            for b in range(0, 256, 17):
                L, C, H = srgb_nach_oklch(r, g, b)
                (r2, g2, b2), _ = oklch_nach_srgb(L, C, H)
                schlimmster = max(schlimmster, abs(r - r2), abs(g - g2), abs(b - b2))
    if schlimmster > 1:
        print(f"FEHLER Rundlauf: groesste Abweichung {schlimmster} Stufen")
        fehler += 1
    else:
        print(f"Rundlauf ueber 4.096 Farben: groesste Abweichung "
              f"{schlimmster:.0f} von 255 Stufen")
    print("Selbstprobe bestanden" if not fehler else f"{fehler} Fehler")
    return fehler


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("css", nargs="?", type=Path,
                   default=Path("../news/frontend/src/index.css"))
    p.add_argument("--ziel", type=Path, default=Path("lib/design/tokens.dart"))
    p.add_argument("--pruefe", action="store_true",
                   help="nur die Selbstprobe fahren, nichts schreiben")
    args = p.parse_args()

    if args.pruefe:
        return 1 if selbstprobe() else 0

    if not args.css.exists():
        print(f"index.css nicht gefunden: {args.css}", file=sys.stderr)
        return 1
    if selbstprobe():
        return 1
    text = erzeuge(args.css)
    args.ziel.parent.mkdir(parents=True, exist_ok=True)
    args.ziel.write_text(text, encoding="utf-8")
    anzahl = text.count("static const")
    print(f"{anzahl} Farbtokens nach {args.ziel} geschrieben")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
