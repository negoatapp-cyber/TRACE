# TRACE · Marseille, base de monde du 20 novembre 2026

## Diderot, façade ancienne

Le départ historique du boulevard Lavéran, ses références, les éléments estimés et ses essais de déplacement sont documentés dans [Diderot depuis le boulevard Lavéran](docs/DIDEROT.md).

## Ce que représente la carte

Les 16 arrondissements et les 111 quartiers de la commune partagent le même relief IGN, la même projection, les mêmes règles de hauteur et le même découpage pour les bâtiments et la voirie. Dans l’atlas et en exploration libre, le bâti décrit l’état de la cartographie en novembre 2026. Le bouton **Les Lauriers · 2013** ouvre la scène historique du jeu. La tour Cyprès B reste présente après une avance du temps ou la reprise d’une sauvegarde. Le calendrier revient à janvier 2013 après décembre. L’âge des graffitis continue en jours cumulés. La position et la hauteur de la tour restent celles estimées dans le relevé.

| Périmètre | Géométrie livrée | Usage |
| --- | --- | --- |
| Commune, îles comprises | 285 806 polygones de bâtiments, 53 516 lignes de voirie après découpe communale, 1 049 tuiles contenant des vecteurs | Carte d’ensemble en relief, zoom, sélection de chacun des 111 quartiers, exploration à pied ou en skate sur les tuiles proches |
| Malpassé, secteur prioritaire | Grille locale IGN de 400 × 600 m, soit 0,24 km². Rue de Marathon, impasse et plateau, barre des Lauriers, boulevard Lavéran et façades de Diderot | Trottoirs, loggias, mobilier, murets, rails, escaliers et courses à hauteur humaine. Quatre départs et retour à la carte |
| Cour de test | Îlot gris historique du dépôt, géométrie fictive | Réglage reproductible du contrôleur, kicker, rail et ledge |

Les 53 516 lignes correspondent à 53 282 identifiants de voies OSM. Une voie peut produire plusieurs morceaux à la limite communale. Le stockage en tuiles contient 65 121 polylignes après découpe supplémentaire. Le petit complément OSM de Planier ajoute sept bâtiments à l’extrait BBBike, dont la limite ouest passait à l’est de l’île. Le nombre de bâtiments mesure des polygones OSM, pas un décompte cadastral de propriétés.

## Parcours de contrôle des Lauriers en 2013

Dans Godot 4.7.2 à 60 pas physiques par seconde, Loums part au pied de l’escalier de l’impasse PAIX. À pied, il rejoint la rue de Marathon et poursuit vers l’est, soit 100,8 m parcourus dans le plan horizontal. Le retour en skate, avec poussées, virages et freinage, couvre 94,8 m et se termine à moins de 2,2 m du départ, au sol. Le changement de mode se fait sur place. Ces valeurs décrivent le parcours du personnage dans la maquette.

Le test d’horloge reprend une sauvegarde de 1 300 jours de jeu écoulés. Il retrouve la tour, l’année 2013 et l’âge cumulé. La capture du point de départ « Tour B · Les Cyprès » a été prise dans Godot depuis la rue d’Entremont. Le raccord jusqu’au boulevard Lavéran reste à tester en un seul trajet depuis Marathon.

## Projet repris

Base de travail du dépôt public `negoatapp-cyber/TRACE` au commit `f0f81b6f51fb3074766800ed54f3f4743d878e57`. Godot 4.7.2, GDScript et physique Jolt. Le second dépôt identifié, TRACE-private, présente un export Web sur sa branche par défaut. Le document de conception d’origine nomme Diderot, le 13013 et Loums. Le dossier de production du dépôt attribue les systèmes de jeu et les éléments d’habillage aux travaux antérieurs.

La scène des Lauriers conserve le contrôleur de Loums, le skate, la caméra avec bras de collision, la grimpe, la mission existante, le graffiti, le temps, le son, les habitants et les contrôles tactiles. Le chargeur de personnages accepte toujours les GLB privés installés sur le poste. Cette distribution utilise une doublure articulée originale quand ces modèles sont absents. Les photos, planches et textures personnelles restent dans leurs emplacements d’origine.

## Références et géoréférencement

