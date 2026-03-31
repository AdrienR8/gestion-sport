import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/tournoi_service.dart';

class HorairesTab extends StatefulWidget {
  final List<MatchPoule> matchsPoule;
  final List<MatchArbre> matchsArbre;
  final VoidCallback onGenerer;

  const HorairesTab({
    super.key,
    required this.matchsPoule,
    required this.matchsArbre,
    required this.onGenerer,
  });

  @override
  State<HorairesTab> createState() => _HorairesTabState();
}

class _HorairesTabState extends State<HorairesTab> with SingleTickerProviderStateMixin {
  late TabController _sub;
  String _catPoule = 'R15M';
  String _catArbre = 'R15M';

  // Paramètres d'application automatique
  DateTime _debutAuto = DateTime(2025, 5, 10, 8, 0);
  int _intervalle = 30;
  String _terrainAuto = '';

  static const Map<String, Color> catColors = {
    'R15M': Color(0xFF1A5C2A),
    'R7M':  Color(0xFF8B4513),
    'R7F':  Color(0xFF6B1A5C),
  };

  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }

  void _appliquerAuto() async {
    final matchsCat = widget.matchsPoule.where((m) => m.cat == _catPoule).toList();
    DateTime current = _debutAuto;
    for (final m in matchsCat) {
      m.start = current;
      if (_terrainAuto.isNotEmpty) m.terrain = _terrainAuto;
      current = current.add(Duration(minutes: _intervalle));
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Horaires appliqués pour $_catPoule'), backgroundColor: catColors[_catPoule]),
    );
  }

  Future<void> _choisirDateDebut() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _debutAuto,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_debutAuto),
    );
    if (time == null) return;
    setState(() => _debutAuto = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} '
        '${dt.hour.toString().padLeft(2,'0')}h${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _sub,
            labelColor: const Color(0xFF1A5C2A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF1A5C2A),
            tabs: const [
              Tab(text: 'Matchs de poule'),
              Tab(text: 'Arbre de compétition'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _sub,
            children: [
              _buildPoule(),
              _buildArbre(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Onglet Poules ─────────────────────────────────────────────────────────
  Widget _buildPoule() {
    return Column(
      children: [
        // Barre paramètres auto
        Container(
          color: const Color(0xFFF8F8F5),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Application automatique des horaires', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Cat
                  ...categories.map((cat) => ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 11)),
                    selected: _catPoule == cat,
                    selectedColor: catColors[cat]!.withOpacity(0.15),
                    labelStyle: TextStyle(color: _catPoule == cat ? catColors[cat]! : Colors.grey),
                    side: BorderSide(color: _catPoule == cat ? catColors[cat]! : Colors.grey.shade300),
                    onSelected: (_) => setState(() => _catPoule = cat),
                  )),
                  const SizedBox(width: 8),
                  // Début
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(_fmt(_debutAuto), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    onPressed: _choisirDateDebut,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                  // Intervalle
                  SizedBox(
                    width: 100,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Intervalle (min)',
                        labelStyle: TextStyle(fontSize: 11),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: '$_intervalle')
                        ..selection = TextSelection.collapsed(offset: '$_intervalle'.length),
                      onChanged: (v) => _intervalle = int.tryParse(v) ?? 30,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                  // Terrain
                  SizedBox(
                    width: 140,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Terrain par défaut',
                        labelStyle: TextStyle(fontSize: 11),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (v) => _terrainAuto = v,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _appliquerAuto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: catColors[_catPoule],
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    child: const Text('Appliquer', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Tableau
        Expanded(
          child: _buildTablePoule(),
        ),
      ],
    );
  }

  Widget _buildTablePoule() {
    final matchs = widget.matchsPoule.where((m) => m.cat == _catPoule).toList();
    if (matchs.isEmpty) {
      return const Center(child: Text('Aucun match — vérifie que les poules sont remplies', style: TextStyle(color: Colors.grey)));
    }
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 36,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey),
        columns: const [
          DataColumn(label: Text('POULE')),
          DataColumn(label: Text('ÉQUIPE 1')),
          DataColumn(label: Text('ÉQUIPE 2')),
          DataColumn(label: Text('DATE / HEURE')),
          DataColumn(label: Text('TERRAIN')),
        ],
        rows: matchs.asMap().entries.map((entry) {
          final i = entry.key;
          final m = entry.value;
          final idx = widget.matchsPoule.indexOf(m);
          return DataRow(cells: [
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColors[m.cat]!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Poule ${m.poule}', style: TextStyle(fontSize: 11, color: catColors[m.cat]!, fontWeight: FontWeight.w600)),
              ),
            ),
            DataCell(Text(m.eq1.name, style: const TextStyle(fontSize: 12))),
            DataCell(Text(m.eq2.name, style: const TextStyle(fontSize: 12))),
            DataCell(_DateCell(
              value: m.start,
              onChanged: (dt) => setState(() => widget.matchsPoule[idx].start = dt),
            )),
            DataCell(_TerrainCell(
              value: m.terrain,
              onChanged: (v) => setState(() => widget.matchsPoule[idx].terrain = v),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  // ── Onglet Arbre ──────────────────────────────────────────────────────────
  Widget _buildArbre() {
    return Column(
      children: [
        Container(
          color: const Color(0xFFF8F8F5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat, style: const TextStyle(fontSize: 11)),
                  selected: _catArbre == cat,
                  selectedColor: catColors[cat]!.withOpacity(0.15),
                  labelStyle: TextStyle(color: _catArbre == cat ? catColors[cat]! : Colors.grey),
                  side: BorderSide(color: _catArbre == cat ? catColors[cat]! : Colors.grey.shade300),
                  onSelected: (_) => setState(() => _catArbre = cat),
                ),
              )),
              const Spacer(),
              Text(
                'Les équipes se rempliront automatiquement après les poules',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildTableArbre(),
        ),
      ],
    );
  }

  Widget _buildTableArbre() {
    final matchs = widget.matchsArbre.where((m) => m.cat == _catArbre).toList();
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 36,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey),
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('PHASE')),
          DataColumn(label: Text('DATE / HEURE')),
          DataColumn(label: Text('TERRAIN')),
        ],
        rows: matchs.asMap().entries.map((entry) {
          final m = entry.value;
          final idx = widget.matchsArbre.indexOf(m);
          return DataRow(cells: [
            DataCell(Text('${m.cat}${m.id}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E8D0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(m.phaseLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF8B6914), fontWeight: FontWeight.w600)),
              ),
            ),
            DataCell(_DateCell(
              value: m.start,
              onChanged: (dt) => setState(() => widget.matchsArbre[idx].start = dt),
            )),
            DataCell(_TerrainCell(
              value: m.terrain,
              onChanged: (v) => setState(() => widget.matchsArbre[idx].terrain = v),
            )),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Cellules éditables ────────────────────────────────────────────────────
class _DateCell extends StatelessWidget {
  final DateTime? value;
  final void Function(DateTime?) onChanged;
  const _DateCell({required this.value, required this.onChanged});

  String get _label {
    if (value == null) return 'Choisir...';
    return '${value!.day.toString().padLeft(2,'0')}/${value!.month.toString().padLeft(2,'0')} '
        '${value!.hour.toString().padLeft(2,'0')}h${value!.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(2025, 5, 10),
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
        );
        if (date == null) return;
        final time = await showTimePicker(
          context: context,
          initialTime: value != null ? TimeOfDay.fromDateTime(value!) : const TimeOfDay(hour: 9, minute: 0),
        );
        if (time == null) return;
        onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value != null ? const Color(0xFFEAF5EC) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: value != null ? const Color(0xFF90C99A) : const Color(0xFFE0E0E0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 12, color: value != null ? const Color(0xFF1A5C2A) : Colors.grey),
            const SizedBox(width: 5),
            Text(_label, style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: value != null ? const Color(0xFF1A5C2A) : Colors.grey,
            )),
          ],
        ),
      ),
    );
  }
}

class _TerrainCell extends StatefulWidget {
  final String? value;
  final void Function(String) onChanged;
  const _TerrainCell({required this.value, required this.onChanged});

  @override
  State<_TerrainCell> createState() => _TerrainCellState();
}

class _TerrainCellState extends State<_TerrainCell> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Terrain...',
          hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1A5C2A))),
        ),
      ),
    );
  }
}
