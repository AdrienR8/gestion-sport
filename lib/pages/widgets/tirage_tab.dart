import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/tournoi_service.dart';

class TirageTab extends StatefulWidget {
  final List<Equipe> toutesEquipes;
  final Map<String, Map<String, List<Equipe>>> poulesParCat;
  final List<Equipe> Function(String cat) equipesNonPlacees;
  final void Function(String cat, String poule, Equipe eq) onAjouter;
  final void Function(String cat, String poule, String id) onRetirer;
  final void Function(String cat) onTirageAuto;
  final void Function(String cat) onReset;

  const TirageTab({
    super.key,
    required this.toutesEquipes,
    required this.poulesParCat,
    required this.equipesNonPlacees,
    required this.onAjouter,
    required this.onRetirer,
    required this.onTirageAuto,
    required this.onReset,
  });

  @override
  State<TirageTab> createState() => _TirageTabState();
}

class _TirageTabState extends State<TirageTab> {
  String _cat = 'R15M';

  static const Map<String, Color> catColors = {
    'R15M': Color(0xFF1A5C2A),
    'R7M':  Color(0xFF8B4513),
    'R7F':  Color(0xFF6B1A5C),
    'RF':   Color(0xFF1A4A7A),
  };

  static const Map<String, String> catLabels = {
    'R15M': 'Rugby XV Masculin',
    'R7M':  'Rugby VII Masculin',
    'R7F':  'Rugby VII Féminin',
    'RF':   'Rugby Fauteuil',
  };

  @override
  Widget build(BuildContext context) {
    final dispo = widget.equipesNonPlacees(_cat);
    final color = catColors[_cat]!;

    return Column(
      children: [
        // Sélecteur de catégorie
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(catLabels[cat]!),
                  selected: _cat == cat,
                  selectedColor: catColors[cat]!.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: _cat == cat ? catColors[cat]! : Colors.grey,
                    fontWeight: _cat == cat ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: _cat == cat ? catColors[cat]! : Colors.grey.shade300),
                  onSelected: (_) => setState(() => _cat = cat),
                ),
              )),
              const Spacer(),
              TextButton.icon(
                icon: Icon(Icons.casino_outlined, size: 16, color: color),
                label: Text('Tirage auto', style: TextStyle(color: color, fontSize: 12)),
                onPressed: () {
                  widget.onTirageAuto(_cat);
                  setState(() {});
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                label: const Text('Reset', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onPressed: () {
                  widget.onReset(_cat);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Colonne gauche : équipes disponibles ────────────
              Container(
                width: 220,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F8F5),
                  border: Border(right: BorderSide(color: Color(0xFFE0E0E0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      child: Row(
                        children: [
                          Text('Équipes disponibles',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.5)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text('${dispo.length}', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: dispo.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, color: color, size: 32),
                            const SizedBox(height: 8),
                            Text('Toutes placées !', style: TextStyle(fontSize: 12, color: color)),
                          ],
                        ),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: dispo.length,
                        itemBuilder: (ctx, i) {
                          final eq = dispo[i];
                          return _DraggableEquipe(eq: eq, color: color);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ── Zone des poules ─────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: poules.map((poule) {
                      final items = widget.poulesParCat[_cat]?[poule] ?? [];
                      return _PouleZone(
                        poule: poule,
                        cat: _cat,
                        equipes: items,
                        color: color,
                        onAccept: (eq) {
                          widget.onAjouter(_cat, poule, eq);
                          setState(() {});
                        },
                        onRetirer: (id) {
                          widget.onRetirer(_cat, poule, id);
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Barre de statut ────────────────────────────────────
        _StatutBar(cat: _cat, poulesParCat: widget.poulesParCat, toutesEquipes: widget.toutesEquipes, color: color),
      ],
    );
  }
}

// ── Widget équipe draggable ────────────────────────────────────────────────
class _DraggableEquipe extends StatelessWidget {
  final Equipe eq;
  final Color color;

  const _DraggableEquipe({required this.eq, required this.color});

  @override
  Widget build(BuildContext context) {
    return Draggable<Equipe>(
      data: eq,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(eq.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _EquipeChip(eq: eq, color: color),
      ),
      child: _EquipeChip(eq: eq, color: color),
    );
  }
}

class _EquipeChip extends StatelessWidget {
  final Equipe eq;
  final Color color;
  const _EquipeChip({required this.eq, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eq.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(eq.id, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Zone de poule ─────────────────────────────────────────────────────────
class _PouleZone extends StatefulWidget {
  final String poule;
  final String cat;
  final List<Equipe> equipes;
  final Color color;
  final void Function(Equipe) onAccept;
  final void Function(String id) onRetirer;

  const _PouleZone({
    required this.poule,
    required this.cat,
    required this.equipes,
    required this.color,
    required this.onAccept,
    required this.onRetirer,
  });

  @override
  State<_PouleZone> createState() => _PouleZoneState();
}

class _PouleZoneState extends State<_PouleZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isFull = widget.equipes.length >= 4;
    return DragTarget<Equipe>(
      onWillAcceptWithDetails: (d) {
        if (isFull) return false;
        if (widget.equipes.any((e) => e.id == d.data.id)) return false;
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (d) {
        setState(() => _hovering = false);
        widget.onAccept(d.data);
      },
      builder: (ctx, candidates, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 200,
          constraints: const BoxConstraints(minHeight: 180),
          decoration: BoxDecoration(
            color: _hovering ? widget.color.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering
                  ? widget.color
                  : isFull
                  ? widget.color.withOpacity(0.4)
                  : const Color(0xFFE0E0E0),
              width: _hovering ? 2 : 1,
              style: isFull || _hovering ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header poule
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: BoxDecoration(
                  color: isFull ? widget.color.withOpacity(0.08) : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Poule ${widget.poule}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.equipes.length}/4',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Équipes
              Padding(
                padding: const EdgeInsets.all(8),
                child: widget.equipes.isEmpty
                    ? Container(
                  height: 60,
                  alignment: Alignment.center,
                  child: Text(
                    'Glisse une équipe ici',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                )
                    : Column(
                  children: widget.equipes.map((eq) => _PouleItem(
                    eq: eq,
                    color: widget.color,
                    onRetirer: () => widget.onRetirer(eq.id),
                  )).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PouleItem extends StatelessWidget {
  final Equipe eq;
  final Color color;
  final VoidCallback onRetirer;
  const _PouleItem({required this.eq, required this.color, required this.onRetirer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(eq.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ),
          GestureDetector(
            onTap: onRetirer,
            child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ── Barre de statut ────────────────────────────────────────────────────────
class _StatutBar extends StatelessWidget {
  final String cat;
  final Map<String, Map<String, List<Equipe>>> poulesParCat;
  final List<Equipe> toutesEquipes;
  final Color color;

  const _StatutBar({required this.cat, required this.poulesParCat, required this.toutesEquipes, required this.color});

  @override
  Widget build(BuildContext context) {
    final total = toutesEquipes.where((e) => e.categorie == cat).length;
    final poulesDesCat = cat == 'RF'
        ? ['A', 'B', 'C', 'D']
        : poules;
    final placees = poulesDesCat.fold<int>(0, (s, p) => s + (poulesParCat[cat]?[p]?.length ?? 0));
    final ok = placees == total && total > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: ok ? const Color(0xFF2D9148) : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            ok
                ? 'Toutes les équipes $cat sont placées ($total/$total)'
                : '$placees/$total équipes placées pour $cat',
            style: TextStyle(fontSize: 12, color: ok ? const Color(0xFF2D9148) : Colors.orange.shade800),
          ),
        ],
      ),
    );
  }
}
