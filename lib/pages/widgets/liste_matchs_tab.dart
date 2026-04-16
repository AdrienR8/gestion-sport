// lib/pages/widgets/liste_matchs_tab.dart
//
// Vue 1 — Liste chronologique de tous les matchs de poule,
// triée par poule, avec édition inline de l'horaire, du terrain et de l'arbitre.
//
// MODIFICATIONS APPORTÉES :
//   • Nouveau fichier — remplace partiellement horaires_tab.dart
//   • Données chargées depuis Supabase (tables PouleR15M, PouleR7M, PouleR7F)
//   • Champ "Arbitre" sauvegardé via colonne "Arbitre" dans chaque table Poule*
//   • Filtre par catégorie en haut de page
//   • Dialog d'édition par match (horaire, terrain, arbitre)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Constantes ──────────────────────────────────────────────────────────────
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

// ─── Widget principal ─────────────────────────────────────────────────────────
class ListeMatchsTab extends StatefulWidget {
  const ListeMatchsTab({super.key});

  @override
  State<ListeMatchsTab> createState() => _ListeMatchsTabState();
}

class _ListeMatchsTabState extends State<ListeMatchsTab> {
  final _supabase = Supabase.instance.client;

  // Tous les matchs chargés, clés : 'cat', 'poule', 'id', 'Equipe1', 'Equipe2',
  // 'Start', 'Terrain', 'Arbitre', 'Gagnant', 'Score1', 'Score2'
  List<Map<String, dynamic>> _matchs = [];
  bool _chargement = true;
  String? _erreur;
  String _catFiltre = 'R15M';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  // ── Chargement ─────────────────────────────────────────────────────────────
  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = null; });
    try {
      final List<Map<String, dynamic>> tous = [];
      for (final cat in _categories) {
        final rows = await _supabase
            .from('Poule$cat')
            .select()
            .order('Poule', ascending: true)
            .order('Start', ascending: true);
        for (final r in (rows as List)) {
          tous.add({...Map<String, dynamic>.from(r), 'cat': cat});
        }
      }
      // Tri global : catégorie → poule → start
      tous.sort((a, b) {
        final catCmp = (a['cat'] as String).compareTo(b['cat'] as String);
        if (catCmp != 0) return catCmp;
        final pouleCmp = (a['Poule'] ?? '').toString().compareTo((b['Poule'] ?? '').toString());
        if (pouleCmp != 0) return pouleCmp;
        return (a['Start'] ?? '').toString().compareTo((b['Start'] ?? '').toString());
      });
      setState(() { _matchs = tous; _chargement = false; });
    } catch (e) {
      setState(() { _erreur = e.toString(); _chargement = false; });
    }
  }

  // ── Sauvegarde d'un match ──────────────────────────────────────────────────
  Future<void> _sauvegarder(Map<String, dynamic> match) async {
    final cat = match['cat'] as String;
    await _supabase
        .from('Poule$cat')
        .update({
      'Start':   match['Start'],
      'Terrain': match['Terrain'],
      'Arbitre': match['Arbitre'],
    })
        .eq('id', match['id']);
  }

  // ── Dialog d'édition ──────────────────────────────────────────────────────
  Future<void> _ouvrirEdition(Map<String, dynamic> match) async {
    final ctrlTerrain = TextEditingController(text: match['Terrain']?.toString() ?? '');
    final ctrlArbitre = TextEditingController(text: match['Arbitre']?.toString() ?? '');
    DateTime? dateChoisie = _parseDate(match['Start']?.toString());

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              _badgeCat(match['cat'] as String),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${match["Equipe1"]} vs ${match["Equipe2"]}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poule info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _catFond[match['cat']] ?? const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Poule ${match["Poule"]} · match #${match["id"]}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _catColors[match['cat']] ?? Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                    hintText: 'ex: Terrain 1',
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
                backgroundColor: const Color(0xFF1A5C2A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                // Mettre à jour la map locale
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
    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final jour = jours[d.weekday - 1];
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$jour $dd/$mm ${hh}h$min';
  }

  Widget _badgeCat(String cat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (_catColors[cat] ?? Colors.grey).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: (_catColors[cat] ?? Colors.grey).withOpacity(0.3)),
      ),
      child: Text(
        cat,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _catColors[cat] ?? Colors.grey,
        ),
      ),
    );
  }

  Widget _statutBadge(Map<String, dynamic> m) {
    final gagnant = m['Gagnant']?.toString() ?? '0';
    if (gagnant != '0' && gagnant.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5EC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF2D9148).withOpacity(0.4)),
        ),
        child: const Text('Terminé', style: TextStyle(fontSize: 10, color: Color(0xFF1A5C2A), fontWeight: FontWeight.w700)),
      );
    }
    final hasTime = _parseDate(m['Start']?.toString()) != null;
    if (!hasTime) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: const Text('Sans horaire', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF0FB),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1A4A7A).withOpacity(0.4)),
      ),
      child: const Text('Planifié', style: TextStyle(fontSize: 10, color: Color(0xFF1A4A7A), fontWeight: FontWeight.w700)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de filtre catégorie
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
              // Compteurs rapides
              _buildCompteur(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Recharger',
                onPressed: _charger,
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
              : _buildListe(),
        ),
      ],
    );
  }

  Widget _buildCompteur() {
    final filtres = _matchs.where((m) => m['cat'] == _catFiltre).toList();
    final total = filtres.length;
    final sansHoraire = filtres.where((m) => _parseDate(m['Start']?.toString()) == null).length;
    final sansArbitre = filtres.where((m) => (m['Arbitre']?.toString() ?? '').isEmpty).length;
    return Row(
      children: [
        _chip('$total matchs', Colors.grey.shade600, Colors.grey.shade100),
        if (sansHoraire > 0) ...[
          const SizedBox(width: 6),
          _chip('$sansHoraire sans horaire', Colors.orange.shade700, Colors.orange.shade50),
        ],
        if (sansArbitre > 0) ...[
          const SizedBox(width: 6),
          _chip('$sansArbitre sans arbitre', Colors.red.shade600, Colors.red.shade50),
        ],
      ],
    );
  }

  Widget _chip(String label, Color text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
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

  Widget _buildListe() {
    final filtres = _matchs.where((m) => m['cat'] == _catFiltre).toList();
    if (filtres.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_rugby, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucun match pour $_catFiltre', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    // Grouper par poule
    final Map<String, List<Map<String, dynamic>>> parPoule = {};
    for (final m in filtres) {
      final p = m['Poule']?.toString() ?? '?';
      parPoule.putIfAbsent(p, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: parPoule.entries.map((entry) {
        final poule = entry.key;
        final matchsPoule = entry.value;
        return _PouleSection(
          poule: poule,
          cat: _catFiltre,
          matchs: matchsPoule,
          catColor: _catColors[_catFiltre] ?? Colors.grey,
          catFond: _catFond[_catFiltre] ?? const Color(0xFFF0F0F0),
          formatDate: _formatDate,
          statutBadge: _statutBadge,
          onEdit: _ouvrirEdition,
        );
      }).toList(),
    );
  }
}

// ─── Section par poule ────────────────────────────────────────────────────────
class _PouleSection extends StatelessWidget {
  final String poule;
  final String cat;
  final List<Map<String, dynamic>> matchs;
  final Color catColor;
  final Color catFond;
  final String Function(String?) formatDate;
  final Widget Function(Map<String, dynamic>) statutBadge;
  final Future<void> Function(Map<String, dynamic>) onEdit;

  const _PouleSection({
    required this.poule,
    required this.cat,
    required this.matchs,
    required this.catColor,
    required this.catFond,
    required this.formatDate,
    required this.statutBadge,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final termines = matchs.where((m) {
      final g = m['Gagnant']?.toString() ?? '0';
      return g != '0' && g.isNotEmpty;
    }).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: catColor.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête poule
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: catFond,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: catColor.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    poule,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Poule $poule · $cat',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: catColor),
                ),
                const Spacer(),
                Text(
                  '$termines / ${matchs.length} joués',
                  style: TextStyle(fontSize: 11, color: catColor.withOpacity(0.8)),
                ),
                const SizedBox(width: 8),
                // Mini barre de progression
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: matchs.isEmpty ? 0 : termines / matchs.length,
                      backgroundColor: Colors.grey.shade200,
                      color: catColor,
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lignes de matchs
          ...matchs.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            return _MatchRow(
              match: m,
              isLast: i == matchs.length - 1,
              catColor: catColor,
              formatDate: formatDate,
              statutBadge: statutBadge,
              onEdit: onEdit,
            );
          }),
        ],
      ),
    );
  }
}

