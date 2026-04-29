import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'equipe_detail_page.dart';

final _supabase = Supabase.instance.client;

// ════════════════════════════════════════════════════════════
// MODÈLE — colonnes exactes de la table public."Equipes"
// id, Name, Categorie, Ecole, Poule, NbEssai (bigint),
// NbEssaiEncaisse (text), MatchsGagne (text), NbJaune (text),
// NbRouge (text), Points (text), GoalAverage (text)
// ════════════════════════════════════════════════════════════
class Equipe {
  final String id;
  final String nom;            // Name
  final String categorie;      // Categorie
  final String ecole;          // Ecole
  final String poule;          // Poule
  final int    nbEssai;        // NbEssai (bigint)
  final int    nbEssaiEncaisse;// NbEssaiEncaisse (text)
  final int    matchsGagne;    // MatchsGagne (text)
  final int    nbJaune;        // NbJaune (text)
  final int    nbRouge;        // NbRouge (text)
  final String points;         // Points
  final String goalAverage;    // GoalAverage

  Equipe({
    required this.id,
    required this.nom,
    required this.categorie,
    required this.ecole,
    required this.poule,
    required this.nbEssai,
    required this.nbEssaiEncaisse,
    required this.matchsGagne,
    required this.nbJaune,
    required this.nbRouge,
    required this.points,
    required this.goalAverage,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  factory Equipe.fromJson(Map<String, dynamic> j) => Equipe(
    id:               (j['id']              ?? '').toString(),
    nom:              (j['Name']            ?? '').toString(),   // ← 'Name'
    categorie:        (j['Categorie']       ?? '').toString(),
    ecole:            (j['Ecole']           ?? '').toString(),
    poule:            (j['Poule']           ?? '0').toString(),
    nbEssai:          _toInt(j['NbEssai']),
    nbEssaiEncaisse:  _toInt(j['NbEssaiEncaisse']),
    matchsGagne:      _toInt(j['MatchsGagne']),
    nbJaune:          _toInt(j['NbJaune']),
    nbRouge:          _toInt(j['NbRouge']),
    points:           (j['Points']          ?? '0').toString(),
    goalAverage:      (j['GoalAverage']     ?? '0').toString(),
  );
}

// ════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ════════════════════════════════════════════════════════════
class EquipesPage extends StatefulWidget {
  const EquipesPage({super.key});

  @override
  State<EquipesPage> createState() => _EquipesPageState();
}

class _EquipesPageState extends State<EquipesPage> {
  List<Equipe> _toutesEquipes = [];
  bool _chargement = true;
  String? _erreur;
  String _catFiltre = 'Tous';

  static const _cats = ['Tous', 'R15M', 'R7M', 'R7F', 'RF', ];

  static const Map<String, Color> _catColors = {
    'R15M': Color(0xFF1A5C2A),
    'R7M':  Color(0xFF8B4513),
    'R7F':  Color(0xFF6B1A5C),
    'RF':   Color(0xFF1A4A7A),
  };

  static const Map<String, String> _catLabels = {
    'Tous': 'Toutes',
    'R15M': 'Rugby à 15',
    'R7M':  'VII Masculin',
    'R7F':  'VII Féminin',
    'RF':   'Rugby Fauteuil',
  };

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = null; });
    try {
      final data = await _supabase
          .from('Equipes')
          .select()
          .order('Name', ascending: true); // tri par Name
      setState(() {
        _toutesEquipes = (data as List).map((e) => Equipe.fromJson(e)).toList();
        _chargement = false;
      });
    } catch (e) {
      setState(() { _erreur = e.toString(); _chargement = false; });
    }
  }

  List<Equipe> get _equipesFiltrees {
    if (_catFiltre == 'Tous') return _toutesEquipes;
    return _toutesEquipes.where((e) => e.categorie == _catFiltre).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gestion des équipes',
          style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 17, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8E8E8)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B1A5C)),
            onPressed: _charger,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFiltres(),
          const Divider(height: 1, color: Color(0xFFE8E8E8)),
          Expanded(child: _buildCorps()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final total = _equipesFiltrees.length;
    final label = _catFiltre == 'Tous' ? 'toutes catégories' : (_catLabels[_catFiltre] ?? _catFiltre);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: const Color(0xFFF5E8F5), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.shield_rounded, color: Color(0xFF6B1A5C), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Équipes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              Text(
                _chargement ? 'Chargement…' : '$total équipe${total > 1 ? 's' : ''} · $label',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltres() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _cats.map((cat) {
            final selected = _catFiltre == cat;
            final color = cat == 'Tous' ? const Color(0xFF6B1A5C) : (_catColors[cat] ?? const Color(0xFF6B1A5C));
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_catLabels[cat] ?? cat),
                selected: selected,
                selectedColor: color.withOpacity(0.12),
                backgroundColor: Colors.transparent,
                checkmarkColor: color,
                labelStyle: TextStyle(
                  color: selected ? color : Colors.grey.shade600,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(color: selected ? color : Colors.grey.shade300, width: selected ? 1.5 : 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (_) => setState(() => _catFiltre = cat),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCorps() {
    if (_chargement) return const Center(child: CircularProgressIndicator(color: Color(0xFF6B1A5C)));

    if (_erreur != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE57373)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_erreur!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _charger,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B1A5C), foregroundColor: Colors.white),
          ),
        ]),
      );
    }

    final equipes = _equipesFiltrees;
    if (equipes.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Aucune équipe pour cette catégorie', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      ]));
    }

    if (_catFiltre == 'Tous') return _buildListeGroupee(equipes);
    return _buildListeSimple(equipes, _catColors[_catFiltre] ?? const Color(0xFF6B1A5C));
  }

  Widget _buildListeGroupee(List<Equipe> equipes) {
    final groupes = <String, List<Equipe>>{};
    for (final e in equipes) {
      groupes.putIfAbsent(e.categorie, () => []).add(e);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: groupes.entries.map((entry) {
        final color = _catColors[entry.key] ?? const Color(0xFF6B1A5C);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHeader(entry.key, color, entry.value.length),
          const SizedBox(height: 8),
          ...entry.value.map((eq) => _buildEquipeCard(eq, color)),
          const SizedBox(height: 20),
        ]);
      }).toList(),
    );
  }

  Widget _buildListeSimple(List<Equipe> equipes, Color color) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: equipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildEquipeCard(equipes[i], color),
    );
  }

  Widget _buildSectionHeader(String cat, Color color, int count) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(_catLabels[cat] ?? cat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _buildEquipeCard(Equipe eq, Color color) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EquipeDetailPage(equipe: eq))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(
                eq.nom.isNotEmpty ? eq.nom[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                eq.nom.isNotEmpty ? eq.nom : eq.id,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
              ),
              if (eq.ecole.isNotEmpty && eq.ecole != '0')
                Text(eq.ecole, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 4),
              Row(children: [
                if (eq.poule.isNotEmpty && eq.poule != '0') ...[
                  _miniTag('Poule ${eq.poule}', color.withOpacity(0.12), color),
                  const SizedBox(width: 6),
                ],
                _miniTag('${eq.matchsGagne} V', const Color(0xFFE8F5EC), const Color(0xFF1A5C2A)),
                const SizedBox(width: 6),
                _miniTag('${eq.nbEssai} essais', const Color(0xFFF0F0F0), Colors.grey.shade600),
              ]),
            ])),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _miniTag(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
  );
}
