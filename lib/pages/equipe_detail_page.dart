import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'equipes_page.dart';

final _supabase = Supabase.instance.client;

// ════════════════════════════════════════════════════════════
// PAGE DÉTAIL ÉQUIPE
// Joueurs chargés depuis table public.joueur via team_code
// (team_code = id de l'équipe dans Equipes)
// ════════════════════════════════════════════════════════════
class EquipeDetailPage extends StatefulWidget {
  final Equipe equipe;
  const EquipeDetailPage({super.key, required this.equipe});

  @override
  State<EquipeDetailPage> createState() => _EquipeDetailPageState();
}

class _EquipeDetailPageState extends State<EquipeDetailPage> {
  List<Map<String, dynamic>> _joueurs = [];
  bool _chargement = true;
  String? _erreur;

  static const Map<String, Color> _catColors = {
    'R15M': Color(0xFF1A5C2A),
    'R7M':  Color(0xFF8B4513),
    'R7F':  Color(0xFF6B1A5C),
    'RF':   Color(0xFF1A4A7A),
    'PP':   Color(0xFFB5338A),
  };

  Color get _couleur => _catColors[widget.equipe.categorie] ?? const Color(0xFF6B1A5C);

  @override
  void initState() {
    super.initState();
    _chargerJoueurs();
  }

  Future<void> _chargerJoueurs() async {
    setState(() { _chargement = true; _erreur = null; });
    try {
      // Table joueur — colonnes : nom, prenom, carton_jaune, carton_rouge,
      //   carton_bleu, suspendu_un_match, suspendu_definitif, team_code
      // team_code correspond à l'id de la table Equipes
      final data = await _supabase
          .from('joueur')
          .select('id, nom, prenom, carton_jaune, carton_rouge, carton_bleu, suspendu_un_match, suspendu_definitif')
          .eq('team_code', widget.equipe.id)
          .order('nom', ascending: true);

      setState(() {
        _joueurs = List<Map<String, dynamic>>.from(data);
        _chargement = false;
      });
    } catch (e) {
      setState(() { _erreur = e.toString(); _chargement = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildStats()),
          SliverToBoxAdapter(child: _buildTitreJoueurs()),
          _buildListeJoueurs(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── App bar dégradé ──────────────────────────────────────
  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: _couleur,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_couleur, _couleur.withOpacity(0.75)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.equipe.categorie,
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.equipe.nom.isNotEmpty ? widget.equipe.nom : widget.equipe.id,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.equipe.ecole.isNotEmpty && widget.equipe.ecole != '0')
                    Text(widget.equipe.ecole,
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                  if (widget.equipe.poule.isNotEmpty && widget.equipe.poule != '0')
                    Text('Poule ${widget.equipe.poule}',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Bloc statistiques ────────────────────────────────────
  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Statistiques',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _couleur)),
        const SizedBox(height: 14),
        Row(children: [
          _statCell(icon: Icons.sports_rugby,   label: 'Essais',     value: widget.equipe.nbEssai.toString(),         color: const Color(0xFF1A5C2A)),
          _divV(),
          _statCell(icon: Icons.shield_outlined, label: 'Encaissés', value: widget.equipe.nbEssaiEncaisse.toString(),  color: const Color(0xFFE53E3E)),
          _divV(),
          _statCell(icon: Icons.emoji_events,    label: 'Victoires',  value: widget.equipe.matchsGagne.toString(),     color: const Color(0xFFF5A623)),
        ]),
        const Divider(height: 24, color: Color(0xFFEEEEEE)),
        Row(children: [
          _statCell(icon: Icons.rectangle_rounded, label: 'Jaunes',  value: widget.equipe.nbJaune.toString(), color: const Color(0xFFF5A623)),
          _divV(),
          _statCell(icon: Icons.rectangle_rounded, label: 'Rouges',  value: widget.equipe.nbRouge.toString(), color: const Color(0xFFE53E3E)),
          _divV(),
          _statCell(icon: Icons.people_rounded,    label: 'Joueurs',
              value: _chargement ? '…' : _joueurs.length.toString(), color: _couleur),
        ]),
        const Divider(height: 24, color: Color(0xFFEEEEEE)),
        Row(children: [
          _statCell(icon: Icons.star_rounded,    label: 'Points',      value: widget.equipe.points,      color: const Color(0xFF1A4A7A)),
          _divV(),
          _statCell(icon: Icons.trending_up,     label: 'Goal avg',    value: widget.equipe.goalAverage, color: Colors.grey.shade600),
          _divV(),
          const Expanded(child: SizedBox()), // spacer
        ]),
      ]),
    );
  }

  Widget _statCell({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _divV() => Container(width: 1, height: 50, color: const Color(0xFFEEEEEE));

  // ── Titre section joueurs ────────────────────────────────
  Widget _buildTitreJoueurs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: _couleur, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        const Text('Joueurs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        const SizedBox(width: 8),
        if (!_chargement)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: _couleur.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text('${_joueurs.length}',
                style: TextStyle(fontSize: 11, color: _couleur, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  // ── Liste des joueurs ────────────────────────────────────
  SliverList _buildListeJoueurs() {
    if (_chargement) {
      return SliverList(delegate: SliverChildListDelegate([
        const Padding(padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF6B1A5C)))),
      ]));
    }

    if (_erreur != null) {
      return SliverList(delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFE57373)),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextButton.icon(onPressed: _chargerJoueurs,
                icon: const Icon(Icons.refresh, size: 16), label: const Text('Réessayer')),
          ]),
        ),
      ]));
    }

    if (_joueurs.isEmpty) {
      return SliverList(delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_off_outlined, size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucun joueur enregistré pour cette équipe',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ]),
        ),
      ]));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final j = _joueurs[index];
          final nom    = (j['nom']    ?? '').toString();
          final prenom = (j['prenom'] ?? '').toString();
          final nomComplet = '$prenom $nom'.trim();
          final initiale = prenom.isNotEmpty ? prenom[0].toUpperCase() : (nom.isNotEmpty ? nom[0].toUpperCase() : '?');

          final suspendu1  = j['suspendu_un_match']  == true;
          final suspenduDef = j['suspendu_definitif'] == true;
          final jaune  = (j['carton_jaune']  ?? 0) as int;
          final rouge  = (j['carton_rouge']  ?? 0) as int;
          final bleu   = (j['carton_bleu']   ?? 0) as int;

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: suspenduDef
                    ? const Color(0xFFE53E3E).withOpacity(0.4)
                    : suspendu1
                    ? const Color(0xFFF5A623).withOpacity(0.4)
                    : const Color(0xFFEEEEEE),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: _couleur.withOpacity(0.12),
                child: Text(initiale, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _couleur)),
              ),
              title: Text(
                nomComplet.isNotEmpty ? nomComplet : 'Joueur inconnu',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
              ),
              subtitle: Row(children: [
                if (suspenduDef)
                  _badge('Suspendu définit.', const Color(0xFFE53E3E))
                else if (suspendu1)
                  _badge('Suspendu 1m.', const Color(0xFFF5A623))
                else
                  _badge('OK', const Color(0xFF2D9148)),
                const SizedBox(width: 6),
                if (rouge > 0) _cartonBadge('$rouge', const Color(0xFFE53E3E)),
                if (bleu > 0)  _cartonBadge('$bleu',  const Color(0xFF1A4A7A)),
                if (jaune > 0) _cartonBadge('$jaune', const Color(0xFFF5A623)),
              ]),
            ),
          );
        },
        childCount: _joueurs.length,
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );

  Widget _cartonBadge(String count, Color color) => Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
    child: Text(count, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
  );
}
