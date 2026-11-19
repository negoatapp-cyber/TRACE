# TRACE — missions (conversation n°4, histoire)

*Tenu par la conversation n°4. Mis à jour le 19.11.2026.*

## Territoires

| n° | Rôle | Ne touche pas aux fichiers de… |
|---|---|---|
| 1 | Actions, gameplay, systèmes | — |
| 2 | Décor, habillage | — |
| 3 | Son | — |
| **4** | **Histoire, missions, dialogues** | **1, 2, 3** |

**Fichiers de n°4 :** `scripts/mission.gd`, `histoire/` (les textes), `docs/MISSIONS.md`.
**Seule ligne ajoutée à un fichier partagé :** `Mission="*res://scripts/mission.gd"` dans `[autoload]` de `project.godot`.

## Mission 1, « Premier mur » (≈ 8 min)

Lundi 15 septembre 2014, 16 h 30, devant le lycée. Le cahier est plein de LOUMS : il lui faut un vrai mur.

1. **Le snack.** Il est sur le boulevard Lavéran, en face du lycée. En s'approchant à moins de 5 m pendant 0,5 s, le patron donne quatre bombes pleines et quelques mots. **Aucun bouton** : ça marche au clavier, à la manette et au toucher.
2. **Un mur, au choix.** Un tag suffit. Le lieu compte :
   - **haut** (toit, grimpe) : visible de loin ;
   - **boulevard** (à moins de 45 m du snack) : visible, risqué ;
   - **terrain vague** (à moins de 30 m du conteneur) : discret ;
   - **ailleurs**.
3. **Les témoins.** Le jeu note déjà qui voit Loums (gardien, voisine, jeunes, passant). Loums commente juste après le tag.
4. **Retour au snack.** Le patron réagit selon le lieu et le témoin le plus marquant (gardien > voisine > jeunes > passant > personne).
5. **Fin.** La trace est sauvegardée dans `user://mission.json` : `{type, spot, temoins, vu_par, jour, heure}`. C'est l'entrée du simulateur pour J3.

Pas d'échec bloquant. Être vu ne fait que colorer la fin.

## Ce que n°4 lit (rien n'est modifié chez les autres)

- groupe `ravitaillement` (Area3D, meta `type = "peinture"`), posé par n°2 au snack ;
- groupe `conteneur` ; `graffiti.poses`, `graffiti._trace`, `graffiti._fouiller()` ; le champ `temoins` des poses ;
- `quartier.h(x, z)`, `temps.jour()`, `temps.heure()`.

## Signaux émis (pour n°3, le son)

- `Mission.etape_changee(etape)` : `peinture`, `mur`, `retour`, `fini` ;
- `Mission.mission_terminee(trace)`.

n°3 peut jouer un son à chaque étape en se branchant sur ces signaux, sans rien me demander.

## Demandes aux autres conversations

- **n°1 :** (a) aujourd'hui `_conteneur_proche()` ne reconnaît pas le snack : sur mobile, le bouton FOUILLE n'apparaît donc qu'au conteneur. La mission contourne le problème, mais si tu veux un vrai ravitaillement à la demande, étends-le au groupe `ravitaillement`. (b) Exporte et déploie la version web quand tu veux la tester sur téléphone : n°4 ne déploie pas (coût Vercel). (c) Mets à jour `docs/PLAN.md` : la peinture se prend **au snack** (le conteneur reste un bonus).
- **n°2 :** rien. Ne déplace pas le groupe `ravitaillement` du snack.
- **n°3 :** si tu veux une ambiance ou une voix au snack, branche-toi sur les signaux ci-dessus.

## Tests

- F9 remet la mission à zéro.
- Pour tester vite : va au snack, puis tague un mur, puis reviens.
- Fichier de sauvegarde : `user://mission.json`.
- Vérifié (19.11) : le script passe le contrôle de syntaxe Godot 4.7.2, et l'enchaînement des quatre étapes est passé sur une scène factice. **Pas encore joué dans le vrai jeu ni sur téléphone.**

## Limites connues, à régler en jouant

- Les seuils `HAUTEUR_TOIT` (3 m), `RAYON_TERRAIN_VAGUE` (30 m) et `RAYON_BOULEVARD` (45 m) sont des hypothèses.
- Le toit est détecté par l'altitude de Loums au moment du tag, pas par la hauteur du tag (la perche ne compte donc pas).
- L'interface (objectif et dialogues) est en haut à droite ; à vérifier qu'elle ne gêne pas les boutons tactiles.
- Position du snack et du conteneur : à confirmer sur le terrain (hypothèse de n°2).
