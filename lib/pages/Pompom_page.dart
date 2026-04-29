import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

// ════════════════════════════════════════════════════════════════════════════
// MODÈLE
// ════════════════════════════════════════════════════════════════════════════

class PomPomEquipe {
  final String id;
  final String school;
  final String name;
  String finale;          // "oui" | "non"
  int podium;             // 0, 1, 2, 3
  int ordrePassage;       // 0, 1, 2, …
  int ordreFinale;        // 0, 1, 2, … (ordre de passage en finale)
  bool enCours;           // true = passage en cours (un seul à la fois)
  String? description;
  String? image;

  PomPomEquipe({
    required this.id,
    required this.school,
    required this.name,
    required this.finale,
    required this.podium,
    required this.ordrePassage,
    required this.ordreFinale,
    required this.enCours,
    this.description,
    this.image,
  });

  factory PomPomEquipe.fromJson(Map<String, dynamic> j) => PomPomEquipe(
    id:           j['id']?.toString() ?? '',
    school:       j['school']?.toString() ?? '',
    name:         j['name']?.toString() ?? '',
    finale:       j['final']?.toString() ?? 'non',
    podium:       (j['Podium'] as num?)?.toInt() ?? 0,
    ordrePassage: (j['ordrePassage'] as num?)?.toInt() ?? 0,
    ordreFinale:  (j['ordre_final'] as num?)?.toInt() ?? 0,
    enCours:      j['en_cours'] == true,
    description:  j['description']?.toString(),
    image:        j['image']?.toString(),
  );

  PomPomEquipe copyWith({
    String? finale,
    int? podium,
    int? ordrePassage,
    int? ordreFinale,
    bool? enCours,
    String? description,
    String? image,
  }) =>
      PomPomEquipe(
        id:           id,
        school:       school,
        name:         name,
        finale:       finale ?? this.finale,
        podium:       podium ?? this.podium,
        ordrePassage: ordrePassage ?? this.ordrePassage,
        ordreFinale:  ordreFinale ?? this.ordreFinale,
        enCours:      enCours ?? this.enCours,
        description:  description ?? this.description,
        image:        image ?? this.image,
      );
}

// ════════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ════════════════════════════════════════════════════════════════════════════

class PomPomPage extends StatefulWidget {
  const PomPomPage({super.key});

  @override
  State<PomPomPage> createState() => _PomPomPageState();
}

class _PomPomPageState extends State<PomPomPage> {
  // ── État ─────────────────────────────────────────────────────────────────
  List<PomPomEquipe> _equipes = [];
  bool _chargement = true;
  bool _syncEnCours = false;
  bool _sauvegardeEnCours = false;
  String? _erreur;

  // id de l'équipe dont le toggle en_cours est en cours de traitement
  String? _toggleEnCoursId;

  // Modifications en attente (id → équipe modifiée)
  final Map<String, PomPomEquipe> _modifications = {};

  static const _couleurPP = Color(0xFFB5338A);

