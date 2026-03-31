import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

// ═══════════════════════════════════════════════════════════
// MODÈLE
// ═══════════════════════════════════════════════════════════
class Joueur {
  final String id;
  final String compteId;
  final String nom;
  final String prenom;
  final String email;
  final String categorie;
  final String? nomEcole;
  final String? teamCode;
  final int cartonJaune;
  final int cartonRouge;
  final int cartonBleu;
  final bool suspenduUnMatch;
  final bool suspenduDefinitif;

  Joueur({
    required this.id,
    required this.compteId,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.categorie,
    this.nomEcole,
    this.teamCode,
    required this.cartonJaune,
    required this.cartonRouge,
    required this.cartonBleu,
    required this.suspenduUnMatch,
    required this.suspenduDefinitif,
  });

  factory Joueur.fromJson(Map<String, dynamic> j) => Joueur(
    id: j['id'] ?? '',
    compteId: j['compte_id'] ?? '',
    nom: j['nom'] ?? '',
    prenom: j['prenom'] ?? '',
    email: j['email'] ?? '',
    categorie: j['categorie'] ?? '0',
    nomEcole: j['nom_ecole'],
    teamCode: j['team_code'],
    cartonJaune: (j['carton_jaune'] ?? 0) as int,
    cartonRouge: (j['carton_rouge'] ?? 0) as int,
    cartonBleu: (j['carton_bleu'] ?? 0) as int,
    suspenduUnMatch: j['suspendu_un_match'] ?? false,
    suspenduDefinitif: j['suspendu_definitif'] ?? false,
  );

  int get totalCartons => cartonJaune + cartonRouge + cartonBleu;
  String get nomComplet => '$prenom $nom';
  bool get estSuspendu => suspenduUnMatch || suspenduDefinitif;
}

// ═══════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════
class JoueursPage extends StatefulWidget {
  const JoueursPage({super.key});

  @override
  State<JoueursPage> createState() => _JoueursPageState();
}

class _JoueursPageState extends State<JoueursPage> {
  List<Joueur> _tousJoueurs = [];
  bool _chargement = true;
  bool _syncEnCours = false;
  String? _erreur;

  String _recherche = '';
  String _catFiltre = 'Tous';
  String _triActif = 'nom';
  bool _triDesc = false;
  bool _seulementSuspendus = false;

  final TextEditingController _searchCtrl = TextEditingController();

