# TRACE — pilote Unreal « Parvis Diderot » (26.11 → 09.12.2026)

Décidé par Louma le 26.11 : priorité au rendu maximal sur PC, direction BD / Miyazaki conservée mais enrichie (matières, lumière), passage à Unreal Engine 5 testé sur **une seule zone** avant toute migration. La version Godot web reste en l'état (tests de gameplay sur téléphone), on n'y développe plus de nouveautés graphiques.

## Objectif

Une zone jouable sur PC, le parvis du lycée Diderot avec la vue sur les Lauriers, où :

1. Loums bouge avec du poids (fin de l'effet « marshmallow ») : marcher, courir, s'arrêter, sauter, enjamber, grimper.
2. Les matières et la lumière sont au niveau de la vidéo de référence (béton, enduit, asphalte, pins, lumière de fin d'après-midi marseillaise).
3. Le rendu reste TRACE : encrage léger, couleurs peintes, beau ciel nuageux.

**Critère de réussite** (jugé par Louma le 09.12) : « en jouant 10 minutes, je ne veux pas revenir à Godot ». Si oui → migration du reste ; sinon → retour Godot en n'ayant perdu que deux semaines.

## Coûts

- Unreal Engine : gratuit (5 % de redevance seulement au-delà de 1 M$ de revenus cumulés).
- Megascans / Megaplants (matières et végétation scannées) : gratuits sur Fab depuis novembre 2026.
- Game Animation Sample (500+ animations, motion matching, enjambement/escalade) : gratuit, licence Unreal uniquement.
- Déjà payés : Meshy Pro (objets, véhicules, personnages), Rokoko (capture des gestes de Louma).

## Répartition

- **Claude** : plan, code C++, scripts Python pour l'éditeur Unreal (imports en série, matières, placement), réglages de rendu, instructions pas à pas pour les manipulations dans l'éditeur.
- **Louma** : manipulations dans l'éditeur (les fichiers Unreal ne sont pas du texte), captures et vidéos à chaque étape, jugement du ressenti.
- Les quatre conversations (gameplay, décor, son, histoire) gardent leur territoire ; ce document sert de référence commune pour le pilote.

## Étapes

### 0. Installation (26 → 27.11, Louma)

- Epic Games Launcher → Unreal Engine 5.8 (version pour laquelle le Game Animation Sample est à jour).
- Fab → « Game Animation Sample » → créer le projet `TRACE_UE` à partir de lui (Blueprint, on ajoutera le C++ ensuite).
- Visual Studio (2022 ou plus récent) avec « Développement de jeux en C++ » — nécessaire dès qu'on écrit du C++.
- Lancer `.tools/export_unreal.gd` dans le projet Godot → `export_unreal/quartier_2013.glb` (géométrie réelle du quartier, pour ne rien perdre de la ressemblance). Voir « Export du quartier » plus bas.
- Envoyer à Claude : modèle exact de la carte graphique, capture du projet `TRACE_UE` ouvert, poids du `.glb`.

### 1. Le corps (28.11 → 02.12)

- Importer Loums (modèle Meshy → Blender si besoin) et le reciblage automatique sur le squelette du mannequin Unreal (IK Retargeter).
- Brancher Loums sur le motion matching du Game Animation Sample : marche, course, arrêts, virages, sauts, enjambement, escalade basse.
- Garder le saut bras écartés « Spider-Man » (animation à reprendre ou à capturer avec Rokoko).
- Caméra selon la règle du 21.11 : libre à l'arrêt, dans le dos dès qu'on bouge.
- Premières captures Rokoko de Louma (3 à 5 s par geste) ajoutées à la banque d'animations.

### 2. Le lieu (29.11 → 04.12, en parallèle)

- Importer `quartier_2013.glb` comme base de volumes (positions et formes réelles), recadré sur le parvis et la vue Lauriers.
- Matières Megascans : béton brut, enduit marseillais, asphalte, trottoirs, bordures ; pins et platanes Megaplants (feuillages sans collision, seul le tronc bloque).
- Lumière : Lumen, soleil de 17-18 h, ciel et nuages volumétriques, brouillard léger avec rayons. Face éclairée / face sombre nettes.
- Voitures Meshy garées droit le long du boulevard Lavéran, avec parcimonie.

### 3. Le style TRACE (03 → 06.12)

- Post-traitement d'encrage (contours depuis profondeur et normales), traits pas trop noirs, Loums exclu de l'encrage sur le visage.
- Ombrage légèrement en aplats, étalonnage chaud « Marseille », ciel peint inspiré des planches Higgsfield de Louma.
- Pas d'excès de liserés jaunes sur les personnages.

### 4. Le ressenti (05 → 08.12)

- Roue d'outils (inspirée de la vidéo de référence) : mains, bombe, perche-rouleau, skate.
- Messages contextuels (« G — graffer » près d'un mur).
- Graffiti mode simple : tag projeté sur le mur, qui grandit tant qu'on maintient.
- Retour d'impact : légère secousse de caméra, particules de peinture, sons en plusieurs couches.

### 5. Bilan (09.12)

- Vidéo de 2 minutes de jeu + captures, comparaison avec Godot, décision de migration.
- Si oui : démo de Noël = pilote poli + premiers défis (« fais ton premier tag », « grimpe sur le toit du lycée »).

## Hors pilote (après)

Skate complet, scooter, escalade par bonds d'arête, progression Skate/Graff/Grimpe, carte de Marseille d'accueil, intérieurs du lycée, version Android.

## Export du quartier (étape 0)

Le quartier est construit au lancement (`quartier_reel.gd`, `habillage*.gd`…) : un export depuis l'éditeur Godot serait vide. Le script `.tools/export_unreal.gd` lance `scenes/marseille_2013.tscn`, attend que le nombre de nœuds soit stable, fige la scène, retire Loums, habitants, caméras, interface, particules et éléments cachés (variantes « après », etc.), puis écrit un `.glb`.

Le plus simple : **double-clique sur `Exporter-Unreal.cmd`** à la racine du dossier TRACE (à côté de `Jouer-TRACE.cmd`). Une fenêtre Godot s'ouvre, laisse-la faire ; la fenêtre noire dit à la fin si le fichier est créé.

Équivalent en ligne de commande (fenêtre visible, **pas** `--headless`, sinon les maillages sortent vides) :

```bat
Godot_v4.7.2-stable_win64.exe --path "C:\Users\Chishan\Downloads\TRACE" -s res://.tools/export_unreal.gd
```

Résultat : `export_unreal\quartier_2013.glb` (dossier ignoré par Godot via `.gdignore` et par Git). Les matières à shader maison (style BD) sortent en gris : c'est voulu, elles seront refaites dans Unreal. Le script ne modifie aucun fichier du projet.

À l'import dans Unreal : Godot exporte en mètres, Y vers le haut ; Unreal convertit automatiquement (échelle 100, Z vers le haut) avec l'importeur glTF / Interchange par défaut.

## Machine de Louma (relevé du 26.11)

- GPU dédié : **NVIDIA RTX 3500 Ada Laptop** (Ada Lovelace, 12 Go de mémoire vidéo ; Windows en affiche ~4 Go, c'est une limite de son compteur). Pilote 596.71 (32.0.15.9671).
- GPU intégré Intel UHD : à ne **jamais** laisser à Unreal (Paramètres Windows → Système → Écran → Graphiques → `UnrealEditor.exe` → Hautes performances). PC branché sur secteur pendant le travail.
- Réglages retenus : Lumen avec ray tracing matériel, Nanite pour Megascans/Megaplants, ombres virtuelles, DLSS (Super Resolution + Frame Generation, disponibles sur Ada). Cible : 60 i/s en 1440p avec DLSS Qualité, sinon 1080p.
