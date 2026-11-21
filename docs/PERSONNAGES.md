# TRACE — les personnages (19.11.2026)

Planches dessinées par Louma (3 planches, 15 personnages). Les images découpées une par une sont en local dans
`assets/personnages/pnj_refs/` (jamais dans le dépôt). Les modèles 3D se font dans Meshy (image → 3D, avec squelette),
comme Loums, puis vont dans `assets/personnages/pnj/<nom>.glb` (local aussi). Le jeu les prend tout seul :
tant qu'un fichier manque, la silhouette provisoire reste.

| N° | Fichier | Rôle dans le jeu | Où |
|---|---|---|---|
| 01 | `01_gardien` | le gardien (ronde autour de la grande barre, chasse le graffeur) | habitants |
| 02 | `02_policier` | la police (J2, rondes et poursuites) | à venir (n°1) |
| 03 | `03_voisine` | les voisines (râlent, préviennent le gardien) | habitants |
| 04 | `04_patron_snack` | le patron du snack (mission 1, ravitaillement en peinture) | habitants, devant le snack |
| 05, 09, 10 | `05_jeune_casquette`, `09_jeune_capuche`, `10_jeune_kaki` | passants | habitants |
| 06, 07, 08 | `06_jeune_couronne`, `07_jeune_chaine`, `08_jeune_doudoune` | la bande des jeunes du bloc | habitants |
| 11 | `loums_bleu` | **2e tenue de Loums** (veste bleue, ceinture de bombes). F8 pour changer de tenue quand le fichier `assets/personnages/loums_bleu.glb` existe | personnage |
| 12 | `12_graffeur_capuche` | crew (histoire, n°4) | `Habitants.creer_personnage("12_graffeur_capuche")` |
| 13 | `13_graffeur_bonnet_violet` | crew (bonnet passé en violet pour ne pas le confondre avec Loums) | idem |
| 14 | `14_fille_violet` | crew (les deux filles se distinguent par leur comportement) | idem |
| 15 | `15_fille_kaki` | crew | idem |

**Avant de montrer la démo :** effacer les bandes sur les côtés des pantalons (01, 05, 06, 11) et les marques
reconnaissables sur les baskets, dans la texture, comme pour Loums (n°1 s'en charge une fois les .glb arrivés).

**Animations :** les clips Meshy dont le nom contient « walk » servent pour la marche, « idle » / « stand » / « breath »
pour l'attente. Les personnages partagent le même squelette que Loums : on pourra leur donner les clips de la capture
de mouvement de Louma.
