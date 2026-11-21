# TRACE — carte jouable et production 3D

Proposition du 20 novembre 2026, après validation en jeu du premier habillage photographique par l’utilisateur. Cible de l’étude : Marseille en 2013. Ce document propose la prochaine production ; il ne constitue pas un relevé historique validé.

La méthode détaillée de production artistique, ses étapes D01–D08 et ses critères de validation figurent dans [PRODUCTION_DECOR.md](PRODUCTION_DECOR.md). La cartographie conserve la responsabilité des implantations ; le chantier décor suit cette base commune.

## Décision de périmètre proposée

Terminer le quartier actuellement jouable avant une extension à d’autres quartiers de Marseille. Constituer un espace continu, reconnaissable, avec des accès cohérents et plusieurs chemins entre les objectifs. Les lieux plus éloignés pourront devenir des cartes distinctes reliées par une transition de déplacement. Leur sélection doit servir une mission et disposer de références suffisantes.

Le lancement normal utilise désormais `scenes/marseille_2013.tscn`, avec son horloge et son fichier de sauvegarde distincts. La scène de développement `lauriers.tscn` conserve son calendrier 2014 et la comparaison avant/après. La version 2013 impose la carte historique et ignore la bascule T vers aujourd’hui.

**Repère historique prioritaire, confirmé par l’utilisateur : la grande tour Cyprès B doit être présente en 2013.** Son absence du quartier actuel ne justifie aucune suppression dans la carte du jeu. Le plan fourni le 20 novembre situe la tour ; les deux photographies prises depuis le toit du lycée sont des références de cadrage et de silhouette. Elles sont présentées comme datant de 2014 : utiles pour 2013, sans déduire que chaque détail du chantier était identique un an plus tôt.

Contrôle effectué : la branche GitHub `main` consultée contient encore la ligne historique de la tour dans `data/quartier_reel.txt`. Correction locale : chargement de l’époque historique avant construction et annulation de l’état statique de démolition lorsqu’on charge une date antérieure. Onze contrôles de non-régression réussis dans `.tools/verify_cypres_2013.log`, dont présence du modèle visible, grande hauteur et collisions. Aucune publication GitHub effectuée par cette intervention.

**Comparaison depuis le lycée encore à résoudre :** les captures `.tools/review_cypres_2013/toit_lycee_photo1.png` et `toit_lycee_photo3.png` confirment la présence de la tour, mais les façades, la végétation et les premiers plans ne reproduisent pas encore les photos fournies. Les positions de caméra sont des essais, pas des poses calibrées. Ne pas présenter la seule présence de la tour comme une validation de son implantation ou de sa silhouette exacte.

Référence supplémentaire `IMG_1895.jpg`, fournie pour montrer le haut de la tour : volumes clairs de hauteurs différentes ; bande centrale orangée en retrait ; stries verticales du parement ; fenêtres horizontales contrastant avec les rangées étroites ; antenne fine et petits volumes techniques visibles en toiture. Vérifier ces points dans `assets/decor/source/quartier/tour_cypres_b.py` avant une nouvelle génération. Les faces cachées, dimensions exactes et équipements peu lisibles ne sont pas établis par cette seule vue. Les deux photos du lycée contrôlent les rapports entre bâtiments ; celle-ci contrôle le sommet. Ces références restent privées et ne doivent pas être exportées dans le dépôt public.

## Fragilités techniques déjà identifiées

- La géographie générale s’appuie sur des contours OSM relevés en 2026 et un relief IGN à 25 m ; cela ne valide ni l’état de 2013, ni les petites différences de niveau.
- `greffe_paix.gd` insère une rue pilote dans la carte, remplace des bâtiments, aplanit le terrain et retire certains murets. Ces raccords doivent être comparés aux références ; leur existence ne prouve pas à elle seule une erreur.
- Les modèles peints et les volumes cartographiques viennent de sources différentes. Une façade convaincante peut donc masquer un mauvais alignement ou une mauvaise profondeur.
- Les dimensions précises, entrées, limites et altitudes des lieux restent à vérifier avant toute nouvelle décoration structurelle.

## Secteurs de missions proposés dans l’emprise existante

| Secteur | Rôle | Missions envisageables, à écrire | Besoin cartographique prioritaire |
|---|---|---|---|
| Impasse de la Paix et raccord rue de Marathon | Départ, apprentissage, premier mur | Rejoindre un contact, découvrir une technique, revenir voir sa trace | Largeur, raccords, soutènement, accès et limites |
| Pied des Cyprès, esplanade et parcours vers la grande barre | Exploration, vie du quartier, retour récurrent | Retrouver quelqu’un, chercher du matériel, choisir un trajet au sol ou en hauteur | Pieds des tours, cheminements, dénivelés et stationnements |
| Rue de Marathon, lycée et snack | Axe quotidien, circulation, contacts | Rendez-vous, approvisionnement, trajet avec délai | Continuité de la rue, position des accès et traversées |
| Lisières, terrains et toits accessibles | Parcours secondaires et récompenses | Repérage d’un spot, itinéraire de grimpe, point de vue | Accès réellement possibles et retours sûrs ; lieux exacts à confirmer |

