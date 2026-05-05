// lib/pages/suivi_matchs_fauteuil_page.dart
//
// Page "Rugby en Fauteuil" — point d'entrée des deux vues RF.
// Clone de suivi_matchs_page.dart, dédié exclusivement à la catégorie RF.
//
// Ouverte en mode standalone depuis home_page.dart.
//
// FICHIERS TOUCHÉS :
//   • lib/pages/suivi_matchs_fauteuil_page.dart          → NOUVEAU
//   • lib/pages/widgets/liste_matchs_fauteuil_tab.dart   → NOUVEAU (étape 3)
//   • lib/pages/widgets/arbre_fauteuil_tab.dart          → NOUVEAU (étape 4)

import 'package:flutter/material.dart';
import 'widgets/liste_matchs_fauteuil_tab.dart';
import 'widgets/arbre_fauteuil_tab.dart';

class SuiviMatchsFauteilPage extends StatefulWidget {
  const SuiviMatchsFauteilPage({super.key});

  @override
  State<SuiviMatchsFauteilPage> createState() => _SuiviMatchsFauteilPageState();
}

class _SuiviMatchsFauteilPageState extends State<SuiviMatchsFauteilPage>
    with TickerProviderStateMixin {
  // Couleur RF — identique à _catColors['RF'] dans joueurs_page.dart
  static const Color _couleurRF = Color(0xFF1A4A7A);
  static const Color _couleurRFLight = Color(0xFF8BADD4);

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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: _couleurRF,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text(
              'Ovalies',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            SizedBox(width: 8),
            Text(
              'Rugby en Fauteuil',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _couleurRFLight,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: _couleurRF,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: _couleurRFLight,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
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
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ListeMatchsFauteilTab(),
          ArbreFauteilTab(),
        ],
      ),
    );
  }
}
