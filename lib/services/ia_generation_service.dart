import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'equipes_mapping.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODÈLES DE RÉPONSE IA
// ─────────────────────────────────────────────────────────────────────────────

class MatchPouleIA {
  final String categorie;    // "R15M" | "R7M" | "R7F"
  final String poule;        // "A" … "F"
  final String codeEquipe1;  // "R15M9"
  final String equipe1;      // "XV Purpanais"
  final String codeEquipe2;  // "R15M2"
  final String equipe2;      // "Unilasalle Beauvais XV"
  final String start;        // "2025-05-10 10:00:00"
  final String terrain;      // "rs" | "corteva" | …
  String? gagnant;           // null tant que non joué

  MatchPouleIA({
    required this.categorie,
    required this.poule,
    required this.codeEquipe1,
    required this.equipe1,
    required this.codeEquipe2,
    required this.equipe2,
    required this.start,
    required this.terrain,
    this.gagnant,
  });

  factory MatchPouleIA.fromJson(Map<String, dynamic> j) => MatchPouleIA(
    categorie:   j['categorie']   ?? '',
    poule:       j['poule']       ?? '',
    codeEquipe1: j['codeEquipe1'] ?? '',
    equipe1:     j['equipe1']     ?? '',
    codeEquipe2: j['codeEquipe2'] ?? '',
    equipe2:     j['equipe2']     ?? '',
    start:       j['start']       ?? '2025-05-10 09:00:00',
    terrain:     j['terrain']     ?? '',
    gagnant:     j['gagnant'],
  );

  Map<String, dynamic> toSupabase() => {
    'Poule':        poule,
    'CodeCategorie': categorie,
    'Categorie':    categorie,
    'Gagnant':      '0',
    'CodeEquipe1':  codeEquipe1,
    'Equipe1':      equipe1,
    'CodeEquipe2':  codeEquipe2,
    'Equipe2':      equipe2,
    'Niveau':       '3',
    'Score1':       '0',
    'Score2':       '0',
    'Start':        start,
    'Terrain':      terrain,
    'NbEssai1':     '0',
    'NbEssai2':     '0',
    'CartonJaune1': '0',
    'CartonJaune2': '0',
    'CartonRouge1': '0',
    'CartonRouge2': '0',
  };

  MatchPouleIA copyWith({String? start, String? terrain}) => MatchPouleIA(
    categorie: categorie, poule: poule,
    codeEquipe1: codeEquipe1, equipe1: equipe1,
    codeEquipe2: codeEquipe2, equipe2: equipe2,
    start: start ?? this.start,
    terrain: terrain ?? this.terrain,
    gagnant: gagnant,
  );
}

class MatchArbreIA {
  final String id;           // ex: "11" (ID match dans la table R15M)
  final String categorie;
  final String niveau;       // "1"=8e "2"=qf "3"=sf "4"=finale
  String start;
  String terrain;

  MatchArbreIA({
    required this.id,
    required this.categorie,
    required this.niveau,
    required this.start,
    required this.terrain,
  });

  factory MatchArbreIA.fromJson(Map<String, dynamic> j) => MatchArbreIA(
    id:        j['id']        ?? '',
    categorie: j['categorie'] ?? '',
    niveau:    j['niveau']    ?? '1',
    start:     j['start']     ?? '2025-05-10 08:00:00',
    terrain:   j['terrain']   ?? '',
  );

  Map<String, dynamic> toSupabase() => {
    'id':            id,
    'CodeCategorie': categorie,
    'Categorie':     categorie,
    'Gagnant':       '0',
    'Niveau':        niveau,
    'Score1':        '0',
    'Score2':        '0',
    'Start':         start,
    'Terrain':       terrain,
    'NbEssai1':      '0',
    'NbEssai2':      '0',
    'CartonJaune1':  '0',
    'CartonJaune2':  '0',
    'CartonRouge1':  '0',
    'CartonRouge2':  '0',
    'CartonBleu1':   '0',
    'CartonBleu2':   '0',
  };

  String get phaseLabel {
    switch (niveau) {
      case '1': return '1/8 de finale';
      case '2': return '1/4 de finale';
      case '3': return '1/2 finale';
      case '4': return 'Finale';
      default:  return 'Niveau $niveau';
    }
  }
}

class IaGenerationResult {
  final List<MatchPouleIA> matchsPoule;
  final List<MatchArbreIA> matchsArbre;
  final String rawJson;
  final String? erreur;

