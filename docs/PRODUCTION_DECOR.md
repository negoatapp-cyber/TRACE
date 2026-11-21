# TRACE — méthode de production du décor

Plan de travail du 20 novembre 2026. Périmètre prioritaire : lycée Diderot, tour Cyprès B, pieds des bâtiments et liaisons du parcours de départ, dans l’état visé de 2013.

## 1. Résultat attendu et règles de travail

Produire un quartier reconnaissable depuis les photos et les souvenirs de l’utilisateur, cohérent à hauteur de joueur et agréable à parcourir. Conserver le rendu peint et l’encrage déjà appréciés ; renforcer la précision architecturale et la richesse des matières sans remplacer arbitrairement la direction artistique.

La tour Cyprès B est un repère obligatoire de la version 2013. Son implantation, ses volumes décalés, sa partie centrale orangée en retrait et son sommet doivent être contrôlés. Le lycée est un lieu de départ : ses accès, ses premiers plans et ses rapports visuels avec les tours ont la même priorité que leurs façades.

Ne pas étendre le traitement au quartier entier avant d’avoir réalisé et évalué un segment représentatif. Un bon résultat exige trois validations distinctes : fidélité aux références, qualité du rendu dans Godot et fonctionnement en mouvement. Une image générée ne valide aucune dimension réelle.

État initial : premier habillage photographique de l’impasse testé et apprécié par l’utilisateur ; lancement local en 2013 sécurisé ; présence de la tour testée. Implantation précise, façades, cadrages du lycée, richesse des premiers plans et performance mobile restent à valider. Aucun nouveau lot Higgsfield n’est encore généré pour ce plan.

## 2. Répartition avec la cartographie

### Contrainte de référence — entrée des Cyprès

La référence initiale `Capture d'écran 2026-11-20 163427.png`, d’abord annoncée comme unique, est maintenant complétée par cinq vues du pied de tour fournies par l’utilisateur : 225701, 225623, 225633, 225646 et 225604. Ne pas conditionner la production à d’autres photos. Ces fichiers restent privés ; leurs horodatages de capture et les filigranes ne datent pas les prises de vue Street View.

**Autorisation artistique confirmée :** l’utilisateur autorise à créer librement ce qui manque, tant que la tour ressemble à l’originale. Les parties non documentées peuvent donc être conçues pour enrichir le lieu et son gameplay. Conserver les repères reconnaissables et identifier les ajouts comme des créations, sans imposer une reconstruction documentaire exhaustive.

- Éléments visibles à reproduire : petit auvent courbe brun/rouge, porte sombre sous l’auvent, entrée en retrait, seuil et raccord au pied de façade. Le stationnement, les potelets bleus et les arbres servent à lire les abords ; le local technique au premier plan est un objet distinct de l’entrée.
- Dimensions estimées : largeur et hauteur de porte, portée de l’auvent, profondeur du retrait et hauteur du seuil. Employer des proportions cohérentes avec les travées de façade et une échelle humaine, sans les présenter comme mesurées sur place.
- Parties à concevoir : détails de la porte et de l’interphone, structure de l’auvent, intérieur du hall et faces cachées. Leur création est autorisée ; adapter leur richesse au rôle dans le jeu et conserver une source modifiable.
- Méthode : construire un volume 3D simple de l’entrée, poser une caméra proche de la vue fournie, comparer la silhouette et les proportions, puis ajouter les matières et détails réellement lisibles. Préserver un passage praticable et contrôler les collisions à hauteur de joueur.
- Higgsfield peut aider à décliner les matières et le traitement peint à partir de cette référence. Toute face ou précision ajoutée par le modèle reste une hypothèse ; une nouvelle image générée ne constitue pas une seconde preuve architecturale.

Critère de sortie : auvent, retrait et porte reconnaissables depuis la vue de référence et lisibles dans le jeu ; hypothèses conservées dans la fiche de l’asset.

