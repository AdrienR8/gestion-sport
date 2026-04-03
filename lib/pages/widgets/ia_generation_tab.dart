import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../services/ia_generation_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET GÉNÉRATION IA
// Remplace l'ancien GenerationTab basé sur la génération algorithmique
// ─────────────────────────────────────────────────────────────────────────────

class IaGenerationTab extends StatefulWidget {
  const IaGenerationTab({super.key});

  @override
  State<IaGenerationTab> createState() => _IaGenerationTabState();
}

class _IaGenerationTabState extends State<IaGenerationTab> {
  final _service = IaGenerationService();

  // ── État ──────────────────────────────────────────────────────────────────
  Uint8List? _excelBytes;
  String? _excelFileName;
  IaGenerationResult? _result;
  bool _enCours = false;
  double _progress = 0;
  final List<_LogEntry> _logs = [];
  final ScrollController _scrollCtrl = ScrollController();

  // ── Clé API ───────────────────────────────────────────────────────────────
  final TextEditingController _apiKeyCtrl = TextEditingController();
  bool _apiKeyVisible = false;
  bool get _apiKeyValide => _apiKeyCtrl.text.trim().startsWith('sk-ant-');

  // ── Filtres de preview ────────────────────────────────────────────────────
  String _catFiltre = 'Tous';
  String _typeFiltre = 'Poule'; // 'Poule' | 'Compétition'
  DateTime _dateBase = DateTime(2025, 5, 10);

