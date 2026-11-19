# TRACE — plan de production de la démo

*Document de pilotage. Mis à jour le 19.11.2026. Tenu par la conversation n°1 (gameplay et systèmes).*
*Toute conversation qui travaille sur TRACE lit ce fichier avant de commencer.*

## 1. L'objectif

**Une démo jouable de 30 minutes.** On est en 2014-2015, dans le quartier des Lauriers et devant le lycée. Le joueur incarne Loums :

- il se déplace à pied et en skate dans le quartier réel ;
- il graffe, du tag rapide à la grosse pièce, à la bombe, à la perche et au rouleau ;
- il grimpe pour atteindre les spots en hauteur ;
- il croise des habitants qui le voient faire ;
- le quartier garde la trace de ce qu'il fait : murs peints, regards, réputation.

Elle est réussie si une personne qui ne connaît pas le projet joue 30 minutes sans s'ennuyer ni rester bloquée, et peut raconter ensuite ce que Loums a fait et ce que le quartier en a retenu.

**Hors de la démo :** les intérieurs (lycée, appartements), les autres villes, les années après 2016, l'histoire complète et les dialogues longs.

## 2. Les quatre jalons

| Jalon | Contenu | Il est fini quand… |
|---|---|---|
| **J1. Le corps** | Tous les gestes de Loums sont animés et lisibles : skate, graffiti, grimpe (détail en section 4). | On joue 10 minutes sans voir un seul geste manquant ou faux. |
| **J2. Le quartier vivant** | Habillage du quartier (textures, mobilier urbain, lumière). Des habitants avec leurs trajets et leurs habitudes. Le fait d'être vu. | Le quartier se reconnaît, et quelqu'un réagit quand on graffe sous ses yeux. |
| **J3. La trace** | Branchement du simulateur V3.1 : ce que Loums fait laisse des souvenirs chez les habitants et en lui. Réputation par milieu. Le temps qui passe : jour et nuit, semaines, la tour Cyprès B démolie en juillet 2016. | Deux parties jouées différemment donnent deux quartiers différents. |
| **J4. Le test des 30 minutes** | Réglages, son, menus minimum, puis trois testeurs extérieurs. | Les trois testeurs finissent les 30 minutes. |

On ne commence pas un jalon avant d'avoir joué au précédent.

## 3. Qui fait quoi

Plusieurs conversations Claude travaillent en parallèle. Pour ne pas se marcher dessus, chacune a son territoire.

| Conversation | Territoire | Fichiers à elle |
|---|---|---|
| **N°1 : gameplay et systèmes** (celle-ci, qui tient ce plan) | Loums, skate, graffiti, grimpe, habitants, simulateur, données du quartier, intégration | `scripts/player_controller.gd`, `skate_controller.gd`, `skateboard.gd`, `graffiti.gd`, `personnage.gd`, `quartier_reel.gd`, `input_setup.gd`, `data/`, `scenes/`, `.tools/`, `docs/PLAN.md` |
| **N°2 : habillage urbain** | Textures, matériaux, mobilier urbain, éclairage, ciel | `assets/decor/`, `materials/`, `shaders/` (sauf ce que n°1 y crée), et un script à elle, `scripts/habillage.gd` |

**Le point de contact.** `quartier_reel.gd` construit les volumes et range chaque élément dans un groupe Godot : `terrain`, `batiment` (avec le style en métadonnée `style`), `lycee`, `sol_voie`, `sol_zone`, `mur`, `muret`, `rail`, `voiture`, `arbre`. `habillage.gd` passe après la construction et habille ces groupes. N°2 ne modifie pas `quartier_reel.gd` : si un groupe manque, elle le demande à n°1.

**Les règles communes.**

1. GitHub (`negoatapp-cyber/TRACE`, branche `main`) est la source unique. On récupère la dernière version avant de commencer, et on envoie un commit par tâche terminée.
2. Le dossier du PC (`Downloads\TRACE`) est mis à jour depuis GitHub. On n'y modifie rien sans l'envoyer aussi sur GitHub, sinon la prochaine mise à jour l'efface.
3. Rien de privé dans le dépôt, qui est public : ni le PDF de vie, ni les planches, ni les modèles 3D sous licence Meshy (`assets/personnages/*.glb` reste en local), ni de vraies personnes.
4. Le lieu est réel et les habitants sont fictifs. Aucune marque réelle visible.

## 4. Fiche des gestes (J1)

Chaque geste a une commande, une durée, une animation et un effet. Les animations viennent de la bibliothèque Meshy quand elle a le bon mouvement. Sinon, Loums est posé par le code : rotation des os du squelette et pieds calés par cinématique inverse.

### 4.1 Le skate

