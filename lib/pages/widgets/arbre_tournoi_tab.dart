// lib/pages/widgets/arbre_tournoi_tab.dart
//
// Vue 2 — Arbre du tournoi en deux sections :
//   • Section Poules  : affichage par poule des matchs avec leur état
//   • Section Phase finale : arbre 1/8 → 1/4 → 1/2 → Finale par catégorie
//
// Les deux sections permettent d'éditer horaire, terrain et arbitre via un dialog.
//
// MODIFICATIONS APPORTÉES :
//   • Nouveau fichier — adapte/remplace generation_tab.dart et match_tree.dart côté admin
//   • Lecture des tables Poule{cat} pour la partie poules
//   • Lecture des tables {cat} (R15M, R7M, R7F) pour la phase finale
//   • Écriture des champs Start, Terrain, Arbitre dans les deux types de tables

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Constantes ───────────────────────────────────────────────────────────────
const _categories = ['R15M', 'R7M', 'R7F'];

const Map<String, Color> _catColors = {
  'R15M': Color(0xFF1A5C2A),
  'R7M':  Color(0xFF8B4513),
  'R7F':  Color(0xFF6B1A5C),
};

const Map<String, Color> _catFond = {
  'R15M': Color(0xFFE8F5EC),
  'R7M':  Color(0xFFF5EDE8),
  'R7F':  Color(0xFFF5E8F5),
};

const Map<String, String> _phases = {
  '1': '1/8 de finale',
  '2': '1/4 de finale',
  '3': '1/2 finale',
  '4': 'Finale',
};

// ─── Widget principal ─────────────────────────────────────────────────────────
class ArbreTournoiTab extends StatefulWidget {
  const ArbreTournoiTab({super.key});

  @override
  State<ArbreTournoiTab> createState() => _ArbreTournoiTabState();
}