Premier lot réalisé puis recalé après retour du joueur : `scripts/entree_cypres_2013.gd`, intégré dans la scène 2013. Auvent courbe peu bombé, porte fermée à deux vantaux, encadrement, poignées, interphone, luminaire et supports créés. L'entrée regarde désormais la rue de Marathon et le parking, selon la précision de l’utilisateur : rotation de 90° du modèle autour de son centre, avec ses collisions et directions de grimpe. Le retrait de la porte passe d’environ 5,85 m à 1,95 m. L'ancien perron de 45 cm est remplacé par un seuil de 12 cm et un raccord incliné. L’ancien hall générique et l’ancienne voûte sont retirés de la version 2013. Le nouveau décor est enfant du modèle peint de la tour. Captures courantes : `.tools/review_cypres_recalage_final/`. L’intérieur n’est pas encore une zone jouable.

Validation après recalage : onze contrôles de l’entrée réussis, dont orientation vers Marathon, cote du seuil, accès dégagé, collision de porte, toit courbe et stabilité du personnage sur trois points du parvis. Onze contrôles historiques, neuf du quartier et quinze de l’étude réussis. Le terrain est maintenant nivelé avant les voies et leurs collisions ; le chemin contemporain qui traversait la tour est réservé au mode après démolition, avec un contournement de jeu en 2013. Comparaison privée : `.tools/COMPARAISON_CYPRES.md`. Manifeste : `assets/decor/source/entree_cypres_2013.manifest.json`. Pas de test mobile effectué. Les façades et la végétation restent à affiner.

**Passe complémentaire d’après les nouvelles vues :** le palier est de nouveau surélevé, estimé à 45 cm, avec trois marches frontales et une rampe latérale. Cela remplace le choix provisoire de 12 cm, antérieur aux photos détaillées. Le sens vers Marathon et le parking et le terrain corrigé sont conservés. Création d’un second accès sous petit auvent, porte technique grise, rampe et garde-corps, soubassements bicolores striés, ventilations et potelets bleus. Les positions et dimensions restent des choix de reconstruction à partir des images, pas un relevé métrique. Les objets abandonnés visibles sur une vue ne sont pas ajoutés comme mobilier permanent.

Sources : `scripts/pied_cypres_2013.gd` et `shaders/cypres_soubassement.gdshader`. Les stries sont filtrées dans le matériau pour éviter le bruit d’encrage que produisaient de petites nervures géométriques répétées. Quinze contrôles dédiés réussis dans `.tools/verify_pied_cypres_details.log`, dont stabilité au palier, aux marches et aux deux rampes. Quatre captures Forward+ produites ; vues large et annexe inspectées. Captures courantes : `.tools/review_pied_cypres_details_final/`. Aucun nouveau test mobile ni profilage effectué.

| Responsabilité | Périmètre | Échange nécessaire |
|---|---|---|
| Agent chargé de la carte | Emprises, orientations, distances, relief, niveaux, accès et liaisons | Livrer les coordonnées et volumes de référence corrigés, leur version et les écarts encore ouverts |
| Présent chantier décor | Recherche graphique, modèles de détail, façades, matières, végétation, lumière, intégration et optimisation visuelle | Fournir les dimensions du modèle et signaler les désaccords avec l’enveloppe cartographique |
| Intégration gameplay | Collisions, prises, missions, caméra, destinations des habitants | Vérifier toute modification qui change une silhouette franchissable, un accès ou une surface d’interaction |

Travailler dans des sources et scènes dédiées. Ne pas déplacer un bâtiment pour améliorer une composition de capture. Toute correction d’enveloppe se rapporte au plan commun ; arrêter seulement le lot dépendant si ses coordonnées sont en cours de modification. Préparer les matières et les modules en parallèle sans déléguer à un nouvel agent.

Avant chaque modification : relire les fichiers concernés, conserver une copie/version locale du lot précédent, repérer les autres changements et enregistrer le périmètre. Les sources éditables accompagnent les exports. Les publications et déploiements ne font pas partie du présent plan.

## 3. Priorité des lieux et des objets

