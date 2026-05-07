import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────────
// MODÈLE DE DONNÉES
// ─────────────────────────────────────────────────────────────────────────────

class MatchSheetData {
  final String matchId;
  final String categorie;
  final String start;
  final String terrain;
  final String equipe1;
  final String equipe2;
  final String score1;
  final String score2;
  final String nbEssai1;
  final String nbEssai2;
  final String cartonJaune1;
  final String cartonJaune2;
  final String cartonRouge1;
  final String cartonRouge2;
  final String cartonBleu1;
  final String cartonBleu2;

  final List<Map<String, String>> joueursCartonJaune1;
  final List<Map<String, String>> joueursCartonJaune2;
  final List<Map<String, String>> joueursCartonRouge1;
  final List<Map<String, String>> joueursCartonRouge2;
  final List<Map<String, String>> joueursCartonBleu1;
  final List<Map<String, String>> joueursCartonBleu2;

  final List<String> joueursEquipe1;
  final List<String> joueursEquipe2;

  final String commentaireExclusions;
  final String commentaireBlessures;
  final String observationRespoTerrain;
  final String reclamationEquipe1;
  final String reclamationEquipe2;
  final String nomArbitre;

  final String? signatureArbitre;
  final String? signatureCapitaine1;
  final String? signatureCapitaine2;

  const MatchSheetData({
    required this.matchId,
    required this.categorie,
    required this.start,
    required this.terrain,
    required this.equipe1,
    required this.equipe2,
    required this.score1,
    required this.score2,
    required this.nbEssai1,
    required this.nbEssai2,
    required this.cartonJaune1,
    required this.cartonJaune2,
    required this.cartonRouge1,
    required this.cartonRouge2,
    required this.cartonBleu1,
    required this.cartonBleu2,
    this.joueursCartonJaune1 = const [],
    this.joueursCartonJaune2 = const [],
    this.joueursCartonRouge1 = const [],
    this.joueursCartonRouge2 = const [],
    this.joueursCartonBleu1  = const [],
    this.joueursCartonBleu2  = const [],
    this.joueursEquipe1      = const [],
    this.joueursEquipe2      = const [],
    this.commentaireExclusions   = '',
    this.commentaireBlessures    = '',
    this.observationRespoTerrain = '',
    this.reclamationEquipe1      = '',
    this.reclamationEquipe2      = '',
    this.nomArbitre              = '',
    this.signatureArbitre,
    this.signatureCapitaine1,
    this.signatureCapitaine2,
  });

