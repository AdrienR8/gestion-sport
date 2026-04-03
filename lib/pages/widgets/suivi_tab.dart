import 'package:flutter/material.dart';
import '../../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUIVI TAB — vue d'ensemble poules + arbre de compétition
// Onglet 4 de TiragePage
// ─────────────────────────────────────────────────────────────────────────────

class SuiviTab extends StatefulWidget {
  final List<MatchPoule> matchsPoule;
  final List<MatchArbre> matchsArbre;

  /// Callbacks de mise à jour (identiques à ceux de HorairesTab)
  final void Function(int idx, DateTime? dt) onPouleDate;
  final void Function(int idx, String terrain) onPouleTerrain;
  final void Function(int idx, DateTime? dt) onArbreDate;
  final void Function(int idx, String terrain) onArbreTerrain;

  const SuiviTab({
    super.key,
    required this.matchsPoule,
    required this.matchsArbre,
    required this.onPouleDate,
    required this.onPouleTerrain,
    required this.onArbreDate,
    required this.onArbreTerrain,
  });

  @override
  State<SuiviTab> createState() => _SuiviTabState();
}

class _SuiviTabState extends State<SuiviTab> {
  String _cat = 'R15M';
  bool _modeArbre = false; // false = poules, true = arbre

  static const Map<String, Color> _catColors = {
    'R15M': Color(0xFF1A5C2A),
    'R7M': Color(0xFF8B4513),
    'R7F': Color(0xFF6B1A5C),
  };

  static const Map<String, String> _catLabels = {
    'R15M': 'Rugby XV Masculin',
    'R7M': 'Rugby VII Masculin',
    'R7F': 'Rugby VII Féminin',
  };

  static const List<String> _categories = ['R15M', 'R7M', 'R7F'];
  static const List<String> _poules = ['A', 'B', 'C', 'D', 'E', 'F'];
  static const List<String> _niveaux = ['1', '2', '3', '4'];
  static const Map<String, String> _phaseLabels = {
    '1': '1/8 de finale',
    '2': '1/4 de finale',
    '3': '1/2 finale',
    '4': 'Finale',
  };

  Color get _color => _catColors[_cat]!;

  // ── Stats rapides ────────────────────────────────────────────────────────

  int _nbMatchsPoule(String cat) =>
      widget.matchsPoule.where((m) => m.cat == cat).length;

