# TRACE

Jeu en monde ouvert sur la construction de l'identité. Moteur : **Godot 4.7** (GDScript, physique Jolt).

## Phase 1 : « Le geste »

On veut un îlot en blocs gris où l'on marche, où l'on monte sur la planche et où l'on enchaîne quelques figures. On ne travaille pas encore l'art : on juge seulement si le skate est **agréable**.

**Démo de fin de phase** : 10 minutes de skate dans le gris, filmées, puis montrées à 3 skateurs.

### Ouvrir le projet
Sur ce PC, le moteur est déjà extrait dans `.tools/godot/` :
- Double-clique sur `Jouer-TRACE.cmd` pour jouer directement.
- Double-clique sur `Ouvrir-Godot.cmd` pour ouvrir le projet dans l'éditeur.

Pour une installation sur un autre PC :
1. Dézippe Godot 4.7.2 (version standard) et lance `Godot_v4.7.2-stable_win64.exe`.
2. Dans le gestionnaire de projets, clique sur **Importer** et choisis le fichier `project.godot` de ce dossier.
3. Appuie sur **F5** (ou ▶ en haut à droite) pour jouer.

Validation locale du 19 novembre 2026 : import et lancement sous Godot 4.7.2,
affichage Vulkan Forward+, puis 20 vérifications automatisées réussies
(orientation des obstacles, marche, planche, poussée, figures, grind et chute).
Le ressenti du skate reste à évaluer en jouant.

### Contrôles
| Action | Clavier | Manette |
| --- | --- | --- |
| Se déplacer / diriger la planche | ZQSD | stick gauche |
| Caméra | souris | stick droit |
| Monter / descendre de la planche | E | Y / △ |
| Pousser | Maj (ou Z) | gâchette droite |
| Freiner | S | stick vers le bas |
| Saut / ollie | Espace | A / ✕ |
| Kickflip (en l'air) | J | X / □ |
| Shove-it (en l'air) | K | B / ○ |
| Grind 50-50 (maintenir près d'un rail) | L | épaule droite |
| Revenir au départ | R | Select |
| Libérer la souris | Échap | — |

Les 4 figures sont l'ollie, le kickflip, le shove-it et le 50-50.
Les 3 obstacles sont le kicker (au centre), le rail (à droite) et le ledge (à gauche).

### Où régler le « feel »
Tous les réglages sont exposés dans l'inspecteur. Clique sur le nœud `Player > SkateController` et modifie les valeurs en jouant :
- **Roulage** : poussée, vitesse max, frottement, virage, effet des pentes
- **Air** : hauteur de l'ollie, contrôle en l'air, durée des flips
- **Grind** : rayon d'accroche au rail, vitesse minimale

Si une figure n'est pas finie à l'atterrissage, c'est une **chute** : la vitesse est fortement réduite.

### Structure
```
project.godot
scenes/   lauriers.tscn (le quartier réel, scène lancée par défaut), ilot_grey.tscn (cour de réglage du skate), player.tscn (LOUMS)
scripts/  player_controller.gd (marche, caméra, HUD)
          skate_controller.gd  (physique du skate, figures, grind)
          rail.gd              (rail / ledge réglable)
          input_setup.gd       (contrôles clavier + manette)
data/     (phase 3 : npcs.json, places.json…)
```

## Phase 2 — le quartier réel

`scenes/lauriers.tscn` est la scène lancée par défaut. Le quartier est construit au lancement par
`scripts/quartier_reel.gd` à partir du relevé `data/quartier_reel.txt` :

- contours des bâtiments et tracé des rues : © les contributeurs d'OpenStreetMap (ODbL) ;
- relief : IGN, RGE ALTI (licence ouverte), grille de 25 m.

Les positions, les formes au sol et les pentes sont donc celles du terrain. Les **hauteurs** et les **couleurs**
des immeubles sont des estimations : elles se corrigent dans le fichier de relevé (une ligne par bâtiment).
Les habitants, eux, restent fictifs.

Vérification automatique : `.tools/verify_quartier.gd`.

## Rendu « bande dessinée »

Le quartier est rendu en BD : aplats de couleur en trois tons (soleil, demi-teinte, ombre teintée violet),
traits d'encre sur les silhouettes et les arêtes, cadres de fenêtres encrés, ciel franc.
**Touche B** : comparer avec l'éclairage d'origine.

- `scripts/style_bd.gd` (nœud `StyleBD` de `lauriers.tscn`) convertit automatiquement chaque matériau
  standard en matériau BD, y compris les objets ajoutés plus tard (Loums importé, décors…).
- `shaders/bd_lumiere.gdshaderinc` : la lumière en trois tons, partagée par tous les matériaux.
- `shaders/bd_encrage.gdshader` : l'encrage plein écran (épaisseur, sensibilité, portée réglables).
- Réglages communs dans *Projet > Paramètres du projet > Shader Globals* :
  `bd_ombre` (couleur des ombres), `bd_trame` (hachures dans les ombres, 0 = aucune), `bd_actif`.
- La palette des sols et des voies est dans `scripts/quartier_reel.gd` (constantes `VOIES`, `ZONES`, `STYLES`).

Captures automatiques : `godot --path . -s .tools/capture.gd -- <dossier> [bd|brut]`.

## Le son

Tous les bruitages (pas, planche, figures, grind, grimpe, graffiti, habitants, scooter, ambiance jour/nuit)
sont dans `assets/sons/`, fabriqués par `.tools/son_generer.py`, et joués par `scripts/son.gd` (autoload « Son »)
qui observe le jeu sans toucher au gameplay. Détail, liste des sons et façon de les remplacer par de vrais
enregistrements : `assets/sons/LISEZMOI.md`. Vérification : `.tools/verify_son.gd`.
