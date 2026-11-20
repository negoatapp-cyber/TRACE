# Carte de contrôle de Malpassé

État du modèle Godot examiné le 20 novembre 2026 sur la branche `feature/marseille-explorable`, révision `9cb2053`. Le départ Diderot appelle le quartier avec le filtre historique `avant`. Le fond des Lauriers mélange ainsi le quartier du jeu vers 2014, des géométries cartographiques plus récentes et la visite de la façade ancienne du lycée. Cette planche est un document de production.

![Carte des sept points de contrôle](controle/implantations.webp)

## Registre des contrôles

| N° | Point en mètres (X est, Z sud) | Constat et décision avant intervention |
| --- | --- | --- |
| 1 | −125, 64 | Depuis l’est, le rayon horizontal heurte `Limite3` à x = −124,5. Le centre de l’amphithéâtre est à −131. Décider du périmètre jouable et tracer une limite qui conserve la continuité des surfaces aux deux extrémités du passage. Le décor de la place du Jardin est une adaptation du jeu. |
| 2 | −8, −21 | L’intersection de la ligne piétonne active et de l’emprise provisoire de la tour B mesure 24,98 m en plan. Elle entre par (−17, −24,13) et sort par (7, −17,19). Comparer une image aérienne historique à plusieurs angles de façade avant de choisir quel élément corriger. |
| 3 | −11,8, 13 | Le rayon à hauteur humaine touche le corps `Passage_sombre`. Déterminer la destination réelle de cette ouverture avant de la transformer en passage ou de la représenter comme une porte fermée. |
| 4 | −15, 9 | À PAIX, le calcul du plateau donne Y = 5,5152 m contre 0,9152 au pied de référence. Cela représente une hauteur de 4,60 m dans le jeu. Relever pied, palier et débouché. Tester séparément montée à pied et retour roulant. |
| 5 | 125, 75 | La cote locale passe de −5,19 à −1,351 m sous l’effet du lissage. Devant la façade, à (142, 90), l’écart tombe à +0,53 m. Prendre une coupe commune chaussée, bordure, trottoir et seuil. |
| 6 | 124, 42 | Le script pose le snack à un emplacement explicitement hypothétique. Suspendre les déclencheurs de rendez-vous ou de ravitaillement jusqu’à son identification. |
| 7 | 128,5, 91,5 | Point d’axe de la façade de Diderot. Le passage central côté boulevard a été testé lors de la livraison précédente. Relever les cotes restantes avant de figer les raccords du seuil. |

## Contrôle 02 • Plan « Tour B » et vue au pied de la tour

![Superposition du centre indicatif et du chemin actif](controle/tour-b.webp)

Le document aérien fourni (967 × 660 px) désigne la tour par un carré rouge. Son centre graphique a été pointé vers le pixel (465, 320). Le détourage, le géoréférencement officiel, la date du cliché et la légende complète manquent. Le registre ci-dessus conserve le constat mesuré dans la version 9cb2053.

Une similitude plane à quatre paramètres, ajustée par moindres carrés sans déformation locale, relie les pixels (origine en haut à gauche) au repère du jeu. Les appuis sont des correspondances visuelles provisoires.

| Appui interprété | Pixel (u, v) | Jeu (X, Z) m | Résidu en plan |
| --- | --- | --- | ---: |
| Jonction Lavéran–Marathon au nord | 656, 196 | 140, −112 | 1,5 m |
| Coude sud de Marathon | 530, 475 | 48, 93 | 10,0 m |
| Jonction ouest de Marathon | 274, 458 | −120, 90 | 7,1 m |
| Angle sud-est du terrain sportif | 612, 165 | 114, −136 | 6,3 m |

L’échelle ajustée vaut 0,718 m/px. Le centre de Cyprès A sert de contrôle indépendant approximatif (écart d’environ 5,7 m, avec un effet possible du déport du toit sur l’image). Le carré se projette vers (+7,4 ; −17,4) m, à environ 13 m du centre courant (−5 ; −22). En retirant un appui à la fois, X varie de +1,2 à +11,4 m et Z de −22,4 à −15,4 m. Ces chiffres expriment la sensibilité du calcul. Ils ne constituent pas des cotes d’arpentage.

Le centre ajusté tombe à moins d’un mètre de l’axe piéton tracé dans le jeu. Cette coïncidence ne permet pas de rétablir un passage historique. La vue de rue montre une allée arborée à gauche dans l’image, un édicule clair, des potelets bleus, le stationnement et une entrée sous auvent. Le point de prise de vue, son orientation et les débouchés restent à identifier. Décision de production : rechercher le contournement au pied de la tour ; réserver le tronçon litigieux hors du réseau de missions historiques jusqu’à validation.

La presse locale confirme la démolition de la tour le 21 juillet 2016. La date de cet événement situe la tour dans la chronologie du jeu. Elle ne date pas les deux images fournies. [Article du 22 juillet 2016](https://madeinmarseille.net/a-la-une-marseille/17922-demolition-tour-malpasse-renovation/).

## Relief et bord de carte

La grille locale contient 17 × 25 valeurs espacées de 25 m. Le maillage affiné est interpolé à 5 m. L’axe Lavéran est lissé deux fois par moyenne sur ±60 m, avec correction latérale pleine jusqu’à 15 m et transition jusqu’à 30 m. Sur les 9 801 points testés à 5 m dans le rectangle local, 912 présentent un écart absolu supérieur à 50 cm entre les deux surfaces. Le minimum vaut −4,18 m à (165, −325) et le maximum +3,84 m à (125, 75). L’échantillonnage compare deux versions du terrain dans le moteur. Les bordures et ouvrages de quelques centimètres exigent d’autres références.

La jupe visuelle borde le rectangle physique de 400 × 600 m. Son contour adopte le terrain communal à 64 m. Pour le bâti municipal, un sommet dans le rectangle élargi de 10 m suffit à supprimer le bâtiment entier. Pour la voirie, une extrémité dans le rectangle élargi de 12 m suffit à supprimer le segment entier. Contrôler les franchissements externes par rue avant de programmer les transitions.

## Secteurs proposés

![Quatre secteurs et leurs fonctions](controle/secteurs.webp)

Commencer par PAIX → Marathon et les deux côtés de la limite ouest. Les jalons de validation sont une boucle à pied et une boucle en skate, chacune avec retour au départ, puis des parcours facultatifs vers les toits ou les spots. Les essais de cette passe portent sur la physique statique, le relief et les tracés. Les missions et boucles complètes restent à réaliser.

![Capture Godot du quartier vu du dessus](controle/godot.webp)

## Traçabilité

- Géométries actives, variantes d’époque et relief initial : `data/quartier_reel.txt`.
- Tests de masque et terrain : `scripts/quartier_reel.gd`, `scripts/ville_terrain.gd`.
- Collisions du plateau et de la place : `scripts/habillage.gd`, `scripts/habillage_place.gd`.
- Ancrages de jeu : `scripts/habillage_laveran.gd`, `scripts/habillage_toits.gd`.
- Sources et licences : [décisions de production](../DECISIONS.md). Contrôles précédents du portail : [Diderot](DIDEROT.md).