| Niveau | Éléments | Qualité visée |
|---|---|---|
| P0 — repères du départ | Tour Cyprès B, silhouettes des barres voisines, lycée, sortie et liaisons | Modèles spécifiques, proportions vérifiées, silhouette correcte de près et de loin |
| P1 — parcours du joueur | Pied de tour, stationnements, murs, grilles, escaliers et premiers murs de graffiti | Matières cohérentes, détails lisibles à 1–10 m, traversée et interactions vérifiées |
| P2 — cadre du parcours | Bâtiments secondaires, végétation intermédiaire, objets ordinaires | Modules réutilisables, variantes contrôlées et détails adaptés à la distance |
| P3 — horizon | Relief lointain et silhouettes urbaines visibles depuis les points de départ | Masses et couleurs cohérentes ; éviter le détail coûteux sans effet à l’écran |

Ne pas ajouter de monument marseillais dans une direction où il ne serait pas visible. La reconnaissance repose d’abord sur les rapports entre les lieux réellement présents.

## 4. Étapes et critères de passage

### D01 — Dossier de références et état de départ

- Réunir plan d’implantation, deux vues depuis le toit du lycée, vues au sol et `IMG_1895.jpg` pour le sommet de la tour. Réutiliser le catalogue privé des 44 photos pour les matières et détails.
- Noter pour chaque référence : identifiant, date connue ou déclarée, lieu, orientation connue, sujet, provenance, droits et incertitudes. Les dates de capture d’écran ne sont pas les dates des images Street View.
- Les photos présentées comme datant de 2014 renseignent la morphologie proche de 2013 ; un chantier ou un aménagement peut avoir changé entre les deux années. Les références de 2010 et 2012 ne prouvent pas la persistance d’un graffiti en 2013.
- Capturer la version actuelle, à heure et résolution fixes, avant toute refonte.

**Sortie :** registre des références et liste d’écarts numérotés. Toute décision visible sur un élément P0 a une source ou une mention explicite d’hypothèse.

### D02 — Géométrie de référence et caméras de contrôle

- Vérifier avec le chantier cartographique l’échelle métrique, l’origine, les orientations et les cotes du parcours. Choisir plusieurs repères distribués dans les images ; signaler la précision permise par la source.
- Construire ou reprendre les volumes simples de la tour, des barres et du lycée avant leurs détails. Vérifier les écarts entre bâtiments et les changements de niveau.
- Établir au moins quatre caméras stables : deux vues du secteur depuis le lycée, une vue au pied de la tour, une vue du sommet depuis un bâtiment voisin. Conserver position, orientation, champ de vision, heure et résolution.
- Recaler la caméra avant de conclure à un déplacement de bâtiment. Le cadrage, le champ de vision, les filtres et les recadrages des photographies peuvent modifier l’impression de proportions.

**Sortie :** plan commun versionné, caméras documentées et comparaison des silhouettes. Aucun écart majeur non expliqué sur les accès et les volumes P0. Les faces cachées restent des hypothèses documentées. Les caméras d’essai actuelles ne sont pas encore des poses calibrées.

### D03 — Cible graphique avec Higgsfield

- Choisir un cadrage représentatif après D02 : le secteur lycée–Cyprès avec bâtiment, sol, végétation et détails proches.
- Préparer un premier lot limité à trois images du même cadrage : rendu BD actuel affiné, rendu peint plus matériel, variante intermédiaire. Les trois variantes sont un essai unique, pas trois directions à poursuivre en parallèle.
- Utiliser les photos comme références architecturales et la capture Godot comme référence de caméra et de gameplay. Énoncer les invariants : nombre et disposition des volumes, ouvertures, retraits, hauteurs relatives, accès et silhouette du sommet.
- Faire varier le traitement des matières, l’encrage, les valeurs, la palette et la lumière. Vérifier le modèle disponible et le coût avant soumission ; respecter les choix de crédits du service. Le présent document ne lance aucun job.
- Écarter toute variante qui invente des étages, modifie une entrée, déplace la tour, ajoute un monument ou transforme les formes pour rendre la composition plus séduisante.
- Retenir une cible cohérente avec le rendu déjà apprécié et en écrire les règles. Présenter la comparaison à l’utilisateur lors de la revue du lot ; poursuivre les tâches indépendantes sans multiplier les demandes de confirmation.