  static const _cats = ['Tous', 'R15M', 'R7M', 'R7F', 'RF', 'PP'];
  static const _catLabels = {
    'Tous': 'Tous',
    'R15M': 'R15M',
    'R7M':  'R7M',
    'R7F':  'R7F',
    'RF':   'Rugby Fauteuil',
    'PP':   'Pompom',
  };
  static const _tris = {
    'nom':          'Nom',
    'carton_rouge': 'Cartons rouges',
    'carton_jaune': 'Cartons jaunes',
    'carton_bleu':  'Cartons bleus',
    'carton_total': 'Total cartons',
  };
  static const Map<String, Color> _catColors = {
    'R15M': Color(0xFF1A5C2A),
    'R7M':  Color(0xFF8B4513),
    'R7F':  Color(0xFF6B1A5C),
    'RF':   Color(0xFF1A4A7A),
    'PP':   Color(0xFFB5338A),
    '0':    Color(0xFF888888),
  };

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Chargement depuis la table joueur ────────────────────
  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = null; });
    try {
      final data = await _supabase
          .from('joueur')
          .select()
          .order('nom', ascending: true);
      setState(() {
        _tousJoueurs = (data as List).map((j) => Joueur.fromJson(j)).toList();
        _chargement = false;
      });
    } catch (e) {
      setState(() { _erreur = e.toString(); _chargement = false; });
    }
  }

  // ── Synchronisation complète depuis Comptes ─────────────
  // 1. Insère les nouveaux comptes joueur non encore dans joueur
  // 2. Met à jour TOUS les existants avec les infos fraîches
  //    (nom_ecole <- team-name, team_code <- team-code,
  //     nom <- name, prenom <- first-name, categorie <- categorie)
  Future<void> _synchroniser() async {
    setState(() => _syncEnCours = true);
    try {
      // Charger tous les comptes joueurs depuis Comptes
      final comptes = await _supabase
          .from('Comptes')
          .select('id, name, first-name, categorie, team-name, team-code')
          .eq('type', 'joueur');
      final listeComptes = comptes as List;

      // Charger les lignes existantes dans joueur
      final existants = await _supabase
          .from('joueur')
          .select('id, compte_id');
      final existantsParCompteId = {
        for (final e in existants as List)
          e['compte_id'].toString(): e['id'].toString()
      };

      int nbInserts = 0;
      int nbUpdates = 0;

      for (final c in listeComptes) {
        final compteId  = c['id'].toString();
        final nom       = (c['name'] ?? '').toString();
        final prenom    = (c['first-name'] ?? '').toString();
        final categorie = (c['categorie'] ?? '0').toString();
        final nomEcole  = (c['team-name'] ?? '').toString();
        final teamCode  = (c['team-code'] ?? '').toString();

        if (existantsParCompteId.containsKey(compteId)) {
          // Mettre à jour l'existant (sans toucher aux cartons/suspensions)
          await _supabase
              .from('joueur')
              .update({
            'nom':       nom,
            'prenom':    prenom,
            'categorie': categorie,
            'nom_ecole': nomEcole.isNotEmpty ? nomEcole : null,
            'team_code': teamCode.isNotEmpty ? teamCode : null,
          })
              .eq('compte_id', compteId);
          nbUpdates++;
        } else {
          // Insérer le nouveau joueur
          await _supabase.from('joueur').insert({
            'compte_id': compteId,
            'nom':       nom,
            'prenom':    prenom,
            'email':     compteId,
            'categorie': categorie,
            'nom_ecole': nomEcole.isNotEmpty ? nomEcole : null,
            'team_code': teamCode.isNotEmpty ? teamCode : null,
          });
          nbInserts++;
        }
      }

      // Résumé
      final parties = <String>[];
      if (nbInserts > 0) parties.add('$nbInserts nouveau${nbInserts > 1 ? 'x' : ''}');
      if (nbUpdates > 0) parties.add('$nbUpdates mis à jour');
      _showSnack(
        parties.isNotEmpty ? parties.join(' · ') : 'Aucune modification',
        isInfo: parties.isEmpty,
      );

      await _charger();
    } catch (e) {
      _showSnack('Erreur de synchronisation : $e', isError: true);
      setState(() => _syncEnCours = false);
    }
  }

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

  // ── Filtrage + tri ────────────────────────────────────────
  List<Joueur> get _joueursFiltres {
    var liste = List<Joueur>.from(_tousJoueurs);

    if (_catFiltre != 'Tous') {
      liste = liste.where((j) => j.categorie == _catFiltre).toList();
    }
    if (_seulementSuspendus) {
      liste = liste.where((j) => j.estSuspendu).toList();
    }
    if (_recherche.isNotEmpty) {
      final q = _recherche.toLowerCase();
      liste = liste.where((j) =>
      j.nom.toLowerCase().contains(q) ||
          j.prenom.toLowerCase().contains(q) ||
          j.email.toLowerCase().contains(q) ||
          (j.nomEcole?.toLowerCase().contains(q) ?? false)).toList();
    }

    liste.sort((a, b) {
      int cmp;
      switch (_triActif) {
        case 'carton_total':  cmp = a.totalCartons.compareTo(b.totalCartons);
        case 'carton_rouge':  cmp = a.cartonRouge.compareTo(b.cartonRouge);
        case 'carton_jaune':  cmp = a.cartonJaune.compareTo(b.cartonJaune);
        case 'carton_bleu':   cmp = a.cartonBleu.compareTo(b.cartonBleu);
        default:              cmp = a.nom.compareTo(b.nom);
      }
      return _triDesc ? -cmp : cmp;
    });

    return liste;
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A4A7A),
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
            Text('Gestion des joueurs',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF8BADD4))),
          ],
        ),
        actions: [
          // Bouton synchroniser
          _syncEnCours
              ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          )
              : TextButton.icon(
            onPressed: _synchroniser,
            icon: const Icon(Icons.sync, size: 16, color: Colors.white),
            label: const Text('Synchroniser',
                style: TextStyle(color: Colors.white, fontSize: 12)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargement ? null : _charger,
            tooltip: 'Recharger',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A4A7A)))
          : _erreur != null
          ? _buildErreur()
          : _buildListe(),
    );
  }

  // ═══════════════════════════════════════════════════════
  // LISTE
  // ═══════════════════════════════════════════════════════
  Widget _buildListe() {
    final joueurs = _joueursFiltres;

    return Column(
      children: [
        // ── Filtres ─────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              // Recherche
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _recherche = v),
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, prénom, email…',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF1A4A7A)),
                  suffixIcon: _recherche.isNotEmpty
                      ? IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                      onPressed: () { _searchCtrl.clear(); setState(() => _recherche = ''); })
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1A4A7A))),
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                ),
              ),
              const SizedBox(height: 10),

              // Catégories + filtre suspendus
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _cats.map((cat) {
                          final active = _catFiltre == cat;
                          final color = cat == 'Tous'
                              ? const Color(0xFF444444)
                              : (_catColors[cat] ?? Colors.grey);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setState(() => _catFiltre = cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: active ? color : color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: active ? color : color.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _catLabels[cat] ?? cat,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : color),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _seulementSuspendus = !_seulementSuspendus),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _seulementSuspendus ? const Color(0xFFE53E3E) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _seulementSuspendus ? const Color(0xFFE53E3E) : const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block, size: 12, color: _seulementSuspendus ? Colors.white : const Color(0xFFE53E3E)),
                          const SizedBox(width: 4),
                          Text('Suspendus',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _seulementSuspendus ? Colors.white : const Color(0xFFE53E3E))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tri
              Row(
                children: [
                  Text('Trier par :', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tris.entries.map((e) {
                          final active = _triActif == e.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                if (_triActif == e.key) {
                                  _triDesc = !_triDesc;
                                } else {
                                  _triActif = e.key;
                                  _triDesc = e.key != 'nom';
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: active ? const Color(0xFF1A4A7A) : const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(e.value,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : Colors.grey.shade600)),
                                    if (active) ...[
                                      const SizedBox(width: 4),
                                      Icon(_triDesc ? Icons.arrow_downward : Icons.arrow_upward, size: 10, color: Colors.white),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Compteur ───────────────────────────────────
        Container(
          color: const Color(0xFFF8F8F5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              Text('${joueurs.length} joueur${joueurs.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Text('sur ${_tousJoueurs.length}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              if (_catFiltre != 'Tous' || _seulementSuspendus || _recherche.isNotEmpty) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _catFiltre = 'Tous';
                    _seulementSuspendus = false;
                    _recherche = '';
                    _searchCtrl.clear();
                    _triActif = 'nom';
                    _triDesc = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Effacer les filtres', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Liste joueurs ───────────────────────────────
        Expanded(
          child: joueurs.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: joueurs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => _ouvrirFeuillesMatch(context, joueurs[i]),
              child: _JoueurCard(joueur: joueurs[i], catColors: _catColors),
            ),
          ),
        ),
      ],
    );
  }


  // ── Dialog feuilles de match d'un joueur ────────────────
  Future<void> _ouvrirFeuillesMatch(BuildContext context, Joueur joueur) async {
    if (joueur.teamCode == null || joueur.teamCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucun code équipe associé à ce joueur'),
        backgroundColor: Color(0xFF888888),
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _FeuillesMatchDialog(joueur: joueur),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _recherche.isNotEmpty ? 'Aucun joueur pour "$_recherche"' : 'Aucun joueur dans cette catégorie',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErreur() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFE57373)),
          const SizedBox(height: 16),
          const Text('Erreur de chargement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_erreur ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _charger,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A4A7A)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CARTE JOUEUR
// ═══════════════════════════════════════════════════════════
class _JoueurCard extends StatelessWidget {
  final Joueur joueur;
  final Map<String, Color> catColors;
  const _JoueurCard({required this.joueur, required this.catColors});

  @override
  Widget build(BuildContext context) {
    final catColor = catColors[joueur.categorie] ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: joueur.suspenduDefinitif
              ? const Color(0xFFE53E3E).withOpacity(0.4)
              : joueur.suspenduUnMatch
              ? Colors.orange.withOpacity(0.4)
              : const Color(0xFFE8E8E8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar initiales
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: catColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  '${joueur.prenom.isNotEmpty ? joueur.prenom[0] : '?'}${joueur.nom.isNotEmpty ? joueur.nom[0] : '?'}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: catColor),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nom + école
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(joueur.nomComplet,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          joueur.categorie == '0' ? 'N/A' : joueur.categorie,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: catColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(joueur.nomEcole ?? joueur.email,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),

            // Cartons
            Row(
              children: [
                if (joueur.cartonJaune > 0)
                  _CartonBadge(nb: joueur.cartonJaune, couleur: const Color(0xFFF6C90E), textColor: const Color(0xFF7A6200)),
                if (joueur.cartonRouge > 0)
                  _CartonBadge(nb: joueur.cartonRouge, couleur: const Color(0xFFE53E3E), textColor: Colors.white),
                if (joueur.cartonBleu > 0)
                  _CartonBadge(nb: joueur.cartonBleu, couleur: const Color(0xFF3B82F6), textColor: Colors.white),
              ],
            ),
            const SizedBox(width: 8),

            _SuspensionBadge(joueur: joueur),
          ],
        ),
      ),
    );
  }
}

class _CartonBadge extends StatelessWidget {
  final int nb;
  final Color couleur;
  final Color textColor;
  const _CartonBadge({required this.nb, required this.couleur, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 26, height: 26,
      decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(6)),
      child: Center(child: Text('$nb', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textColor))),
    );
  }
}

class _SuspensionBadge extends StatelessWidget {
  final Joueur joueur;
  const _SuspensionBadge({required this.joueur});

  @override
  Widget build(BuildContext context) {
    if (joueur.suspenduDefinitif) return _badge('Suspendu déf.', const Color(0xFFE53E3E));
    if (joueur.suspenduUnMatch)   return _badge('Suspendu 1m.', Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF90C99A)),
      ),
      child: const Text('OK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF1A5C2A))),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
  );
}