  int _nbAvecHoraire(String cat) =>
      widget.matchsPoule.where((m) => m.cat == cat && m.start != null).length;

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        const Divider(height: 1),
        Expanded(
          child: _modeArbre ? _buildArbre() : _buildPoules(),
        ),
      ],
    );
  }

  // ── Barre de contrôle ────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Sélecteur catégorie
          ...(_categories.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_catLabels[cat]!,
                  style: const TextStyle(fontSize: 11)),
              selected: _cat == cat,
              selectedColor: _catColors[cat]!.withOpacity(0.15),
              labelStyle: TextStyle(
                color: _cat == cat ? _catColors[cat]! : Colors.grey,
                fontWeight:
                _cat == cat ? FontWeight.w700 : FontWeight.normal,
              ),
              side: BorderSide(
                  color: _cat == cat
                      ? _catColors[cat]!
                      : Colors.grey.shade300),
              onSelected: (_) => setState(() => _cat = cat),
            ),
          ))),
          const Spacer(),
          // Toggle poules / arbre
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggleBtn('Poules', !_modeArbre, () {
                  setState(() => _modeArbre = false);
                }),
                _toggleBtn('Arbre', _modeArbre, () {
                  setState(() => _modeArbre = true);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VUE POULES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPoules() {
    final matchsCat =
    widget.matchsPoule.where((m) => m.cat == _cat).toList();

    if (matchsCat.isEmpty) {
      return _emptyState(
        'Aucun match de poule généré',
        'Complète le tirage et génère les matchs dans l\'onglet Horaires.',
      );
    }

    // Regrouper par poule
    final Map<String, List<MatchPoule>> parPoule = {};
    for (final m in matchsCat) {
      parPoule.putIfAbsent(m.poule, ()=>[] ).add(m);
    }

    // Stats rapides en haut
    final total = matchsCat.length;
    final avecHoraire = matchsCat.where((m) => m.start != null).length;

    return Column(
      children: [
        // Bandeau stats
        _bandeauStats(total, avecHoraire),
        // Grille de poules
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _poules
                  .where((p) => parPoule.containsKey(p))
                  .map((p) => _pouleCard(p, parPoule[p]!))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bandeauStats(int total, int avecHoraire) {
    final pct =
    total == 0 ? 0.0 : avecHoraire / total;
    final ok = avecHoraire == total && total > 0;

    return Container(
      color: const Color(0xFFF8F8F5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.pending_outlined,
            size: 16,
            color: ok ? const Color(0xFF2D9148) : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            '$avecHoraire / $total matchs avec horaire',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
              ok ? const Color(0xFF2D9148) : Colors.orange.shade800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor:
                AlwaysStoppedAnimation<Color>(ok ? const Color(0xFF2D9148) : Colors.orange),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pouleCard(String poule, List<MatchPoule> matchs) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.07),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Text(
                  'Poule $poule',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _color,
                  ),
                ),
                const Spacer(),
                Text(
                  '${matchs.length} match${matchs.length > 1 ? 's' : ''}',
                  style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Matchs
          ...matchs.asMap().entries.map((entry) {
            final idx = widget.matchsPoule.indexOf(entry.value);
            return _matchPouleRow(entry.value, idx);
          }),
        ],
      ),
    );
  }

  Widget _matchPouleRow(MatchPoule m, int globalIdx) {
    final hasDate = m.start != null;
    final hasTerrain =
        m.terrain != null && m.terrain!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          // Équipes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.eq1.name}  vs  ${m.eq2.name}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _badge(
                      hasDate
                          ? _fmtDate(m.start!)
                          : 'Sans horaire',
                      hasDate
                          ? const Color(0xFFEAF5EC)
                          : const Color(0xFFFFF3CD),
                      hasDate
                          ? const Color(0xFF1A5C2A)
                          : const Color(0xFF856404),
                      Icons.access_time,
                    ),
                    if (hasTerrain) ...[
                      const SizedBox(width: 6),
                      _badge(
                        m.terrain!,
                        const Color(0xFFF0F0F0),
                        Colors.grey.shade600,
                        Icons.place_outlined,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Bouton édition
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: Colors.grey.shade400,
            tooltip: 'Modifier horaire / terrain',
            onPressed: () => _ouvrirEditPoule(m, globalIdx),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VUE ARBRE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildArbre() {
    final matchsCat =
    widget.matchsArbre.where((m) => m.cat == _cat).toList();

    if (matchsCat.isEmpty) {
      return _emptyState(
        'Aucun match de compétition généré',
        'Génère les matchs dans l\'onglet Horaires.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _niveaux.map((niveau) {
            final matchsNiveau = matchsCat
                .where((m) => m.niveau == niveau)
                .toList();
            if (matchsNiveau.isEmpty) return const SizedBox.shrink();
            return _colonneArbre(niveau, matchsNiveau);
          }).toList(),
        ),
      ),
    );
  }

  Widget _colonneArbre(String niveau, List<MatchArbre> matchs) {
    // Espacement vertical croissant selon le niveau (comme dans l'app)
    final double espacement = () {
      switch (niveau) {
        case '1': return 8.0;
        case '2': return 56.0;
        case '3': return 148.0;
        case '4': return 340.0;
        default:  return 8.0;
      }
    }();

    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre du niveau
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _phaseLabels[niveau] ?? 'Niveau $niveau',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _color,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Matchs
          ...matchs.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            final globalIdx = widget.matchsArbre.indexOf(m);
            return Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : espacement,
                bottom: 0,
              ),
              child: _arbreCard(m, globalIdx),
            );
          }),
        ],
      ),
    );
  }

  Widget _arbreCard(MatchArbre m, int globalIdx) {
    final hasDate = m.start != null;
    final hasTerrain =
        m.terrain != null && m.terrain!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // ID + horaire
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.05),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Text(
                  '${m.cat}${m.id}',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                // Statut horaire
                _badge(
                  hasDate ? _fmtDate(m.start!) : 'À planifier',
                  hasDate
                      ? const Color(0xFFEAF5EC)
                      : const Color(0xFFFFF3CD),
                  hasDate
                      ? const Color(0xFF1A5C2A)
                      : const Color(0xFF856404),
                  Icons.access_time,
                ),
              ],
            ),
          ),
          // Équipes placeholder
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                _equipeRow('Équipe A', false),
                const SizedBox(height: 6),
                _equipeRow('Équipe B', false),
                if (hasTerrain) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(m.terrain!,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Bouton édition
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: TextButton.icon(
              onPressed: () => _ouvrirEditArbre(m, globalIdx),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Modifier horaire / terrain',
                  style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade500,
                padding: const EdgeInsets.symmetric(vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _equipeRow(String label, bool gagnant) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gagnant
            ? const Color(0xFFEAF5EC)
            : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: gagnant
                ? const Color(0xFF90C99A)
                : const Color(0xFFEEEEEE)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight:
          gagnant ? FontWeight.w700 : FontWeight.normal,
          color: gagnant
              ? const Color(0xFF1A5C2A)
              : Colors.grey.shade500,
          fontStyle:
          gagnant ? FontStyle.normal : FontStyle.italic,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS D'ÉDITION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _ouvrirEditPoule(MatchPoule m, int idx) async {
    await _editDialog(
      titre:
      '${m.eq1.name}  vs  ${m.eq2.name}',
      sousTitre: '${m.cat} — Poule ${m.poule}',
      dateInitiale: m.start,
      terrainInitial: m.terrain ?? '',
      color: _color,
      onSave: (dt, terrain) {
        widget.onPouleDate(idx, dt);
        widget.onPouleTerrain(idx, terrain);
        setState(() {});
      },
    );
  }

  Future<void> _ouvrirEditArbre(MatchArbre m, int idx) async {
    await _editDialog(
      titre: _phaseLabels[m.niveau] ?? 'Niveau ${m.niveau}',
      sousTitre: '${m.cat}${m.id}',
      dateInitiale: m.start,
      terrainInitial: m.terrain ?? '',
      color: _color,
      onSave: (dt, terrain) {
        widget.onArbreDate(idx, dt);
        widget.onArbreTerrain(idx, terrain);
        setState(() {});
      },
    );
  }

  Future<void> _editDialog({
    required String titre,
    required String sousTitre,
    required DateTime? dateInitiale,
    required String terrainInitial,
    required Color color,
    required void Function(DateTime? dt, String terrain) onSave,
  }) async {
    DateTime? selectedDate = dateInitiale;
    final terrainCtrl =
    TextEditingController(text: terrainInitial);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titre,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sousTitre,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sélecteur date/heure
              const Text('Date & Heure',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate:
                    selectedDate ?? DateTime(2025, 5, 10),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: selectedDate != null
                        ? TimeOfDay.fromDateTime(selectedDate!)
                        : const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (time == null) return;
                  setLocal(() {
                    selectedDate = DateTime(date.year, date.month,
                        date.day, time.hour, time.minute);
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedDate != null
                        ? const Color(0xFFEAF5EC)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedDate != null
                          ? const Color(0xFF90C99A)
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14,
                          color: selectedDate != null
                              ? color
                              : Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        selectedDate != null
                            ? _fmtDate(selectedDate!)
                            : 'Choisir une date…',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: selectedDate != null
                              ? color
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Terrain
              const Text('Terrain',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey)),
              const SizedBox(height: 6),
              TextField(
                controller: terrainCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Nom du terrain…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                    const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                    const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: color),
                  ),
                  prefixIcon: Icon(Icons.place_outlined,
                      size: 16, color: Colors.grey.shade400),
                ),
              ),
              if (selectedDate != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setLocal(() => selectedDate = null),
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Supprimer l\'horaire',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(selectedDate, terrainCtrl.text.trim());
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    terrainCtrl.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _badge(
      String label, Color bg, Color fg, IconData icon) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ],
      ),
    );
  }

  Widget _emptyState(String titre, String sous) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_rugby_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(titre,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey)),
          const SizedBox(height: 6),
          Text(sous,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade400),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}h'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