**Sortie :** une cible graphique principale, une palette, des exemples de matière et des règles d’encrage. Prompts, références, paramètres, coût constaté et origine générée sont conservés. La cible est une intention à traduire en 3D, pas une texture à coller sur tout le quartier.

### D04 — Segment représentatif à qualité finale

- Traiter un court segment du départ : un accès du lycée et sa liaison vers les Cyprès, sélectionnés selon les coordonnées validées. Inclure la tour dans au moins une perspective de ce segment.
- Donner à ce segment son modèle, ses matières, sa végétation, son éclairage et ses collisions finales avant de multiplier les bâtiments.
- Enregistrer une traversée à pied et en skate, une vue arrêtée à hauteur d’œil et une vue depuis le lycée.
- Confronter photo, cible Higgsfield et capture du moteur. Réviser les règles artistiques si leur traduction 3D ne fonctionne pas.

**Sortie :** un segment jouable qui sert de référence réelle de qualité et de coût. Reconnaissance des lieux à examiner avec l’utilisateur ; trajets et accès testés ; pas de défaut majeur masqué par un cadrage avantageux.

### D05 — Architecture spécifique et kit modulaire

- Reprendre la source existante de la tour avant de produire un modèle concurrent. Contrôler d’abord les volumes, puis les travées, fenêtres, loggias, retraits, rez-de-chaussée et toiture.
- Traiter séparément les faces visibles dans les photos. Reconstituer les stries verticales à l’échelle du bâtiment ; conserver les détails de toiture réellement lisibles. Ne pas multiplier des antennes arbitraires.
- Pour le lycée : établir façades, vitrages, structures, toits et accès à partir des références compatibles avec l’époque. Détailler en priorité ce que le joueur voit au départ.
- Construire les éléments répétés en modules : ouvertures, appuis, garde-corps, clôtures, couronnements, marches, tuyaux, coffrets et bordures. Utiliser les dimensions réelles disponibles ; la grille d’assemblage ne doit pas déformer les tracés existants.
- Valider unités, axes, pivots, normales, UV, transitions entre pièces et nombre de matériaux. Exporter en GLB avec sources éditables conservées.
- Employer des collisions simplifiées pour le décor ordinaire. Réserver les collisions détaillées aux surfaces dont le relief est nécessaire au gameplay, et tester les prises de grimpe après modification.

**Sortie :** modèles P0 reconnaissables sous les caméras de contrôle, kit de modules et manifeste des assets. Aucun élément généré en 3D n’est accepté sur sa seule vignette ; géométrie, UV, échelle et collisions sont examinées dans Godot.

### D06 — Matières, graffiti et vieillissement

| Famille | Variations de départ | Contrôle particulier |
|---|---|---|
| Enduits | Clair entretenu, patiné, reprises ponctuelles | Grain fin, cohérence des reprises et des arêtes |
| Béton banché | Sec, exposé à l’eau | Joints et trous de coffrage distincts des fissures |
| Blocs maçonnés | Brut, peint | Dimensions des blocs et mortier lisibles à bonne distance |
| Sols | Enrobé, reprises, trottoir | Raccords, caniveaux, niveaux et répétitions |
| Métal | Peinture conservée, délavée, rouille aux attaches | Rugosité et usure localisée |
| Vitrages | Clair, reflet atténué, quelques variantes | Réflexions cohérentes, transparence et coût |
| Graffiti | Tag, pièce, trace ancienne | Silhouette du lettrage, vraie transparence et projection limitée au support |

