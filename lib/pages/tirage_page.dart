import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/tournoi_service.dart';
import 'widgets/tirage_tab.dart';
import 'widgets/horaires_tab.dart';
// ── MODIFIÉ : import du nouvel onglet IA ──
import 'widgets/ia_generation_tab.dart';

class TiragePage extends StatefulWidget {
  const TiragePage({super.key});

  @override
  State<TiragePage> createState() => _TiragePageState();
}

class _TiragePageState extends State<TiragePage> with TickerProviderStateMixin {
  final _service = TournoisService();
  late final TabController _tabController;

  List<Equipe> _toutesEquipes = [];
  bool _chargement = true;
  String? _erreur;

  final Map<String, Map<String, List<Equipe>>> _poulesParCat = {
    'R15M': {for (var p in poules) p: []},
    'R7M':  {for (var p in poules) p: []},
    'R7F':  {for (var p in poules) p: []},
  };

  List<MatchPoule> _matchsPoule = [];
  List<MatchArbre> _matchsArbre = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      // ── MODIFIÉ : onglet 1 (Horaires) génère encore les matchs
      // onglet 2 (IA) n'en a plus besoin, il fait tout lui-même
      if (_tabController.index == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _genererMatchs();
        });
      }
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

  void _genererMatchs() {
    setState(() {
      _matchsPoule = _service.genererMatchsPoule(_poulesParCat);
      _matchsArbre = _service.genererMatchsArbre();
    });
  }

  List<Equipe> _equipesNonPlacees(String cat) {
    final placees = poules
        .expand((p) => _poulesParCat[cat]?[p] ?? [])
        .map((e) => e.id)
        .toSet();
    return _toutesEquipes
        .where((e) => e.categorie == cat && !placees.contains(e.id))
        .toList();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('Ovalies',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            SizedBox(width: 8),
            Text('Admin — Tirage au sort',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400,
                    color: Color(0xFFAED6B5))),
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
                  const Text('2 — Horaires'),
                  const SizedBox(width: 6),
                  if (_nbEquipesNonPlacees() > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${_nbEquipesNonPlacees()}',
                          style: const TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            ),
            // ── MODIFIÉ : onglet IA avec badge ──
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14),
                  SizedBox(width: 6),
                  Text('3 — Génération IA'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A5C2A)))
          : _erreur != null
          ? _buildErreur()
          : TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          TirageTab(
            toutesEquipes: _toutesEquipes,
            poulesParCat: _poulesParCat,
            equipesNonPlacees: _equipesNonPlacees,
            onAjouter: _ajouterAPoule,
            onRetirer: _retirerDePoule,
            onTirageAuto: _tiragAuto,
            onReset: _resetTirage,
          ),
          HorairesTab(
            matchsPoule: _matchsPoule,
            matchsArbre: _matchsArbre,
            onGenerer: _genererMatchs,
          ),
          // ── MODIFIÉ : IaGenerationTab remplace GenerationTab ──
          const IaGenerationTab(),
        ],
      ),
    );
  }

  int _nbEquipesNonPlacees() {
    return categories.fold(0, (s, c) => s + _equipesNonPlacees(c).length);
  }

  Widget _buildErreur() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFE57373)),
          const SizedBox(height: 16),
          const Text('Impossible de se connecter à Supabase',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_erreur ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
              onPressed: _charger,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer')),
        ],
      ),
    );
  }
}
