// lib/pages/arbitrage_match_page.dart
//
// Étape 2 v2 — sans QuickAlert, sans import match_sheet_generator externe
//
// REMPLACEMENTS QuickAlert :
//   • Confirmations légères (essai, transformation, pénalité, forfait,
//     informations mises à jour, cartons) → SnackBar flottant coloré
//   • Actions importantes (gagnant, égalité, poule terminée, meilleurs
//     troisièmes, signatures manquantes, PDF généré, erreur) → AlertDialog natif
//
// IMPORTS supprimés : quickalert
// match_sheet_generator.dart doit être cloné dans ce projet séparément.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'match_sheet_generator.dart';

const Color _vertOvalies = Color(0xFF1A5C2A);

class ArbitrageMatchPage extends StatefulWidget {
  final Map<String, dynamic> match;
  const ArbitrageMatchPage({super.key, required this.match});

  @override
  State<ArbitrageMatchPage> createState() => _ArbitrageMatchPageState();
}

class _ArbitrageMatchPageState extends State<ArbitrageMatchPage> {
  final _supabase = Supabase.instance.client;

  Map<String, String?> _dataMatch = {'Score1': ''};

  final List<Map<String, String>> _cartonsEquipe1 = [];
  final List<Map<String, String>> _cartonsEquipe2 = [];

  bool _generationEnCours = false;
  bool _afficherFeuilleDeMatch = false;

  late SignatureController _signatureArbitre;
  late SignatureController _signatureCapitaine1;
  late SignatureController _signatureCapitaine2;

  final _ctrlExclusions       = TextEditingController();
  final _ctrlBlessures        = TextEditingController();
  final _ctrlNomArbitre       = TextEditingController();
  final _ctrlReclamation1     = TextEditingController();
  final _ctrlReclamation2     = TextEditingController();
  final _ctrlObservationRespo = TextEditingController();

  List<Map<String, dynamic>> _joueursEquipe1 = [];
  List<Map<String, dynamic>> _joueursEquipe2 = [];
  bool _joueursCharges = false;

  Color get _catColor {
    switch (widget.match['CodeCategorie']?.toString() ?? '') {
      case 'R15M': return const Color(0xFF1A5C2A);
      case 'R7M':  return const Color(0xFF8B4513);
      case 'R7F':  return const Color(0xFF6B1A5C);
      default:     return _vertOvalies;
    }
  }