  factory MatchSheetData.fromMatch({
    required Map match,
    required Map<String, String> dataMatch,
    List<Map<String, String>> joueursCartonJaune1 = const [],
    List<Map<String, String>> joueursCartonJaune2 = const [],
    List<Map<String, String>> joueursCartonRouge1 = const [],
    List<Map<String, String>> joueursCartonRouge2 = const [],
    List<Map<String, String>> joueursCartonBleu1  = const [],
    List<Map<String, String>> joueursCartonBleu2  = const [],
    List<String> joueursEquipe1 = const [],
    List<String> joueursEquipe2 = const [],
    String commentaireExclusions   = '',
    String commentaireBlessures    = '',
    String observationRespoTerrain = '',
    String reclamationEquipe1      = '',
    String reclamationEquipe2      = '',
    String nomArbitre              = '',
    String? signatureArbitre,
    String? signatureCapitaine1,
    String? signatureCapitaine2,
  }) {
    String safe(dynamic v, [String fallback = '0']) =>
        (v == null || v.toString().trim().isEmpty) ? fallback : v.toString();

    return MatchSheetData(
      matchId:   safe(match['id'], '?'),
      categorie: safe(match['CodeCategorie'], ''),
      start:     safe(match['Start'], DateTime.now().toIso8601String()),
      terrain:   safe(match['Terrain'], safe(match['CodeCategorie'], '')),
      equipe1:   safe(match['Equipe1'], ''),
      equipe2:   safe(match['Equipe2'], ''),
      score1:    safe(dataMatch['Score1']    ?? match['Score1']),
      score2:    safe(dataMatch['Score2']    ?? match['Score2']),
      nbEssai1:  safe(dataMatch['NbEssai1'] ?? match['NbEssai1']),
      nbEssai2:  safe(dataMatch['NbEssai2'] ?? match['NbEssai2']),
      cartonJaune1: safe(dataMatch['CartonJaune1'] ?? match['CartonJaune1']),
      cartonJaune2: safe(dataMatch['CartonJaune2'] ?? match['CartonJaune2']),
      cartonRouge1: safe(dataMatch['CartonRouge1'] ?? match['CartonRouge1']),
      cartonRouge2: safe(dataMatch['CartonRouge2'] ?? match['CartonRouge2']),
      cartonBleu1:  safe(dataMatch['CartonBleu1']  ?? match['CartonBleu1']),
      cartonBleu2:  safe(dataMatch['CartonBleu2']  ?? match['CartonBleu2']),
      joueursCartonJaune1: joueursCartonJaune1,
      joueursCartonJaune2: joueursCartonJaune2,
      joueursCartonRouge1: joueursCartonRouge1,
      joueursCartonRouge2: joueursCartonRouge2,
      joueursCartonBleu1:  joueursCartonBleu1,
      joueursCartonBleu2:  joueursCartonBleu2,
      joueursEquipe1:          joueursEquipe1,
      joueursEquipe2:          joueursEquipe2,
      commentaireExclusions:   commentaireExclusions,
      commentaireBlessures:    commentaireBlessures,
      observationRespoTerrain: observationRespoTerrain,
      reclamationEquipe1:      reclamationEquipe1,
      reclamationEquipe2:      reclamationEquipe2,
      nomArbitre:              nomArbitre,
      signatureArbitre:        signatureArbitre,
      signatureCapitaine1:     signatureCapitaine1,
      signatureCapitaine2:     signatureCapitaine2,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COULEURS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const orange    = PdfColor.fromInt(0xFFF5841F);
  static const green     = PdfColor.fromInt(0xFF2E8B3A);
  static const gray      = PdfColor.fromInt(0xFF5A5A5A);
  static const lightGray = PdfColor.fromInt(0xFFF2F2F2);
  static const border    = PdfColor.fromInt(0xFFDDDDDD);
  static const white     = PdfColors.white;
  static const yellow    = PdfColor.fromInt(0xFFF5C518);
  static const red       = PdfColor.fromInt(0xFFD62828);
  static const blue      = PdfColor.fromInt(0xFF1565C0);
  static const dark      = PdfColor.fromInt(0xFF111111);
  static const bgOrange  = PdfColor.fromInt(0xFFFFF3E0);
  static const bgRed     = PdfColor.fromInt(0xFFFFEBEE);
  static const bgBlue    = PdfColor.fromInt(0xFFE3F2FD);
  static const bgYellow  = PdfColor.fromInt(0xFFFFFDE7);
}

// ─────────────────────────────────────────────────────────────────────────────
// GÉNÉRATEUR — 3 PAGES
//   Page 1 : portrait  — Score + Cartons + Observations
//   Page 2 : paysage   — Signatures (larges) + Récap sanctions
//   Page 3 : portrait  — Liste joueurs
// ─────────────────────────────────────────────────────────────────────────────

class MatchSheetGenerator {
  final MatchSheetData data;
  MatchSheetGenerator(this.data);

  Future<Uint8List> generate() async {
    final doc = pw.Document(
      title:  'Feuille de Match — ${data.equipe1} vs ${data.equipe2}',
      author: 'Ovalies UniLaSalle',
    );

    // PAGE 1 — portrait
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (_) => _buildPage1(),
    ));

    // PAGE 2 — PAYSAGE (A4 tourné)
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(0),
      build: (_) => _buildPage2(),
    ));

    // PAGE 3 — portrait
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (_) => _buildPage3(),
    ));

    return doc.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 1 — Score · Cartons · Observations
  // ══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildPage1() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _headerBand(landscape: false),
        _scoreRow(),
        _divider(_C.orange),
        _cartonsSection(),          // ← renommé "CARTONS"
        _divider(_C.border),
        _observationsSection(),
        pw.Expanded(child: pw.SizedBox()),
        _footer(1, 3),
      ],
    );
  }

  // ── HEADER BAND ───────────────────────────────────────────────────────────
  // landscape=true → marges latérales plus grandes (A4 paysage = 297mm de large)
  pw.Widget _headerBand({bool landscape = false}) {
    final jour    = _formatJour(data.start);
    final heure   = _formatHeure(data.start);
    final terrain = data.terrain;
    final arbitre = data.nomArbitre;
    final hPad    = landscape ? 36.0 : 28.0;

    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: hPad, vertical: 14),
      color: _C.orange,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('FEUILLE DE MATCH', style: pw.TextStyle(
                fontSize: landscape ? 26 : 22,
                fontWeight: pw.FontWeight.bold, color: _C.white, letterSpacing: 1,
              )),
              pw.SizedBox(height: 4),
              pw.Text('${data.categorie} · Match ${data.matchId}',
                  style: pw.TextStyle(fontSize: 10, color: _C.white)),
              pw.Text(
                '$jour${heure.isNotEmpty ? ' · $heure' : ''}${terrain.isNotEmpty ? ' · $terrain' : ''}',
                style: pw.TextStyle(fontSize: 9, color: _C.white),
              ),
              if (arbitre.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text('Arbitre : $arbitre',
                    style: pw.TextStyle(fontSize: 9, color: _C.white)),
              ],
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('OVALIES', style: pw.TextStyle(
                fontSize: landscape ? 26 : 22,
                fontWeight: pw.FontWeight.bold, color: _C.white, letterSpacing: 2,
              )),
              if (arbitre.isNotEmpty)
                pw.Text('Arbitre : $arbitre',
                    style: pw.TextStyle(fontSize: 9, color: _C.white)),
            ],
          ),
        ],
      ),
    );
  }

  // ── SCORE ROW ─────────────────────────────────────────────────────────────
  pw.Widget _scoreRow() {
    final s1    = int.tryParse(data.score1) ?? 0;
    final s2    = int.tryParse(data.score2) ?? 0;
    final e1    = int.tryParse(data.nbEssai1) ?? 0;
    final e2    = int.tryParse(data.nbEssai2) ?? 0;
    final e1Win = s1 > s2;
    final e2Win = s2 > s1;

    return pw.Container(
      color: _C.white,
      child: pw.Row(children: [
        pw.Expanded(child: pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(28, 18, 16, 18),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              right:  pw.BorderSide(color: _C.border),
              bottom: pw.BorderSide(color: _C.border),
            ),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(data.equipe1, style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold, color: _C.dark,
            )),
            pw.SizedBox(height: 6),
            pw.Text(data.score1, style: pw.TextStyle(
              fontSize: 44, fontWeight: pw.FontWeight.bold,
              color: e1Win ? _C.green : _C.gray,
            )),
            pw.SizedBox(height: 4),
            pw.Text('$e1 essai${e1 > 1 ? 's' : ''}',
                style: pw.TextStyle(fontSize: 9, color: _C.gray)),
          ]),
        )),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _C.border)),
          ),
          child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            pw.Text('VS', style: pw.TextStyle(
              fontSize: 14, fontWeight: pw.FontWeight.bold, color: _C.border, letterSpacing: 2,
            )),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              color: s1 == s2 ? _C.gray : _C.orange,
              child: pw.Text(
                s1 == s2 ? 'EGA' : (e1Win ? '<-WIN' : 'WIN->'),
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _C.white),
              ),
            ),
          ]),
        ),
        pw.Expanded(child: pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(16, 18, 28, 18),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left:   pw.BorderSide(color: _C.border),
              bottom: pw.BorderSide(color: _C.border),
            ),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(data.equipe2, style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold, color: _C.dark,
            )),
            pw.SizedBox(height: 6),
            pw.Text(data.score2, style: pw.TextStyle(
              fontSize: 44, fontWeight: pw.FontWeight.bold,
              color: e2Win ? _C.green : _C.gray,
            )),
            pw.SizedBox(height: 4),
            pw.Text('$e2 essai${e2 > 1 ? 's' : ''}',
                style: pw.TextStyle(fontSize: 9, color: _C.gray)),
          ]),
        )),
      ]),
    );
  }

  // ── CARTONS (ex "Sanctions détail nominatif") ─────────────────────────────
  pw.Widget _cartonsSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionBar('CARTONS', _C.red),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 16),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _cartonsCol(
                data.equipe1,
                data.joueursCartonJaune1,
                data.joueursCartonRouge1,
                data.joueursCartonBleu1,
              )),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _cartonsCol(
                data.equipe2,
                data.joueursCartonJaune2,
                data.joueursCartonRouge2,
                data.joueursCartonBleu2,
              )),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _cartonsCol(
      String equipe,
      List<Map<String, String>> jaunes,
      List<Map<String, String>> rouges,
      List<Map<String, String>> bleus,
      ) {
    final tous = [...jaunes, ...rouges, ...bleus];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Titre équipe
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _C.orange, width: 1.5)),
          ),
          child: pw.Text(equipe.toUpperCase(), style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold, color: _C.dark, letterSpacing: 0.5,
          )),
        ),
        pw.SizedBox(height: 8),

        // Compteurs visuels jaune / rouge / bleu
        pw.Row(children: [
          _compteurBadge(data.equipe1 == equipe ? data.cartonJaune1 : data.cartonJaune2, 'Jaune', _C.yellow),
          pw.SizedBox(width: 6),
          _compteurBadge(data.equipe1 == equipe ? data.cartonRouge1 : data.cartonRouge2, 'Rouge', _C.red),
          pw.SizedBox(width: 6),
          _compteurBadge(data.equipe1 == equipe ? data.cartonBleu1  : data.cartonBleu2,  'Bleu',  _C.blue),
        ]),
        pw.SizedBox(height: 10),

        if (tous.isEmpty)
          pw.Text('Aucune sanction', style: pw.TextStyle(
            fontSize: 9, color: _C.gray, fontStyle: pw.FontStyle.italic,
          ))
        else ...[
          if (jaunes.isNotEmpty) ...[
            _cartonTypeLabel('CARTONS JAUNES', _C.yellow),
            pw.SizedBox(height: 4),
            for (final j in jaunes) _cartonRow(j['nom'] ?? 'Non attribué', j['motif'] ?? '', _C.yellow, _C.bgYellow),
            pw.SizedBox(height: 8),
          ],
          if (rouges.isNotEmpty) ...[
            _cartonTypeLabel('CARTONS ROUGES', _C.red),
            pw.SizedBox(height: 4),
            for (final j in rouges) _cartonRow(j['nom'] ?? 'Non attribué', j['motif'] ?? '', _C.red, _C.bgRed),
            pw.SizedBox(height: 8),
          ],
          if (bleus.isNotEmpty) ...[
            _cartonTypeLabel('CARTONS BLEUS', _C.blue),
            pw.SizedBox(height: 4),
            for (final j in bleus) _cartonRow(
              j['nom'] ?? 'Non attribué',
              j['motif'] ?? 'Suspicion commotion / exclusion définitive',
              _C.blue,
              _C.bgBlue,
            ),
          ],
        ],
      ],
    );
  }

  // Badge compteur (ex : "2 Jaune")
  pw.Widget _compteurBadge(String nb, String label, PdfColor couleur) {
    final n = int.tryParse(nb) ?? 0;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: n > 0 ? couleur : _C.border,
      child: pw.Column(children: [
        pw.Text('$n', style: pw.TextStyle(
          fontSize: 14, fontWeight: pw.FontWeight.bold, color: _C.white,
        )),
        pw.Text(label, style: pw.TextStyle(fontSize: 7, color: _C.white)),
      ]),
    );
  }

  pw.Widget _cartonTypeLabel(String label, PdfColor couleur) {
    return pw.Text(label, style: pw.TextStyle(
      fontSize: 7, fontWeight: pw.FontWeight.bold, color: couleur, letterSpacing: 0.8,
    ));
  }

  // Ligne joueur sanctionné — Stack pour éviter borderRadius+Border partiel
  pw.Widget _cartonRow(String nom, String motif, PdfColor couleur, PdfColor bg) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Stack(children: [
        pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.fromLTRB(14, 6, 10, 6),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(nom, style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold, color: _C.dark,
            )),
            if (motif.isNotEmpty)
              pw.Text(motif, style: pw.TextStyle(fontSize: 8, color: _C.gray)),
          ]),
        ),
        pw.Positioned(left: 0, top: 0, bottom: 0,
            child: pw.Container(width: 4, color: couleur)),
      ]),
    );
  }

  // ── OBSERVATIONS ──────────────────────────────────────────────────────────
  pw.Widget _observationsSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionBar('OBSERVATIONS', _C.green),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 16),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(child: _obsBlock('COMPORTEMENTS & EXCLUSIONS', data.commentaireExclusions)),
              pw.SizedBox(width: 16),
              pw.Expanded(child: _obsBlock('SORTIES SUR BLESSURE', data.commentaireBlessures)),
            ]),
            pw.SizedBox(height: 12),
            _obsBlock('OBSERVATION RESPO DE TERRAIN', data.observationRespoTerrain),
            pw.SizedBox(height: 12),
            pw.Text('RÉCLAMATIONS', style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, color: _C.gray, letterSpacing: 1,
            )),
            pw.SizedBox(height: 6),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(child: _obsBlock(data.equipe1.toUpperCase(), data.reclamationEquipe1)),
              pw.SizedBox(width: 16),
              pw.Expanded(child: _obsBlock(data.equipe2.toUpperCase(), data.reclamationEquipe2)),
            ]),
          ]),
        ),
      ],
    );
  }

  pw.Widget _obsBlock(String titre, String texte) {
    final empty = texte.trim().isEmpty;
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _C.border),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: _C.lightGray,
            borderRadius: pw.BorderRadius.only(
              topLeft:  pw.Radius.circular(3),
              topRight: pw.Radius.circular(3),
            ),
          ),
          child: pw.Text(titre, style: pw.TextStyle(
            fontSize: 7, fontWeight: pw.FontWeight.bold, color: _C.gray, letterSpacing: 0.8,
          )),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            empty ? 'Aucune observation.' : texte,
            style: pw.TextStyle(
              fontSize: 9,
              color:     empty ? _C.border : _C.dark,
              fontStyle: empty ? pw.FontStyle.italic : pw.FontStyle.normal,
              lineSpacing: 1.4,
            ),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 2 — PAYSAGE — Signatures larges + Récapitulatif sanctions
  // ══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildPage2() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _headerBand(landscape: true),
        _sectionBar('SIGNATURES DE FIN DE MATCH', _C.green),

        // Les 3 signatures en colonnes — format paysage = beaucoup de largeur
        pw.Expanded(
          flex: 7,
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(36, 18, 36, 18),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Arbitre
                pw.Expanded(child: _sigBlock(
                  'ARBITRE',
                  data.nomArbitre,
                  data.signatureArbitre,
                  _C.orange,
                )),
                pw.SizedBox(width: 20),
                // Capitaine équipe 1
                pw.Expanded(child: _sigBlock(
                  'CAPITAINE',
                  data.equipe1,
                  data.signatureCapitaine1,
                  _C.green,
                )),
                pw.SizedBox(width: 20),
                // Capitaine équipe 2
                pw.Expanded(child: _sigBlock(
                  'CAPITAINE',
                  data.equipe2,
                  data.signatureCapitaine2,
                  _C.blue,
                )),
              ],
            ),
          ),
        ),

        _divider(_C.border),

        // Récapitulatif sanctions compact en bas
        _sectionBar('RÉCAPITULATIF DES SANCTIONS', _C.red),
        pw.Expanded(
          flex: 3,
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(36, 14, 36, 14),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _recapSanctionsCol(
                  data.equipe1,
                  data.joueursCartonJaune1,
                  data.joueursCartonRouge1,
                  data.joueursCartonBleu1,
                )),
                pw.SizedBox(width: 32),
                pw.Expanded(child: _recapSanctionsCol(
                  data.equipe2,
                  data.joueursCartonJaune2,
                  data.joueursCartonRouge2,
                  data.joueursCartonBleu2,
                )),
              ],
            ),
          ),
        ),

        _footer(2, 3),
      ],
    );
  }

  // Bloc signature individuel
  pw.Widget _sigBlock(String titre, String sousTitre, String? base64Sig, PdfColor accent) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _C.border),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        // En-tête coloré
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: const pw.BorderRadius.only(
              topLeft:  pw.Radius.circular(3),
              topRight: pw.Radius.circular(3),
            ),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(titre, style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: _C.white, letterSpacing: 1,
            )),
            if (sousTitre.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(sousTitre, style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: _C.white,
              )),
            ],
          ]),
        ),
        // Zone signature — grande car format paysage
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: base64Sig != null && base64Sig.isNotEmpty
                ? _sigImage(base64Sig)
                : pw.Center(child: pw.Text('Non signé', style: pw.TextStyle(
              fontSize: 10, color: _C.border, fontStyle: pw.FontStyle.italic,
            ))),
          ),
        ),
        // Ligne accent en bas
        pw.Container(height: 3, color: accent),
      ]),
    );
  }

  pw.Widget _sigImage(String base64) {
    try {
      final bytes = base64Decode(base64);
      return pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain);
    } catch (_) {
      return pw.Center(child: pw.Text('Erreur signature',
          style: pw.TextStyle(fontSize: 8, color: _C.red)));
    }
  }

  // Récapitulatif compact (bas page 2)
  pw.Widget _recapSanctionsCol(
      String equipe,
      List<Map<String, String>> jaunes,
      List<Map<String, String>> rouges,
      List<Map<String, String>> bleus,
      ) {
    final tous = [...jaunes, ...rouges, ...bleus];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(equipe, style: pw.TextStyle(
          fontSize: 11, fontWeight: pw.FontWeight.bold, color: _C.dark,
        )),
        pw.SizedBox(height: 8),
        if (tous.isEmpty)
          pw.Text('Aucune sanction', style: pw.TextStyle(
            fontSize: 9, color: _C.gray, fontStyle: pw.FontStyle.italic,
          ))
        else ...[
          for (final j in jaunes) _recapRow(j['nom'] ?? 'Non attribué', _C.yellow),
          for (final j in rouges) _recapRow(j['nom'] ?? 'Non attribué', _C.red),
          for (final j in bleus)  _recapRow(j['nom'] ?? 'Non attribué', _C.blue),
        ],
      ],
    );
  }

  pw.Widget _recapRow(String nom, PdfColor couleur) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(children: [
        pw.Container(
          width: 10, height: 10,
          decoration: pw.BoxDecoration(color: couleur, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 10),
        pw.Text(nom, style: pw.TextStyle(fontSize: 10, color: _C.dark)),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 3 — Liste des joueurs
  // ══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildPage3() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _headerBand(landscape: false),
        _sectionBar('LISTE DES JOUEURS', _C.green),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _joueursCol(data.equipe1, data.joueursEquipe1)),
                pw.SizedBox(width: 24),
                pw.Expanded(child: _joueursCol(data.equipe2, data.joueursEquipe2)),
              ],
            ),
          ),
        ),
        _footer(3, 3),
      ],
    );
  }

  pw.Widget _joueursCol(String equipe, List<String> joueurs) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _C.orange,
          child: pw.Text(equipe, style: pw.TextStyle(
            fontSize: 11, fontWeight: pw.FontWeight.bold, color: _C.white,
          )),
        ),
        pw.SizedBox(height: 10),
        if (joueurs.isEmpty)
          pw.Text('Aucun joueur enregistré', style: pw.TextStyle(
            fontSize: 9, color: _C.gray, fontStyle: pw.FontStyle.italic,
          ))
        else
          ...joueurs.asMap().entries.map((e) {
            final idx = e.key + 1;
            final nom = e.value;
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: idx % 2 == 0 ? _C.lightGray : _C.white,
                border: pw.Border(
                  bottom: pw.BorderSide(color: _C.border, width: 0.5),
                ),
              ),
              child: pw.Row(children: [
                pw.SizedBox(
                  width: 24,
                  child: pw.Text('$idx.', style: pw.TextStyle(
                    fontSize: 9, color: _C.gray, fontWeight: pw.FontWeight.bold,
                  )),
                ),
                pw.Text(nom, style: pw.TextStyle(fontSize: 10, color: _C.dark)),
              ]),
            );
          }),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS COMMUNS
  // ══════════════════════════════════════════════════════════════════════════

  pw.Widget _sectionBar(String titre, PdfColor accent) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      color: _C.lightGray,
      child: pw.Row(children: [
        pw.Container(width: 4, height: 14, color: accent),
        pw.SizedBox(width: 10),
        pw.Text(titre, style: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: _C.gray, letterSpacing: 1.5,
        )),
      ]),
    );
  }

  pw.Widget _divider(PdfColor color) => pw.Container(height: 1, color: color);

  pw.Widget _footer(int page, int total) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: _C.lightGray,
        border: pw.Border(top: pw.BorderSide(color: _C.border)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Ovalies · UniLaSalle Beauvais · Feuille de match',
              style: pw.TextStyle(fontSize: 7, color: _C.gray)),
          pw.Text('Page $page / $total', style: pw.TextStyle(
            fontSize: 8, fontWeight: pw.FontWeight.bold, color: _C.orange,
          )),
        ],
      ),
    );
  }

  String _formatJour(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const j = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
      return j[dt.weekday - 1];
    } catch (_) { return ''; }
  }

  String _formatHeure(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