  // ── Chargement ────────────────────────────────────────────────────────────
  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
      _modifications.clear();
    });
    try {
      final data = await _supabase
          .from('PomPom')
          .select()
          .order('ordrePassage', ascending: true);
      setState(() {
        _equipes =
            (data as List).map((j) => PomPomEquipe.fromJson(j)).toList();
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  // ── Toggle en_cours (un seul autorisé à la fois) ──────────────────────────
  Future<void> _toggleEnCours(String id) async {
    // Récupère l'équipe courante (depuis modifications ou liste)
    final equipe =
        _modifications[id] ?? _equipes.firstWhere((e) => e.id == id);
    final nouvelEtat = !equipe.enCours;

    setState(() => _toggleEnCoursId = id);

    try {
      if (nouvelEtat) {
        // 1. Remettre TOUTES les équipes à false en DB
        await _supabase
            .from('PomPom')
            .update({'en_cours': false})
            .neq('id', id);

        // 2. Mettre CETTE équipe à true
        await _supabase
            .from('PomPom')
            .update({'en_cours': true})
            .eq('id', id);

        // 3. Refléter localement : toutes à false puis celle-ci à true
        setState(() {
          for (int i = 0; i < _equipes.length; i++) {
            _equipes[i] = _equipes[i].copyWith(enCours: false);
            // Annule aussi les éventuelles modifications pendantes sur ce champ
            if (_modifications.containsKey(_equipes[i].id)) {
              _modifications[_equipes[i].id] =
                  _modifications[_equipes[i].id]!.copyWith(enCours: false);
            }
          }
          final idx = _equipes.indexWhere((e) => e.id == id);
          if (idx != -1) _equipes[idx] = _equipes[idx].copyWith(enCours: true);
          if (_modifications.containsKey(id)) {
            _modifications[id] = _modifications[id]!.copyWith(enCours: true);
          }
        });

        _showSnack('▶ ${equipe.name} — passage démarré');
      } else {
        // Remettre uniquement cette équipe à false
        await _supabase
            .from('PomPom')
            .update({'en_cours': false})
            .eq('id', id);

        setState(() {
          final idx = _equipes.indexWhere((e) => e.id == id);
          if (idx != -1) {
            _equipes[idx] = _equipes[idx].copyWith(enCours: false);
          }
          if (_modifications.containsKey(id)) {
            _modifications[id] = _modifications[id]!.copyWith(enCours: false);
          }
        });

        _showSnack('⏹ ${equipe.name} — passage terminé', isInfo: true);
      }
    } catch (e) {
      _showSnack('Erreur : ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _toggleEnCoursId = null);
    }
  }

  // ── Synchronisation description + image depuis Formulaires ────────────────
  Future<void> _synchroniser() async {
    setState(() => _syncEnCours = true);
    try {
      final formulaires = await _supabase
          .from('Formulaires')
          .select('Ecole, description_equipe, photo_equipe_url')
          .not('description_equipe', 'is', null)
          .neq('description_equipe', '');

      final listeFormulaires = formulaires as List;

      final Map<String, Map<String, dynamic>> indexEcole = {
        for (final f in listeFormulaires)
          (f['Ecole'] ?? '').toString(): f,
      };

      int nbMaj = 0;
      for (final equipe in _equipes) {
        final formulaire = indexEcole[equipe.school];
        if (formulaire == null) continue;

        final desc  = formulaire['description_equipe']?.toString() ?? '';
        final image = formulaire['photo_equipe_url']?.toString() ?? '';

        if (desc.isEmpty) continue;

        await _supabase.from('PomPom').update({
          'description': desc,
          if (image.isNotEmpty) 'image': image,
        }).eq('id', equipe.id);

        nbMaj++;
      }

      _showSnack(
        nbMaj > 0
            ? '$nbMaj équipe${nbMaj > 1 ? 's' : ''} synchronisée${nbMaj > 1 ? 's' : ''}'
            : 'Aucune correspondance trouvée',
        isInfo: nbMaj == 0,
      );

      await _charger();
    } catch (e) {
      _showSnack('Erreur de synchronisation : $e', isError: true);
    } finally {
      if (mounted) setState(() => _syncEnCours = false);
    }
  }

  // ── Sauvegarde de toutes les modifications en attente ─────────────────────
  Future<void> _sauvegarderTout() async {
    if (_modifications.isEmpty) return;
    setState(() => _sauvegardeEnCours = true);
    try {
      for (final entry in _modifications.entries) {
        final eq = entry.value;
        await _supabase.from('PomPom').update({
          'final':        eq.finale,
          'Podium':       eq.podium,
          'ordrePassage': eq.ordrePassage,
          'ordre_final':  eq.ordreFinale,
          // en_cours est géré indépendamment via _toggleEnCours, mais on
          // inclut quand même la valeur locale pour rester cohérent.
          'en_cours':     eq.enCours,
        }).eq('id', eq.id);
      }
      _showSnack(
        '${_modifications.length} équipe${_modifications.length > 1 ? 's' : ''} sauvegardée${_modifications.length > 1 ? 's' : ''}',
      );
      await _charger();
    } catch (e) {
      _showSnack('Erreur de sauvegarde : $e', isError: true);
    } finally {
      if (mounted) setState(() => _sauvegardeEnCours = false);
    }
  }

  // ── Modification locale d'une équipe ─────────────────────────────────────
  void _modifier(String id, PomPomEquipe modif) {
    setState(() => _modifications[id] = modif);
    final idx = _equipes.indexWhere((e) => e.id == id);
    if (idx != -1) _equipes[idx] = modif;
  }

  // ── Snackbar ─────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false, bool isInfo = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError
          ? const Color(0xFFE53E3E)
          : isInfo
          ? const Color(0xFF1A4A7A)
          : const Color(0xFF1A5C2A),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  void initState() {
    super.initState();
    _charger();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5FB),
      appBar: AppBar(
        backgroundColor: _couleurPP,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('Ovalies',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            SizedBox(width: 8),
            Text('Gestion PomPom',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFEFC8E8))),
          ],
        ),
        actions: [
          _syncEnCours
              ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
          )
              : TextButton.icon(
            onPressed: _synchroniser,
            icon: const Icon(Icons.sync, size: 16, color: Colors.white),
            label: const Text('Sync. descriptions',
                style: TextStyle(color: Colors.white, fontSize: 12)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargement ? null : _charger,
            tooltip: 'Recharger',
          ),
          const SizedBox(width: 4),
        ],
      ),

      floatingActionButton: _modifications.isEmpty
          ? null
          : FloatingActionButton.extended(
        onPressed: _sauvegardeEnCours ? null : _sauvegarderTout,
        backgroundColor: _couleurPP,
        icon: _sauvegardeEnCours
            ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded, color: Colors.white),
        label: Text(
          _sauvegardeEnCours
              ? 'Sauvegarde…'
              : 'Sauvegarder (${_modifications.length})',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),

      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _couleurPP))
          : _erreur != null
          ? _buildErreur()
          : _buildListe(),
    );
  }

  // ── Liste des équipes ─────────────────────────────────────────────────────
  Widget _buildListe() {
    if (_equipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border_rounded,
                size: 56, color: _couleurPP.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text('Aucune équipe PomPom trouvée',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
            itemCount: _equipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final eq = _modifications[_equipes[i].id] ?? _equipes[i];
              return _PomPomCard(
                equipe: eq,
                modifiee: _modifications.containsKey(eq.id),
                toggleEnCoursLoading: _toggleEnCoursId == eq.id,
                onChanged: (modif) => _modifier(eq.id, modif),
                onToggleEnCours: () => _toggleEnCours(eq.id),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Bandeau stats ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final nbFinales  = _equipes.where((e) => e.finale == 'oui').length;
    final nbPodium   = _equipes.where((e) => e.podium > 0).length;
    final nbSync     = _equipes.where((e) => e.description != null && e.description!.isNotEmpty).length;
    final enCoursNom = _equipes.where((e) => e.enCours).map((e) => e.name).firstOrNull;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatChip(label: 'Équipes',   value: '${_equipes.length}', color: _couleurPP),
              const SizedBox(width: 10),
              _StatChip(label: 'En finale', value: '$nbFinales', color: const Color(0xFFD95F1A)),
              const SizedBox(width: 10),
              _StatChip(label: 'Au podium', value: '$nbPodium',  color: const Color(0xFF1A6B9A)),
              const SizedBox(width: 10),
              _StatChip(label: 'Décrits',   value: '$nbSync',    color: const Color(0xFF1A5C2A)),
              if (_modifications.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _couleurPP.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _couleurPP.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_modifications.length} modif.',
                    style: const TextStyle(
                        fontSize: 11,
                        color: _couleurPP,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
          // ── Bandeau "En cours" si un passage est actif ─────────────
          if (enCoursNom != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5C2A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1A5C2A).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_filled_rounded,
                      size: 16, color: Color(0xFF1A5C2A)),
                  const SizedBox(width: 8),
                  Text(
                    'En cours de passage : $enCoursNom',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A5C2A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Erreur ────────────────────────────────────────────────────────────────
  Widget _buildErreur() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFE57373)),
          const SizedBox(height: 16),
          const Text('Erreur de chargement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_erreur ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _charger,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style:
            ElevatedButton.styleFrom(backgroundColor: _couleurPP),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CARTE ÉQUIPE POMPOM
// ════════════════════════════════════════════════════════════════════════════

class _PomPomCard extends StatelessWidget {
  final PomPomEquipe equipe;
  final bool modifiee;
  final bool toggleEnCoursLoading;
  final void Function(PomPomEquipe) onChanged;
  final VoidCallback onToggleEnCours;

  const _PomPomCard({
    required this.equipe,
    required this.modifiee,
    required this.toggleEnCoursLoading,
    required this.onChanged,
    required this.onToggleEnCours,
  });

  static const _couleurPP    = Color(0xFFB5338A);
  static const _couleurVert  = Color(0xFF1A5C2A);
  static const _couleurVertC = Color(0xFFE8F5EC);

  @override
  Widget build(BuildContext context) {
    final estEnFinale = equipe.finale == 'oui';
    final estEnCours  = equipe.enCours;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: estEnCours
            ? _couleurVertC
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: estEnCours
              ? _couleurVert.withOpacity(0.5)
              : modifiee
              ? _couleurPP.withOpacity(0.6)
              : const Color(0xFFE8E8E8),
          width: estEnCours || modifiee ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: estEnCours
                ? _couleurVert.withOpacity(0.12)
                : modifiee
                ? _couleurPP.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ligne 1 : identité + badges ─────────────────────────────
            Row(
              children: [
                // Numéro d'ordre
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _couleurPP.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _couleurPP.withOpacity(0.25)),
                  ),
                  child: Center(
                    child: Text(
                      equipe.ordrePassage == 0 ? '–' : '${equipe.ordrePassage}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _couleurPP),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(equipe.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A1A))),
                          if (estEnCours) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _couleurVert,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded,
                                      size: 10, color: Colors.white),
                                  SizedBox(width: 2),
                                  Text('En cours',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(equipe.school,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                if (modifiee)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _couleurPP.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Modifié',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _couleurPP)),
                  ),
                if (equipe.description != null &&
                    equipe.description!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Description synchronisée',
                    child: Icon(Icons.description_rounded,
                        size: 14, color: Color(0xFF1A5C2A)),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // ── Ligne 2 : contrôles ─────────────────────────────────────
            Row(
              children: [
                // ── EN COURS toggle ─────────────────────────────────────
                Expanded(
                  child: _ControlBlock(
                    label: 'EN COURS',
                    child: GestureDetector(
                      onTap: toggleEnCoursLoading ? null : onToggleEnCours,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: estEnCours
                              ? _couleurVert
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: estEnCours
                                ? _couleurVert
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (toggleEnCoursLoading)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            else
                              Icon(
                                estEnCours
                                    ? Icons.stop_circle_outlined
                                    : Icons.play_circle_outline_rounded,
                                size: 16,
                                color: estEnCours
                                    ? Colors.white
                                    : Colors.grey.shade500,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              estEnCours ? 'Stop' : 'Démarrer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: estEnCours
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // FINAL toggle
                Expanded(
                  child: _ControlBlock(
                    label: 'FINALE',
                    child: Row(
                      children: [
                        Switch(
                          value: estEnFinale,
                          onChanged: (v) =>
                              onChanged(equipe.copyWith(finale: v ? 'oui' : 'non')),
                          activeColor: _couleurPP,
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          estEnFinale ? 'Oui' : 'Non',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: estEnFinale
                                ? _couleurPP
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // ORDRE DE PASSAGE spinner
                Expanded(
                  child: _ControlBlock(
                    label: 'ORDRE DE PASSAGE',
                    child: _Spinner(
                      value: equipe.ordrePassage,
                      min: 0,
                      max: 99,
                      onChanged: (v) =>
                          onChanged(equipe.copyWith(ordrePassage: v)),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // ORDRE FINALE spinner
                Expanded(
                  child: _ControlBlock(
                    label: 'ORDRE FINALE',
                    child: _Spinner(
                      value: equipe.ordreFinale,
                      min: 0,
                      max: 99,
                      onChanged: (v) =>
                          onChanged(equipe.copyWith(ordreFinale: v)),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // PODIUM dropdown
                Expanded(
                  child: _ControlBlock(
                    label: 'PODIUM',
                    child: DropdownButton<int>(
                      value: equipe.podium,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A)),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('—  Aucun')),
                        DropdownMenuItem(value: 1, child: Text('🥇  1ᵉʳ')),
                        DropdownMenuItem(value: 2, child: Text('🥈  2ᵉ')),
                        DropdownMenuItem(value: 3, child: Text('🥉  3ᵉ')),
                      ],
                      onChanged: (v) {
                        if (v != null) onChanged(equipe.copyWith(podium: v));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ════════════════════════════════════════════════════════════════════════════

class _ControlBlock extends StatelessWidget {
  final String label;
  final Widget child;
  const _ControlBlock({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade400,
                letterSpacing: 0.5)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E0EC)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;
  const _Spinner(
      {required this.value,
        required this.min,
        required this.max,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: value > min ? () => onChanged(value - 1) : null,
          child: Icon(Icons.remove_circle_outline,
              size: 20,
              color: value > min
                  ? const Color(0xFFB5338A)
                  : Colors.grey.shade300),
        ),
        Expanded(
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
        ),
        GestureDetector(
          onTap: value < max ? () => onChanged(value + 1) : null,
          child: Icon(Icons.add_circle_outline,
              size: 20,
              color: value < max
                  ? const Color(0xFFB5338A)
                  : Colors.grey.shade300),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }
}