- Commencer avec des textures de 1024² pour les matières répétées, 2048 pour certains éléments spécifiques si leur couverture à l’écran le justifie. Hypothèses de densité : environ 256 pixels/m pour les surfaces courantes et 512 pixels/m pour les surfaces proches prioritaires ; à régler après D04. Répétitions et textures de détails permettent de couvrir un grand mur sans texture géante.
- Contrôler les surfaces sur une répétition 3 × 3 puis dans le moteur. Une texture dite raccordable doit être vérifiée, y compris les lignes de symétrie si elle est répétée en miroir.
- Séparer couleur de base, relief et rugosité lorsque cela aide le rendu choisi. Les cartes de données ne sont pas importées comme des couleurs. Préserver le fonctionnement du shader peint existant.
- Garder les ombres directionnelles hors des nouvelles textures de surface. Identifier les ombres déjà peintes dans les assets existants pour éviter de les doubler.
- Placer coulures sous les appuis, poussière au pied et rouille près des fixations ; conserver des pans entretenus. Graffitis, reprises et salissures ont des causes et une histoire locale.
- Générer ou éditer les images avec l’outil image/Higgsfield selon le besoin, puis normaliser dimensions, marges et formats de manière déterministe. Signaler les reconstructions assistées plutôt que les qualifier de découpes exactes.

**Sortie :** bibliothèque cohérente, sources et transformations documentées, mipmaps et filtrage vérifiés, alpha contrôlé pour les marques, rapport de validation et planche d’assets inspectée. Comparaisons aux distances de 1–3 m, 10 m et au-delà de 50 m.

### D07 — Habillage, végétation et lumière

- Poser d’abord les éléments qui structurent les lieux : limites de parcelles, arbres majeurs, lampadaires, stationnements et cheminements. Puis ajouter les petits objets, les détails des pieds de façade et les traces d’usage.
- Répartir les arbres selon les références ; leurs masses ne doivent pas cacher un mauvais modèle ou une mauvaise implantation. Prévoir des variantes de silhouettes et une densité mesurée.
- Préserver les lignes de vue utiles aux missions et le passage de la caméra. Les objets de rencontre et les murs de graffiti doivent être accessibles ; la lisibilité ne doit pas dépendre de la seule couleur.
- Définir une lumière de référence pour comparer les lots, puis vérifier matin, fin d’après-midi et nuit. Régler exposition, contraste, ombres et encrage avant de compenser par des textures plus claires.
- Maintenir une continuité entre décor peint, objets génériques et éléments issus des photos. Examiner les reflets, le bruit de grain, la finesse des contours et le contraste en mouvement.

**Sortie :** ensemble habité et lisible depuis les caméras fixes et le parcours. Aucun détail placé dans une porte, sur une trajectoire obligatoire ou au détriment de la visibilité du joueur.

### D08 — Optimisation, intégration et revue finale

- Répéter les mêmes captures à 1600 × 900 sur PC ; tester aussi la résolution réelle du téléphone cible et son renderer. Contrôler le repli des graffitis sans Decal.
- Établir une mesure de référence sur un parcours identique : temps CPU/GPU par image, images lentes, appels de dessin, mémoire des textures, chargement et saccades. Mesurer les pointes et les changements de zone, pas seulement une moyenne à l’arrêt.
- Objectifs proposés, à confirmer sur les appareils cibles : 60 images/s sur le PC cible, soit environ 16,7 ms/image ; 30 images/s sur téléphone, soit environ 33,3 ms/image. Aucun de ces objectifs n’est déjà validé. Fixer les budgets d’assets après mesure du segment D04.
- Réutiliser matières et textures, regrouper les objets répétés, configurer distances de visibilité et niveaux de détail. Conserver la silhouette de la tour et éviter les apparitions brusques de gros éléments.
- Tester marche, skate, caméra, accès, grimpe concernée, surfaces de graffiti, déplacements des habitants et retour de sauvegarde. Rejouer la mission de départ quand elle existe.
- Refaire les contrôles historiques : date 2013, tour visible, collisions présentes, absence d’état contemporain importé. Les tests existants ne valident pas les proportions architecturales ni le ressenti humain.
- Examiner les défauts à l’arrêt et en mouvement : trous, intersections, ombres doubles, textures étirées, coutures, clignotements et changements de matériau. Classer séparément les avertissements moteur préexistants.