Ces secteurs sont des regroupements de gameplay proposés, pas des nouveaux quartiers attestés. Leur position et leurs liaisons suivent le relevé corrigé. Les limites peuvent être des clôtures, bâtiments, portails ou transitions lisibles ; ne pas fermer une vraie liaison simplement parce qu’une mission ne l’utilise pas encore.

## Ordre de production

1. **Plan de référence et registre des écarts.** Vue du dessus annotée avec rues, emprises, accès, murs, escaliers et cotes connues. Pour chaque anomalie : position, capture, source, confiance et correction proposée. Recouper les références datées avec les souvenirs de l’utilisateur. Distinguer attesté, analogie et choix de jeu. Sortie : carte de correction consultable, sans déplacement massif des assets.
2. **Structure et parcours.** Corriger un raccord à la fois, en commençant par impasse → Cyprès → Marathon. Construire les volumes simples à l’échelle avant de refaire l’habillage. Fixer les volumes validés et partager les mêmes coordonnées entre sol, modèle, collision, grimpe et mission. Sortie : boucle continue à pied et en skate, accès lisibles, aucun trou ni collision fantôme sur les trajets testés.
3. **Familles de matières et détails.** Enduits, béton banché, blocs, bitume, métal peint ; graffiti posé séparément pour conserver ses couches. Définir une densité cohérente en mètres, vérifier les répétitions, réserver les grandes textures aux éléments uniques. Varier l’usure selon sa cause et conserver des zones entretenues. Sortie : comparaisons avant/après aux mêmes points de vue et même heure.
4. **Missions et habitants.** Placer les objectifs sur des accès validés. Pour chaque mission : départ, but, trajets possibles, durée mesurée, conséquence et moyen de reprise. Essayer les variantes et sorties involontaires. Sortie : une première boucle complète sans blocage, puis des branches facultatives.
5. **Validation et extension.** Mesurer temps d’image, mémoire, chargement et visibilité sur PC, puis appareil mobile cible. Tester marche, skate, grimpe, caméra et sauvegarde sur le parcours. Ajouter une autre zone seulement quand elle possède une fonction de mission, des références et un budget mesuré.

## Compétences mobilisables

- Godot 3D : scènes, transformations, terrain, meshes procéduraux, collisions, matériaux, éclairage, import GLB/glTF, scripts et outils de contrôle.
- Production de décor : modules de façades, ouvertures, murets, clôtures, escaliers, mobilier et détails métriques ; UV et textures ; placement et intégration des modèles existants.
- Rendu : shaders, relief et grain de matière, projection de graffiti, palette BD, lumières et ombres, mipmaps et contrôle des répétitions.
- Animation et interaction : intégration d’animations et adaptation des interactions de grimpe ; une animation crédible demande aussi des essais en mouvement et, pour les gestes complexes, une source adaptée.
- Optimisation : répétition par instances/MultiMesh, distances de visibilité, niveaux de détail et profilage sur matériel réel.
- Création assistée : textures et concepts depuis les photos via l’outil image ; génération 3D possible selon les outils disponibles, avec validation de la géométrie, des UV, de l’échelle et des collisions avant intégration.

Les compétences installées pertinentes comprennent `level-design`, `game-docs`, `create-game-assets`, `godot-3d-essentials`, `godot-gdscript`, `godot-physics`, `godot-shaders`, `camera-systems`, `game-ui-ux`, `performance-optimization` et `godot-export`. Elles fournissent des méthodes ; elles ne remplacent pas les sources historiques ni les tests humains.

Une photo permet de reconstruire une apparence et une partie des proportions ; elle ne fournit pas automatiquement une hauteur exacte, une face cachée ou une implantation cadastrale. Les modèles organiques complexes et les mouvements précis nécessitent des références, un travail spécialisé ou des assets adaptés. Aucun outil supplémentaire n’est nécessaire pour commencer l’audit et les corrections Godot.

## Premier livrable à produire ensuite

Une carte du dessus de l’emprise actuelle avec secteurs, connexions et anomalies numérotées, accompagnée d’une première correction de raccord vérifiée en jeu. Les indications de l’utilisateur sur les endroits qui « sonnent faux » permettront de prioriser et de valider le relevé.
