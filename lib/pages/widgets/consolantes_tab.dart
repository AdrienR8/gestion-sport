// lib/pages/widgets/consolantes_tab.dart
//
// NOUVEAU FICHIER
//
// Affiche la liste des matchs de consolante groupés par Niveau.
// Cliquable vers ArbitrageMatchPage avec tableType = 'consolante'.
//
// Paramètre optionnel [categorieFiltre] :
//   • null  → affiche un sélecteur de catégorie (R15M / R7M / R7F)
//   • 'RF'  → affiche un état vide (pas de ConsolanteRF)
//   • autre → filtre fixe sur cette catégorie

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../arbitrage_match_page.dart';

// Labels des niveaux de consolante
const Map<String, String> _phasesConsolante = {
  '1': 'Quart consolante',
  '2': 'Demi consolante',
  '3': 'Finale consolante',
};

const Map<String, Color> _catColors = {
  'R15M': Color(0xFF1A5C2A),
  'R7M':  Color(0xFF8B4513),
  'R7F':  Color(0xFF6B1A5C),
};

class ConsolantesTab extends StatefulWidget {
  /// Si null, un sélecteur de catégorie est affiché.
  /// Si 'RF', affiche directement un état vide.
  final String? categorieFiltre;

  const ConsolantesTab({super.key, this.categorieFiltre});

  @override
  State<ConsolantesTab> createState() => _ConsolantesTabState();
}

class _ConsolantesTabState extends State<ConsolantesTab> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _matchs = [];
  bool _chargement = false;
  String? _erreur;

  // Catégorie active (ignorée si widget.categorieFiltre != null)
  String _catActive = 'R15M';

  String get _catEffective => widget.categorieFiltre ?? _catActive;

  @override
  void initState() {
    super.initState();
    if (widget.categorieFiltre != 'RF') _charger();
  }

  Future<void> _charger() async {
    if (_catEffective == 'RF') return;
    setState(() { _chargement = true; _erreur = null; });
    try {
      final rows = await _supabase
          .from('Consolante$_catEffective')
          .select()
          .order('Niveau', ascending: true)
          .order('id',     ascending: true);
      setState(() {
        _matchs = (rows as List)
            .map((r) => {
          ...Map<String, dynamic>.from(r),
          'cat':       _catEffective,
          'tableType': 'consolante',
          'CodeCategorie': _catEffective,
        })
            .toList();
        _chargement = false;
      });
    } catch (e) {
      setState(() { _erreur = e.toString(); _chargement = false; });
    }
  }

  void _ouvrirMatch(Map<String, dynamic> match) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArbitrageMatchPage(match: match)),
    ).then((_) => _charger());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool _estTermine(Map<String, dynamic> m) {
    final g = m['Gagnant']?.toString() ?? '0';
    return g.isNotEmpty && g != '0';
  }

  String _formatDate(String? s) {
    if (s == null || s.isEmpty) return '—';
    try {
      final d = DateTime.parse(s);
      const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return '${jours[d.weekday - 1]} ${d.day.toString().padLeft(2,'0')}/'
          '${d.month.toString().padLeft(2,'0')} '
          '${d.hour.toString().padLeft(2,'0')}h'
          '${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return '—'; }
  }

  Color _phaseColor(String niveau) {
    switch (niveau) {
      case '1': return const Color(0xFFD47A1A);
      case '2': return const Color(0xFFB5600A);
      case '3': return const Color(0xFF8B4513);
      default:  return Colors.grey;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // RF — état vide immédiat
    if (_catEffective == 'RF') {
      return _emptyState('Pas de consolante pour la catégorie RF');
    }

    final catColor = _catColors[_catEffective] ?? const Color(0xFF1A5C2A);

    return Column(children: [
      // Sélecteur de catégorie — affiché uniquement si aucun filtre fixe
      if (widget.categorieFiltre == null) _buildSelecteur(catColor),

      // Corps
      Expanded(
        child: _chargement
            ? Center(child: CircularProgressIndicator(color: catColor))
            : _erreur != null
            ? _buildErreur()
            : _matchs.isEmpty
            ? _emptyState(
            'Aucun match de consolante pour $_catEffective\n'
                '(les équipes seront attribuées après les poules)')
            : _buildListe(catColor),
      ),
    ]);
  }

  Widget _buildSelecteur(Color catColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        const Text('Catégorie :',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(width: 10),
        ...['R15M', 'R7M', 'R7F'].map((cat) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(cat, style: const TextStyle(fontSize: 11)),
            selected: _catActive == cat,
            selectedColor: (_catColors[cat] ?? Colors.grey).withOpacity(0.15),
            labelStyle: TextStyle(
              color: _catActive == cat ? (_catColors[cat] ?? Colors.grey) : Colors.grey,
              fontWeight: _catActive == cat ? FontWeight.w700 : FontWeight.normal,
            ),
            side: BorderSide(
              color: _catActive == cat
                  ? (_catColors[cat] ?? Colors.grey)
                  : Colors.grey.shade300,
            ),
            onSelected: (_) {
              setState(() { _catActive = cat; _matchs = []; });
              _charger();
            },
          ),
        )),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.refresh, color: catColor, size: 20),
          tooltip: 'Recharger',
          onPressed: _charger,
        ),
      ]),
    );
  }

  Widget _buildListe(Color catColor) {
    // Grouper par niveau
    final Map<String, List<Map<String, dynamic>>> parNiveau = {};
    for (final m in _matchs) {
      final n = m['Niveau']?.toString() ?? '?';
      parNiveau.putIfAbsent(n, () => []).add(m);
    }
    final niveaux = parNiveau.keys.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a) ?? 99;
        final bi = int.tryParse(b) ?? 99;
        return ai.compareTo(bi);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: niveaux.map((niveau) {
        final mNiveau    = parNiveau[niveau]!;
        final phase      = _phasesConsolante[niveau] ?? 'Phase $niveau';
        final termines   = mNiveau.where(_estTermine).length;
        final phaseColor = _phaseColor(niveau);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: phaseColor.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: phaseColor.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // En-tête phase
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: phaseColor.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: phaseColor.withOpacity(0.2))),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: phaseColor, borderRadius: BorderRadius.circular(8)),
                  child: Text(phase,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (catColor).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: catColor.withOpacity(0.3)),
                  ),
                  child: Text(_catEffective,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: catColor)),
                ),
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
                      color: phaseColor, minHeight: 5,
                    ),
                  ),
                ),
              ]),
            ),
            // Lignes de matchs
            ...mNiveau.asMap().entries.map((e) => _LigneConsolante(
              match: e.value,
              isLast: e.key == mNiveau.length - 1,
              phaseColor: phaseColor,
              phase: phase,
              formatDate: _formatDate,
              estTermine: _estTermine,
              onTap: _ouvrirMatch,
            )),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildErreur() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off, size: 40, color: Color(0xFFE57373)),
      const SizedBox(height: 12),
      Text(_erreur!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 16),
      TextButton(onPressed: _charger, child: const Text('Réessayer')),
    ]),
  );

  Widget _emptyState(String msg) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(msg, textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, height: 1.5)),
    ]),
  );
}