  @override
  void initState() {
    super.initState();
    _signatureArbitre    = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);
    _signatureCapitaine1 = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);
    _signatureCapitaine2 = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);
    _ctrlNomArbitre.text = widget.match['Arbitre']?.toString() ?? '';
    _chargerJoueursEquipes();
  }

  @override
  void dispose() {
    _signatureArbitre.dispose();
    _signatureCapitaine1.dispose();
    _signatureCapitaine2.dispose();
    _ctrlExclusions.dispose();
    _ctrlBlessures.dispose();
    _ctrlNomArbitre.dispose();
    _ctrlReclamation1.dispose();
    _ctrlReclamation2.dispose();
    _ctrlObservationRespo.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS — remplaçants de QuickAlert
  // ══════════════════════════════════════════════════════════════════════════

  // SnackBar flottant — confirmations légères
  void _snack(String msg, {Color color = const Color(0xFF2D9148), IconData icon = Icons.check_circle_outline}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  void _snackSuccess(String msg) => _snack(msg, color: const Color(0xFF2D9148), icon: Icons.check_circle_outline);
  void _snackInfo(String msg)    => _snack(msg, color: const Color(0xFF1A4A7A), icon: Icons.info_outline);

  // AlertDialog natif — actions importantes
  Future<void> _alert(String titre, String message, {Color? couleur}) async {
    if (!mounted) return;
    final c = couleur ?? _catColor;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: BoxDecoration(
            color: c.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border(bottom: BorderSide(color: c.withOpacity(0.2))),
          ),
          child: Text(titre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c)),
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: c),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INIT DATAMATCH
  // ══════════════════════════════════════════════════════════════════════════
  void _initDataMatch() {
    if (_dataMatch['Score1'] == '') {
      _dataMatch = {
        'Score1':       widget.match['Score1']?.toString()       ?? '0',
        'Score2':       widget.match['Score2']?.toString()       ?? '0',
        'NbEssai1':     widget.match['NbEssai1']?.toString()     ?? '0',
        'NbEssai2':     widget.match['NbEssai2']?.toString()     ?? '0',
        'CartonJaune1': widget.match['CartonJaune1']?.toString() ?? '0',
        'CartonJaune2': widget.match['CartonJaune2']?.toString() ?? '0',
        'CartonRouge1': widget.match['CartonRouge1']?.toString() ?? '0',
        'CartonRouge2': widget.match['CartonRouge2']?.toString() ?? '0',
        'CartonBleu1':  widget.match['CartonBleu1']?.toString()  ?? '0',
        'CartonBleu2':  widget.match['CartonBleu2']?.toString()  ?? '0',
      };
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHARGEMENT JOUEURS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _chargerJoueursEquipes() async {
    try {
      final code1 = widget.match['CodeEquipe1']?.toString() ?? '';
      final code2 = widget.match['CodeEquipe2']?.toString() ?? '';
      List<Map<String, dynamic>> j1 = [];
      List<Map<String, dynamic>> j2 = [];
      if (code1.isNotEmpty) {
        final res = await _supabase
            .from('joueur')
            .select('id, nom, prenom, carton_jaune, carton_rouge, carton_bleu, suspendu_un_match, suspendu_definitif, team_code')
            .eq('team_code', code1)
            .order('nom', ascending: true);
        j1 = List<Map<String, dynamic>>.from(res);
      }
      if (code2.isNotEmpty) {
        final res = await _supabase
            .from('joueur')
            .select('id, nom, prenom, carton_jaune, carton_rouge, carton_bleu, suspendu_un_match, suspendu_definitif, team_code')
            .eq('team_code', code2)
            .order('nom', ascending: true);
        j2 = List<Map<String, dynamic>>.from(res);
      }
      setState(() {
        _joueursEquipe1 = j1;
        _joueursEquipe2 = j2;
        _joueursCharges = true;
        if (widget.match['Gagnant'] != null && widget.match['Gagnant'] != '0') {
          _afficherFeuilleDeMatch = true;
        }
      });
    } catch (e) {
      setState(() => _joueursCharges = true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS TABLE
  // ══════════════════════════════════════════════════════════════════════════
  String get _tableMatch {
    final poule = widget.match.containsKey('Poule') ? 'Poule' : '';
    return '$poule${widget.match["CodeCategorie"]}';
  }

  bool get _estMatchPoule => widget.match.containsKey('Poule');

  // ══════════════════════════════════════════════════════════════════════════
  // MODIFICATION SCORE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _modifScore(String? score1, String? score2) async {
    await _supabase.from(_tableMatch).update({'Score1': score1}).eq('id', widget.match['id']);
    await _supabase.from(_tableMatch).update({'Score2': score2}).eq('id', widget.match['id']);
    setState(() {
      _dataMatch['Score1'] = score1;
      _dataMatch['Score2'] = score2;
      widget.match['Score1'] = score1;
      widget.match['Score2'] = score2;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MODIFICATION DIRECTE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _modifInformations() async {
    for (final key in _dataMatch.keys) {
      if (_dataMatch[key] != null) {
        await _supabase.from(_tableMatch)
            .update({key: _dataMatch[key].toString()})
            .eq('id', widget.match['id']);
      }
    }
    _snackSuccess('Informations mises à jour');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS PENDANT LE MATCH
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _faireAction(int equipe, int action) async {
    int score = int.tryParse(_dataMatch['Score$equipe'] ?? '0') ?? 0;

    switch (action) {
      case 1: // Essai +5
        score += 5;
        if (equipe == 1) await _modifScore(score.toString(), _dataMatch['Score2']);
        else              await _modifScore(_dataMatch['Score1'], score.toString());
        final nbEssaiRes = await _supabase.from(_tableMatch).select('NbEssai$equipe').eq('id', widget.match['id']).single();
        final nbEssai = int.tryParse(nbEssaiRes['NbEssai$equipe'].toString()) ?? 0;
        await _supabase.from(_tableMatch).update({'NbEssai$equipe': (nbEssai + 1).toString()}).eq('id', widget.match['id']);
        setState(() {
          widget.match['NbEssai$equipe'] = (nbEssai + 1).toString();
          _dataMatch['NbEssai$equipe']   = widget.match['NbEssai$equipe'];
        });
        _snackSuccess("Essai ! Total essais : ${nbEssai + 1}");

      case 2: // Transformation +2
        score += 2;
        if (equipe == 1) await _modifScore(score.toString(), widget.match['Score2']);
        else              await _modifScore(widget.match['Score1'], score.toString());
        _snackSuccess('Transformation validée');

      case 3: await _gererCarton(equipe: equipe, typeCarton: 'jaune', champ: 'CartonJaune');
      case 4: await _gererCarton(equipe: equipe, typeCarton: 'rouge', champ: 'CartonRouge');
      case 5: await _gererCarton(equipe: equipe, typeCarton: 'bleu',  champ: 'CartonBleu');

      case 6:
        _snackInfo('Forfait déclaré');

      case 7: // Pénalité +3
        score += 3;
        if (equipe == 1) await _modifScore(score.toString(), _dataMatch['Score2']);
        else              await _modifScore(_dataMatch['Score1'], score.toString());
        _snackSuccess('Pénalité — +3 pts pour ${widget.match["Equipe$equipe"]}');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GESTION CARTONS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _gererCarton({required int equipe, required String typeCarton, required String champ}) async {
    final res = await _supabase.from(_tableMatch).select('$champ$equipe').eq('id', widget.match['id']).single();
    final valActuelle = int.tryParse(res['$champ$equipe'].toString()) ?? 0;
    final nouvelleVal = valActuelle + 1;
    await _supabase.from(_tableMatch).update({'$champ$equipe': nouvelleVal.toString()}).eq('id', widget.match['id']);
    setState(() {
      widget.match['$champ$equipe'] = nouvelleVal.toString();
      _dataMatch['$champ$equipe']   = nouvelleVal.toString();
    });

    final joueurs   = equipe == 1 ? _joueursEquipe1 : _joueursEquipe2;
    final nomEquipe = widget.match['Equipe$equipe'].toString();
    final selection = await _dialogSelectionJoueur(joueurs: joueurs, typeCarton: typeCarton, nomEquipe: nomEquipe);

    if (selection == null) {
      // Annulé → rollback
      await _supabase.from(_tableMatch).update({'$champ$equipe': valActuelle.toString()}).eq('id', widget.match['id']);
      setState(() {
        widget.match['$champ$equipe'] = valActuelle.toString();
        _dataMatch['$champ$equipe']   = valActuelle.toString();
      });
      return;
    }

    final idJoueur  = selection['id'] ?? '';
    final nomJoueur = selection['nom'] ?? 'Non attribué';

    if (idJoueur.isNotEmpty) {
      final champCarton = typeCarton == 'jaune' ? 'carton_jaune'
          : typeCarton == 'rouge' ? 'carton_rouge' : 'carton_bleu';
      final joueurRes = await _supabase.from('joueur').select(champCarton).eq('id', idJoueur).single();
      final valCarton = (joueurRes[champCarton] ?? 0) as int;
      await _supabase.from('joueur').update({champCarton: valCarton + 1}).eq('id', idJoueur);
      if (typeCarton == 'rouge') {
        await _supabase.from('joueur').update({'suspendu_un_match': true}).eq('id', idJoueur);
        await _supabase.from('Comptes').update({'Suspendu1match': true}).eq('id', idJoueur);
      } else if (typeCarton == 'bleu') {
        await _supabase.from('joueur').update({'suspendu_definitif': true}).eq('id', idJoueur);
        await _supabase.from('Comptes').update({'Suspendudefinitif': true}).eq('id', idJoueur);
      }
      _rafraichirJoueur(idJoueur, typeCarton == 'jaune' ? 'carton_jaune' : typeCarton == 'rouge' ? 'carton_rouge' : 'carton_bleu');
    }

    final motif = typeCarton == 'bleu' ? 'Suspicion commotion / exclusion définitive' : '';
    final liste  = equipe == 1 ? _cartonsEquipe1 : _cartonsEquipe2;
    setState(() => liste.add({'id': idJoueur, 'nom': nomJoueur, 'motif': motif, 'type': typeCarton}));

    // SnackBar coloré selon type
    final cartonColor = typeCarton == 'jaune' ? const Color(0xFFD4A017)
        : typeCarton == 'rouge' ? const Color(0xFFE53E3E)
        : const Color(0xFF1A4A7A);
    final cartonMsg = typeCarton == 'rouge'
        ? 'Carton Rouge — $nomJoueur suspendu 1 match · Total : $nouvelleVal'
        : typeCarton == 'bleu'
        ? 'Carton Bleu — $nomJoueur suspendu définitivement · Total : $nouvelleVal'
        : 'Carton Jaune — $nomJoueur · Total : $nouvelleVal';
    _snack(cartonMsg, color: cartonColor, icon: Icons.square_rounded);
  }

  void _rafraichirJoueur(String id, String champ) {
    for (int i = 0; i < _joueursEquipe1.length; i++) {
      if (_joueursEquipe1[i]['id'].toString() == id) {
        final val = (_joueursEquipe1[i][champ] ?? 0) as int;
        setState(() => _joueursEquipe1[i] = {..._joueursEquipe1[i], champ: val + 1});
        return;
      }
    }
    for (int i = 0; i < _joueursEquipe2.length; i++) {
      if (_joueursEquipe2[i]['id'].toString() == id) {
        final val = (_joueursEquipe2[i][champ] ?? 0) as int;
        setState(() => _joueursEquipe2[i] = {..._joueursEquipe2[i], champ: val + 1});
        return;
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIALOG SÉLECTION JOUEUR
  // ══════════════════════════════════════════════════════════════════════════
  Future<Map<String, String>?> _dialogSelectionJoueur({
    required List<Map<String, dynamic>> joueurs,
    required String typeCarton,
    required String nomEquipe,
  }) async {
    final Color couleur = typeCarton == 'jaune' ? const Color(0xFFFFB800)
        : typeCarton == 'rouge' ? const Color(0xFFE53E3E)
        : const Color(0xFF1A4A7A);
    final String label = typeCarton == 'jaune' ? 'Carton Jaune'
        : typeCarton == 'rouge' ? 'Carton Rouge' : 'Carton Bleu';

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7, maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(color: couleur, borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
              child: Row(children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(nomEquipe, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Quel joueur reçoit ce carton ?', style: TextStyle(fontSize: 13, color: Colors.black54)),
            ),
            Flexible(
              child: joueurs.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun joueur trouvé pour cette équipe.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
                  : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: joueurs.length,
                itemBuilder: (ctx2, i) {
                  final j         = joueurs[i];
                  final nom       = '${j["prenom"] ?? ""} ${j["nom"] ?? ""}'.trim();
                  final suspendu1 = j['suspendu_un_match'] == true;
                  final suspenduD = j['suspendu_definitif'] == true;
                  final nbActuel  = typeCarton == 'jaune' ? (j['carton_jaune'] ?? 0) as int
                      : typeCarton == 'rouge' ? (j['carton_rouge'] ?? 0) as int
                      : (j['carton_bleu'] ?? 0) as int;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    title: Text(nom, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: suspenduD ? Colors.red.shade300 : Colors.black87)),
                    subtitle: suspenduD
                        ? const Text('⚠️ Suspendu définitivement', style: TextStyle(fontSize: 10, color: Colors.red))
                        : suspendu1
                        ? const Text('⚠️ Suspendu 1 match', style: TextStyle(fontSize: 10, color: Colors.orange))
                        : null,
                    trailing: nbActuel > 0
                        ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: couleur.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text('$nbActuel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: couleur)))
                        : null,
                    onTap: () => Navigator.pop(ctx2, {'id': j['id'].toString(), 'nom': nom}),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, {'id': '', 'nom': 'Non attribué'}),
                    child: const Text('Sans attribution', style: TextStyle(fontSize: 12)))),
                const SizedBox(width: 8),
                Expanded(child: TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Annuler', style: TextStyle(fontSize: 12, color: Colors.grey)))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAGNANT
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _gagnant(String equipe) async {
    final codeMatch = widget.match['id'].toString();

    if (widget.match['Gagnant'] != null && widget.match['Gagnant'] != '0') {
      await _alert('Match déjà terminé',
          'Ce match a déjà été clôturé.\nGagnant enregistré : ${widget.match["Gagnant"]}',
          couleur: const Color(0xFFE53E3E));
      return;
    }

    setState(() { widget.match['Gagnant'] = 'Gagnant'; _afficherFeuilleDeMatch = true; });

    final String codeEquipe = equipe == widget.match['CodeEquipe1'].toString()
        ? widget.match['CodeEquipe1'].toString() : widget.match['CodeEquipe2'].toString();
    final String nomEquipe = equipe == widget.match['CodeEquipe1'].toString()
        ? widget.match['Equipe1'].toString() : widget.match['Equipe2'].toString();
    String equipePerdante = '';

    if (_estMatchPoule) {
      // Lire les scores réels depuis la DB — _dataMatch peut être vide
      // si les scores n'ont pas été modifiés pendant cette session.
      final matchDB = await _supabase.from(_tableMatch)
          .select('Score1, Score2').eq('id', widget.match['id']).single();
      final s1DB = int.tryParse(matchDB['Score1']?.toString() ?? '0') ?? 0;
      final s2DB = int.tryParse(matchDB['Score2']?.toString() ?? '0') ?? 0;

      await _attributionDonnesMatch();

      if (s1DB == s2DB) {
        await _supabase.from(_tableMatch).update({'Gagnant': 'egalité'}).eq('id', widget.match['id']);
        final p1 = await _supabase.from('Equipes').select('Points').eq('id', widget.match['CodeEquipe1']).single();
        await _supabase.from('Equipes').update({'Points': (int.parse(p1['Points'].toString()) + 2).toString()}).eq('id', widget.match['CodeEquipe1']);
        final p2 = await _supabase.from('Equipes').select('Points').eq('id', widget.match['CodeEquipe2']).single();
        await _supabase.from('Equipes').update({'Points': (int.parse(p2['Points'].toString()) + 2).toString()}).eq('id', widget.match['CodeEquipe2']);
        await _alert('Égalité', 'Match nul — 2 points attribués à chaque équipe.', couleur: const Color(0xFF5B8FCC));
      } else {
        await _supabase.from(_tableMatch).update({'Gagnant': codeEquipe}).eq('id', widget.match['id']);
        final ps = await _supabase.from('Equipes').select('Points').eq('id', equipe).single();
        await _supabase.from('Equipes').update({'Points': (int.parse(ps['Points'].toString()) + 4).toString()}).eq('id', equipe);
        final nb = await _supabase.from('Equipes').select('MatchsGagne').eq('id', equipe).single();
        await _supabase.from('Equipes').update({'MatchsGagne': (int.parse(nb['MatchsGagne'].toString()) + 1).toString()}).eq('id', equipe);
        _snackSuccess('$nomEquipe — équipe gagnante ! +4 points');
      }

      if (widget.match['Niveau']?.toString() == '3') await _passagePouleACompetition(equipe, nomEquipe);

      equipePerdante = equipe == widget.match['CodeEquipe1'].toString()
          ? widget.match['CodeEquipe2'].toString() : widget.match['CodeEquipe1'].toString();
    } else {
      var idMatch = int.parse(codeMatch.substring(1));
      String codeEquipeSuivant;
      String equipeSuivante;
      if (idMatch % 2 == 0) {
        codeEquipeSuivant = 'CodeEquipe2'; equipeSuivante = 'Equipe2';
        equipePerdante = widget.match['CodeEquipe1'].toString();
      } else {
        idMatch += 1; codeEquipeSuivant = 'CodeEquipe1'; equipeSuivante = 'Equipe1';
        equipePerdante = widget.match['CodeEquipe2'].toString();
      }
      idMatch = (idMatch / 2).ceil();
      final codeSuivant    = (int.parse(codeMatch.substring(0, 1)) + 1).ceil();
      final idMatchSuivant = '$codeSuivant$idMatch';
      await _supabase.from(widget.match['CodeCategorie']).update({'Gagnant': codeEquipe}).eq('id', widget.match['id']);
      await _supabase.from(widget.match['CodeCategorie']).update({equipeSuivante: nomEquipe}).eq('id', idMatchSuivant);
      await _supabase.from(widget.match['CodeCategorie']).update({codeEquipeSuivant: codeEquipe}).eq('id', idMatchSuivant);
      _snackSuccess('$nomEquipe qualifié pour le tour suivant !');
    }

    await _attributionRepas('gagnant', widget.match['CodeCategorie'], widget.match['id'], equipe);
    if (equipePerdante.isNotEmpty) {
      await _attributionRepas('perdant', widget.match['CodeCategorie'], widget.match['id'], equipePerdante);
    }
    await _leverSuspensionsCartonRouge();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ATTRIBUTION DONNÉES MATCH
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _attributionDonnesMatch() async {
    // On relit les données depuis la DB pour être sûr d'avoir les valeurs à jour.
    // Note : on passe volontairement la vérification Gagnant == '0' car à ce stade
    // widget.match['Gagnant'] a déjà été mis à 'Gagnant' par setState — on utilise
    // directement les scores pour décider des points bonus.
    final match   = await _supabase.from(_tableMatch).select().eq('id', widget.match['id']).single();
    final equipe1 = await _supabase.from('Equipes').select().eq('id', widget.match['CodeEquipe1']).single();
    final equipe2 = await _supabase.from('Equipes').select().eq('id', widget.match['CodeEquipe2']).single();

    final nbE1m = (equipe1['NbEssai'] as int) + int.parse(match['NbEssai1'].toString());
    final nbE1e = int.parse(equipe1['NbEssaiEncaisse'].toString()) + int.parse(match['NbEssai2'].toString());
    final nbE2m = (equipe2['NbEssai'] as int) + int.parse(match['NbEssai2'].toString());
    final nbE2e = int.parse(equipe2['NbEssaiEncaisse'].toString()) + int.parse(match['NbEssai1'].toString());
    final cj1   = int.parse(equipe1['NbJaune'].toString()) + int.parse(match['CartonJaune1'].toString());
    final cj2   = int.parse(equipe2['NbJaune'].toString()) + int.parse(match['CartonJaune2'].toString());
    final cr1   = int.parse(equipe1['NbRouge'].toString()) + int.parse(match['CartonRouge1'].toString());
    final cr2   = int.parse(equipe2['NbRouge'].toString()) + int.parse(match['CartonRouge2'].toString());
    final s1    = int.parse(match['Score1'].toString());
    final s2    = int.parse(match['Score2'].toString());

    // Points bonus R15M — appliqués uniquement si les scores sont différents
    // (le cas égalité est géré dans _gagnant, pas ici)
    if (widget.match['CodeCategorie'] == 'R15M' && s1 != s2) {
      var pts1 = int.parse((await _supabase.from('Equipes').select('Points').eq('id', match['CodeEquipe1']).single())['Points'].toString());
      var pts2 = int.parse((await _supabase.from('Equipes').select('Points').eq('id', match['CodeEquipe2']).single())['Points'].toString());
      // Bonus essai (3 essais d'écart ou plus)
      if (int.parse(match['NbEssai1'].toString()) >= int.parse(match['NbEssai2'].toString()) + 3) pts1++;
      else if (s1 < s2 && s1 > s2 - 7) pts1++; // Bonus défaite de moins de 7 pts
      if (int.parse(match['NbEssai2'].toString()) >= int.parse(match['NbEssai1'].toString()) + 3) pts2++;
      else if (s2 < s1 && s2 > s1 - 7) pts2++;
      await _supabase.from('Equipes').update({'Points': pts1.toString()}).eq('id', widget.match['CodeEquipe1']);
      await _supabase.from('Equipes').update({'Points': pts2.toString()}).eq('id', widget.match['CodeEquipe2']);
    }

    String ga1 = nbE1e > 0 ? (nbE1m / nbE1e).toString() : '1000';
    String ga2 = nbE2e > 0 ? (nbE2m / nbE2e).toString() : '1000';
    if (ga1 == 'NaN') ga1 = '0';
    if (ga2 == 'NaN') ga2 = '0';

    // NbBleu n'existe pas dans la table Equipes — on ne l'inclut pas
    await _supabase.from('Equipes').update({
      'GoalAverage':    ga1,
      'NbEssai':        nbE1m,
      'NbEssaiEncaisse': nbE1e.toString(),
      'NbJaune':        cj1.toString(),
      'NbRouge':        cr1.toString(),
    }).eq('id', widget.match['CodeEquipe1']);

    await _supabase.from('Equipes').update({
      'GoalAverage':    ga2,
      'NbEssai':        nbE2m,
      'NbEssaiEncaisse': nbE2e.toString(),
      'NbJaune':        cj2.toString(),
      'NbRouge':        cr2.toString(),
    }).eq('id', widget.match['CodeEquipe2']);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASSAGE POULE → COMPÉTITION
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _passagePouleACompetition(String codeEquipe, String nomEquipe) async {
    final matchsPoule = await _supabase.from(_tableMatch).select().eq('Poule', widget.match['Poule']);
    final pouleFinie  = (matchsPoule as List).every((m) => m['Gagnant'] != '0');

    if (pouleFinie) {
      // Dans _passagePouleACompetition
      List equipesPoule = await _supabase.from('Equipes').select()
          .eq('Poule', widget.match['Poule'])
          .eq('Categorie', widget.match['CodeCategorie'])
          .order('Points');
      equipesPoule = _trieEquipes(equipesPoule);
      const matrice = [
        ['CodeEquipe1','Equipe1','1','11','A'], ['CodeEquipe2','Equipe2','1','11','C'],
        ['CodeEquipe1','Equipe1','0','12','D'], ['CodeEquipe1','Equipe1','0','13','B'],
        ['CodeEquipe1','Equipe1','0','14','F'], ['CodeEquipe2','Equipe2','1','14','E'],
        ['CodeEquipe1','Equipe1','0','15','C'], ['CodeEquipe1','Equipe1','0','16','E'],
        ['CodeEquipe2','Equipe2','1','16','D'], ['CodeEquipe1','Equipe1','0','17','A'],
        ['CodeEquipe1','Equipe1','1','18','B'], ['CodeEquipe2','Equipe2','1','18','F'],
      ];
      for (final ligne in matrice) {
        if (widget.match['Poule'] == ligne[4]) {
          await _supabase.from(widget.match['CodeCategorie']).update({ligne[0]: equipesPoule[int.parse(ligne[2])]['id']}).eq('id', ligne[3]);
          await _supabase.from(widget.match['CodeCategorie']).update({ligne[1]: equipesPoule[int.parse(ligne[2])]['Name']}).eq('id', ligne[3]);
        }
      }
      await _alert('Poule terminée', 'Les deux meilleurs ont été attribués dans la compétition.', couleur: const Color(0xFF2D9148));
    }

    final matchsCat = await _supabase.from(_tableMatch).select();
    final catFinie  = (matchsCat as List).every((m) => m['Gagnant'] != '0');
    if (catFinie) {
      final et = <dynamic>[];
      for (final p in ['A','B','C','D','E','F']) {
        // Dans _mt, dans la boucle for
        List eq = await _supabase.from('Equipes').select()
            .eq('Poule', p).eq('Categorie', widget.match['CodeCategorie']).order('Points');
        eq = _trieEquipes(eq);
        et.add(eq[2]);
      }
      await _mt(et);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRI ÉQUIPES
  // ══════════════════════════════════════════════════════════════════════════
  List _trieEquipes(List equipesPoule) {
    for (int i = 0; i < equipesPoule.length - 1; i++) {
      for (int j = 0; j < equipesPoule.length - 1 - i; j++) {
        final e1 = equipesPoule[j]; final e2 = equipesPoule[j + 1];
        bool swap = false;
        if (int.parse(e1['Points'].toString()) < int.parse(e2['Points'].toString())) {
          swap = true;
        } else if (int.parse(e1['Points'].toString()) == int.parse(e2['Points'].toString())) {
          if (double.parse(e1['GoalAverage'].toString()) < double.parse(e2['GoalAverage'].toString())) {
            swap = true;
          } else if (double.parse(e1['GoalAverage'].toString()) == double.parse(e2['GoalAverage'].toString())) {
            if (e1['NbEssai'] < e2['NbEssai']) swap = true;
            else if (e1['NbEssai'] == e2['NbEssai']) {
              if (int.parse(e1['NbRouge'].toString()) > int.parse(e2['NbRouge'].toString())) swap = true;
              else if (int.parse(e1['NbRouge'].toString()) == int.parse(e2['NbRouge'].toString())) {
                if (int.parse(e1['NbJaune'].toString()) > int.parse(e2['NbJaune'].toString())) swap = true;
                else if (int.parse(e1['NbJaune'].toString()) == int.parse(e2['NbJaune'].toString())) {
                  if (int.parse(e1['MatchsGagne'].toString()) < int.parse(e2['MatchsGagne'].toString())) swap = true;
                }
              }
            }
          }
        }
        if (swap) { final tmp = equipesPoule[j]; equipesPoule[j] = equipesPoule[j + 1]; equipesPoule[j + 1] = tmp; }
      }
    }
    return equipesPoule;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MATRICE TROISIÈMES
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _mt(List equipesTroisieme) async {
    const header = ['17', '13', '15', '12'];
    const matriceTroisieme = [
      [['A','B','C','D'], 'C', 'D', 'A','B'], [['A','B','C','E'], 'C', 'A', 'B','E'],
      [['A','B','C','F'], 'C', 'A', 'B','F'], [['A','B','D','E'], 'D', 'A', 'B','E'],
      [['A','B','D','F'], 'D', 'A', 'B','F'], [['A','B','E','F'], 'E', 'A', 'B','F'],
      [['A','C','D','E'], 'C', 'D', 'A','E'], [['A','C','D','F'], 'C', 'D', 'A','F'],
      [['A','C','E','F'], 'C', 'A', 'F','E'], [['A','D','E','F'], 'D', 'A', 'F','E'],
      [['B','C','D','E'], 'C', 'D', 'B','E'], [['B','C','D','F'], 'C', 'D', 'B','F'],
      [['B','C','E','F'], 'E', 'C', 'B','F'], [['B','D','E','F'], 'E', 'D', 'B','F'],
      [['C','D','E','F'], 'C', 'D', 'F','E'],
    ];

    equipesTroisieme = _trieEquipes(equipesTroisieme);
    final e1 = equipesTroisieme[0]['Poule']; final e2 = equipesTroisieme[1]['Poule'];
    final e3 = equipesTroisieme[2]['Poule']; final e4 = equipesTroisieme[3]['Poule'];
    final codeEquipes = [equipesTroisieme[0]['id'], equipesTroisieme[1]['id'], equipesTroisieme[2]['id'], equipesTroisieme[3]['id']];
    final nomEquipes  = [equipesTroisieme[0]['Name'], equipesTroisieme[1]['Name'], equipesTroisieme[2]['Name'], equipesTroisieme[3]['Name']];

    await _alert('Attribution des meilleurs troisièmes',
        'Les 4 meilleurs troisièmes sont issus des poules : $e1, $e2, $e3, $e4',
        couleur: const Color(0xFF5B8FCC));

    var correspondance = 0; var lignes;
    for (lignes in matriceTroisieme) {
      correspondance = 0;
      for (final e in [e1, e2, e3, e4]) {
        if ((lignes[0] as List).contains(e)) correspondance++;
        if (correspondance == 4) break;
      }
      if (correspondance == 4) break;
    }

    if (correspondance == 4) {
      for (int index = 0; index < 4; index++) {
        var colonne = 0;
        final ce = codeEquipes[index];
        final pe = equipesTroisieme[index]['Poule'];
        final ne = nomEquipes[index];
        for (final value in (lignes as List)) {
          if (value == pe) {
            await _supabase.from(widget.match['CodeCategorie']).update({'CodeEquipe2': ce}).eq('id', header[colonne - 1]);
            await _supabase.from(widget.match['CodeCategorie']).update({'Equipe2': ne}).eq('id', header[colonne - 1]);
            break;
          }
          colonne++;
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LEVER SUSPENSIONS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _leverSuspensionsCartonRouge() async {
    final j1 = await _supabase.from('Comptes').select().eq('type', 'joueur').eq('equipe', widget.match['CodeEquipe1']).eq('Suspendu1match', true);
    final j2 = await _supabase.from('Comptes').select().eq('type', 'joueur').eq('equipe', widget.match['CodeEquipe2']).eq('Suspendu1match', true);
    for (final j in [...(j1 as List), ...(j2 as List)]) {
      await _supabase.from('Comptes').update({'Suspendu1match': false}).eq('id', j['id']);
    }
    for (final j in [..._joueursEquipe1, ..._joueursEquipe2]) {
      if (j['suspendu_un_match'] == true) {
        await _supabase.from('joueur').update({'suspendu_un_match': false}).eq('id', j['id']);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ATTRIBUTION REPAS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _attributionRepas(String etat, String categorie, dynamic id, String idEquipe) async {
    if (!['R15M','R7M','R7F'].contains(categorie)) return;
    final idStr = id.toString();
    try {
      if (etat == 'perdant' && idStr.isNotEmpty && idStr[0] == '2') {
        final repas = await _supabase.from('Equipes').select('Repas').eq('id', idEquipe).single();
        repas['Repas']['Repas'].add('2025-05-10 11:15:00');
        await _supabase.from('Equipes').update({'Repas': repas['Repas']}).eq('id', idEquipe);
      }
      if ((categorie == 'R15M' && idStr == '31') ||
          (etat == 'perdant' && categorie == 'R15M' && idStr == '23') ||
          (etat == 'perdant' && categorie == 'R15M' && idStr == '24') ||
          (etat == 'perdant' && categorie == 'R7M'  && idStr.isNotEmpty && idStr[0] == '2') ||
          (etat == 'perdant' && categorie == 'R7F'  && idStr.isNotEmpty && idStr[0] == '2')) {
        final repas = await _supabase.from('Equipes').select('Repas').eq('id', idEquipe).single();
        repas['Repas']['Repas'].add('2025-05-10 12:30:00');
        await _supabase.from('Equipes').update({'Repas': repas['Repas']}).eq('id', idEquipe);
      }
      if ((categorie == 'R15M' && idStr.isNotEmpty && idStr[0] == '3') ||
          (categorie == 'R7M'  && idStr.isNotEmpty && idStr[0] == '3') ||
          (categorie == 'R7F'  && idStr.isNotEmpty && idStr[0] == '3')) {
        final repas = await _supabase.from('Equipes').select('Repas').eq('id', idEquipe).single();
        repas['Repas']['Repas'].add('2025-05-10 13:30:00');
        await _supabase.from('Equipes').update({'Repas': repas['Repas']}).eq('id', idEquipe);
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GÉNÉRATION PDF + UPLOAD SUPABASE
  // ══════════════════════════════════════════════════════════════════════════

  // Reconstruit les listes nominatives de cartons depuis la table joueur.
  // On filtre par team_code et on ne retient que les joueurs ayant au moins
  // 1 carton du type demandé. Cela fonctionne même si la page a été rechargée.
  Future<List<Map<String, String>>> _joueursAvecCarton(
      String teamCode, String champ) async {
    if (teamCode.isEmpty) return [];
    final rows = await _supabase
        .from('joueur')
        .select('nom, prenom, $champ')
        .eq('team_code', teamCode)
        .gt(champ, 0)
        .order('nom', ascending: true);
    return (rows as List).map((r) {
      final nom    = '${r["prenom"] ?? ""} ${r["nom"] ?? ""}'.trim();
      final count  = r[champ]?.toString() ?? '1';
      return {'nom': '$nom ($count)', 'motif': ''};
    }).toList();
  }

  Future<void> _genererFeuilleDeMatch() async {
    if (_signatureArbitre.isEmpty || _signatureCapitaine1.isEmpty || _signatureCapitaine2.isEmpty) {
      await _alert('Signatures manquantes',
          'Veuillez compléter toutes les signatures avant de générer la feuille de match.',
          couleur: const Color(0xFFD47A1A));
      return;
    }
    setState(() => _generationEnCours = true);
    try {
      final safeDataMatch = <String, String>{
        'Score1':       _dataMatch['Score1']       ?? widget.match['Score1']?.toString()       ?? '0',
        'Score2':       _dataMatch['Score2']       ?? widget.match['Score2']?.toString()       ?? '0',
        'NbEssai1':     _dataMatch['NbEssai1']     ?? widget.match['NbEssai1']?.toString()     ?? '0',
        'NbEssai2':     _dataMatch['NbEssai2']     ?? widget.match['NbEssai2']?.toString()     ?? '0',
        'CartonJaune1': _dataMatch['CartonJaune1'] ?? widget.match['CartonJaune1']?.toString() ?? '0',
        'CartonJaune2': _dataMatch['CartonJaune2'] ?? widget.match['CartonJaune2']?.toString() ?? '0',
        'CartonRouge1': _dataMatch['CartonRouge1'] ?? widget.match['CartonRouge1']?.toString() ?? '0',
        'CartonRouge2': _dataMatch['CartonRouge2'] ?? widget.match['CartonRouge2']?.toString() ?? '0',
        'CartonBleu1':  _dataMatch['CartonBleu1']  ?? widget.match['CartonBleu1']?.toString()  ?? '0',
        'CartonBleu2':  _dataMatch['CartonBleu2']  ?? widget.match['CartonBleu2']?.toString()  ?? '0',
      };

      // ── Reconstruction des listes nominatives depuis joueur ───────────────
      // On interroge directement la table joueur par team_code pour avoir
      // les noms réels, même si la page a été rechargée entre les cartons
      // et la génération de la feuille.
      final code1 = widget.match['CodeEquipe1']?.toString() ?? '';
      final code2 = widget.match['CodeEquipe2']?.toString() ?? '';

      final joueursJaune1 = await _joueursAvecCarton(code1, 'carton_jaune');
      final joueursJaune2 = await _joueursAvecCarton(code2, 'carton_jaune');
      final joueursRouge1 = await _joueursAvecCarton(code1, 'carton_rouge');
      final joueursRouge2 = await _joueursAvecCarton(code2, 'carton_rouge');
      final joueursBleu1  = await _joueursAvecCarton(code1, 'carton_bleu');
      final joueursBleu2  = await _joueursAvecCarton(code2, 'carton_bleu');

      // Ajouter le motif pour les cartons bleus
      for (final j in joueursBleu1) j['motif'] = 'Suspicion commotion / exclusion définitive';
      for (final j in joueursBleu2) j['motif'] = 'Suspicion commotion / exclusion définitive';

      final sig1 = await _signatureArbitre.toPngBytes();
      final sig2 = await _signatureCapitaine1.toPngBytes();
      final sig3 = await _signatureCapitaine2.toPngBytes();

      final data = MatchSheetData.fromMatch(
        match:     widget.match,
        dataMatch: safeDataMatch,
        joueursCartonJaune1: joueursJaune1,
        joueursCartonJaune2: joueursJaune2,
        joueursCartonRouge1: joueursRouge1,
        joueursCartonRouge2: joueursRouge2,
        joueursCartonBleu1:  joueursBleu1,
        joueursCartonBleu2:  joueursBleu2,
        commentaireExclusions:   _ctrlExclusions.text.trim(),
        commentaireBlessures:    _ctrlBlessures.text.trim(),
        observationRespoTerrain: _ctrlObservationRespo.text.trim(),
        nomArbitre:              _ctrlNomArbitre.text.trim(),
        reclamationEquipe1:      _ctrlReclamation1.text.trim(),
        reclamationEquipe2:      _ctrlReclamation2.text.trim(),
        joueursEquipe1: _joueursEquipe1.map((j) => '${j["prenom"] ?? ""} ${j["nom"] ?? ""}'.trim()).toList(),
        joueursEquipe2: _joueursEquipe2.map((j) => '${j["prenom"] ?? ""} ${j["nom"] ?? ""}'.trim()).toList(),
        signatureArbitre:    sig1 != null ? base64Encode(sig1) : null,
        signatureCapitaine1: sig2 != null ? base64Encode(sig2) : null,
        signatureCapitaine2: sig3 != null ? base64Encode(sig3) : null,
      );

      final Uint8List pdfBytes = await MatchSheetGenerator(data).generate();

      final now        = DateTime.now();
      final timestamp  = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}'
          '-${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}';
      final codeEq1    = widget.match['CodeEquipe1']?.toString()  ?? 'EQ1';
      final codeEq2    = widget.match['CodeEquipe2']?.toString()  ?? 'EQ2';
      final cat        = widget.match['CodeCategorie']?.toString() ?? 'CAT';
      final matchId    = widget.match['id']?.toString()           ?? '0';
      final nomFichier = '${cat}_${codeEq1}_vs_${codeEq2}_${matchId}_$timestamp.pdf';

      await _supabase.storage.from('feuille de match').uploadBinary(
        nomFichier, pdfBytes,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
      );

      await _alert('Feuille générée', 'PDF sauvegardé avec succès !\n$nomFichier', couleur: const Color(0xFF2D9148));
    } catch (e) {
      await _alert('Erreur', 'Une erreur est survenue :\n$e', couleur: const Color(0xFFE53E3E));
    } finally {
      setState(() => _generationEnCours = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    _initDataMatch();
    final matchTermine = widget.match['Gagnant'] != null && widget.match['Gagnant'] != '0';
    final eq1 = widget.match['Equipe1']?.toString() ?? '?';
    final eq2 = widget.match['Equipe2']?.toString() ?? '?';
    final cat = widget.match['CodeCategorie']?.toString() ?? '';

    String dateLabel = '';
    try {
      final dt = DateTime.parse(widget.match['Start'].toString());
      const jours = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
      final hh = dt.hour.toString().padLeft(2,'0');
      final mn = dt.minute.toString().padLeft(2,'0');
      dateLabel = '${jours[dt.weekday-1]} ${dt.day}/${dt.month} · ${hh}h$mn';
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: _catColor, foregroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$eq1  vs  $eq2',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('$cat · ${matchTermine ? "Terminé" : "En cours"} · $dateLabel',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      ),
      body: !_joueursCharges
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _bandeauSuspendus(),
          const SizedBox(height: 16),
          _sectionScore(),
          const SizedBox(height: 20),
          if (!matchTermine) ...[
            _sectionFinDeMatch(),
            const SizedBox(height: 20),
            _sectionActions(),
            const SizedBox(height: 20),
            _sectionModifDirecte(),
            const SizedBox(height: 20),
          ],
          if (!matchTermine && !_afficherFeuilleDeMatch) _boutonForcerFeuille(),
          if (matchTermine || _afficherFeuilleDeMatch) ...[
            const SizedBox(height: 8),
            _sectionFeuilleDeMatch(eq1, eq2),
          ],
          const SizedBox(height: 20),
          _sectionInfosBrutes(),
        ]),
      ),
    );
  }

  // ── BANDEAU SUSPENDUS ──────────────────────────────────────────────────────
  Widget _bandeauSuspendus() {
    final suspendus = [
      ..._joueursEquipe1.where((j) => j['suspendu_un_match'] == true || j['suspendu_definitif'] == true),
      ..._joueursEquipe2.where((j) => j['suspendu_un_match'] == true || j['suspendu_definitif'] == true),
    ];
    if (suspendus.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53E3E), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFE53E3E), size: 18),
          SizedBox(width: 6),
          Text('JOUEURS SUSPENDUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE53E3E), letterSpacing: 1)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 8, children: suspendus.map((j) {
          final nom       = '${j["prenom"] ?? ""} ${j["nom"] ?? ""}'.trim();
          final definitif = j['suspendu_definitif'] == true;
          final couleur   = definitif ? const Color(0xFF1A4A7A) : const Color(0xFFE53E3E);
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nom, style: TextStyle(fontSize: 12, color: couleur, fontWeight: FontWeight.w600)),
              Text(definitif ? 'Suspendu définitivement' : 'Suspendu 1 match',
                  style: TextStyle(fontSize: 10, color: couleur)),
            ]),
          ]);
        }).toList()),
      ]),
    );
  }

  // ── SCORE ──────────────────────────────────────────────────────────────────
  Widget _sectionScore() {
    final s1 = _dataMatch['Score1'] ?? '0';
    final s2 = _dataMatch['Score2'] ?? '0';
    final matchTermine = widget.match['Gagnant'] != null && widget.match['Gagnant'] != '0';
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _catColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0,3))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(color: _catColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Center(child: Text(matchTermine ? 'MATCH TERMINÉ' : 'EN COURS',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(children: [
            Expanded(child: Column(children: [
              Text(widget.match['Equipe1']?.toString() ?? '?',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(s1, style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: _catColor), textAlign: TextAlign.center),
              Text('${_dataMatch["NbEssai1"] ?? "0"} essai(s)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('–', style: TextStyle(fontSize: 36, color: Colors.grey.shade300, fontWeight: FontWeight.w300))),
            Expanded(child: Column(children: [
              Text(widget.match['Equipe2']?.toString() ?? '?',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(s2, style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: _catColor), textAlign: TextAlign.center),
              Text('${_dataMatch["NbEssai2"] ?? "0"} essai(s)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
          ]),
        ),
      ]),
    );
  }

  // ── FIN DE MATCH ───────────────────────────────────────────────────────────
  Widget _sectionFinDeMatch() {
    return _card(
      titre: 'Fin de match', icon: Icons.sports_score_rounded, couleur: Colors.red.shade700,
      enfant: _estMatchPoule
          ? ElevatedButton.icon(
        icon: const Icon(Icons.flag_rounded), label: const Text('Mettre fin au match'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: () {
          final s1 = int.tryParse(_dataMatch['Score1'] ?? '0') ?? 0;
          final s2 = int.tryParse(_dataMatch['Score2'] ?? '0') ?? 0;
          _gagnant(s1 >= s2 ? widget.match['CodeEquipe1'].toString() : widget.match['CodeEquipe2'].toString());
        },
      )
          : Row(children: [
        Expanded(child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _catColor, foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => _gagnant(widget.match['CodeEquipe1'].toString()),
          child: Text(widget.match['Equipe1']?.toString() ?? 'Équipe 1', overflow: TextOverflow.ellipsis),
        )),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _catColor, foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => _gagnant(widget.match['CodeEquipe2'].toString()),
          child: Text(widget.match['Equipe2']?.toString() ?? 'Équipe 2', overflow: TextOverflow.ellipsis),
        )),
      ]),
    );
  }

  // ── ACTIONS ────────────────────────────────────────────────────────────────
  Widget _sectionActions() {
    return _card(
      titre: 'Actions pendant le match', icon: Icons.sports_rugby, couleur: _catColor,
      enfant: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _colonneActions(widget.match['Equipe1']?.toString() ?? 'Éq. 1', 1)),
        const SizedBox(width: 16),
        Expanded(child: _colonneActions(widget.match['Equipe2']?.toString() ?? 'Éq. 2', 2)),
      ]),
    );
  }

  Widget _colonneActions(String nomEquipe, int equipe) {
    const actions = [
      (1, 'Essai (+5)',          Color(0xFF2D9148)),
      (2, 'Transformation (+2)', Color(0xFF5B8FCC)),
      (7, 'Pénalité (+3)',       Color(0xFF5B8FCC)),
      (3, 'Carton Jaune',        Color(0xFFD4A017)),
      (4, 'Carton Rouge',        Color(0xFFE53E3E)),
      (5, 'Carton Bleu',         Color(0xFF1A4A7A)),
      (6, 'Forfait',             Color(0xFF888888)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: _catColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Text(nomEquipe, textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _catColor), overflow: TextOverflow.ellipsis)),
      const SizedBox(height: 8),
      ...actions.map((a) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: a.$3, foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(36), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () => _faireAction(equipe, a.$1),
          child: Text(a.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ),
      )),
    ]);
  }

  // ── MODIFICATION DIRECTE ───────────────────────────────────────────────────
  Widget _sectionModifDirecte() {
    return _card(
      titre: 'Modifier directement les informations', icon: Icons.edit_rounded, couleur: Colors.grey.shade700,
      enfant: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _colonneModif(widget.match['Equipe1']?.toString() ?? 'Éq. 1', [
            ('Score', 'Score1'), ('Nb Essais', 'NbEssai1'),
            ('C. Jaune', 'CartonJaune1'), ('C. Rouge', 'CartonRouge1'), ('C. Bleu', 'CartonBleu1'),
          ])),
          const SizedBox(width: 16),
          Expanded(child: _colonneModif(widget.match['Equipe2']?.toString() ?? 'Éq. 2', [
            ('Score', 'Score2'), ('Nb Essais', 'NbEssai2'),
            ('C. Jaune', 'CartonJaune2'), ('C. Rouge', 'CartonRouge2'), ('C. Bleu', 'CartonBleu2'),
          ])),
        ]),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          icon: const Icon(Icons.save_rounded, size: 16), label: const Text('Enregistrer les modifications'),
          style: ElevatedButton.styleFrom(backgroundColor: _catColor, foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _modifInformations,
        ),
      ]),
    );
  }

  Widget _colonneModif(String nom, List<(String, String)> champs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(nom, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _catColor), overflow: TextOverflow.ellipsis),
      const SizedBox(height: 8),
      ...champs.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.$1, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          TextField(
            decoration: InputDecoration(hintText: _dataMatch[c.$2]?.toString() ?? '0', isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            style: const TextStyle(fontSize: 13),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _dataMatch[c.$2] = v),
          ),
        ]),
      )),
    ]);
  }

  // ── BOUTON FORCER FEUILLE ──────────────────────────────────────────────────
  Widget _boutonForcerFeuille() => OutlinedButton.icon(
    icon: const Icon(Icons.description_outlined),
    label: const Text('Générer la feuille de match maintenant'),
    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    onPressed: () => setState(() => _afficherFeuilleDeMatch = true),
  );

  // ── FEUILLE DE MATCH ───────────────────────────────────────────────────────
  Widget _sectionFeuilleDeMatch(String eq1, String eq2) {
    return _card(
      titre: 'Feuille de match', icon: Icons.picture_as_pdf_rounded, couleur: const Color(0xFF2E8B3A),
      enfant: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _champCommentaire(controller: _ctrlExclusions, label: 'COMPORTEMENTS & EXCLUSIONS', hint: 'Décrivez les incidents disciplinaires...'),
        const SizedBox(height: 10),
        _champCommentaire(controller: _ctrlBlessures, label: 'SORTIES SUR BLESSURE', hint: 'Décrivez les sorties sur blessure...'),
        const SizedBox(height: 10),
        _champCommentaire(controller: _ctrlObservationRespo, label: 'OBSERVATION RESPO DE TERRAIN', hint: 'Observations...', couleur: const Color(0xFFF5841F)),
        const SizedBox(height: 10),
        _champCommentaire(controller: _ctrlReclamation1, label: 'RÉCLAMATION — $eq1', hint: 'Réclamation éventuelle...', couleur: const Color(0xFF1565C0)),
        const SizedBox(height: 10),
        _champCommentaire(controller: _ctrlReclamation2, label: 'RÉCLAMATION — $eq2', hint: 'Réclamation éventuelle...', couleur: const Color(0xFF1565C0)),
        const SizedBox(height: 16),
        const Text('Signatures de fin de match', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        _champNomArbitre(),
        const SizedBox(height: 10),
        _zoneSignature('Signature Arbitre', _signatureArbitre),
        _zoneSignature('Signature Capitaine — $eq1', _signatureCapitaine1),
        _zoneSignature('Signature Capitaine — $eq2', _signatureCapitaine2),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: _generationEnCours
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_generationEnCours ? 'Génération en cours...' : 'Générer la feuille de match'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _generationEnCours ? Colors.grey : const Color(0xFF2E8B3A),
            foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _generationEnCours ? null : _genererFeuilleDeMatch,
        ),
      ]),
    );
  }

  // ── INFOS BRUTES ───────────────────────────────────────────────────────────
  Widget _sectionInfosBrutes() {
    return _card(
      titre: 'Informations du match', icon: Icons.info_outline_rounded, couleur: Colors.grey.shade600,
      enfant: Column(children: widget.match.entries.where((e) => !['cat','tableType'].contains(e.key)).map((e) =>
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(e.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _catColor)),
              Text(e.value?.toString() ?? '—', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          )).toList()),
    );
  }

  // ── WIDGETS HELPERS ────────────────────────────────────────────────────────
  Widget _card({required String titre, required IconData icon, required Color couleur, required Widget enfant}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: couleur.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: couleur.withOpacity(0.15)))),
          child: Row(children: [
            Icon(icon, size: 16, color: couleur), const SizedBox(width: 8),
            Text(titre, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: couleur)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: enfant),
      ]),
    );
  }

  Widget _champCommentaire({required TextEditingController controller, required String label, required String hint, Color? couleur}) {
    final c = couleur ?? _catColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c, letterSpacing: 1)),
      const SizedBox(height: 5),
      TextField(
        controller: controller, maxLines: 3, minLines: 2,
        style: const TextStyle(fontSize: 13, color: Color(0xFF222222), height: 1.5),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
            filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.withOpacity(0.3), width: 1.5)),
            focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: 1.5))),
      ),
    ]);
  }

  Widget _champNomArbitre() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("NOM DE L'ARBITRE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _catColor, letterSpacing: 1)),
      const SizedBox(height: 5),
      TextField(
        controller: _ctrlNomArbitre,
        style: const TextStyle(fontSize: 14, color: Color(0xFF222222)),
        decoration: InputDecoration(hintText: "Prénom Nom de l'arbitre", filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon: Icon(Icons.person_outline, color: _catColor),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _catColor.withOpacity(0.3), width: 1.5)),
            focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _catColor, width: 1.5))),
      ),
    ]);
  }

  Widget _zoneSignature(String titre, SignatureController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _catColor, width: 1.5)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _catColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(titre, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
            TextButton(
              onPressed: () => setState(() => controller.clear()),
              style: TextButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
              child: Text('Effacer', style: TextStyle(color: _catColor, fontSize: 12)),
            ),
          ]),
        ),
        Container(
          height: 150,
          decoration: const BoxDecoration(color: Color(0xFFF5F5F5), borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
          child: Signature(controller: controller, backgroundColor: const Color(0xFFF5F5F5)),
        ),
      ]),
    );
  }
}
