# Les sons de TRACE

**D'où viennent-ils ?** Ils sont tous *fabriqués par synthèse* par `.tools/son_generer.py` (Python + numpy) :
bruits filtrés, résonances amorties, oscillateurs. Aucun enregistrement, aucune banque de sons, aucun fichier
tiers. Donc aucune licence à respecter et rien de privé dans le dépôt public. Le script tire ses hasards
d'une graine fixe : le relancer redonne exactement les mêmes fichiers.

Le dossier perso `trace/` (mémos vocaux, vidéos, photos de vraies personnes) n'est **pas** utilisé.

    python3 .tools/son_generer.py            # régénère tout dans assets/sons/

## Remplacer un son par un vrai enregistrement
Déposer ici un fichier du même nom (`.wav` ou `.ogg`). Rien à changer dans le code.
- `nom.wav` : un son. `nom_1.wav`, `nom_2.wav`… : des variantes, le jeu en tire une au hasard (jamais deux fois la même d'affilée).
- `nom_loop.wav` : un son qui tourne en boucle (roulage, grind, jet de bombe, moteur, ambiance). Il doit boucler sans clic.
- Au lancement, `Jouer-TRACE.cmd` réimporte tout seul les nouveaux fichiers.

## Qui joue quoi
Tout est branché dans `scripts/son.gd` (autoload « Son »), qui **observe** l'état du jeu sans toucher au gameplay.
Test : `godot --headless --audio-driver Dummy --path . -s res://.tools/verify_son.gd`.

| Famille | Sons |
|---|---|
| Pas, saut | `pas_dur` `pas_herbe` `pas_gravier` (selon le sol), `saut_pied`, `atterri_pied` |
| Planche | `planche_pose` `planche_pied` (monter), `planche_ramasse` `planche_range` (descendre), `pousse`, `frein_loop`, `roule_loop` / `roule_gravier_loop` / `roule_herbe_loop` |
| Figures | `ollie_pop`, `kickflip`, `shoveit`, `atterri_leger` / `atterri_dur`, `grind_debut` `grind_loop` (métal) `grind_beton_loop` (ledge) `grind_fin`, `chute`, `planche_chute`, `choc_planche` |
| Grimpe | `hisse`, `main_mur`, `decale`, `lache`, `course_murale`, `goutiere_agrippe`, `goutiere_grimpe` |
| Graffiti | `bombe_secoue`, `spray_debut` `spray_loop` `spray_fin` `spray_tap`, `bombe_change`, `bombe_vide`, `perche_deplie`, `rouleau_trempe` `rouleau_loop`, `goutte`, `etape_ok`, `graff_pose`, `graff_rate`, `fouille`, `bombes_pleines` |
| Habitants | `vu`, `chasse`, `voix_gardien` `voix_passant` `voix_voisine` `voix_jeune` (marmonnements synthétiques, en attendant de vraies répliques), pas placés dans l'espace |
| Véhicules | `scooter_loop` `voiture_loop`, `demarre_*`, `coupe_*`, `portiere`, `bequille`, `pneu_crisse_loop`, `choc_vehicule` |
| Quartier | `amb_jour_loop` `amb_nuit_loop` (fondu selon l'heure du jeu), `oiseau`, `mouette`, `voiture_loin`, `moto_loin`, `sirene_loin`, `demolition` (tour Cyprès B) |
| Interface | `ui_bascule` (B, T, M), `temps_saut` (N), `respawn` (R) |
