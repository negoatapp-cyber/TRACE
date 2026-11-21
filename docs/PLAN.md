# TRACE — plan de production de la démo

*Document de pilotage. Mis à jour le 19.11.2026. Tenu par la conversation n°1 (gameplay et systèmes).*
*Toute conversation qui travaille sur TRACE lit ce fichier avant de commencer.*

**20.11.2026 — nouvelle cible demandée : Marseille 2013.** Le diagnostic, le plan d'habillage et les résultats de la première étude jouable sont dans [MARSEILLE_2013.md](MARSEILLE_2013.md). L'étude se lance avec `Jouer-Marseille-2013.cmd` ; la scène principale conserve son calendrier existant pendant cette comparaison. Les jalons ci-dessous restent l'historique du plan du 19.11.

## 1. L'objectif

**Une démo jouable de 30 minutes, prête pour Noël (vendredi 25.12.2026).** On est en 2014-2015, dans le quartier des Lauriers et devant le lycée. Le joueur incarne Loums :

- il se déplace à pied et en skate dans le quartier réel ;
- il graffe, du tag rapide à la grosse pièce, à la bombe, à la perche et au rouleau ;
- il grimpe pour atteindre les spots en hauteur ;
- il croise des habitants qui le voient faire ;
- le quartier garde la trace de ce qu'il fait : murs peints, regards, réputation.

Elle est réussie si une personne qui ne connaît pas le projet joue 30 minutes sans s'ennuyer ni rester bloquée, et peut raconter ensuite ce que Loums a fait et ce que le quartier en a retenu.

**Hors de la démo :** les intérieurs (lycée, appartements), les autres villes, les années après 2016, l'histoire complète et les dialogues longs.

## 2. Les quatre jalons

| Jalon | Contenu | Il est fini quand… | Date |
|---|---|---|---|
| **J1. Le corps** | Tous les gestes de Loums sont animés et lisibles : skate, graffiti, grimpe (détail en section 4). | On joue 10 minutes sans voir un seul geste manquant ou faux. | 29.11 |
| **J2. Le quartier vivant** | Habillage du quartier (textures, mobilier urbain, lumière). Des habitants avec leurs trajets et leurs habitudes. Le fait d'être vu. | Le quartier se reconnaît, et quelqu'un réagit quand on graffe sous ses yeux. | 08.12 |
| **J3. La trace** | Branchement du simulateur V3.1 : ce que Loums fait laisse des souvenirs chez les habitants et en lui. Réputation par milieu. Le temps qui passe : jour et nuit, semaines, la tour Cyprès B démolie en juillet 2016. | Deux parties jouées différemment donnent deux quartiers différents. | 16.12 |
| **J4. Le test des 30 minutes** | Réglages, son, menus minimum, puis trois testeurs extérieurs. | Les trois testeurs finissent les 30 minutes. | 22.12 |

On ne commence pas un jalon avant d'avoir joué au précédent.

**Calendrier (5 semaines).** Du 22 au 24.12 : marge, pas de nouveauté, seulement des corrections. Si un jalon glisse de plus de deux jours, on coupe dans le jalon suivant plutôt que de repousser Noël. Ce qu'on coupe en premier, dans l'ordre : le temps qui passe en semaines et la démolition de Cyprès B (J3), puis les réputations par milieu (J3, on garde une seule réputation), puis le rouleau (J1).

## 3. Qui fait quoi

Plusieurs conversations Claude travaillent en parallèle. Pour ne pas se marcher dessus, chacune a son territoire.

| Conversation | Territoire | Fichiers à elle |
|---|---|---|
| **N°1 : gameplay et systèmes** (celle-ci, qui tient ce plan) | Loums, skate, graffiti, grimpe, habitants, simulateur, données du quartier, intégration | `scripts/player_controller.gd`, `skate_controller.gd`, `skateboard.gd`, `graffiti.gd`, `personnage.gd`, `quartier_reel.gd`, `input_setup.gd`, `data/`, `scenes/`, `.tools/`, `docs/PLAN.md` |
| **N°2 : habillage urbain** | Rendu BD, textures, matériaux, mobilier urbain, éclairage, ciel | `scripts/style_bd.gd`, `shaders/bd_*`, `shaders/facade.gdshader`, `assets/decor/`, `materials/`, et un script à elle pour le mobilier, `scripts/habillage.gd` |

**Le point de contact.** `quartier_reel.gd` construit les volumes et range chaque élément dans un groupe Godot : `terrain`, `batiment` (avec le style en métadonnée `style`), `lycee`, `sol_voie`, `sol_zone`, `mur`, `muret`, `rail`, `voiture`, `arbre`. `habillage.gd` passe après la construction et habille ces groupes. N°2 ne modifie pas `quartier_reel.gd` : si un groupe manque, elle le demande à n°1.

**Les règles communes.**

