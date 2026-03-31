import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

final supabase = Supabase.instance.client;

const Map<String, String> tablePoule = {
  'R15M': 'PouleR15M',
  'R7M': 'PouleR7M',
  'R7F': 'PouleR7F',
};

const Map<String, String> tableArbre = {
  'R15M': 'R15M',
  'R7M': 'R7M',
  'R7F': 'R7F',
};

const List<String> categories = ['R15M', 'R7M', 'R7F'];
const List<String> poules = ['A', 'B', 'C', 'D', 'E', 'F'];

class TournoisService {
  // ── Chargement des équipes ─────────────────────────────────────────────────
  Future<List<Equipe>> chargerEquipes() async {
    final data = await supabase
        .from('Equipes')
        .select('id, Name, Categorie, Poule')
        .order('id');
    return (data as List).map((e) => Equipe.fromJson(e)).toList();
  }

  // ── Génération round-robin poule ──────────────────────────────────────────
  List<MatchPoule> genererMatchsPoule(
      Map<String, Map<String, List<Equipe>>> poulesParCat) {
    final List<MatchPoule> matchs = [];
    for (final cat in categories) {
      for (final poule in poules) {
        final equipes = poulesParCat[cat]?[poule] ?? [];
        if (equipes.length < 2) continue;
        for (int i = 0; i < equipes.length; i++) {
          for (int j = i + 1; j < equipes.length; j++) {
            matchs.add(MatchPoule(
              poule: poule,
              cat: cat,
              eq1: equipes[i],
              eq2: equipes[j],
            ));
          }
        }
      }
    }
    return matchs;
  }

  // ── Génération de l'arbre de compétition ──────────────────────────────────
  List<MatchArbre> genererMatchsArbre() {
    final List<MatchArbre> matchs = [];
    for (final cat in categories) {
      // Niveau 1 : 11→18
      for (int i = 1; i <= 8; i++) {
        matchs.add(MatchArbre(id: '1$i', cat: cat, niveau: '1'));
      }
      // Niveau 2 : 21→24
      for (int i = 1; i <= 4; i++) {
        matchs.add(MatchArbre(id: '2$i', cat: cat, niveau: '2'));
      }
      // Niveau 3 : 31, 32
      for (int i = 1; i <= 2; i++) {
        matchs.add(MatchArbre(id: '3$i', cat: cat, niveau: '3'));
      }
      // Niveau 4 : 41
      matchs.add(MatchArbre(id: '41', cat: cat, niveau: '4'));
    }
    return matchs;
  }

  // ── INSERTION COMPLÈTE ────────────────────────────────────────────────────
  Future<void> genererTout({
    required Map<String, Map<String, List<Equipe>>> poulesParCat,
    required List<MatchPoule> matchsPoule,
    required List<MatchArbre> matchsArbre,
    required void Function(String msg, bool isError) onLog,
    required void Function(double progress) onProgress,
  }) async {
    int done = 0;
    final total = matchsPoule.length + matchsArbre.length +
        categories.fold<int>(0, (s, c) =>
        s + poules.fold<int>(0, (ss, p) => ss + (poulesParCat[c]?[p]?.length ?? 0)));

    void progress(String msg, {bool error = false}) {
      done++;
      onLog(msg, error);
      onProgress(done / total);
    }

    // 1. UPDATE Equipes → Poule
    onLog('━━ Mise à jour des poules dans Equipes', false);
    for (final cat in categories) {
      for (final poule in poules) {
        for (final eq in (poulesParCat[cat]?[poule] ?? [])) {
          try {
            await supabase.from('Equipes').update({'Poule': poule}).eq('id', eq.id);
            progress('  ✓ ${eq.name} → Poule $poule');
          } catch (e) {
            progress('  ✗ ${eq.name}: $e', error: true);
          }
        }
      }
    }

    // 2. INSERT Matchs de poule
    onLog('━━ Insertion des matchs de poule', false);
    for (final cat in categories) {
      final table = tablePoule[cat]!;
      onLog('  → $table', false);

      // Vider la table
      try {
        await supabase.from(table).delete().gte('id', 1);
        onLog('  ✓ $table vidée', false);
      } catch (e) {
        onLog('  ⚠ Impossible de vider $table: $e', true);
      }

      final matchsCat = matchsPoule.where((m) => m.cat == cat).toList();
      for (final m in matchsCat) {
        try {
          final row = {
            'Poule': m.poule,
            'CodeCategorie': cat,
            'Gagnant': '0',
            'Categorie': cat,
            'CodeEquipe1': m.eq1.id,
            'CodeEquipe2': m.eq2.id,
            'Equipe1': m.eq1.name,
            'Equipe2': m.eq2.name,
            'Niveau': '1',
            'Score1': null,
            'Score2': null,
            'Start': m.start != null ? _formatDatetime(m.start!) : '2025-05-10 08:00:00',
            'Terrain': m.terrain,
            'Profondeur': null,
            'CartonJaune1': '0',
            'CartonJaune2': '0',
            'CartonRouge1': '0',
            'CartonRouge2': '0',
            'CartonBleu1': '0',
            'CartonBleu2': '0',
            'NbEssai1': '0',
            'NbEssai2': '0',
          };
          await supabase.from(table).insert(row);
          progress('  ✓ Poule ${m.poule}: ${m.eq1.name} vs ${m.eq2.name}');
        } catch (e) {
          progress('  ✗ Poule ${m.poule} ${m.eq1.name} vs ${m.eq2.name}: $e', error: true);
        }
      }
    }

    // 3. INSERT Arbre de compétition
    onLog('━━ Insertion de l\'arbre de compétition', false);
    for (final cat in categories) {
      final table = tableArbre[cat]!;
      onLog('  → $table', false);

      // Vider la table arbre
      try {
        await supabase.from(table).delete().gte('id', '0');
        onLog('  ✓ $table vidée', false);
      } catch (e) {
        onLog('  ⚠ Impossible de vider $table: $e', true);
      }

      final matchsCat = matchsArbre.where((m) => m.cat == cat).toList();
      for (final m in matchsCat) {
        try {
          final row = <String, dynamic>{
            'id': m.id,
            'CodeCategorie': cat,
            'Gagnant': null,
            'Categorie': cat,
            'CodeEquipe1': null,
            'CodeEquipe2': null,
            'Equipe1': null,
            'Equipe2': null,
            'Niveau': m.niveau,
            'Score1': null,
            'Score2': null,
            'Start': m.start != null ? _formatDatetime(m.start!) : null,
            'Terrain': m.terrain,
            'CartonJaune1': '0',
            'CartonJaune2': '0',
            'CartonRouge1': '0',
            'CartonRouge2': '0',
            'NbEssai1': '0',
            'NbEssai2': '0',
          };
          if (cat == 'R15M') {
            row['CartonBleu1'] = '0';
            row['CartonBleu2'] = '0';
          }
          await supabase.from(table).insert(row);
          progress('  ✓ $cat match ${m.id} — ${m.phaseLabel}');
        } catch (e) {
          progress('  ✗ $cat match ${m.id}: $e', error: true);
        }
      }
    }
  }

  String _formatDatetime(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '-${dt.month.toString().padLeft(2, '0')}'
        '-${dt.day.toString().padLeft(2, '0')}'
        ' ${dt.hour.toString().padLeft(2, '0')}'
        ':${dt.minute.toString().padLeft(2, '0')}:00';
  }
}