  static const Map<String, Color> _catColors = {
    'R15M': Color(0xFF1A5C2A),
    'R7M':  Color(0xFF8B4513),
    'R7F':  Color(0xFF6B1A5C),
  };

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  // ── Zone clé API ─────────────────────────────────────────────────────────
  Widget _buildApiKeyZone() {
    final hasKey = _apiKeyValide;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasKey ? const Color(0xFFEAF5EC) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasKey ? const Color(0xFF2D9148) : const Color(0xFFFFB300),
          width: hasKey ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              hasKey ? Icons.check_circle_rounded : Icons.key_rounded,
              size: 16,
              color: hasKey ? const Color(0xFF2D9148) : const Color(0xFFE65100),
            ),
            const SizedBox(width: 8),
            Text(
              hasKey ? 'Clé API configurée ✓' : 'Clé API Anthropic requise',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: hasKey ? const Color(0xFF1A5C2A) : const Color(0xFF856404),
              ),
            ),
            const Spacer(),
            if (!hasKey)
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 12),
                label: const Text('Obtenir une clé', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  // Ouvre console.anthropic.com dans le navigateur
                  // Nécessite url_launcher si pas déjà présent
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF856404),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: !_apiKeyVisible,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'sk-ant-api03-XXXXXXXXXXXXXXXX...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1A5C2A), width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _apiKeyVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _apiKeyVisible = !_apiKeyVisible),
                tooltip: _apiKeyVisible ? 'Masquer la clé' : 'Afficher la clé',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.lock_outline, size: 11, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              'Stockée en mémoire uniquement — jamais sauvegardée ni envoyée ailleurs qu\'à Anthropic.',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Upload du fichier Excel ───────────────────────────────────────────────
  Future<void> _pickExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _excelBytes   = file.bytes;
      _excelFileName = file.name;
      _result       = null;
      _logs.clear();
    });
  }

  // ── Choix de la date du tournoi ───────────────────────────────────────────
  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateBase,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'Date du tournoi (Jour 1)',
    );
    if (date != null) setState(() => _dateBase = date);
  }

  String get _dateBaseStr =>
      '${_dateBase.year}-${_dateBase.month.toString().padLeft(2,'0')}-${_dateBase.day.toString().padLeft(2,'0')}';

  // ── Appel IA ──────────────────────────────────────────────────────────────
  Future<void> _lancerGeneration() async {
    if (_excelBytes == null) return;

    final confirmed = await _showConfirmDialog();
    if (confirmed != true) return;

    setState(() {
      _enCours  = true;
      _progress = 0;
      _logs.clear();
      _result   = null;
    });

    try {
      _addLog('━━ Étape 1 : Analyse du fichier par Claude IA', false);

      final result = await _service.genererDepuisExcel(
        excelBytes: _excelBytes!,
        dateBase:   _dateBaseStr,
        apiKey:     _apiKeyCtrl.text.trim(),
        onLog:      (msg) => _addLog(msg, false),
      );

      setState(() => _result = result);

      if (result.erreur != null) {
        _addLog('✗ ${result.erreur}', true);
        setState(() => _enCours = false);
        return;
      }

      _addLog('', false);
      _addLog('━━ Étape 2 : Insertion en base de données', false);

      await _service.insererEnBase(
        matchsPoule: result.matchsPoule,
        matchsArbre: result.matchsArbre,
        onLog:      (msg) => _addLog(msg, false),
        onProgress: (p)   => setState(() => _progress = p),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Génération IA terminée ! 🎉'),
          backgroundColor: Color(0xFF1A5C2A),
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      _addLog('ERREUR FATALE : $e', true);
    }

    setState(() => _enCours = false);
  }

  void _addLog(String msg, bool isError) {
    setState(() => _logs.add(_LogEntry(msg, isError)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<bool?> _showConfirmDialog() {
    final nbPoule = _result?.matchsPoule.length ?? '?';
    final nbArbre = _result?.matchsArbre.length ?? '?';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la génération IA',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cette action va :'),
            const SizedBox(height: 8),
            _bullet('Envoyer le fichier Excel à Claude IA'),
            _bullet('Vider les tables de matchs existantes'),
            _bullet('Insérer les matchs générés en base'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD700)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFF856404), size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Cette opération est irréversible.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF856404)))),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5C2A)),
            child: const Text('Lancer la génération IA'),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      const Text('  •  ', style: TextStyle(fontSize: 14)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildApiKeyZone(),
          const SizedBox(height: 20),
          _buildUploadZone(),
          const SizedBox(height: 20),
          _buildConfig(),
          const SizedBox(height: 20),
          _buildBoutonGenerer(),
          if (_enCours) ...[
            const SizedBox(height: 16),
            _buildProgress(),
          ],
          if (_result != null && _result!.erreur == null) ...[
            const SizedBox(height: 24),
            _buildPreview(),
          ],
          if (_logs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildLog(),
          ],
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A5C2A), const Color(0xFF2D9148)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Génération IA', style: TextStyle(
                color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w900, letterSpacing: -0.5,
              )),
              SizedBox(height: 4),
              Text(
                'Dépose ton fichier Excel de planning — Claude analyse et génère tous les matchs automatiquement.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Zone upload ───────────────────────────────────────────────────────────
  Widget _buildUploadZone() {
    final hasFile = _excelBytes != null;
    return GestureDetector(
      onTap: _enCours ? null : _pickExcel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFEAF5EC) : const Color(0xFFF8F8F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile ? const Color(0xFF2D9148) : const Color(0xFFDDDDDD),
            width: hasFile ? 2 : 1.5,
            style: hasFile ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.upload_file_rounded,
              size: 48,
              color: hasFile ? const Color(0xFF2D9148) : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              hasFile ? _excelFileName! : 'Cliquer pour déposer le fichier Excel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasFile ? FontWeight.w700 : FontWeight.w400,
                color: hasFile ? const Color(0xFF1A5C2A) : Colors.grey.shade500,
              ),
            ),
            if (hasFile) ...[
              const SizedBox(height: 6),
              Text(
                '${(_excelBytes!.length / 1024).toStringAsFixed(1)} Ko · Cliquer pour changer',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Formats acceptés : .xlsx, .xls',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Config date ───────────────────────────────────────────────────────────
  Widget _buildConfig() {
    return Row(children: [
      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
      const SizedBox(width: 8),
      Text('Date du tournoi (Jour 1) :',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.edit_calendar, size: 14),
        label: Text(_dateBaseStr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        onPressed: _enCours ? null : _choisirDate,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          side: const BorderSide(color: Color(0xFF1A5C2A)),
          foregroundColor: const Color(0xFF1A5C2A),
        ),
      ),
    ]);
  }

  // ── Bouton principal ──────────────────────────────────────────────────────
  Widget _buildBoutonGenerer() {
    final ready = _excelBytes != null && !_enCours && _apiKeyValide;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD4B0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prêt à générer ?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Claude va analyser le fichier Excel, extraire tous les matchs et les insérer directement en base Supabase.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: ready ? _lancerGeneration : null,
            icon: _enCours
                ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.auto_awesome),
            label: Text(_enCours
                ? 'Génération en cours...'
                : !_apiKeyValide
                ? 'Clé API requise'
                : _excelBytes == null
                ? 'Déposer un fichier Excel d\'abord'
                : 'Générer avec Claude IA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ready ? const Color(0xFF1A5C2A) : Colors.grey.shade300,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barre de progression ──────────────────────────────────────────────────
  Widget _buildProgress() {
    return Column(children: [
      LinearProgressIndicator(
        value: _progress > 0 ? _progress : null,
        backgroundColor: const Color(0xFFE0E0E0),
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D9148)),
        minHeight: 6,
        borderRadius: BorderRadius.circular(10),
      ),
      const SizedBox(height: 8),
      Text(
        _progress > 0 ? '${(_progress * 100).round()}% inséré en base' : 'Claude analyse le fichier...',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    ]);
  }

  // ── Preview des matchs générés ────────────────────────────────────────────
  Widget _buildPreview() {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats
        Row(children: [
          _StatCard(
            label: 'Matchs de poule',
            value: '${result.matchsPoule.length}',
            color: const Color(0xFF1A5C2A),
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Matchs compétition',
            value: '${result.matchsArbre.length}',
            color: const Color(0xFFD95F1A),
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Total',
            value: '${result.matchsPoule.length + result.matchsArbre.length}',
            color: const Color(0xFF1A6B9A),
          ),
        ]),
        const SizedBox(height: 20),

        // Filtres
        const Text('PRÉVISUALISATION',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: Colors.grey, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Row(children: [
          // Type
          ...['Poule', 'Compétition'].map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(t, style: const TextStyle(fontSize: 11)),
              selected: _typeFiltre == t,
              selectedColor: const Color(0xFF1A5C2A).withOpacity(0.15),
              labelStyle: TextStyle(
                  color: _typeFiltre == t ? const Color(0xFF1A5C2A) : Colors.grey,
                  fontWeight: _typeFiltre == t ? FontWeight.w700 : FontWeight.normal),
              side: BorderSide(color: _typeFiltre == t ? const Color(0xFF1A5C2A) : Colors.grey.shade300),
              onSelected: (_) => setState(() => _typeFiltre = t),
            ),
          )),
          const SizedBox(width: 12),
          // Catégorie
          ...['Tous', 'R15M', 'R7M', 'R7F'].map((c) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(c, style: const TextStyle(fontSize: 11)),
              selected: _catFiltre == c,
              selectedColor: (_catColors[c] ?? const Color(0xFF444444)).withOpacity(0.15),
              labelStyle: TextStyle(
                  color: _catFiltre == c
                      ? (_catColors[c] ?? const Color(0xFF444444))
                      : Colors.grey),
              side: BorderSide(
                  color: _catFiltre == c
                      ? (_catColors[c] ?? const Color(0xFF444444))
                      : Colors.grey.shade300),
              onSelected: (_) => setState(() => _catFiltre = c),
            ),
          )),
        ]),
        const SizedBox(height: 12),

        // Tableau
        if (_typeFiltre == 'Poule')
          _buildTablePoule(result.matchsPoule)
        else
          _buildTableArbre(result.matchsArbre),
      ],
    );
  }

  Widget _buildTablePoule(List<MatchPouleIA> matchs) {
    final filtered = matchs.where((m) =>
    _catFiltre == 'Tous' || m.categorie == _catFiltre).toList();

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 36,
          dataRowMinHeight: 44,
          headingTextStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey),
          columns: const [
            DataColumn(label: Text('CAT')),
            DataColumn(label: Text('POULE')),
            DataColumn(label: Text('ÉQUIPE 1')),
            DataColumn(label: Text('ÉQUIPE 2')),
            DataColumn(label: Text('HORAIRE')),
            DataColumn(label: Text('TERRAIN')),
          ],
          rows: filtered.map((m) {
            final color = _catColors[m.categorie] ?? Colors.grey;
            return DataRow(cells: [
              DataCell(_catBadge(m.categorie, color)),
              DataCell(Text('Poule ${m.poule}',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
              DataCell(Text(m.equipe1, style: const TextStyle(fontSize: 12))),
              DataCell(Text(m.equipe2, style: const TextStyle(fontSize: 12))),
              DataCell(Text(_formatHeure(m.start),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
              DataCell(Text(m.terrain, style: const TextStyle(fontSize: 11))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTableArbre(List<MatchArbreIA> matchs) {
    final filtered = matchs.where((m) =>
    _catFiltre == 'Tous' || m.categorie == _catFiltre).toList();

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 36,
          dataRowMinHeight: 44,
          headingTextStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey),
          columns: const [
            DataColumn(label: Text('CAT')),
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('PHASE')),
            DataColumn(label: Text('HORAIRE')),
            DataColumn(label: Text('TERRAIN')),
          ],
          rows: filtered.map((m) {
            final color = _catColors[m.categorie] ?? Colors.grey;
            return DataRow(cells: [
              DataCell(_catBadge(m.categorie, color)),
              DataCell(Text(m.id,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E8D0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(m.phaseLabel,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8B6914),
                        fontWeight: FontWeight.w600)),
              )),
              DataCell(Text(_formatHeure(m.start),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
              DataCell(Text(m.terrain, style: const TextStyle(fontSize: 11))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _catBadge(String cat, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(cat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
  );

  // ── Journal d'exécution ───────────────────────────────────────────────────
  Widget _buildLog() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text("Journal d'exécution",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _logs.length,
              itemBuilder: (ctx, i) {
                final entry = _logs[i];
                if (entry.msg.isEmpty) return const SizedBox(height: 4);
                Color color;
                if (entry.isError)              color = const Color(0xFFE74C3C);
                else if (entry.msg.startsWith('━━')) color = const Color(0xFF5BA4CF);
                else if (entry.msg.startsWith('  ✓')) color = const Color(0xFF7DD99A);
                else if (entry.msg.startsWith('  ✗')) color = const Color(0xFFE74C3C);
                else if (entry.msg.startsWith('✓')) color = const Color(0xFF2ECC71);
                else if (entry.msg.startsWith('📤')) color = const Color(0xFFE8B84B);
                else color = const Color(0xFF888888);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(entry.msg,
                      style: TextStyle(fontSize: 11, color: color,
                          fontFamily: 'monospace', height: 1.5)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatHeure(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2,'0')}h${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _LogEntry {
  final String msg;
  final bool isError;
  _LogEntry(this.msg, this.isError);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(children: [
            Text(value, style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