class _ArbreTournoiTabState extends State<ArbreTournoiTab>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _sub;

  // Données poules : cat → liste de matchs
  final Map<String, List<Map<String, dynamic>>> _matchsPoule = {};
  // Données arbre : cat → liste de matchs
  final Map<String, List<Map<String, dynamic>>> _matchsArbre = {};

  bool _chargement = true;
  String? _erreur;
  String _catFiltre = 'R15M';

  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 2, vsync: this);
    _charger();
  }

  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }

  // ── Chargement ─────────────────────────────────────────────────────────────
  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = null; });
    try {
      for (final cat in _categories) {
        // Poules
        final pouleRows = await _supabase
            .from('Poule$cat')
            .select()
            .order('Poule', ascending: true)
            .order('id', ascending: true);
        _matchsPoule[cat] = (pouleRows as List)
            .map((r) => {...Map<String, dynamic>.from(r), 'cat': cat, 'tableType': 'poule'})
            .toList();

        // Arbre / phase finale
        final arbreRows = await _supabase
            .from(cat)
            .select()
            .order('Niveau', ascending: true)
            .order('id', ascending: true);
        _matchsArbre[cat] = (arbreRows as List)
            .map((r) => {...Map<String, dynamic>.from(r), 'cat': cat, 'tableType': 'arbre'})
            .toList();
      }
      setState(() { _chargement = false; });
    } catch (e) {
      setState(() { _erreur = e.toString(); _chargement = false; });
    }
  }

  // ── Sauvegarde ─────────────────────────────────────────────────────────────
  Future<void> _sauvegarder(Map<String, dynamic> match) async {
    final cat       = match['cat'] as String;
    final tableType = match['tableType'] as String;
    final table     = tableType == 'poule' ? 'Poule$cat' : cat;
    await _supabase
        .from(table)
        .update({
      'Start':   match['Start'],
      'Terrain': match['Terrain'],
      'Arbitre': match['Arbitre'],
    })
        .eq('id', match['id']);
  }

  // ── Dialog d'édition (partagé poules + arbre) ─────────────────────────────
  Future<void> _ouvrirEdition(Map<String, dynamic> match) async {
    final cat       = match['cat'] as String;
    final tableType = match['tableType'] as String;
    final ctrlTerrain = TextEditingController(text: match['Terrain']?.toString() ?? '');
    final ctrlArbitre = TextEditingController(text: match['Arbitre']?.toString() ?? '');
    DateTime? dateChoisie = _parseDate(match['Start']?.toString());

    // Label du match
    final String titre = tableType == 'poule'
        ? '${match["Equipe1"] ?? "?"} vs ${match["Equipe2"] ?? "?"}'
        : _phases[match['Niveau']?.toString()] ?? 'Match';

    final String sousTitre = tableType == 'poule'
        ? 'Poule ${match["Poule"]} · $cat'
        : '$cat · ${_phases[match["Niveau"]?.toString()] ?? ""}';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _badgeCat(cat),
                  const SizedBox(width: 8),
                  if (tableType == 'arbre')
                    _badgePhase(match['Niveau']?.toString() ?? ''),
                ],
              ),
              const SizedBox(height: 6),
              Text(titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(sousTitre, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horaire
                const Text('Horaire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: dateChoisie ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2027),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: dateChoisie != null
                          ? TimeOfDay.fromDateTime(dateChoisie!)
                          : const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (t == null) return;
                    setDlg(() {
                      dateChoisie = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          dateChoisie != null
                              ? _formatDateComplete(dateChoisie!)
                              : 'Appuyer pour choisir…',
                          style: TextStyle(
                            fontSize: 13,
                            color: dateChoisie != null ? const Color(0xFF1A1A1A) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Terrain
                const Text('Terrain', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrlTerrain,
                  decoration: InputDecoration(
                    hintText: 'ex: Terrain 2',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Arbitre
                const Text('Arbitre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrlArbitre,
                  decoration: InputDecoration(
                    hintText: 'Nom de l\'arbitre',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _catColors[cat] ?? const Color(0xFF1A5C2A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                match['Start']   = dateChoisie?.toIso8601String() ?? match['Start'];
                match['Terrain'] = ctrlTerrain.text.trim().isEmpty ? null : ctrlTerrain.text.trim();
                match['Arbitre'] = ctrlArbitre.text.trim().isEmpty ? null : ctrlArbitre.text.trim();
                Navigator.pop(ctx);
                try {
                  await _sauvegarder(match);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Match mis à jour'),
                      backgroundColor: Color(0xFF1A5C2A),
                      duration: Duration(seconds: 2),
                    ));
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Erreur : $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  static String _formatDateComplete(DateTime d) {
    final dd  = d.day.toString().padLeft(2, '0');
    final mm  = d.month.toString().padLeft(2, '0');
    final hh  = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} ${hh}h$min';
  }

  String _formatDate(String? s) {
    final d = _parseDate(s);
    if (d == null) return '—';
    final dd  = d.day.toString().padLeft(2, '0');
    final mm  = d.month.toString().padLeft(2, '0');
    final hh  = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm ${hh}h$min';
  }

  Widget _badgeCat(String cat) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (_catColors[cat] ?? Colors.grey).withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: (_catColors[cat] ?? Colors.grey).withOpacity(0.3)),
    ),
    child: Text(cat,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _catColors[cat] ?? Colors.grey)),
  );

  Widget _badgePhase(String niveau) {
    final label = _phases[niveau] ?? 'Phase $niveau';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8D0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD4A820).withOpacity(0.4)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF8B6914))),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sélecteur de catégorie
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              const Text('Catégorie :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(width: 10),
              ..._categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat, style: const TextStyle(fontSize: 11)),
                  selected: _catFiltre == cat,
                  selectedColor: (_catColors[cat] ?? Colors.grey).withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: _catFiltre == cat ? (_catColors[cat] ?? Colors.grey) : Colors.grey,
                    fontWeight: _catFiltre == cat ? FontWeight.w700 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: _catFiltre == cat ? (_catColors[cat] ?? Colors.grey) : Colors.grey.shade300,
                  ),
                  onSelected: (_) => setState(() => _catFiltre = cat),
                ),
              )),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Recharger',
                onPressed: _charger,
              ),
            ],
          ),
        ),

        // Sous-onglets Poules / Phase finale
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _sub,
            labelColor: _catColors[_catFiltre] ?? const Color(0xFF1A5C2A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: _catColors[_catFiltre] ?? const Color(0xFF1A5C2A),
            indicatorWeight: 2,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grid_view_rounded, size: 15),
                    const SizedBox(width: 6),
                    const Text('Poules', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    _progressBadgePoule(),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_tree_rounded, size: 15),
                    const SizedBox(width: 6),
                    const Text('Phase finale', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    _progressBadgeArbre(),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Corps
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A5C2A)))
              : _erreur != null
              ? _buildErreur()
              : TabBarView(
            controller: _sub,
            children: [
              _buildPoules(),
              _buildArbre(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressBadgePoule() {
    final matchs = _matchsPoule[_catFiltre] ?? [];
    if (matchs.isEmpty) return const SizedBox.shrink();
    final termines = matchs.where((m) {
      final g = m['Gagnant']?.toString() ?? '0';
      return g != '0' && g.isNotEmpty;
    }).length;
    return _miniProgress(termines, matchs.length, _catColors[_catFiltre] ?? Colors.grey);
  }

  Widget _progressBadgeArbre() {
    final matchs = _matchsArbre[_catFiltre] ?? [];
    if (matchs.isEmpty) return const SizedBox.shrink();
    final termines = matchs.where((m) {
      final g = m['Gagnant']?.toString() ?? '0';
      return g != '0' && g.isNotEmpty;
    }).length;
    return _miniProgress(termines, matchs.length, const Color(0xFF8B6914));
  }

  Widget _miniProgress(int done, int total, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$done/$total',
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _buildErreur() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off, size: 40, color: Color(0xFFE57373)),
        const SizedBox(height: 12),
        Text(_erreur!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        TextButton(onPressed: _charger, child: const Text('Réessayer')),
      ],
    ),
  );

  // ─── Section Poules ──────────────────────────────────────────────────────
  Widget _buildPoules() {
    final matchs = _matchsPoule[_catFiltre] ?? [];
    if (matchs.isEmpty) {
      return _emptyState('Aucun match de poule pour $_catFiltre');
    }

    // Grouper par poule
    final Map<String, List<Map<String, dynamic>>> parPoule = {};
    for (final m in matchs) {
      final p = m['Poule']?.toString() ?? '?';
      parPoule.putIfAbsent(p, () => []).add(m);
    }

    final catColor = _catColors[_catFiltre] ?? Colors.grey;
    final catFond  = _catFond[_catFiltre] ?? const Color(0xFFF0F0F0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: parPoule.entries.map((entry) {
        final poule    = entry.key;
        final mPoule   = entry.value;
        final termines = mPoule.where((m) {
          final g = m['Gagnant']?.toString() ?? '0';
          return g != '0' && g.isNotEmpty;
        }).length;
        final pouleTerminee = termines == mPoule.length && mPoule.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: pouleTerminee ? catColor.withOpacity(0.5) : Colors.grey.shade200,
              width: pouleTerminee ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(color: catColor.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête poule
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: catFond,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: catColor.withOpacity(0.2))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: pouleTerminee ? catColor : catColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(poule,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Text('Poule $poule',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: catColor)),
                    if (pouleTerminee) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, size: 14, color: catColor),
                    ],
                    const Spacer(),
                    Text('$termines/${mPoule.length} joués',
                        style: TextStyle(fontSize: 11, color: catColor.withOpacity(0.8))),
                  ],
                ),
              ),
              // Cards de matchs en grille 2 colonnes
              Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mPoule.map((m) => _MatchCard(
                    match: m,
                    catColor: catColor,
                    formatDate: _formatDate,
                    onEdit: _ouvrirEdition,
                  )).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Section Phase finale ─────────────────────────────────────────────────
  Widget _buildArbre() {
    final matchs = _matchsArbre[_catFiltre] ?? [];
    if (matchs.isEmpty) {
      return _emptyState('Aucun match de phase finale pour $_catFiltre\n(les équipes seront attribuées après les poules)');
    }

    // Grouper par niveau / phase
    final Map<String, List<Map<String, dynamic>>> parNiveau = {};
    for (final m in matchs) {
      final n = m['Niveau']?.toString() ?? '?';
      parNiveau.putIfAbsent(n, () => []).add(m);
    }
    // Trier par niveau croissant
    final niveaux = parNiveau.keys.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a) ?? 99;
        final bi = int.tryParse(b) ?? 99;
        return ai.compareTo(bi);
      });

    final catColor = _catColors[_catFiltre] ?? Colors.grey;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: niveaux.map((niveau) {
        final mNiveau = parNiveau[niveau]!;
        final phase   = _phases[niveau] ?? 'Phase $niveau';
        final termines = mNiveau.where((m) {
          final g = m['Gagnant']?.toString() ?? '0';
          return g != '0' && g.isNotEmpty;
        }).length;

        // Couleur de phase : plus on avance, plus c'est doré
        final phaseColor = _phaseColor(niveau);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: phaseColor.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: phaseColor.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête phase
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: phaseColor.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: phaseColor.withOpacity(0.2))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: phaseColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        phase,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _badgeCat(_catFiltre),
                    const Spacer(),
                    Text('$termines/${mNiveau.length}',
                        style: TextStyle(fontSize: 11, color: phaseColor)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: mNiveau.isEmpty ? 0 : termines / mNiveau.length,
                          backgroundColor: Colors.grey.shade200,
                          color: phaseColor,
                          minHeight: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cartes de matchs
              Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mNiveau.map((m) => _MatchCard(
                    match: m,
                    catColor: catColor,
                    formatDate: _formatDate,
                    onEdit: _ouvrirEdition,
                    isArbre: true,
                  )).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _phaseColor(String niveau) {
    switch (niveau) {
      case '1': return const Color(0xFF5B8FCC); // 1/8 — bleu
      case '2': return const Color(0xFF2D9148); // 1/4 — vert
      case '3': return const Color(0xFFD47A1A); // 1/2 — orange
      case '4': return const Color(0xFFB5338A); // Finale — violet/rose
      default: return Colors.grey;
    }
  }

  Widget _emptyState(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sports_rugby, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, height: 1.5)),
      ],
    ),
  );
}

