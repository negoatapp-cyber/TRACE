# Les Lauriers et Diderot en HD

La référence jouable est l’export Web filmé sur téléphone. Il contient une version de Marseille 2013 plus avancée que les sources publiques. La variante HD reprend ses scènes, personnages, véhicules et sons. L’habillage s’applique aux matériaux communs. La vérification détaillée porte sur Marathon, le lycée et la place du Jardin.

## Voir ou jouer

- [Ouvrir Marseille 2013 en HD](https://trace-marseille-atlas.caroule-skateshop.chatgpt.site/hd/)
- [Ouvrir en mode fluide](https://trace-marseille-atlas.caroule-skateshop.chatgpt.site/hd/?qualite=fluide)
- [Comparer les captures de Marathon et Diderot](https://trace-marseille-atlas.caroule-skateshop.chatgpt.site/hd/comparatif.html)

Les deux profils adaptent la résolution interne à la taille de l’écran. Le budget cible est de 2,07 millions de pixels en HD et de 0,92 million en mode fluide, avec un facteur d’échelle compris entre 0,4 et 1. Les captures du comparatif proviennent du moteur en 1920 × 1080, à 16 h 30, avec des caméras identiques pour chaque paire.

## Décisions de rendu et de circulation

- Le grain et les reprises du bitume ont moins de contraste. Les bordures ressortent ainsi mieux en mouvement. La lecture de profondeur pour les contours est corrigée en rendu de compatibilité.
- L’enduit original se répète tous les deux mètres. La texture de 1024 × 1024 décrit la matière et ne sert pas de document historique. Aucune nouvelle position de bâtiment n’a été déduite des captures.
- La limite ouest de la carte coupait l’accès à l’amphithéâtre. Son tracé physique contourne maintenant la place. Le joueur peut atteindre le point local (−131, 64) depuis le sud.
- Les formes de collision du lycée sont regroupées spatialement pour réduire le coût de construction de la scène au lancement. Le menu de graffitis ajuste sa taille à la zone visible quand il s’ouvre et lors de la rotation de l’écran.

## Reproduire

Les sources s’ouvrent avec Godot 4.7.2. Pour reproduire précisément la version filmée avec ses ressources supplémentaires, utiliser l’export d’origine comme entrée. Le script vérifie son SHA-256 avant toute transformation.

```sh
python3 tools/export_hd_2013.py /chemin/original.pck /tmp/TRACE-HD.pck
godot --rendering-method gl_compatibility --main-pack /tmp/TRACE-HD.pck res://scenes/marseille_2013.tscn
```

Pour tester le profil fluide, ajouter `-- fluide` à la dernière commande. Le fichier d’origine attendu a pour SHA-256 `4b7d0a488bb5043d9813a68eef962fa006c170c11a873ef6892b5d8aa5bb54ab`. Les licences et attributions des données existantes restent dans le projet.

## Vérifications et limites

- Sur la version filmée et sa variante HD, les 3 258 boîtes de collision échantillonnées au lycée ont les mêmes dimensions et transformations. Les 2 146 sondages verticaux donnent les mêmes hauteurs au millimètre. La scène instanciée en local sans affichage passe de 4,51 à 2,07 secondes lors de la comparaison.
- Dans Godot, Loums rejoint à pied l’amphithéâtre par le sud. En skate, poussée à 3,95 m/s, départ au contact du sol et retour au sol vérifiés. Une pression anticipée pendant une brève perte de contact sur chaussée irrégulière peut encore manquer le saut. Déplacement en scooter vérifié sur 6,74 mètres.
- Les commandes du sélecteur de graffiti tiennent dans les deux formats testés (390 × 844 et 844 × 390). Leur confort tactile en session longue reste à mesurer.
- L’assemblage des blocs livrés au navigateur restitue exactement le paquet exécuté dans Godot. Le navigateur de vérification ne fournit pas WebGL 2. La cadence et le temps de chargement complet sur téléphone physique restent à mesurer. Le premier téléchargement reste conséquent.
- Ce passage porte sur les matériaux, l’interface et des raccords précis. L’altimétrie au centimètre, l’implantation historique de la tour et la continuité de tous les itinéraires de Marseille demandent des contrôles distincts.