// ─── Ligne d'un match consolante ──────────────────────────────────────────────
class _LigneConsolante extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool isLast;
  final Color phaseColor;
  final String phase;
  final String Function(String?) formatDate;
  final bool Function(Map<String, dynamic>) estTermine;
  final void Function(Map<String, dynamic>) onTap;

  const _LigneConsolante({
    required this.match,
    required this.isLast,
    required this.phaseColor,
    required this.phase,
    required this.formatDate,
    required this.estTermine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final termine = estTermine(match);
    final eq1     = match['Equipe1']?.toString() ?? '';
    final eq2     = match['Equipe2']?.toString() ?? '';
    final score1  = match['Score1']?.toString() ?? '—';
    final score2  = match['Score2']?.toString() ?? '—';
    final gagnant = match['Gagnant']?.toString() ?? '0';
    final terrain = match['Terrain']?.toString() ?? '';
    final eq1Win  = gagnant == match['CodeEquipe1']?.toString();
    final eq2Win  = gagnant == match['CodeEquipe2']?.toString();

    return InkWell(
      onTap: () => onTap(match),
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(12))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: termine ? phaseColor.withOpacity(0.03) : Colors.white,
          border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(children: [
          // ID
          SizedBox(
            width: 28,
            child: Text('#${match["id"]}',
                style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey.shade400)),
          ),

          // Badge phase
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: phaseColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4),
            ),
            child: Text(phase,
                style: TextStyle(fontSize: 9, color: phaseColor, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),

          // Équipes + score
          Expanded(
            flex: 5,
            child: Row(children: [
              Expanded(
                child: Text(
                  eq1.isEmpty ? '(À définir)' : eq1,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: eq1Win ? FontWeight.w700 : FontWeight.w500,
                    color: eq1.isEmpty ? Colors.grey.shade400 : eq1Win ? phaseColor : const Color(0xFF1A1A1A),
                    fontStyle: eq1.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: termine ? phaseColor.withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  termine ? '$score1 – $score2' : 'vs',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: termine ? phaseColor : Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  eq2.isEmpty ? '(À définir)' : eq2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: eq2Win ? FontWeight.w700 : FontWeight.w500,
                    color: eq2.isEmpty ? Colors.grey.shade400 : eq2Win ? phaseColor : const Color(0xFF1A1A1A),
                    fontStyle: eq2.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),

          const SizedBox(width: 8),

          // Horaire
          Expanded(
            flex: 2,
            child: Row(children: [
              const Icon(Icons.schedule, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(formatDate(match['Start']?.toString()),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),

          // Terrain
          if (terrain.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: Row(children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(terrain,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ],

          const SizedBox(width: 8),

          // Statut
          _statutBadge(termine, phaseColor),
          const SizedBox(width: 8),

          // Icône action
          Icon(
            termine ? Icons.sports_score_rounded : Icons.play_arrow_rounded,
            size: 18,
            color: termine ? phaseColor.withOpacity(0.5) : phaseColor,
          ),
        ]),
      ),
    );
  }

  Widget _statutBadge(bool termine, Color color) {
    if (termine) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5EC), borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF2D9148).withOpacity(0.4)),
        ),
        child: const Text('Terminé',
            style: TextStyle(fontSize: 10, color: Color(0xFF1A5C2A), fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text('Arbitrer',
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}