1. **Deux copies du projet existent.** Le dossier du PC (`Downloads\TRACE`), où l'on joue, et GitHub (`negoatapp-cyber/TRACE`, branche `main`), qui garde l'historique.
2. **N°2 travaille directement dans le dossier du PC.** Elle ne touche pas aux fichiers de n°1, sauf pour la palette de couleurs (`STYLES`, `VOIES`, `ZONES`, `BANDES` en tête de `quartier_reel.gd`) et pour ajouter des styles dans `data/quartier_reel.txt`.
3. **N°1 rapatrie le travail du PC sur GitHub** avant chaque mise à jour du PC : elle compare les fichiers, fusionne ce qui a changé des deux côtés, envoie le tout sur GitHub, puis seulement recopie sur le PC. Rien n'est écrasé sans avoir été fusionné.
4. **Rien de privé dans le dépôt**, qui est public : ni le PDF de vie, ni les planches, ni les photos personnelles (`*.jpg` à la racine), ni le modèle de Loums et ses textures (`assets/personnages/` reste en local, licence Meshy privée), ni de vraies personnes.
5. Le lieu est réel et les habitants sont fictifs. Aucune marque réelle visible.

**La version téléphone.** Elle est en ligne sur https://trace-opal-nu.vercel.app (projet Vercel « trace »). N°1 la met à jour après chaque étape jouable : export Web depuis le dépôt (préréglage `export_presets.cfg`), dépôt du résultat sur la branche `web` de GitHub, puis déploiement Vercel de cette branche. Pas de déploiement automatique à chaque modification, pour limiter la consommation Vercel.

## 4. Fiche des gestes (J1)

Chaque geste a une commande, une durée, une animation et un effet. **Décision du 19.11 :** le corps calculé par le code fait « marshmallow ». On passe à de la vraie capture de mouvement, filmée par Louma lui-même et convertie par IA (vidéo → mouvement 3D), avec Sleeping Dogs et Getting Up comme références de fluidité. Le code ne fait plus que caler les pieds et les mains sur le décor. Les animations viennent de la bibliothèque Meshy quand elle a le bon mouvement. Sinon, Loums est posé par le code : rotation des os du squelette et pieds calés par cinématique inverse.

### 4.1 Le skate

| Geste | Commande | Ce qu'on voit | Effet |
|---|---|---|---|
| Sortir la planche | E, à pied | Il pose la planche au sol devant lui, met le pied avant dessus et monte (0,4 s). | Passe en mode skate. |
| Rouler | — | Pieds sur les vis des trucks, genoux fléchis, de profil. **Loums est goofy** : pied droit devant, il regarde vers sa gauche. | — |
| Pousser | Maj, ou stick vers l'avant | Le pied arrière quitte la planche, frappe le sol et revient (cycle de 0,7 s). | Une impulsion à chaque poussée, et non une accélération continue. |
| Tourner | Stick gauche-droite | Le corps se penche et la planche bascule de quelques degrés vers l'intérieur. | Virage plus serré à faible vitesse. |
| Freiner | Stick arrière | Le pied arrière traîne au sol. | Ralentit. |
| Ollie | Maintenir Espace, puis relâcher | Il s'accroupit pendant qu'on maintient, puis le tail claque, la planche monte, le pied avant glisse vers le nose et il se réceptionne genoux fléchis. | La hauteur dépend du temps de maintien (de 0,2 à 0,6 s). |
| Kickflip / shove-it | J / K en l'air | La planche tourne sous lui, il lève les pieds puis la rattrape. | Si elle n'est pas rattrapée, c'est la chute. |
| 50-50 | L près d'un rail | Les deux trucks sont sur le rail, les bras sont écartés. | Glisse le long du rail. |
| Chute | Réception ratée | Il tombe, la planche part en roulant. | Il faut marcher jusqu'à elle pour la ramasser. |
| Ranger la planche | E en skate | Il saute, attrape la planche par le tail et la porte à la main. | Passe en mode à pied, planche en main droite. |

### 4.2 Le graffiti

**Les règles du graffiti (données par Louma).** Les lettres LOUMS doivent toujours se lire, liées entre elles.

| Taille | Couches |
|---|---|
| **Tag** | Une signature, un seul trait. Ça va vite. |
| **Flop** | Fond + contour + surcontour (deux ou trois couches). |
| **Pièce** | Fond + contour (sombre ou clair selon le fond) + lights (touches lumineuses) + surcontour. Plus grosse, souvent signée d'un petit tag. |

Le lettrage est dessiné dans le style du jeu (aplats et encre), pas découpé dans des photos. Les photos de Louma servent de référence pour le trait et l'esprit. Le tag reprend son vrai trait. L'outil `.tools/lettrage.py` fabrique les couches ; le jeu les teinte avec les couleurs des bombes. Les images restent en local (`assets/graffitis/`).

**L'équipement est visible sur lui :** quatre bombes à la ceinture, la perche dans le dos. Le rouleau et le pot sont dans le sac et ne sortent que pour s'en servir.