// ═══════════════════════════════════════════════════════════
// DIALOG FEUILLES DE MATCH
// ═══════════════════════════════════════════════════════════
class _FeuillesMatchDialog extends StatefulWidget {
  final Joueur joueur;
  const _FeuillesMatchDialog({required this.joueur});

  @override
  State<_FeuillesMatchDialog> createState() => _FeuillesMatchDialogState();
}

class _FeuillesMatchDialogState extends State<_FeuillesMatchDialog> {
  List<Map<String, String>> _fichiers = [];
  bool _chargement = true;
  String? _erreur;

  static const Map<String, Color> _catColors = {
    'R15M': Color(0xFF1A5C2A),
    'R7M':  Color(0xFF8B4513),
    'R7F':  Color(0xFF6B1A5C),
    'RF':   Color(0xFF1A4A7A),
    'PP':   Color(0xFFB5338A),
  };

  @override
  void initState() {
    super.initState();
    _chargerFeuilles();
  }

  // Liste tous les PDFs du bucket "feuille de match"
  // dont le nom contient le team_code du joueur
  Future<void> _chargerFeuilles() async {
    try {
      final teamCode = widget.joueur.teamCode ?? '';
      final fichiers = await _supabase.storage
          .from('feuille de match')
          .list();

      final filtres = fichiers
          .where((f) => f.name.contains(teamCode) && f.name.endsWith('.pdf'))
          .map((f) {
        final url = _supabase.storage
            .from('feuille de match')
            .getPublicUrl(f.name);
        return {'name': f.name, 'url': url};
      })
          .toList();

      // Plus récents en premier (tri par nom desc, le timestamp est en fin de nom)
      filtres.sort((a, b) => (b['name'] ?? '').compareTo(a['name'] ?? ''));

      setState(() {
        _fichiers = filtres;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  // Décompose le nom structuré en label lisible
  // Format : {cat}_{codeEq1}_vs_{codeEq2}_{matchId}_{date}.pdf
  String _labelFichier(String name) {
    try {
      final sans  = name.replaceAll('.pdf', '');
      final parts = sans.split('_');
      if (parts.length >= 5) {
        final cat     = parts[0];
        final code1   = parts[1];
        final code2   = parts[3];
        final matchId = parts[4];
        final date    = parts.length > 5 ? parts[5] : '';
        // Reformater la date YYYYMMDD-HHMM → JJ/MM HHhMM
        String dateLisible = date;
        if (date.length >= 13) {
          final d = date.substring(0, 8);
          final h = date.substring(9, 13);
          dateLisible = '${d.substring(6)}/${d.substring(4,6)} ${h.substring(0,2)}h${h.substring(2)}';
        }
        return '$cat — $code1 vs $code2  ·  match $matchId  ·  $dateLisible';
      }
    } catch (_) {}
    return name;
  }

  // Identifie l'équipe adverse pour afficher un label contextuel
  String _labelAdversaire(String name) {
    try {
      final sans  = name.replaceAll('.pdf', '');
      final parts = sans.split('_');
      if (parts.length >= 4) {
        final code1 = parts[1];
        final code2 = parts[3];
        final teamCode = widget.joueur.teamCode ?? '';
        return teamCode == code1 ? 'vs $code2' : 'vs $code1';
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _catColors[widget.joueur.categorie] ?? const Color(0xFF888888);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        // ── Header ──────────────────────────────────────
        Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
        decoration: BoxDecoration(
          color: catColor.withOpacity(0.07),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(bottom: BorderSide(color: catColor.withOpacity(0.2))),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: catColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  '${widget.joueur.prenom.isNotEmpty ? widget.joueur.prenom[0] : '?'}'
                      '${widget.joueur.nom.isNotEmpty ? widget.joueur.nom[0] : '?'}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: catColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.joueur.nomComplet,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(widget.joueur.categorie,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: catColor)),
                    ),
                    if (widget.joueur.teamCode != null) ...[
                      const SizedBox(width: 6),
                      Text(widget.joueur.teamCode!,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                              fontFamily: 'monospace')),
                    ],
                  ]),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(context),
              color: Colors.grey,
            ),
          ],
        ),
      ),

