import 'package:flutter/material.dart';
import 'tirage_page.dart';
import 'joueurs_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color _vert = Color(0xFF1A5C2A);
  static const Color _vertVif = Color(0xFF2D9148);
  static const Color _vertClair = Color(0xFFE8F5EC);
  static const Color _fond = Color(0xFFF5F5F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcome(context),
                  const SizedBox(height: 40),
                  _buildGrid(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 64,
      color: _vert,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Logo / titre
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('O', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ovalies',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Administration',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Badge version
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Text(
              'v1.0 — Interne',
              style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Message de bienvenue ─────────────────────────────────────────────────
  Widget _buildWelcome(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bienvenue',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Plateforme de gestion du tournoi Ovalies. Sélectionne un module pour commencer.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        // Décoratif — stats rapides
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _vertClair,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _vertVif.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              _miniStat('3', 'Catégories'),
              const SizedBox(width: 24),
              _miniStat('6', 'Poules max'),
              const SizedBox(width: 24),
              _miniStat('4', 'Niveaux'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _vert)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  // ── Grille des modules ───────────────────────────────────────────────────
  Widget _buildGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossCount = constraints.maxWidth > 800 ? 3 : constraints.maxWidth > 500 ? 2 : 1;
        return GridView.count(
          crossAxisCount: crossCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: [
            _ModuleCard(
              icon: Icons.emoji_events_rounded,
              titre: 'Gestion du tournoi',
              sousTitre: 'Tirage au sort des poules, génération des matchs et horaires',
              couleur: const Color(0xFF1A5C2A),
              couleurFond: const Color(0xFFE8F5EC),
              badge: 'Disponible',
              badgeCouleur: const Color(0xFF2D9148),
              points: const [
                'Tirage au sort par catégorie',
                'Drag & drop des équipes',
                'Génération automatique des matchs',
                'Saisie des horaires et terrains',
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TiragePage()),
              ),
            ),
            _ModuleCard(
              icon: Icons.people_rounded,
              titre: 'Gestion des joueurs',
              sousTitre: 'Recherche, cartons et suivi individuel de chaque joueur',
              couleur: const Color(0xFF1A4A7A),
              couleurFond: const Color(0xFFE8F0FB),
              badge: 'Bientôt',
              badgeCouleur: const Color(0xFF5B8FCC),
              points: const [
                'Barre de recherche par nom',
                'Historique des cartons jaunes/rouges',
                'Statut de suspension',
                'Fiche individuelle du joueur',
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoueursPage()),
              ),
            ),
            _ModuleCard(
              icon: Icons.shield_rounded,
              titre: 'Gestion des équipes',
              sousTitre: 'Statistiques, classements et performances par équipe',
              couleur: const Color(0xFF6B1A5C),
              couleurFond: const Color(0xFFF5E8F5),
              badge: 'Bientôt',
              badgeCouleur: const Color(0xFFB05CA0),
              points: const [
                'Stats par équipe (essais, cartons)',
                'Classement dans la poule',
                'Goal average et points',
                'Composition de l\'équipe',
              ],
              onTap: null, // À implémenter
            ),
          ],
        );
      },
    );
  }
}

// ── Carte de module ──────────────────────────────────────────────────────────
class _ModuleCard extends StatefulWidget {
  final IconData icon;
  final String titre;
  final String sousTitre;
  final Color couleur;
  final Color couleurFond;
  final String badge;
  final Color badgeCouleur;
  final List<String> points;
  final VoidCallback? onTap;

  const _ModuleCard({
    required this.icon,
    required this.titre,
    required this.sousTitre,
    required this.couleur,
    required this.couleurFond,
    required this.badge,
    required this.badgeCouleur,
    required this.points,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final disponible = widget.onTap != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: disponible ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, _hovering && disponible ? -4.0 : 0.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering && disponible
                  ? widget.couleur.withOpacity(0.5)
                  : const Color(0xFFE0E0E0),
              width: _hovering && disponible ? 1.5 : 1,
            ),
            boxShadow: _hovering && disponible
                ? [BoxShadow(color: widget.couleur.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))]
                : [const BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header coloré ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: widget.couleurFond,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.couleur,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 22),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.badgeCouleur.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: widget.badgeCouleur.withOpacity(0.3)),
                      ),
                      child: Text(
                        widget.badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.badgeCouleur,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Corps ────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.sousTitre,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      // Points clés
                      ...widget.points.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(right: 8, top: 1),
                              decoration: BoxDecoration(
                                color: disponible ? widget.couleur : Colors.grey.shade300,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: disponible ? const Color(0xFF3A3A3A) : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const Spacer(),
                      // Bouton bas de carte
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: disponible
                              ? (_hovering ? widget.couleur : widget.couleur.withOpacity(0.08))
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              disponible ? 'Ouvrir le module' : 'En développement',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: disponible
                                    ? (_hovering ? Colors.white : widget.couleur)
                                    : Colors.grey.shade400,
                              ),
                            ),
                            if (disponible) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: _hovering ? Colors.white : widget.couleur,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