**Sortie :** lot intégré avec captures, séquence de parcours et rapport de mesures. Aucun défaut bloquant connu sur le trajet de départ. Les écarts historiques et visuels restants sont listés explicitement ; aucune validation mobile sans essai réel.

## 5. Suivi de chaque asset et de chaque lot

Chaque entrée du manifeste contient : identifiant stable, zone, priorité, source et droits, niveau de confiance historique, dimensions en mètres, fichier éditable, export, UV, matériaux, textures et espaces colorimétriques, collision, interactions concernées, niveaux de détail, origine générée éventuelle, état des contrôles et capture de validation. Conserver les prompts et paramètres des images générées.

États : à documenter → volume provisoire → géométrie vérifiée → matière prête → intégré → contrôlé. Un objet ne passe pas à « contrôlé » par sa seule présence dans la scène.

Pour chaque livraison : annoncer le périmètre, montrer l’avant/après au même cadrage, expliquer les corrections, joindre les contrôles et nommer les limites. Enregistrer les retours de l’utilisateur comme tâches concrètes. Reprendre le lot concerné sans remettre tout le quartier à zéro.

Photos personnelles et dérivés privés restent locaux, conformément aux règles du projet. Le manifeste distingue usage local et diffusion autorisée ; une référence ne devient pas un asset public par son intégration au jeu.

## 6. Ordre de démarrage et état du plan

| Étape | État au 20.11.2026 | Prochaine sortie |
|---|---|---|
| D01 | Références disponibles, catalogue partiel et captures existantes | Registre P0 et écarts numérotés |
| D02 | En attente du recalage cartographique ; caméras d’essai disponibles | Géométrie et caméras de référence |
| D03 | À faire ; aucune génération de ce lot lancée | Trois variantes comparables et une cible retenue |
| D04 | À faire | Segment de départ au niveau de qualité visé |
| D05–D08 | À décliner après validation du segment | Production par familles puis intégration du parcours |

Commencer par D01 et l’inventaire des sources de la tour et du lycée. En parallèle, préparer le kit de matières sans changer l’implantation de la carte. Passer à la recherche Higgsfield une fois le cadrage et les volumes du segment suffisamment fiables. La première livraison porte sur une vue de contrôle et un court segment jouable ; l’extension suit les résultats obtenus, sans date de fin inventée avant l’inventaire et les premiers essais.

Choix du joueur après cette passe : le canapé abîmé de la vue 225701 sera conservé comme détail narratif près des portes techniques, en laissant le passage libre. Cette demande remplace son exclusion précédente avec les objets abandonnés. Réalisation 3D encore à faire ; forme et usure à interpréter d’après la référence peu définie.

## Cour arrière : adaptation pour le skate

À la demande du joueur, six jardinières sont organisées en deux rangées de trois. Dimensions approximatives : 2,18 × 2,4 m, hauteur 46 cm, entraxe transversal 9 m et longitudinal 11 m. La cour fait environ 16 × 32 m, à la cote du parvis, avec un raccord du terrain élargi localement dans la scène 2013. L'axe de skate est débarrassé des anciens arbres qui l'obstruaient ; les arbres latéraux restent. Curb central de 8 m, largeur 45 cm, hauteur nominale 25 cm, utilisant Rail et le contrôleur de grind existants. L'implantation est une adaptation ludique autorisée, pas un relevé historique exact. Source : scripts/cour_arriere_cypres.gd. Captures : .tools/review_cour_cypres_final/. Le canapé reste à créer.

Validation : six jardinières, niveaux du sol et dégagements, accroche et sortie du curb dans les deux sens par le contrôleur réel ; contrôles de l'entrée relancés. Le parcours complet au clavier et le rendu mobile restent à tester.