  IaGenerationResult({
    required this.matchsPoule,
    required this.matchsArbre,
    required this.rawJson,
    this.erreur,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class IaGenerationService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model  = 'claude-sonnet-4-20250514';
  final _supabase = Supabase.instance.client;

  // ── Appel Claude avec le fichier Excel en base64 ──────────────────────────
  Future<IaGenerationResult> genererDepuisExcel({
    required Uint8List excelBytes,
    required String dateBase,           // "2025-05-10"
    required String apiKey,             // "sk-ant-..."
    required void Function(String) onLog,
  }) async {
    onLog('📤 Envoi du fichier Excel à Claude...');

    final base64Excel = base64Encode(excelBytes);
    final systemPrompt = _buildSystemPrompt(dateBase);
    final userPrompt   = _buildUserPrompt();

    final body = jsonEncode({
      'model':      _model,
      'max_tokens': 8000,
      'system':     systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'document',
              'source': {
                'type':       'base64',
                'media_type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                'data':       base64Excel,
              },
            },
            {
              'type': 'text',
              'text': userPrompt,
            },
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':         apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('API Anthropic erreur ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final rawText = (decoded['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('');

    onLog('✓ Réponse reçue de Claude (${rawText.length} caractères)');

    return _parseResponse(rawText, onLog);
  }

  // ── Parsing de la réponse JSON de Claude ──────────────────────────────────
  IaGenerationResult _parseResponse(String rawText, void Function(String) onLog) {
    try {
      // Extraire le JSON entre ```json et ```
      String jsonStr = rawText;
      final start = rawText.indexOf('```json');
      final end   = rawText.lastIndexOf('```');
      if (start != -1 && end > start) {
        jsonStr = rawText.substring(start + 7, end).trim();
      } else {
        // Essayer de trouver directement un { }
        final s = rawText.indexOf('{');
        final e = rawText.lastIndexOf('}');
        if (s != -1 && e > s) jsonStr = rawText.substring(s, e + 1);
      }

      final Map<String, dynamic> parsed = jsonDecode(jsonStr);

      final matchsPoule = (parsed['matchs_poule'] as List? ?? [])
          .map((m) => MatchPouleIA.fromJson(m as Map<String, dynamic>))
          .toList();

      final matchsArbre = (parsed['matchs_arbre'] as List? ?? [])
          .map((m) => MatchArbreIA.fromJson(m as Map<String, dynamic>))
          .toList();

      onLog('✓ ${matchsPoule.length} matchs de poule parsés');
      onLog('✓ ${matchsArbre.length} matchs de compétition parsés');

      return IaGenerationResult(
        matchsPoule: matchsPoule,
        matchsArbre: matchsArbre,
        rawJson:     jsonStr,
      );
    } catch (e) {
      return IaGenerationResult(
        matchsPoule: [],
        matchsArbre: [],
        rawJson:     rawText,
        erreur:      'Erreur parsing JSON : $e',
      );
    }
  }

  // ── Insertion en base de données ──────────────────────────────────────────
  Future<void> insererEnBase({
    required List<MatchPouleIA> matchsPoule,
    required List<MatchArbreIA> matchsArbre,
    required void Function(String) onLog,
    required void Function(double) onProgress,
  }) async {
    final total = matchsPoule.length + matchsArbre.length;
    var done = 0;

    // ── Vider les tables existantes ──
    onLog('━━ Vidage des tables existantes...');
    for (final cat in ['R15M', 'R7M', 'R7F']) {
      await _supabase.from('Poule$cat').delete().neq('id', -1);
      await _supabase.from(cat).delete().neq('id', '');
      onLog('  ✓ Tables Poule$cat et $cat vidées');
    }

    // ── Insertion matchs de poule ──
    onLog('━━ Insertion des matchs de poule...');
    for (final m in matchsPoule) {
      try {
        await _supabase.from('Poule${m.categorie}').insert(m.toSupabase());
        onLog('  ✓ ${m.categorie} Poule ${m.poule} — ${m.equipe1} vs ${m.equipe2}');
      } catch (e) {
        onLog('  ✗ ERREUR ${m.equipe1} vs ${m.equipe2} : $e');
      }
      done++;
      onProgress(done / total);
    }

    // ── Insertion matchs arbre ──
    onLog('━━ Insertion des matchs de compétition...');
    for (final m in matchsArbre) {
      try {
        await _supabase.from(m.categorie).insert(m.toSupabase());
        onLog('  ✓ ${m.categorie} ${m.phaseLabel} — id: ${m.id}');
      } catch (e) {
        onLog('  ✗ ERREUR ${m.categorie} ${m.id} : $e');
      }
      done++;
      onProgress(done / total);
    }

    // ── Mise à jour des équipes (poule attribuée) ──
    onLog('━━ Mise à jour des équipes dans Supabase...');
    final equipesMaj = <String, String>{};
    for (final m in matchsPoule) {
      equipesMaj[m.codeEquipe1] = m.poule;
      equipesMaj[m.codeEquipe2] = m.poule;
    }
    for (final entry in equipesMaj.entries) {
      try {
        await _supabase.from('Equipes')
            .update({'Poule': entry.value})
            .eq('id', entry.key);
        onLog('  ✓ ${entry.key} → Poule ${entry.value}');
      } catch (e) {
        onLog('  ✗ ERREUR MAJ équipe ${entry.key} : $e');
      }
    }

    onLog('');
    onLog('✓ Génération terminée avec succès !');
  }

  // ── Prompt système ────────────────────────────────────────────────────────
  String _buildSystemPrompt(String dateBase) {
    return '''Tu es un assistant expert en gestion de tournois de rugby. 
Tu reçois un fichier Excel de planning de tournoi et tu dois extraire tous les matchs pour les insérer dans une base de données Supabase.

## TABLE DE CORRESPONDANCE DES ÉQUIPES
Le fichier Excel utilise des codes courts (ex: "a1", "b3") pour identifier les équipes.
Voici la correspondance exacte avec les identifiants de la base de données :

${EquipesMapping.fullPromptMapping}

## FORMAT DES DATES
La date de base du tournoi est : $dateBase
Les horaires dans le fichier sont au format "10h", "10h30", "11h15", etc.
Tu dois les convertir en format SQL : "${dateBase} HH:MM:00"
Exemple : "10h30" → "${dateBase} 10:30:00"
Exemple : "11h15" → "${dateBase} 11:15:00"

## STRUCTURE DES TABLES SUPABASE

### Matchs de poule (table "PouleR15M", "PouleR7M", "PouleR7F")
- categorie : "R15M" | "R7M" | "R7F"
- poule : "A" | "B" | "C" | "D" | "E" | "F"
- codeEquipe1 : team-code de l'équipe 1 (ex: "R15M9")
- equipe1 : nom de l'équipe 1
- codeEquipe2 : team-code de l'équipe 2
- equipe2 : nom de l'équipe 2
- start : datetime SQL (ex: "2025-05-10 10:00:00")
- terrain : nom du terrain (ex: "rs", "corteva", "isagri", "valeco", "La manutention")

### Matchs de compétition (table "R15M", "R7M", "R7F") 
- id : identifiant du match (ex: "11", "12", etc. selon la numérotation du tableau)
- categorie : "R15M" | "R7M" | "R7F"  
- niveau : "1"=1/8 de finale, "2"=1/4 de finale, "3"=1/2 finale, "4"=finale
- start : datetime SQL
- terrain : nom du terrain

## RÈGLES IMPORTANTES
1. Pour chaque match "X vs Y", X est toujours CodeEquipe1 et Y CodeEquipe2
2. Les terrains peuvent être abrégés dans le tableau (rs = grand terrain principal, corteva = terrain corteva, etc.)
3. Il y a 2 jours de poules : le tableau montre "Jour 1" et "Jour 2" (ou "planning 2ème jour")
4. Inclus TOUS les matchs de poule des 3 catégories (R15M, R7M, R7F)
5. Inclus TOUS les matchs de l'arbre (8èmes, quarts, demis, finale) pour les 3 catégories

## FORMAT DE RÉPONSE
Réponds UNIQUEMENT avec un JSON valide, sans texte avant ou après, dans ce format exact :

```json
{
  "matchs_poule": [
    {
      "categorie": "R15M",
      "poule": "A",
      "codeEquipe1": "R15M9",
      "equipe1": "XV Purpanais",
      "codeEquipe2": "R15M8",
      "equipe2": "ENSAM P3 Rugby",
      "start": "${dateBase} 10:00:00",
      "terrain": "rs"
    }
  ],
  "matchs_arbre": [
    {
      "id": "11",
      "categorie": "R15M",
      "niveau": "1",
      "start": "${dateBase} 08:00:00",
      "terrain": "rs"
    }
  ]
}
```''';
  }

  String _buildUserPrompt() {
    return '''Analyse ce fichier Excel de planning de tournoi de rugby Ovalies.

Extrait TOUS les matchs de toutes les catégories (R15M, R7M, R7F) :
1. Les matchs de poule du jour 1 ET du jour 2
2. Les matchs de l'arbre de compétition (8èmes, quarts, demis, finale)

Utilise la table de correspondance fournie pour convertir les codes Excel (a1, b3, etc.) en team-codes de la base de données.

Réponds uniquement avec le JSON demandé.''';
  }
}