| Geste | Commande | Ce qu'on voit | Effet |
|---|---|---|---|
| Sortir la planche | E, à pied | Il pose la planche au sol devant lui, met le pied avant dessus et monte (0,4 s). | Passe en mode skate. |
| Rouler | — | Pieds sur les vis des trucks, genoux fléchis, épaules dans l'axe, regard devant. Pied gauche devant (regular) par défaut, goofy en option. | — |
| Pousser | Maj, ou stick vers l'avant | Le pied arrière quitte la planche, frappe le sol et revient (cycle de 0,7 s). | Une impulsion à chaque poussée, et non une accélération continue. |
| Tourner | Stick gauche-droite | Le corps se penche et la planche bascule de quelques degrés vers l'intérieur. | Virage plus serré à faible vitesse. |
| Freiner | Stick arrière | Le pied arrière traîne au sol. | Ralentit. |
| Ollie | Maintenir Espace, puis relâcher | Il s'accroupit pendant qu'on maintient, puis le tail claque, la planche monte, le pied avant glisse vers le nose et il se réceptionne genoux fléchis. | La hauteur dépend du temps de maintien (de 0,2 à 0,6 s). |
| Kickflip / shove-it | J / K en l'air | La planche tourne sous lui, il lève les pieds puis la rattrape. | Si elle n'est pas rattrapée, c'est la chute. |
| 50-50 | L près d'un rail | Les deux trucks sont sur le rail, les bras sont écartés. | Glisse le long du rail. |
| Chute | Réception ratée | Il tombe, la planche part en roulant. | Il faut marcher jusqu'à elle pour la ramasser. |
| Ranger la planche | E en skate | Il saute, attrape la planche par le tail et la porte à la main. | Passe en mode à pied, planche en main droite. |

### 4.2 Le graffiti

**L'équipement est visible sur lui :** quatre bombes à la ceinture, la perche dans le dos. Le rouleau et le pot sont dans le sac et ne sortent que pour s'en servir.

| Outil | Pour quoi | Commande | Déroulé | Durée |
|---|---|---|---|---|
| **Bombe : tag** | Signature rapide | Maintenir G, peu de temps | Il prend une bombe à la ceinture, la secoue (bruit de bille), tend le bras et fait un trait rapide à hauteur d'yeux. | ~1 s |
| **Bombe : flop** | Lettres rondes, deux couleurs | Maintenir G plus longtemps | Remplissage, puis contour d'une deuxième couleur : il change de bombe au milieu. | 3 à 5 s |
| **Bombe : pièce** | Grosse fresque | Maintenir G, en plusieurs fois | Esquisse, remplissage, contour, contour extérieur, reflets. **On peut s'arrêter et revenir** : le mur garde l'étape atteinte. | 7 à 15 s au total |
| **Perche** | Tag en hauteur, de 3 à 5 m | Maintenir G avec la perche sortie (touche à définir) | Il déplie la perche, y fixe une bombe, lève les bras. Le geste est lent et moins précis. | ~4 s |
| **Rouleau** | Grosses lettres pleines de 1 à 2 m sur un long mur | Maintenir G avec le rouleau sorti | Il pose le pot, trempe le rouleau et trace de haut en bas, lettre après lettre. C'est très visible de loin. | ~3 s par lettre |

**Les règles du graffiti :**

- Chaque bombe a une réserve et le pot de peinture aussi. Quand c'est vide, il faut en trouver d'autres. Le circuit pour en récupérer est à définir avec Louma.
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

1. **Regular ou goofy** pour Loums.
2. **Comment on trace un graffiti.** Le simple maintien de G (comme aujourd'hui), ou un geste guidé : on suit au stick le tracé du blaze, et la qualité dépend de la précision.
3. **Le blaze de Loums** et le style de ses lettres. Il faut un modèle de lettrage (dessin ou police) pour remplacer la police standard.
4. **Comment on récupère des bombes et de la peinture** dans le jeu.
5. **La date visée** pour la démo.

## 6. Où on en est (19.11.2026)

**Fait :**

- Quartier réel (contours OpenStreetMap, relief IGN), époques 2014-2015 et aujourd'hui (touche T), tour Cyprès B, grande barre d'un seul tenant, parking et terrain vague.
- 16 rails et murets, mur du boulevard du lycée, charpentes bleues, halle.
- Marcher, courir, grimper.
- Skate : rouler, ollie, kickflip, shove-it, 50-50.
- Graffiti en trois tailles avec sauvegarde.
- Vraie planche 3D.
- Loums modélisé et animé : attente, marche, course.

**Suivant (n°1) :** J1, dans cet ordre :

1. Loums sur la planche : posture, pieds sur les vis, poussée animée, virage penché, planche portée à la main.
2. Ollie chargé, flips, 50-50 et chute avec planche à récupérer.
3. Graffiti : bombes à la ceinture, perche dans le dos, geste de la bombe, étapes de la pièce, perche, rouleau, réserves.
4. Animation de la grimpe.
