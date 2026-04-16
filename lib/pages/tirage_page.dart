// lib/pages/tirage_page.dart
//
// MODIFICATIONS APPORTÉES :
//   • Suppression de l'import de horaires_tab.dart
//   • Suppression de l'import de generation_tab.dart
//   • Ajout de l'import de suivi_matchs_page.dart
//   • TabController réduit de 3 → 2 onglets (Tirage + Suivi matchs)
//   • Suppression du déclenchement automatique _genererMatchs() sur tab 1 & 2
//     (la génération n'est plus dans ce flux)
//   • Suppression des listes _matchsPoule et _matchsArbre (plus gérées ici)
//   • Le titre de l'onglet 2 est "Suivi matchs" au lieu de "Horaires"
//   • La méthode _genererMatchs() est supprimée

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/tournoi_service.dart';
import 'widgets/tirage_tab.dart';
import 'suivi_matchs_page.dart'; // ← NOUVEAU (remplace horaires_tab + generation_tab)

class TiragePage extends StatefulWidget {
  const TiragePage({super.key});

  @override
  State<TiragePage> createState() => _TiragePageState();
}

class _TiragePageState extends State<TiragePage> with TickerProviderStateMixin {
  final _service = TournoisService();
  late final TabController _tabController;

  // Données
  List<Equipe> _toutesEquipes = [];
  bool _chargement = true;
  String? _erreur;

  // Poules assignées : cat → poule → liste d'équipes
  final Map<String, Map<String, List<Equipe>>> _poulesParCat = {
    'R15M': {for (var p in poules) p: []},
    'R7M':  {for (var p in poules) p: []},
    'R7F':  {for (var p in poules) p: []},
  };

  @override
  void initState() {
    super.initState();
    // ─ MODIFIÉ : 2 onglets au lieu de 3 ──────────────────────────────────
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {});
    });
    _charger();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = null; });
    try {
      final equipes = await _service.chargerEquipes();
      setState(() {
        _toutesEquipes = equipes;
        _chargement = false;
        // Pré-remplir les poules si déjà attribuées en DB
        for (final eq in equipes) {
          if (eq.poule != null && poules.contains(eq.poule)) {
            final pCat = _poulesParCat[eq.categorie];
            if (pCat != null) {
              final pList = pCat[eq.poule!] ?? [];
              if (!pList.any((e) => e.id == eq.id) && pList.length < 4) {
                pList.add(eq);
                pCat[eq.poule!] = pList;
              }
            }
          }
        }
      });
    } catch (e) {
      setState(() { _erreur = e.toString(); _chargement = false; });
    }
  }

  List<Equipe> _equipesNonPlacees(String cat) {
    final placees = poules
        .expand((p) => _poulesParCat[cat]?[p] ?? [])
        .map((e) => e.id)
        .toSet();
    return _toutesEquipes.where((e) => e.categorie == cat && !placees.contains(e.id)).toList();
  }

  int _nbEquipesNonPlacees() =>
      _categories.fold(0, (sum, cat) => sum + _equipesNonPlacees(cat).length);

  void _ajouterAPoule(String cat, String poule, Equipe eq) {
    final list = _poulesParCat[cat]![poule]!;
    if (list.length >= 4) return;
    if (list.any((e) => e.id == eq.id)) return;
    setState(() => list.add(eq));
  }

  void _retirerDePoule(String cat, String poule, String id) {
    setState(() => _poulesParCat[cat]![poule]!.removeWhere((e) => e.id == id));
  }

  void _tiragAuto(String cat) {
    for (final p in poules) _poulesParCat[cat]![p]!.clear();
    final liste = List<Equipe>.from(_toutesEquipes.where((e) => e.categorie == cat));
    liste.shuffle();
    for (int i = 0; i < liste.length; i++) {
      final p = poules[i % 6];
      if ((_poulesParCat[cat]![p]?.length ?? 0) < 4) {
        _poulesParCat[cat]![p]!.add(liste[i]);
      }
    }
    setState(() {});
  }

  void _resetTirage(String cat) {
    for (final p in poules) _poulesParCat[cat]![p]!.clear();
    setState(() {});
  }

  // ── Constantes catégories (conservées pour tirage_tab) ────────────────────
  static const List<String> _categories = ['R15M', 'R7M', 'R7F'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5C2A),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('Ovalies', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            SizedBox(width: 8),
            Text('Admin — Tirage au sort',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFFAED6B5))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger les équipes',
            onPressed: _charger,
          ),
          const SizedBox(width: 8),
        ],
        // ─ MODIFIÉ : 2 onglets ─────────────────────────────────────────────
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF7FC99A),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            const Tab(text: '1 — Tirage'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('2 — Suivi matchs'),
                  const SizedBox(width: 6),
                  // Badge si équipes non placées
                  if (_nbEquipesNonPlacees() > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${_nbEquipesNonPlacees()}',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A5C2A)))
          : _erreur != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Color(0xFFE57373)),
            const SizedBox(height: 16),
            Text(_erreur!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          // ─ Onglet 1 : Tirage (inchangé) ──────────────────────
          TirageTab(
            toutesEquipes: _toutesEquipes,
            poulesParCat: _poulesParCat,
            onAjouter: _ajouterAPoule,
            onRetirer: _retirerDePoule,
            onTirageAuto: _tiragAuto,
            onReset: _resetTirage,
            equipesNonPlacees: _equipesNonPlacees,
          ),
          // ─ Onglet 2 : Suivi matchs (NOUVEAU — remplace Horaires + Génération) ─
          const SuiviMatchsPage(standaloneMode: false),
        ],
      ),
    );
  }
}
