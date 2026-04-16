// lib/pages/suivi_matchs_page.dart
//
// Page "Suivi des matchs" — point d'entrée des deux nouvelles vues.
// Remplace entièrement :
//   • lib/pages/widgets/horaires_tab.dart  (supprimé)
//   • lib/pages/widgets/generation_tab.dart (supprimé)
//
// Elle est intégrée dans tirage_page.dart en tant qu'onglet n°2.
// Elle peut aussi être ouverte de façon autonome depuis home_page.dart.
//
// MODIFICATIONS APPORTÉES :
//   • Nouveau fichier
//   • Contient un TabController avec 2 sous-onglets :
//       1. "Liste des matchs" → ListeMatchsTab
//       2. "Arbre du tournoi" → ArbreTournoiTab

import 'package:flutter/material.dart';
import 'widgets/liste_matchs_tab.dart';
import 'widgets/arbre_tournoi_tab.dart';

class SuiviMatchsPage extends StatefulWidget {
  /// Si [standaloneMode] est true, la page a sa propre AppBar et peut être
  /// poussée directement depuis home_page.dart.
  /// Si false, elle est utilisée comme corps d'un onglet de TiragePage.
  final bool standaloneMode;

  const SuiviMatchsPage({super.key, this.standaloneMode = false});

  @override
  State<SuiviMatchsPage> createState() => _SuiviMatchsPageState();
}

class _SuiviMatchsPageState extends State<SuiviMatchsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── TabBar partagé ─────────────────────────────────────────────────────────
  TabBar _buildTabBar() => TabBar(
    controller: _tabController,
    labelColor: const Color(0xFF1A5C2A),
    unselectedLabelColor: Colors.grey,
    indicatorColor: const Color(0xFF1A5C2A),
    indicatorWeight: 3,
    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    unselectedLabelStyle: const TextStyle(fontSize: 13),
    tabs: const [
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.format_list_bulleted_rounded, size: 16),
            SizedBox(width: 8),
            Text('Liste des matchs'),
          ],
        ),
      ),
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_rounded, size: 16),
            SizedBox(width: 8),
            Text('Arbre du tournoi'),
          ],
        ),
      ),
    ],
  );

  // ── Corps commun ───────────────────────────────────────────────────────────
  Widget _buildBody() => TabBarView(
    controller: _tabController,
    children: const [
      ListeMatchsTab(),
      ArbreTournoiTab(),
    ],
  );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!widget.standaloneMode) {
      // Mode onglet dans TiragePage : pas d'AppBar propre, juste la tab + le corps
      return Column(
        children: [
          Container(
            color: Colors.white,
            child: _buildTabBar(),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      );
    }

    // Mode standalone : AppBar complète
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5C2A),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('Ovalies', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            SizedBox(width: 8),
            Text('Admin — Suivi des matchs',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFFAED6B5))),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: const Color(0xFF1A5C2A),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF7FC99A),
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.format_list_bulleted_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Liste des matchs'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Arbre du tournoi'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }
}