// ─── Ligne d'un match ────────────────────────────────────────────────────────
class _MatchRow extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool isLast;
  final Color catColor;
  final String Function(String?) formatDate;
  final Widget Function(Map<String, dynamic>) statutBadge;
  final Future<void> Function(Map<String, dynamic>) onEdit;

  const _MatchRow({
    required this.match,
    required this.isLast,
    required this.catColor,
    required this.formatDate,
    required this.statutBadge,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final terrain = match['Terrain']?.toString() ?? '';
    final arbitre = match['Arbitre']?.toString() ?? '';
    final score1 = match['Score1']?.toString() ?? '—';
    final score2 = match['Score2']?.toString() ?? '—';
    final gagnant = match['Gagnant']?.toString() ?? '0';
    final termine = gagnant != '0' && gagnant.isNotEmpty;

    return InkWell(
      onTap: () => onEdit(match),
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(12))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            // Numéro de match
            SizedBox(
              width: 28,
              child: Text(
                '#${match["id"]}',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade400,
                ),
              ),
            ),

            // Équipes + score
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      match['Equipe1']?.toString() ?? '?',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (gagnant == match['CodeEquipe1'])
                            ? catColor
                            : const Color(0xFF1A1A1A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: termine ? catColor.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      termine ? '$score1 – $score2' : 'vs',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: termine ? catColor : Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      match['Equipe2']?.toString() ?? '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (gagnant == match['CodeEquipe2'])
                            ? catColor
                            : const Color(0xFF1A1A1A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Horaire
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      formatDate(match['Start']?.toString()),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Terrain
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      terrain.isEmpty ? '—' : terrain,
                      style: TextStyle(
                        fontSize: 11,
                        color: terrain.isEmpty ? Colors.grey.shade400 : Colors.grey.shade700,
                        fontStyle: terrain.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Arbitre
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      arbitre.isEmpty ? '—' : arbitre,
                      style: TextStyle(
                        fontSize: 11,
                        color: arbitre.isEmpty ? Colors.grey.shade400 : Colors.grey.shade700,
                        fontStyle: arbitre.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Statut
            statutBadge(match),

            // Icône édition
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
