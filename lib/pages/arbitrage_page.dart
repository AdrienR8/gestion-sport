import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'arbitrage_match_page.dart';

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

// ─── Page principale ──────────────────────────────────────────────────────────
class ArbitragePage extends StatefulWidget {
  const ArbitragePage({super.key});

  @override
  State<ArbitragePage> createState() => _ArbitragePageState();
}

class _ArbitragePageState extends State<ArbitragePage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

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
    _tabController = TabController(length: 2, vsync: this);
    _charger();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            .map((r) => {
          ...Map<String, dynamic>.from(r),
          'cat': cat,
          'tableType': 'poule',
        })
            .toList();

        // Arbre / phase finale
        final arbreRows = await _supabase
            .from(cat)
            .select()
            .order('Niveau', ascending: true)
            .order('id', ascending: true);
        _matchsArbre[cat] = (arbreRows as List)
            .map((r) => {
          ...Map<String, dynamic>.from(r),
          'cat': cat,
          'tableType': 'arbre',
        })
            .toList();
      }
      setState(() => _chargement = false);
    } catch (e) {
      setState(() { _erreur = e.toString(); _chargement = false; });
    }
  }

  // ── Navigation vers la page d'arbitrage du match ──────────────────────────
  void _ouvrirMatch(Map<String, dynamic> match) {
    // On prépare la map au format attendu par ArbitrageMatchPage
    // (même structure que widget.match dans ModifMatchPage)
    final matchData = Map<String, dynamic>.from(match);

    // Ajouter CodeCategorie si absent (nécessaire pour la logique métier)
    matchData['CodeCategorie'] = match['cat'] ?? '';

    // Pour les matchs de poule, on ajoute la clé "Poule" pour que
    // ArbitrageMatchPage sache qu'il s'agit d'un match de poule
    // (cohérent avec widget.match.containsKey("Poule") dans ModifMatchPage)
    // La clé "Poule" existe déjà dans les données Supabase pour les poules.

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArbitrageMatchPage(match: matchData),
      ),
    ).then((_) => _charger()); // Rafraîchir après retour
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool _estTermine(Map<String, dynamic> m) {
    final g = m['Gagnant']?.toString() ?? '0';
    return g.isNotEmpty && g != '0';
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  String _formatDate(String? s) {
    final d = _parseDate(s);
    if (d == null) return '—';
    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final jour = jours[d.weekday - 1];
    final dd  = d.day.toString().padLeft(2, '0');
    final mm  = d.month.toString().padLeft(2, '0');
    final hh  = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$jour $dd/$mm ${hh}h$min';
  }

  Widget _badgeCat(String cat) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (_catColors[cat] ?? Colors.grey).withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: (_catColors[cat] ?? Colors.grey).withOpacity(0.3)),
    ),
    child: Text(cat, style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w800, color: _catColors[cat] ?? Colors.grey,
    )),
  );

  Widget _progressBadge(List<Map<String, dynamic>> matchs, Color color) {
    if (matchs.isEmpty) return const SizedBox.shrink();
    final termines = matchs.where(_estTermine).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$termines/${matchs.length}',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ── Build principal ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final poulesCat = _matchsPoule[_catFiltre] ?? [];
    final arbreCat  = _matchsArbre[_catFiltre] ?? [];
    final catColor  = _catColors[_catFiltre] ?? Colors.grey;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: catColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            _badgeCat(_catFiltre),
            const SizedBox(width: 10),
            const Text('Arbitrage des matchs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Recharger',
            onPressed: _charger,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Filtre catégorie ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                const Text('Catégorie :',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
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
                      color: _catFiltre == cat
                          ? (_catColors[cat] ?? Colors.grey)
                          : Colors.grey.shade300,
                    ),
                    onSelected: (_) => setState(() => _catFiltre = cat),
                  ),
                )),
                const Spacer(),
                // Compteur global
                _compteurGlobal(poulesCat, arbreCat),
              ],
            ),
          ),

          // ── Sous-onglets Poules / Phase finale ────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: catColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: catColor,
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
                      _progressBadge(poulesCat, catColor),
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
                      _progressBadge(arbreCat, const Color(0xFF8B6914)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Corps ─────────────────────────────────────────────────────────
          Expanded(
            child: _chargement
                ? Center(child: CircularProgressIndicator(color: catColor))
                : _erreur != null
                ? _buildErreur()
                : TabBarView(
              controller: _tabController,
              children: [
                _buildPoules(poulesCat, catColor),
                _buildArbre(arbreCat, catColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compteurGlobal(
      List<Map<String, dynamic>> poules,
      List<Map<String, dynamic>> arbre,
      ) {
    final total    = poules.length + arbre.length;
    final termines = poules.where(_estTermine).length + arbre.where(_estTermine).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$termines / $total matchs joués',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
    );
  }

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

  // ── Section Poules ─────────────────────────────────────────────────────────
  Widget _buildPoules(List<Map<String, dynamic>> matchs, Color catColor) {
    if (matchs.isEmpty) return _emptyState('Aucun match de poule pour $_catFiltre');

    // Grouper par poule
    final Map<String, List<Map<String, dynamic>>> parPoule = {};
    for (final m in matchs) {
      final p = m['Poule']?.toString() ?? '?';
      parPoule.putIfAbsent(p, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: parPoule.entries.map((entry) {
        final poule   = entry.key;
        final mPoule  = entry.value;
        final termines = mPoule.where(_estTermine).length;
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
                  color: _catFond[_catFiltre] ?? const Color(0xFFF0F0F0),
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
                      child: Text(poule, style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Text('Poule $poule · $_catFiltre',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: catColor)),
                    if (pouleTerminee) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, size: 14, color: catColor),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: mPoule.isEmpty ? 0 : termines / mPoule.length,
                          backgroundColor: Colors.grey.shade200,
                          color: catColor,
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$termines/${mPoule.length}',
                        style: TextStyle(fontSize: 11, color: catColor.withOpacity(0.8))),
                  ],
                ),
              ),
              // Lignes de matchs
              ...mPoule.asMap().entries.map((e) => _MatchLigne(
                match: e.value,
                isLast: e.key == mPoule.length - 1,
                catColor: catColor,
                formatDate: _formatDate,
                estTermine: _estTermine,
                onTap: _ouvrirMatch,
              )),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Section Phase finale ───────────────────────────────────────────────────
  Widget _buildArbre(List<Map<String, dynamic>> matchs, Color catColor) {
    if (matchs.isEmpty) {
      return _emptyState(
          'Aucun match de phase finale pour $_catFiltre\n(les équipes seront attribuées après les poules)');
    }

    // Grouper par niveau
    final Map<String, List<Map<String, dynamic>>> parNiveau = {};
    for (final m in matchs) {
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
        final mNiveau  = parNiveau[niveau]!;
        final phase    = _phases[niveau] ?? 'Phase $niveau';
        final termines = mNiveau.where(_estTermine).length;
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
                      child: Text(phase, style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
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
              // Lignes de matchs
              ...mNiveau.asMap().entries.map((e) => _MatchLigne(
                match: e.value,
                isLast: e.key == mNiveau.length - 1,
                catColor: phaseColor,
                formatDate: _formatDate,
                estTermine: _estTermine,
                onTap: _ouvrirMatch,
                isArbre: true,
                phase: phase,
              )),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _phaseColor(String niveau) {
    switch (niveau) {
      case '1': return const Color(0xFF5B8FCC);
      case '2': return const Color(0xFF2D9148);
      case '3': return const Color(0xFFD47A1A);
      case '4': return const Color(0xFFB5338A);
      default:  return Colors.grey;
    }
  }

  Widget _emptyState(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sports_rugby, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(msg, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, height: 1.5)),
      ],
    ),
  );
}

// ─── Ligne d'un match ─────────────────────────────────────────────────────────
class _MatchLigne extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool isLast;
  final Color catColor;
  final String Function(String?) formatDate;
  final bool Function(Map<String, dynamic>) estTermine;
  final void Function(Map<String, dynamic>) onTap;
  final bool isArbre;
  final String? phase;

  const _MatchLigne({
    required this.match,
    required this.isLast,
    required this.catColor,
    required this.formatDate,
    required this.estTermine,
    required this.onTap,
    this.isArbre = false,
    this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final termine  = estTermine(match);
    final eq1      = match['Equipe1']?.toString() ?? '?';
    final eq2      = match['Equipe2']?.toString() ?? '?';
    final score1   = match['Score1']?.toString() ?? '—';
    final score2   = match['Score2']?.toString() ?? '—';
    final gagnant  = match['Gagnant']?.toString() ?? '0';
    final terrain  = match['Terrain']?.toString() ?? '';
    final eq1Win   = gagnant == match['CodeEquipe1']?.toString();
    final eq2Win   = gagnant == match['CodeEquipe2']?.toString();

    return InkWell(
      onTap: () => onTap(match),
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(12))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: termine ? catColor.withOpacity(0.03) : Colors.white,
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            // ID
            SizedBox(
              width: 28,
              child: Text('#${match["id"]}',
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey.shade400)),
            ),

            // Phase badge (arbre uniquement)
            if (isArbre && phase != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(phase!, style: TextStyle(fontSize: 9, color: catColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
            ],

            // Équipes + score
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      eq1.isEmpty ? '(À définir)' : eq1,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: eq1Win ? FontWeight.w700 : FontWeight.w500,
                        color: eq1.isEmpty
                            ? Colors.grey.shade400
                            : eq1Win ? catColor : const Color(0xFF1A1A1A),
                        fontStyle: eq1.isEmpty ? FontStyle.italic : FontStyle.normal,
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
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: termine ? catColor : Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      eq2.isEmpty ? '(À définir)' : eq2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: eq2Win ? FontWeight.w700 : FontWeight.w500,
                        color: eq2.isEmpty
                            ? Colors.grey.shade400
                            : eq2Win ? catColor : const Color(0xFF1A1A1A),
                        fontStyle: eq2.isEmpty ? FontStyle.italic : FontStyle.normal,
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
              flex: 2,
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
            if (terrain.isNotEmpty) ...[
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(terrain,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(width: 8),

            // Statut
            _statutBadge(match, termine, catColor),

            const SizedBox(width: 8),

            // Icône action
            Icon(
              termine ? Icons.sports_score_rounded : Icons.play_arrow_rounded,
              size: 18,
              color: termine ? catColor.withOpacity(0.5) : catColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statutBadge(Map<String, dynamic> m, bool termine, Color catColor) {
    if (termine) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5EC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF2D9148).withOpacity(0.4)),
        ),
        child: const Text('Terminé',
            style: TextStyle(fontSize: 10, color: Color(0xFF1A5C2A), fontWeight: FontWeight.w700)),
      );
    }
    final hasTime = m['Start'] != null && m['Start'].toString().isNotEmpty;
    if (!hasTime) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: const Text('Sans horaire',
            style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: catColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: catColor.withOpacity(0.3)),
      ),
      child: Text('Arbitrer',
          style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.w700)),
    );
  }
}
