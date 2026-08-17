#!/usr/bin/env python3
"""Die vier Schriften auf den Zeichenvorrat verkleinern, den das Blatt braucht.

Die Originale von Google Fonts tragen jedes Zeichen, das die Schrift kennt —
Vietnamesisch, Kyrillisch, phonetische Zeichen, alles. **Gemessen am
17.8.2026** kostet das im APK 3,83 MB, allein `SourceSerif4-VF.ttf` 1,15 MB.
Gebraucht wird davon Latein mit den Erweiterungen, also der Vorrat, den ein
deutschsprachiges Blatt setzt.

Genau das macht das Web auch: Fontsource liefert Subsets mit `unicode-range`,
und der Browser laedt nur, was er braucht. Flutter kann das nicht — es buendelt
die Datei, die dasteht. Also wird sie hier vorher zurechtgeschnitten.

**Was erhalten bleiben muss und leicht verlorengeht:**

* **Die Variable-Achsen.** `wght` traegt Gewicht 620 fuer die Schlagzeile,
  `opsz` die optische Groesse. Ein Subset ohne Achsen waere eine Schrift mit
  einem einzigen Schnitt, und die halbe Typografie waere hin. `pyftsubset`
  behaelt sie, solange nicht instanziiert wird.
* **Die OpenType-Merkmale.** `onum` sind die Mediaevalziffern im Fliesstext,
  `tnum`/`lnum` die Versalziffern in Metazeilen und Tabellen. Die Vorgabe von
  `pyftsubset` wirft beide weg — dann stehen ueberall dieselben Ziffern, und
  niemand findet den Grund, weil die Schrift ja "da" ist.

Aufruf:

    python3 tools/schriften.py            # schneidet assets/fonts/ zurecht
    python3 tools/schriften.py --pruefen  # nur berichten, nichts aendern
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

# Die Bereiche aus den `unicode-range`-Angaben von Google Fonts, Subsets
# `latin` und `latin-ext` — dieselbe Auswahl, die das Web laedt.
BEREICHE = ",".join([
    # latin
    "U+0000-00FF", "U+0131", "U+0152-0153", "U+02BB-02BC", "U+02C6",
    "U+02DA", "U+02DC", "U+0304", "U+0308", "U+0329", "U+2000-206F",
    "U+20AC", "U+2122", "U+2191", "U+2193", "U+2212", "U+2215",
    "U+FEFF", "U+FFFD",
    # latin-ext
    "U+0100-02BA", "U+02BD-02C5", "U+02C7-02CC", "U+02CE-02D7",
    "U+02DD-02FF", "U+1D00-1DBF", "U+1E00-1E9F", "U+1EF2-1EFF",
    "U+2020", "U+20A0-20AB", "U+20AD-20C0", "U+2113", "U+2C60-2C7F",
    "U+A720-A7FF",
])

# Ohne diese Liste wirft pyftsubset alles ausser den Vorgabe-Merkmalen weg.
MERKMALE = ",".join([
    "kern", "liga", "clig", "calt", "ccmp", "locl", "mark", "mkmk",
    "onum",  # Mediaevalziffern — der Grund, warum 1975 im Text nicht heraussticht
    "lnum", "tnum", "pnum",  # Versal-, Tabellen-, Proportionalziffern
    "frac", "sups", "subs", "case", "dnom", "numr",
])


def groesse(pfad: Path) -> float:
    return pfad.stat().st_size / 1024


def schneiden(quelle: Path, ziel: Path) -> None:
    subprocess.run(
        [
            sys.executable, "-m", "fontTools.subset", str(quelle),
            f"--unicodes={BEREICHE}",
            f"--layout-features={MERKMALE}",
            # Namenseintraege behalten: ohne sie meldet die Schrift keinen
            # Familiennamen, und Flutter findet sie im Buendel nicht wieder.
            "--name-IDs=*",
            "--name-legacy",
            "--notdef-outline",
            # **Hinting raus.** Gemessen an SourceSerif4: 455 kB -> 351 kB,
            # also nochmal ein Viertel. Es kostet nichts, weil Skia auf Android
            # und iOS das TrueType-Hinting gar nicht auswertet — es rendert mit
            # eigenem Antialiasing. Die Anweisungen liegen also im Buendel,
            # werden geladen und nie benutzt.
            "--no-hinting",
            # Achsen bleiben: `wght` traegt Gewicht 620 fuer die Schlagzeile,
            # `opsz` die optische Groesse. Instanziiert wird nicht.
            "--recalc-timestamp",
            f"--output-file={ziel}",
        ],
        check=True,
        capture_output=True,
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--ordner", type=Path, default=Path("assets/fonts"))
    p.add_argument("--pruefen", action="store_true",
                   help="nur berichten, nichts aendern")
    args = p.parse_args()

    dateien = sorted(args.ordner.glob("*.ttf"))
    if not dateien:
        print(f"keine Schriften in {args.ordner}", file=sys.stderr)
        return 1

    vorher = sum(groesse(d) for d in dateien)
    if args.pruefen:
        for d in dateien:
            print(f"{groesse(d):8.1f} kB  {d.name}")
        print(f"{vorher:8.1f} kB  gesamt")
        return 0

    # Die Originale bleiben liegen, einmal. Ein zweiter Lauf wuerde sonst ein
    # Subset erneut subsetten — schadet nicht, ist aber nicht rueckholbar, wenn
    # die Bereiche einmal zu eng geraten sind.
    urordner = args.ordner / "original"
    urordner.mkdir(exist_ok=True)

    nachher = 0.0
    for datei in dateien:
        ur = urordner / datei.name
        if not ur.exists():
            shutil.copy2(datei, ur)
        schneiden(ur, datei)
        nachher += groesse(datei)
        print(f"{groesse(ur):8.1f} kB -> {groesse(datei):7.1f} kB  {datei.name}")

    print(f"\n{vorher:8.1f} kB -> {nachher:7.1f} kB  "
          f"gesamt ({100 * (1 - nachher / vorher):.0f} % gespart)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
