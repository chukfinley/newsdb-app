/// Die Anmeldung.
///
/// **Keine Registrierung, kein Google-Login** — beides ausdrückliche Ansage.
/// Konten legt der Betreiber an (A152); die Sperre sitzt in Convex und greift
/// auch dann, wenn jemand die App umbaut. Ein Formular mit einer Schaltfläche,
/// die immer scheitert, wäre nur ein Versprechen, das nicht gilt — deshalb steht
/// hier ein Satz statt eines Knopfes.
library;

import 'package:flutter/material.dart';

import '../auth/konto.dart';
import '../design/papier.dart';
import '../design/thema.dart';
import '../design/typografie.dart';

class Anmeldeseite extends StatefulWidget {
  const Anmeldeseite({required this.anmeldung, super.key});

  final Anmeldung anmeldung;

  @override
  State<Anmeldeseite> createState() => _AnmeldeseiteState();
}

class _AnmeldeseiteState extends State<Anmeldeseite> {
  final _email = TextEditingController();
  final _passwort = TextEditingController();
  final _formular = GlobalKey<FormState>();

  bool _laeuft = false;
  String? _fehler;
  bool _sichtbar = false;

  @override
  void dispose() {
    _email.dispose();
    _passwort.dispose();
    super.dispose();
  }

  Future<void> _absenden() async {
    if (!(_formular.currentState?.validate() ?? false)) return;
    setState(() {
      _laeuft = true;
      _fehler = null;
    });
    try {
      await widget.anmeldung.anmelden(
        email: _email.text,
        passwort: _passwort.text,
      );
      // Kein `Navigator.pop` und kein Wechsel von Hand: die App hört auf die
      // `Anmeldung` und baut sich neu, sobald ein Konto darin steht. Zwei Wege
      // zum selben Zustand wären zwei Gelegenheiten, ihn zu verfehlen.
    } on AnmeldeAusnahme catch (fehler) {
      debugPrint('$fehler');
      if (mounted) setState(() => _fehler = fehler.text);
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return Scaffold(
      body: Papier(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: Mass.kachel,
                vertical: 40,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formular,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Vielstimmig',
                        textAlign: TextAlign.center,
                        style: Stil.schlagzeile(38).copyWith(color: blatt.tinte),
                      ),
                      const SizedBox(height: Mass.knapp),
                      Text(
                        'GESCHLOSSENE BETA',
                        textAlign: TextAlign.center,
                        style: Stil.kicker.copyWith(color: blatt.akzent),
                      ),
                      const SizedBox(height: Mass.kachel),
                      Text(
                        'Dieselbe Anmeldung wie im Web. Wer noch kein Konto '
                        'hat, bekommt es vom Betreiber — anlegen kann man es '
                        'hier nicht.',
                        textAlign: TextAlign.center,
                        style: Stil.meta.copyWith(color: blatt.tinteGedaempft),
                      ),
                      const SizedBox(height: Mass.kachel * 1.5),

                      _Feld(
                        steuerung: _email,
                        beschriftung: 'E-Mail',
                        art: TextInputType.emailAddress,
                        pruefen: (wert) => (wert == null ||
                                !wert.contains('@') ||
                                wert.trim().isEmpty)
                            ? 'Bitte die E-Mail-Adresse eingeben.'
                            : null,
                      ),
                      const SizedBox(height: Mass.normal),
                      _Feld(
                        steuerung: _passwort,
                        beschriftung: 'Passwort',
                        verdeckt: !_sichtbar,
                        absenden: _absenden,
                        // Die Mindestlänge steht in Convex bei 12 Zeichen.
                        // Hier wird sie **nicht** geprüft: bei der Anmeldung
                        // ist die Länge des eingegebenen Passworts keine
                        // Auskunft, die wir bewerten sollten — und ein
                        // bestehendes Konto mit kürzerem Passwort dürfte sich
                        // sonst nicht mehr anmelden.
                        pruefen: (wert) => (wert == null || wert.isEmpty)
                            ? 'Bitte das Passwort eingeben.'
                            : null,
                        nachsatz: IconButton(
                          onPressed: () =>
                              setState(() => _sichtbar = !_sichtbar),
                          icon: Icon(
                            _sichtbar
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          color: blatt.tinteBlass,
                          tooltip: _sichtbar ? 'verbergen' : 'anzeigen',
                        ),
                      ),

                      if (_fehler != null) ...[
                        const SizedBox(height: Mass.block),
                        Container(
                          padding: const EdgeInsets.all(Mass.normal),
                          decoration: BoxDecoration(
                            color: blatt.akzentSanft,
                            borderRadius: BorderRadius.circular(Mass.rundung),
                          ),
                          child: Text(
                            _fehler!,
                            style: Stil.meta.copyWith(color: blatt.schlecht),
                          ),
                        ),
                      ],

                      const SizedBox(height: Mass.kachel),
                      FilledButton(
                        onPressed: _laeuft ? null : _absenden,
                        style: FilledButton.styleFrom(
                          backgroundColor: blatt.akzent,
                          foregroundColor: blatt.papierGehoben,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Mass.rundung),
                          ),
                        ),
                        child: _laeuft
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Anmelden',
                                style: Stil.kicker.copyWith(
                                  color: blatt.papierGehoben,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feld extends StatelessWidget {
  const _Feld({
    required this.steuerung,
    required this.beschriftung,
    this.art = TextInputType.text,
    this.verdeckt = false,
    this.pruefen,
    this.nachsatz,
    this.absenden,
  });

  final TextEditingController steuerung;
  final String beschriftung;
  final TextInputType art;
  final bool verdeckt;
  final String? Function(String?)? pruefen;
  final Widget? nachsatz;
  final VoidCallback? absenden;

  @override
  Widget build(BuildContext context) {
    final blatt = Blatt.of(context);
    return TextFormField(
      controller: steuerung,
      keyboardType: art,
      obscureText: verdeckt,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction:
          absenden == null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: absenden == null ? null : (_) => absenden!(),
      validator: pruefen,
      style: Stil.lesetext.copyWith(fontSize: 16, color: blatt.tinte),
      decoration: InputDecoration(
        labelText: beschriftung,
        labelStyle: Stil.meta.copyWith(color: blatt.tinteGedaempft),
        errorStyle: Stil.meta.copyWith(color: blatt.schlecht),
        suffixIcon: nachsatz,
        filled: true,
        fillColor: blatt.papierVertieft,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Mass.rundung),
          borderSide: BorderSide(color: blatt.linie),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Mass.rundung),
          borderSide: BorderSide(color: blatt.akzent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Mass.rundung),
          borderSide: BorderSide(color: blatt.schlecht),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Mass.rundung),
          borderSide: BorderSide(color: blatt.schlecht, width: 1.5),
        ),
      ),
    );
  }
}