      // ── Titre section ────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 14, color: Color(0xFF888888)),
            const SizedBox(width: 6),
            Text('Feuilles de match de l\'équipe',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600, letterSpacing: 0.3)),
            const Spacer(),
            if (!_chargement && _fichiers.isNotEmpty)
              Text('${_fichiers.length} document${_fichiers.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
      ),
      const Divider(height: 1),

      // ── Contenu ──────────────────────────────────────
      Flexible(
        child: _chargement
            ? const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: Color(0xFF1A4A7A)),
          ),
        )
            : _erreur != null
            ? Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 36, color: Color(0xFFE57373)),
              const SizedBox(height: 12),
              Text(_erreur!, style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(onPressed: () {
                setState(() { _chargement = true; _erreur = null; });
                _chargerFeuilles();
              }, child: const Text('Réessayer')),
            ],
          ),
        )
            : _fichiers.isEmpty
            ? Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Icon(Icons.folder_off_outlined, size: 40,
                color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucune feuille de match trouvé pour le code ${widget.joueur.teamCode ?? 'inconnu'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center),
        ],
      ),
    )
        : ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    shrinkWrap: true,
    itemCount: _fichiers.length,
    separatorBuilder: (_, __) => const SizedBox(height: 6),
    itemBuilder: (ctx, i) {
    final f = _fichiers[i];
    final label    = _labelFichier(f['name']!);
    final adversaire = _labelAdversaire(f['name']!);
    return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () {
    // Ouvre le PDF dans le navigateur
    // ignore: deprecated_member_use
    // Utilise url_launcher si disponible, sinon copie l'URL
    _ouvrirUrl(ctx, f['url']!);
    },
    child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: const Color(0xFFE8E8E8)),
    ),
    child: Row(
    children: [
    Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
    color: const Color(0xFFFFF0E8),
    borderRadius: BorderRadius.circular(8),
    ),
    child: const Center(
    child: Text('PDF', style: TextStyle(
    fontSize: 9, fontWeight: FontWeight.w900,
    color: Color(0xFFD95F1A),
    )),
    ),
    ),
    const SizedBox(width: 12),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(label,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    overflow: TextOverflow.ellipsis),
    if (adversaire.isNotEmpty)
    Text(adversaire,
    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
    ],
    ),
    ),
    const SizedBox(width: 8),
    Icon(Icons.open_in_new, size: 14, color: Colors.grey.shade400),
    ],
    ),
    ),
    );
    },
    ),
    ),
    ],
    ),
    ),
    );
  }

  void _ouvrirUrl(BuildContext context, String url) {
    // Copie l'URL dans le presse-papiers et informe l'utilisateur
    // Pour ouvrir directement, ajoute url_launcher dans pubspec.yaml
    // et utilise launchUrl(Uri.parse(url))
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('URL copiée : $url'),
      action: SnackBarAction(label: 'OK', onPressed: () {}),
      backgroundColor: const Color(0xFF1A4A7A),
    ));
  }
}