// ─── Carte de match (réutilisée poule + arbre) ────────────────────────────────
class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final Color catColor;
  final String Function(String?) formatDate;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final bool isArbre;

  const _MatchCard({
    required this.match,
    required this.catColor,
    required this.formatDate,
    required this.onEdit,
    this.isArbre = false,
  });

  @override
  Widget build(BuildContext context) {
    final eq1     = match['Equipe1']?.toString() ?? (isArbre ? '?' : '?');
    final eq2     = match['Equipe2']?.toString() ?? (isArbre ? '?' : '?');
    final score1  = match['Score1']?.toString() ?? '—';
    final score2  = match['Score2']?.toString() ?? '—';
    final gagnant = match['Gagnant']?.toString() ?? '0';
    final terrain = match['Terrain']?.toString() ?? '';
    final arbitre = match['Arbitre']?.toString() ?? '';
    final termine = gagnant != '0' && gagnant.isNotEmpty;

    final bool eq1Gagne = gagnant == match['CodeEquipe1']?.toString();
    final bool eq2Gagne = gagnant == match['CodeEquipe2']?.toString();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Largeur adapative : 2 cartes min, 4 max selon espace
        final cardWidth = (constraints.maxWidth / 2).clamp(160.0, 240.0);
        return InkWell(
          onTap: () => onEdit(match),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: cardWidth,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: termine ? catColor.withOpacity(0.04) : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: termine ? catColor.withOpacity(0.3) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Score / état
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (termine)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$score1 – $score2',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: catColor),
                        ),
                      )
                    else
                      const Text('vs', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),

                // Équipe 1
                _equipeLine(eq1, eq1Gagne),
                const SizedBox(height: 4),
                // Équipe 2
                _equipeLine(eq2, eq2Gagne),

                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Infos logistiques
                _infoLine(Icons.schedule, formatDate(match['Start']?.toString())),
                if (terrain.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _infoLine(Icons.location_on_outlined, terrain),
                ],
                if (arbitre.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _infoLine(Icons.person_outline, arbitre),
                ],

                // Indicateur éditable
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.edit_outlined, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 3),
                    Text('Modifier', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _equipeLine(String nom, bool gagne) => Row(
    children: [
      if (gagne)
        const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Icon(Icons.arrow_right, size: 14, color: Color(0xFF2D9148)),
        ),
      Expanded(
        child: Text(
          nom.isEmpty ? '(À définir)' : nom,
          style: TextStyle(
            fontSize: 11,
            fontWeight: gagne ? FontWeight.w700 : FontWeight.w500,
            color: nom.isEmpty
                ? Colors.grey.shade400
                : gagne
                ? const Color(0xFF1A1A1A)
                : Colors.grey.shade700,
            fontStyle: nom.isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _infoLine(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 11, color: Colors.grey.shade400),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
