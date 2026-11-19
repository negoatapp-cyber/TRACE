extends RefCounted
## TRACE — mission 1, « Premier mur » : les textes (conversation n°4, histoire).
## Aucun nom réel, aucune marque. Le lieu est réel, les gens sont inventés.
## Chaque réplique est [qui, texte]. « qui » vide = carte de narration.
## Les textes vivent dans un .gd (et non un .json) pour être toujours inclus dans l'export Web.

const TITRE := "Premier mur"

const INTRO := [
	["", "Lundi, après les cours. Le cahier est plein de LOUMS. Il lui faut un vrai mur."],
]

const OBJECTIF := {
	"peinture": "Va au snack, en face du lycée, chercher de la peinture",
	"mur": "Pose ton nom sur un mur : un tag suffit",
	"retour": "Retourne au snack",
	"fini": "Premier mur posé",
}

const ARRIVEE := [
	["Le patron", "Tiens, le môme au cahier. T'as de quoi payer, ou tu viens encore regarder les bombes ?"],
	["Loums", "Je cherche juste de quoi faire du bruit."],
	["Le patron", "Prends. Je t'ai pas vu. Et pas devant ma baraque."],
]


## Juste après le tag : ce que Loums se dit, selon ceux qui l'ont vu.
static func apres_tag(qui: String) -> Array:
	match qui:
		"gardien":
			return [["Loums", "Le gardien m'a vu. Il va falloir faire gaffe ces prochains jours."]]
		"voisine":
			return [["Loums", "Une voisine a tout vu. Elle va en parler."]]
		"jeune":
			return [["Loums", "Les jeunes du bloc ont vu mon nom. Ça va jaser."]]
		"passant":
			return [["Loums", "Un passant a regardé. Il ne sait pas qui je suis."]]
	return [["Loums", "Personne. Mon nom est là, et personne ne sait que c'est le mien."]]


## De retour au snack : le quartier a déjà retenu quelque chose.
static func retour(spot: String, qui: String) -> Array:
	var l: Array = []
	match spot:
		"haut":
			l.append(["Le patron", "Y a un nom tout en haut, là-bas. Ça dit LOUMS. Comment t'as fait pour monter ?"])
		"boulevard":
			l.append(["Le patron", "Sur le boulevard, en plein jour ? T'as du culot. Ça se voit, un nom comme ça."])
		"terrain_vague":
			l.append(["Le patron", "Derrière la barre, sur le terrain vague ? Malin. Personne le verra, mais il est là."])
		_:
			l.append(["Le patron", "Y a un nouveau nom dans le quartier. LOUMS. Moi, je dis rien."])
	match qui:
		"gardien":
			l.append(["Le patron", "Fais gaffe : le gardien t'a dans le collimateur."])
		"voisine":
			l.append(["Le patron", "Une voisine est passée râler. Elle a pas dit ton nom, mais elle a regardé ton cahier."])
		"jeune":
			l.append(["Le patron", "Les jeunes du bloc en parlent déjà."])
	l.append(["", "Premier mur. Le quartier commence à retenir ton nom."])
	return l