| Outil | Pour quoi | Commande | Déroulé | Durée |
|---|---|---|---|---|
| **Bombe : tag** | Signature rapide | Maintenir G, peu de temps | Il prend une bombe à la ceinture, la secoue (bruit de bille), tend le bras et fait un trait rapide à hauteur d'yeux. | ~1 s |
| **Bombe : flop** | Lettres rondes, deux couleurs | Maintenir G plus longtemps | Remplissage, puis contour d'une deuxième couleur : il change de bombe au milieu. | 3 à 5 s |
| **Bombe : pièce** | Grosse fresque | Maintenir G, en plusieurs fois | Esquisse, remplissage, contour, contour extérieur, reflets. **On peut s'arrêter et revenir** : le mur garde l'étape atteinte. | 7 à 15 s au total |
| **Perche** | Tag en hauteur, de 3 à 5 m | Maintenir G avec la perche sortie (touche à définir) | Il déplie la perche, y fixe une bombe, lève les bras. Le geste est lent et moins précis. | ~4 s |
| **Rouleau** | Grosses lettres pleines de 1 à 2 m sur un long mur | Maintenir G avec le rouleau sorti | Il pose le pot, trempe le rouleau et trace de haut en bas, lettre après lettre. C'est très visible de loin. | ~3 s par lettre |

**Les règles du graffiti :**

- Chaque bombe a une réserve et le pot de peinture aussi. Quand c'est vide, il faut aller **au conteneur posé derrière la grande barre des Lauriers** (côté terrain vague) et fouiller (F) : quatre bombes pleines, de nouvelles couleurs.
- Plus on reste longtemps devant un mur, plus on s'expose. Un habitant qui passe le voit, et c'est le lien avec J2.
- Les graffitis vieillissent : ils se salissent, se font recouvrir par d'autres ou effacer. C'est noté dans la bible visuelle (« un mur se remplit par couches »).
- C change de couleur, c'est-à-dire de bombe.

### 4.3 Grimper et courir

| Geste | Commande | Ce qu'on voit |
|---|---|---|
| Courir | Maj, à pied | Animation de course. |
| Se hisser | Espace face à un obstacle de 0,4 à 2,3 m | Mains sur le rebord, il tire, passe une jambe et se relève (0,3 à 0,8 s). |
| Attraper un rebord en sautant | Espace maintenu en l'air | Il s'accroche, puis se hisse. |

## 5. Les décisions qui attendent Louma

1. ~~Regular ou goofy~~ → **goofy** (19.11).
2. **Comment on trace un graffiti.** Proposition du 19.11 : le joueur trace lui-même, Loums exécute. Le tag se trace en entier d'un geste ; flop et pièce étape par étape (fond balayé, contour tracé, lights tapées en rythme, surcontour balayé, signature tracée). La qualité du geste se voit sur le mur (coulures, trait tremblant). En attente de la réponse de Louma.
3. ~~Le blaze~~ → **LOUMS**, d'après ses tags, flops et pièces en photo (19.11). Le lettrage reste à affiner avec lui.
4. ~~Où récupérer la peinture~~ → **un conteneur derrière la grande barre** (19.11).
5. ~~La date visée~~ → **Noël, 25.12.2026** (19.11).

## 6. Où on en est (19.11.2026)

**Fait :**

- Quartier réel (contours OpenStreetMap, relief IGN), époques 2014-2015 et aujourd'hui (touche T), tour Cyprès B, grande barre d'un seul tenant, parking et terrain vague.
- 16 rails et murets, mur du boulevard du lycée, charpentes bleues, halle.
- Marcher, courir, grimper.
- Skate : rouler, ollie, kickflip, shove-it, 50-50.
- Graffiti en trois tailles avec sauvegarde.
- Vraie planche 3D.
- Loums modélisé et animé : attente, marche, course.
- Rendu BD (n°2) : aplats en trois tons, encrage, Cyprès à bandes orange, palette « Marseille délavée » ; touche B pour comparer.

- 19.11 soir : la peinture se prend **au snack** du boulevard Lavéran (zone « ravitaillement » de n°2, bouton FOUILLE au téléphone) ; le conteneur du terrain vague reste un bonus. Mission 1 « Premier mur » (n°4, `scripts/mission.gd`) branchée et vérifiée dans le vrai quartier (`.tools/verify_mission.gd`).
- 19.11 soir : la perche est découpée du modèle (elle quitte le dos quand Loums la prend) ; les trois bandes du pantalon sont effacées de la texture (plus de marque reconnaissable). L'original est gardé en local dans `_sauvegardes/`.
- J1 en cours : Loums goofy sur la planche (pieds posés par IK sur les vis), poussée au pied en coups successifs, virage penché, planche portée à la main ; bombes à réserve et conteneur ; lettrage LOUMS en tag / flop / pièce.

**Suivant (n°1) :** J1, dans cet ordre :

1. ~~Loums sur la planche~~ (fait le 19.11, à valider manette en main).
2. Ollie chargé, flips, 50-50 et chute avec planche à récupérer.
3. Graffiti : bombes à la ceinture, perche dans le dos, geste de la bombe, étapes de la pièce, perche, rouleau, réserves.
4. Animation de la grimpe.