| Élément | Repère vérifié | Interprétation |
| --- | --- | --- |
| Malpassé | Quartier administratif 1321303, arrondissement 13213. Le point 43,3268° N, 5,4120° E est à l’intérieur de son polygone | Origine du relevé existant et de la projection municipale |
| Les Lauriers | La fiche patrimoniale 1362 situe l’ensemble entre les rues de Marathon et d’Entremont. Le point scolaire rue de Marathon est à environ 43,3269° N, 5,4130° E | Ensemble résidentiel dans Malpassé. Le point scolaire permet de recouper la localisation. Le rectangle jouable délimite un lot de production |
| Diderot | Lycée Denis Diderot, 23 boulevard Lavéran. Point documentaire arrondi 43,325° N, 5,414° E dans Malpassé | Les entrées graphiques suivent la scène existante. Le point documentaire sert de contrôle et ne localise pas chaque porte |
| Références photographiques | Les fichiers fournis 18393, 18395 et 18397, le relevé commenté et les observations déjà intégrées au projet fournissent des vues de rue de plusieurs dates. Les annotations visibles de 18393 et 18397 mentionnent le boulevard Lavéran | Références visuelles. Aucune image de Street View n’est redistribuée ni projetée sur les façades |

Sources de localisation : [fiche des Lauriers, ministère de la Culture](https://www.culture.gouv.fr/content/download/51101/file/1362_les_lauriers.pdf), [établissement Diderot, Éducation nationale](https://www.inserjeunes.education.gouv.fr/diffusion/etablissement?id_uai=0130050J), [annuaire géolocalisé des écoles](https://se-unsa13.org/carte-des-ecoles/), [renouvellement du Vallon de Malpassé, Ville de Marseille, 2015](https://www.marseille.fr/sites/default/files/contenu/mairie/RAA/raa_20150420_456.pdf).

## Données embarquées et droits

| Source | Version et traitement local | Attribution et licence |
| --- | --- | --- |
| Extrait OSM Marseille, BBBike | PBF affiché par le distributeur au 14 novembre 2026. Géométries intersectées avec le contour communal. Complément de l’API OSM du 20 novembre pour Planier | © les contributeurs d’OpenStreetMap, ODbL 1.0. La base dérivée des rues, bâtiments et occupations des sols est fournie sous ODbL 1.0. [Source](https://download.bbbike.org/osm/bbbike/Marseille/) · [Licence](https://www.openstreetmap.org/copyright) |
| Quartiers de Marseille, Datactivist / Joël Gombin | Fichier publié le 22 juillet 2026, contours issus des IRIS 2015. Polygones complets dans `data/sources/quartiers-marseille.geojson.gz` | Licence Ouverte 2.0. [Jeu de données](https://www.data.gouv.fr/datasets/quartiers-de-marseille-1) |
| IGN RGE ALTI, Géoplateforme | 12 tuiles de la couche `ELEVATION.ELEVATIONGRIDCOVERAGE.HIGHRES`, matrice WGS84G de niveau 11. Échantillonnage bilinéaire sur grille locale de 64 m. Pas métrique local de 25 m dans le relevé existant des Lauriers | © IGN, Licence Ouverte. [RGE ALTI](https://geoservices.ign.fr/rgealti) · [Service WMTS](https://data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetCapabilities&VERSION=1.0.0) |
| IGN BD TOPO, bâtiments | Instantané WFS de 397 objets dans et autour du secteur prioritaire, extrait le 20 novembre. Réponse conservée dans `data/sources/bdtopo-quartier.geojson.gz` | © IGN, Licence Ouverte. [BD TOPO](https://geoservices.ign.fr/bdtopo) · [Service WFS](https://data.geopf.fr/wfs/ows) |

La base OSM éditable contient les identifiants des objets, les anneaux, les indices des toitures, les axes de voies et leur largeur. Les aménagements de jeu et les données IGN disposent de fichiers distincts. L’attribution abrégée est visible dans le jeu. [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/) · [Licence Ouverte 2.0](https://www.etalab.gouv.fr/licence-ouverte-open-licence/).

## Repère, précision et hauteurs

Projection azimutale équidistante sur WGS84 centrée sur l’origine historique. X vers l’est, Z vers le sud et Y vertical. Une unité Godot représente un mètre. L’ordonnée Y vaut l’altitude du terrain moins 90 m. La scène locale conserve ses coordonnées métriques préexistantes, arrondies dans le relevé. Un arrondi à 10 cm dans les nouvelles tuiles réduit le volume de stockage et ne constitue pas une précision topographique.

| Base municipale | Nombre | Règle |
| --- | ---: | --- |
| Hauteur renseignée par OSM, code `tag` | 323 | Valeur métrique exploitable de `height`. La méthode de mesure de l’auteur reste inconnue |
| Nombre d’étages OSM, code `levels` | 8 871 | Estimation à 3 m par étage |
| Estimation par usage, code `type` | 276 612 | Garage ou remise 3 m, maison 6 m, appartement 15 m, résidentiel 9 m, industriel 8 m, usage générique 8 m |

Dans la scène historique, 11 hauteurs ont été remplacées par des valeurs de la BD TOPO. Le rapprochement exige un bâtiment unique, une intersection sur union d’au moins 80 % et une apparition ou une création renseignée au plus tard en 2014. Le fichier `data/marseille/hauteurs.json` conserve l’ancienne estimation, l’identifiant IGN, la précision renseignée, le taux de recouvrement et la méthode. Sept valeurs proviennent d’une interpolation du bâti, trois de corrélation et une porte la mention générique BDTopo. Ces renseignements décrivent le bâti de la source actuelle. Une surélévation ou une rénovation intervenue depuis 2014 reste possible. Les contours propres à une époque sont exclus de la jointure.

## Génération et rendu

- Le fond de carte combine les polygones de quartier, l’occupation du sol OSM, les emprises et les voies à environ 6 m/pixel. Le relief réel porte cette texture. Le relief municipal est découpé en maillages de 32 × 32 cellules pour éliminer les surfaces hors champ.
- À une échelle inférieure à 3 700 m, la vue charge un voisinage de 3 × 3 tuiles de 512 m. Les emprises, les cours intérieures des multipolygones et la triangulation des toitures sont conservées. La géométrie des bâtiments appartient à la tuile de leur centroïde. Les routes sont découpées aux frontières des tuiles.
- Un index associe chaque tuile à un bloc gzip dans `secteurs.bin`. En natif, un fil de calcul prépare les sommets pendant que le fil de rendu installe les tuiles. Dans un export Web sans threads le chargement de proximité traite une tuile par image. Le test de cet export reste à faire.
- À pied dans la base municipale, le sol et les bâtiments proches ont des collisions. Le démarrage attend le chargement de la tuile sous les pieds. Les deux côtés d’une frontière utilisent les mêmes sommets de relief. Le bouton **Explorer ici** choisit un segment de voie à proximité du centre de la vue. Une zone dépourvue de voie peut être survolée.
- Dans le quartier historique, les silhouettes aléatoires de l’ancien horizon ont laissé place au relief IGN et aux bâtiments OSM voisins. Une bande raccorde le bord du terrain détaillé au maillage IGN. Les limites de jeu de la scène historique restent présentes. F1 permet de reprendre l’exploration municipale.
- Les lampadaires, arbres, bancs, conteneurs et véhicules stationnés réutilisent leurs géométries par lots spatiaux. Les collisions d’origine et les véhicules pilotables conservent leur comportement. Les façades du socle communal reçoivent des ouvertures procédurales indicatives. Les loggias et équipements spécifiques du 13e proviennent du décor distinct des Lauriers.

## Adaptations et limites

Le jeu conserve le boulevard lissé pour le roulement, les largeurs de chaussée estimées, les trottoirs et façades stylisés et le mobilier implanté pour le gameplay. Le contact des roues suit les faibles pentes entre deux triangles, la commande de frein interrompt la poussée et une pression de saut à pied reste mémorisée environ 105 ms avant une réception. L’accès bas de l’escalier de l’impasse utilise une surface continue sous les marches et la chaussée.

L’empreinte exacte de la tour Cyprès B avant démolition reste à confirmer. Le relevé historique la place approximativement. Le jeu représente aussi des pièces, des escaliers, des parcours sur les toits et un snack conçus dans le projet antérieur. Ils relèvent de la mise en scène. Aucune vérification documentaire ne certifie le plan intérieur. Aucun appartement ni nouvelle intrigue n’a été ajouté.

La géométrie municipale dépend de la complétude d’OSM. Les ponts et échangeurs sont rabattus sur le relief, 1 173 objets linéaires déclarés en tunnel ont été écartés, les marches hors zone détaillée sont des cheminements simplifiés. Les voies et les volumes n’incluent pas la signalisation, tous les passages sous immeuble, les rails ou des aménagements de trottoir rue par rue. L’altimétrie à 64 m conserve les grands dénivelés et lisse les petits paliers. La forme de la toiture et les baies sont approximatives. La ville moderne n’a pas fait l’objet d’un inventaire rétrospectif des démolitions et constructions depuis 2014.

## Reproduire les données

Le jeu démarre intégralement sur les données déjà présentes dans `data/`. Pour reconstruire le socle, le générateur nécessite GDAL avec le pilote OSM, Python 3, NumPy, Pillow, Shapely 2, pyproj et mapbox-earcut. Un premier téléchargement alimente le cache désigné. Conserver ce cache pour reproduire le millésime, les flux distants évoluent.

```sh
python3 tools/build_marseille.py /chemin/vers/cache-geographique data/marseille
```

L’empreinte SHA-256 du PBF utilisé est `3ee15a71020bb904d8430b10c830055c5b04405ad2c336953ae24290888a76bc`. Le manifeste `data/marseille/index.json` contient les bornes métriques, la projection, les références de tuiles IGN et les statistiques. Le complément de Planier est conservé dans `data/sources/planier.osm`.

## Validation du 20 novembre 2026

Les scènes ont été exécutées sous Linux avec Godot 4.7.2 et la physique Jolt. Huit suites totalisent 67 contrôles réussis : 20 dans la cour grise, 9 sur la scène de quartier, 3 sur la caméra, 4 sur la grimpe, 14 sur les collisions et véhicules, 1 sur la doublure publique, 8 sur l’atlas et 8 en traversée de rue. Les entrées sont simulées au niveau des actions du contrôleur. La planche a accéléré à 3,05 m/s, tourné, décollé, repris contact et freiné de 3,75 à 1,60 m/s dans la rue de Marathon. L’escalier a été parcouru depuis la rue jusqu’au plateau, soit 21,75 m de progression horizontale pour 5,70 m de montée.

Le test municipal charge les neuf tuiles voisines à L’Estaque puis à Hôtel-de-Ville, pose Loums sur une voie à proximité du Vieux-Port et vérifie son avancée ainsi que les contacts au sol de part et d’autre d’une limite de tuile. Sur une exécution sans rendu, l’atlas s’est construit en 1,31 s, puis les deux groupes de tuiles en 215 et 448 ms. Les 1 049 paquets ont été décompressés et leurs indices de toiture vérifiés. Les tests de circulation portent sur des trajets échantillonnés.

À 1 120 × 630 dans la scène des Lauriers, le rendu OpenGL logiciel Mesa llvmpipe a donné une médiane de **183 ms par image**, soit environ **5,5 images/s**, et 204 ms au 95e centile sur 42 intervalles. Les ombres directionnelles sont limitées à 85 m. Le même point de mesure avec les ombres longues en cascades demandait 340 ms par image. Le ressenti à 30 ou 60 images/s reste à mesurer en conditions de jeu avec une carte graphique, puis sur téléphone. La sortie rapide du test d’atlas signale encore deux références audio WAV au moment où Godot se ferme.

Les commandes suivantes rejouent les vérifications de traversée et de chargement après le premier import du projet.

```sh
godot --headless --path . --script tools/verify_traverse.gd
godot --headless --path . --script tools/verify_atlas.gd
```

[Voir les six captures de construction](docs/CAPTURES.md). L’archive de livraison comprend aussi les WAV synthétiques et un cache sous `data/sources/cache/` avec le PBF de ce millésime, les limites de quartier et les douze tuiles IGN. Le projet Git embarque les produits géographiques prêts à jouer et ses outils de génération.
