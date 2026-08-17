/// Laden, Fehler, Leere — die drei Zustände, die jede Ansicht hat.
///
/// Sie stehen an einer Stelle, weil sie im Web an einer Stelle stehen
/// (`components/states.tsx`) und weil ein Fehlerbild, das in jeder Ansicht
/// anders aussieht, wie ein anderer Fehler wirkt.
///
/// **Ein Fehler sagt, was zu tun ist.** „Etwas ist schiefgelaufen" ist keine
/// Auskunft; „keine Verbindung" und „dafür braucht es eine Anmeldung" sind
/// welche, und sie führen zu verschiedenen Handgriffen.
library;

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../design/thema.dart';
import '../design/typografie.dart';

class Ladeanzeige extends StatelessWidget {
  const Ladeanzeige({this.text, super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    // In einer `ListView` mit `RefreshIndicator`: die Anzeige muss scrollbar
    // sein, sonst greift das Ziehen zum Neuladen nicht.
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 96),
          child: Column(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: blatt.akzent,
                ),
              ),
              if (text != null) ...[
                const SizedBox(height: Mass.block),
                Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class Fehleranzeige extends StatelessWidget {
  const Fehleranzeige({required this.fehler, this.nochmal, super.key});

  final Object fehler;
  final Future<void> Function()? nochmal;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    final api = fehler is ApiFehler ? fehler as ApiFehler : null;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Mass.rand,
            vertical: 80,
          ),
          child: Column(
            children: [
              Icon(
                api?.keinNetz ?? false
                    ? Icons.wifi_off_outlined
                    : Icons.error_outline,
                color: blatt.tinteBlass,
                size: 32,
              ),
              const SizedBox(height: Mass.block),
              Text(
                api?.text ?? 'Da ist etwas schiefgegangen.',
                textAlign: TextAlign.center,
                style: Stil.schlagzeile(20).copyWith(color: blatt.tinte),
              ),
              const SizedBox(height: Mass.knapp),
              // Der technische Grund darunter, klein. Wer ihn nicht braucht,
              // liest ihn nicht; wer einen Fehler meldet, kann ihn abschreiben.
              Text(
                api == null ? '$fehler' : 'HTTP ${api.status} · ${api.pfad}',
                textAlign: TextAlign.center,
                style: Stil.technisch.copyWith(color: blatt.tinteBlass),
              ),
              if (nochmal != null) ...[
                const SizedBox(height: Mass.kachel),
                TextButton(
                  onPressed: nochmal,
                  style: TextButton.styleFrom(foregroundColor: blatt.akzent),
                  child: Text('Nochmal versuchen', style: Stil.zahl),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class Leeranzeige extends StatelessWidget {
  const Leeranzeige({required this.titel, this.hinweis, super.key});

  final String titel;
  final String? hinweis;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Mass.rand,
            vertical: 80,
          ),
          child: Column(
            children: [
              Text(
                titel,
                textAlign: TextAlign.center,
                style: Stil.schlagzeile(22).copyWith(color: blatt.tinte),
              ),
              if (hinweis != null) ...[
                const SizedBox(height: Mass.normal),
                Text(
                  hinweis!,
                  textAlign: TextAlign.center,
                  style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
