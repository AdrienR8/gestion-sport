import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/tournoi_service.dart';

class GenerationTab extends StatefulWidget {
  final Map<String, Map<String, List<Equipe>>> poulesParCat;
  final List<MatchPoule> matchsPoule;
  final List<MatchArbre> matchsArbre;
  final TournoisService service;
  final VoidCallback onGenerer;

  const GenerationTab({
    super.key,
    required this.poulesParCat,
    required this.matchsPoule,
    required this.matchsArbre,
    required this.service,
    required this.onGenerer,
  });

  @override
  State<GenerationTab> createState() => _GenerationTabState();
}

class _GenerationTabState extends State<GenerationTab> {
  bool _enCours = false;
  double _progress = 0;
  final List<_LogEntry> _logs = [];
  final ScrollController _scrollCtrl = ScrollController();

  static const Map<String, Color> catColors = {
    'R15M': Color(0xFF1A5C2A),
    'R7M':  Color(0xFF8B4513),
    'R7F':  Color(0xFF6B1A5C),
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  int get _totalPoule => widget.matchsPoule.length;
  int get _totalArbre => widget.matchsArbre.length;
  int get _totalEquipes => categories.fold(0, (s, c) =>
  s + poules.fold<int>(0, (ss, p) => ss + (widget.poulesParCat[c]?[p]?.length ?? 0)));

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

  Future<void> _lancer() async {
    // Vérification
    final issues = <String>[];
    for (final cat in categories) {
      final placees = poules.fold<int>(0, (s, p) => s + (widget.poulesParCat[cat]?[p]?.length ?? 0));
      final total = widget.matchsPoule.where((m) => m.cat == cat).isEmpty
          ? 0
          : widget.poulesParCat[cat]!.values.expand((e) => e).toSet().length;
      if (placees == 0) continue;
      // comparer avec nb equipes total dans les poules de cette cat
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la génération', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cette action va :'),
            const SizedBox(height: 8),
            _bulletPoint('Vider les tables de poules et d\'arbre existantes'),
            _bulletPoint('Insérer $_totalPoule matchs de poule'),
            _bulletPoint('Insérer $_totalArbre matchs de compétition'),
            _bulletPoint('Mettre à jour $_totalEquipes équipes dans Supabase'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD700)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFF856404), size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('Cette opération est irréversible.', style: TextStyle(fontSize: 12, color: Color(0xFF856404)))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD95F1A)),
            child: const Text('Générer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _enCours = true;
      _progress = 0;
      _logs.clear();
    });

    try {
      await widget.service.genererTout(
        poulesParCat: widget.poulesParCat,
        matchsPoule: widget.matchsPoule,
        matchsArbre: widget.matchsArbre,
        onLog: (msg, isError) => _addLog(msg, isError),
        onProgress: (p) => setState(() => _progress = p),
      );
      _addLog('', false);
      _addLog('✓ Génération terminée avec succès !', false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Génération terminée ! 🎉'),
            backgroundColor: Color(0xFF1A5C2A),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _addLog('ERREUR FATALE : $e', true);
    }

    setState(() => _enCours = false);
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Text('  •  ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques
          _buildStats(),
          const SizedBox(height: 20),

          // Récap par catégorie
          _buildRecap(),
          const SizedBox(height: 20),

          // Bouton génération + progression
          _buildActions(),
          const SizedBox(height: 16),

          // Log
          if (_logs.isNotEmpty) _buildLog(),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        _StatCard(label: 'Matchs de poule', value: '$_totalPoule', color: const Color(0xFF1A5C2A)),
        const SizedBox(width: 12),
        _StatCard(label: 'Matchs compétition', value: '$_totalArbre', color: const Color(0xFFD95F1A)),
        const SizedBox(width: 12),
        _StatCard(label: 'Équipes à MAJ', value: '$_totalEquipes', color: const Color(0xFF6B1A5C)),
        const SizedBox(width: 12),
        _StatCard(label: 'Total opérations', value: '${_totalPoule + _totalArbre + _totalEquipes}', color: const Color(0xFF1A6B9A)),
      ],
    );
  }

  Widget _buildRecap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.map((cat) {
        final color = catColors[cat]!;
        final matchsCat = widget.matchsPoule.where((m) => m.cat == cat).toList();
        final sansHoraire = matchsCat.where((m) => m.start == null).length;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(cat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                    ),
                    const SizedBox(width: 10),
                    Text('${matchsCat.length} matchs de poule', style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    if (sansHoraire > 0)
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('$sansHoraire sans horaire', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                        ],
                      )
                    else if (matchsCat.isNotEmpty)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Color(0xFF2D9148)),
                          SizedBox(width: 4),
                          Text('Horaires OK', style: TextStyle(fontSize: 11, color: Color(0xFF2D9148))),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: poules.map((p) {
                    final eqs = widget.poulesParCat[cat]?[p] ?? [];
                    if (eqs.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Poule $p', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                          const SizedBox(height: 3),
                          ...eqs.map((e) => Text(e.name, style: const TextStyle(fontSize: 11))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD4B0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tout est prêt ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Cette action insère tous les matchs et met à jour les équipes dans Supabase.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          if (_enCours) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D9148)),
              minHeight: 6,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 8),
            Text('${(_progress * 100).round()}% effectué', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: _enCours ? null : _lancer,
            icon: _enCours
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.rocket_launch_rounded),
            label: Text(_enCours ? 'Génération en cours...' : 'Générer dans Supabase'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD95F1A),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLog() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Journal d\'exécution', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
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
                if (entry.isError) color = const Color(0xFFE74C3C);
                else if (entry.msg.startsWith('━━')) color = const Color(0xFF5BA4CF);
                else if (entry.msg.startsWith('  ✓')) color = const Color(0xFF7DD99A);
                else if (entry.msg.startsWith('  ✗')) color = const Color(0xFFE74C3C);
                else color = const Color(0xFF888888);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    entry.msg,
                    style: TextStyle(fontSize: 11, color: color, fontFamily: 'monospace', height: 1.5),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
