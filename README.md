# Ovalies Admin — Outil de tirage au sort

Projet Flutter séparé pour la gestion du tournoi Ovalies.  
Connexion Supabase intégrée dans le code — usage interne uniquement.

## Lancement

```bash
flutter pub get
flutter run
```

## Structure

```
lib/
├── main.dart                    # Point d'entrée + init Supabase
├── models/models.dart           # Equipe, MatchPoule, MatchArbre
├── services/tournoi_service.dart # Logique DB (chargement, génération, INSERT)
└── pages/
    ├── tirage_page.dart         # Page principale (3 onglets)
    └── widgets/
        ├── tirage_tab.dart      # Onglet 1 : drag & drop des équipes
        ├── horaires_tab.dart    # Onglet 2 : saisie horaires & terrains
        └── generation_tab.dart  # Onglet 3 : récap + bouton générer
```

## Ce que ça fait

1. **Onglet Tirage** : charge les équipes depuis Supabase, drag & drop dans les poules A→F par catégorie (R15M, R7M, R7F)
2. **Onglet Horaires** : saisie des horaires/terrains match par match, ou application automatique avec intervalle
3. **Onglet Génération** : récapitulatif, confirmation, INSERT dans Supabase avec log en direct

## Tables modifiées

- `Equipes` → UPDATE Poule pour chaque équipe
- `PouleR15M`, `PouleR7M`, `PouleR7F` → DELETE + INSERT tous les matchs de poule
- `R15M`, `R7M`, `R7F` → DELETE + INSERT l'arbre (IDs 11→18, 21→24, 31→32, 41)
