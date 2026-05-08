// lib/pages/suivi_matchs_page.dart
//
// MODIFICATIONS v2 — Ajout de l'onglet "Consolantes"
//
// CHANGEMENTS :
//   • TabController(length: 2 → 3)
//   • Import de widgets/consolantes_tab.dart
//   • _buildTabBar() : 3ᵉ tab "Consolantes" avec Icons.emoji_events_outlined
//   • TabBar standalone : idem
//   • _buildBody() / TabBarView : ajout de ConsolantesTab()

import 'package:flutter/material.dart';
import 'widgets/liste_matchs_tab.dart';
import 'widgets/arbre_tournoi_tab.dart';
import 'widgets/consolantes_tab.dart'; // ← NOUVEAU

class SuiviMatchsPage extends StatefulWidget {
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
    _tabController = TabController(length: 3, vsync: this); // ← 3
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── TabBar partagé (mode onglet dans TiragePage) ───────────────────────────
  TabBar _buildTabBar() => TabBar(
    controller: _tabController,
    labelColor: const Color(0xFF1A5C2A),
    unselectedLabelColor: Colors.grey,
    indicatorColor: const Color(0xFF1A5C2A),
    indicatorWeight: 3,
    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    unselectedLabelStyle: const TextStyle(fontSize: 13),
    tabs: const [
      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.format_list_bulleted_rounded, size: 16),
        SizedBox(width: 8),
        Text('Liste des matchs'),
      ])),
      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_tree_rounded, size: 16),
        SizedBox(width: 8),
        Text('Arbre du tournoi'),
      ])),
      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [  // ← NOUVEAU
        Icon(Icons.emoji_events_outlined, size: 16),
        SizedBox(width: 8),
        Text('Consolantes'),
      ])),
    ],
  );

  // ── Corps commun ───────────────────────────────────────────────────────────
  Widget _buildBody() => TabBarView(
    controller: _tabController,
    children: const [
      ListeMatchsTab(),
      ArbreTournoiTab(),
      ConsolantesTab(), // ← NOUVEAU
    ],
  );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!widget.standaloneMode) {
      return Column(children: [
        Container(color: Colors.white, child: _buildTabBar()),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ]);
    }

    // Mode standalone : AppBar complète
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5C2A),
        foregroundColor: Colors.white,
        title: const Row(children: [
          Text('Ovalies', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          SizedBox(width: 8),
          Text('Admin — Suivi des matchs',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFFAED6B5))),
        ]),
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
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.format_list_bulleted_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Liste des matchs'),
                ])),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.account_tree_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Arbre du tournoi'),
                ])),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [ // ← NOUVEAU
                  Icon(Icons.emoji_events_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Consolantes'),
                ])),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }
}