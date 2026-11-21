extends RefCounted
## Le plateau des Lauriers (n°2, 21.11.2026).
##
## Louma : « le terrain est trop accidenté, la vérité c'est qu'il est sur une butte, un plateau ».
## Le relief IGN (RGE ALTI, contrôlé point par point sur le service altimétrique de la Géoplateforme)
## est juste à grande échelle : la cité tient le dessus d'une butte (≈ 97-99 m), bordée à l'ouest par
## un talus raide qui descend vers le stade et la rue d'Entremont. Mais échantillonné tous les 25 m,
## il garde à l'intérieur du plateau des bosses et des creux de 2 à 5 m (remblais, buttes de terre,
## talus de parking) qui, sous les pieds du joueur, donnent un sol cabossé.
##
## Méthode (skill « procedural-gen », redistribution et lissage d'un champ de hauteur) :
##   1. un champ lissé S = flou gaussien séparable du relief (σ = 22 m) : garde la pente générale du
##      plateau, efface les bosses ;
##   2. dans le masque du plateau, le sol prend S, avec un raccord progressif de 18 m vers le relief
##      d'origine au bord (le talus ouest reste raide : c'est la butte) ;
##   3. au pied des bâtiments (emprise + 4 m), on garde la cote d'origine, raccordée sur 10 m : les
##      modèles peints ont été construits sur ces cotes, rien ne flotte ni ne s'enterre ;
##   4. terrasses : le résultat est arrondi par paliers de 0,5 m avec un fondu doux, pour que les grandes
##      surfaces (parkings, cour, terrain vague) soient vraiment planes, comme des plates-formes.
## Rien n'est modifié dans quartier_reel.gd : on agit sur ses cotes, avant la construction du terrain.

const SIGMA := 22.0
const RACCORD := 18.0
const MARGE_BAT := 4.0
const RACCORD_BAT := 10.0
const PALIER := 0.0   ## 0 = pas de paliers (ils faisaient des bosses en skate) ; 0.5 = ancien réglage

## Rue de service de la Grande barre (Street View 2011-2014) : côté est, la voie longe le soubassement
## des caves, environ 2,1 m sous le plancher du rez-de-chaussée ; le dessus du plateau (terrain vague,
## arbres, blocs de béton) reste plus haut, derrière un petit talus. Plancher de la barre (relevé) : 7,11.
const BARRE_EST := [
	Vector2(-26, -61), Vector2(-25, -93), Vector2(-24, -125), Vector2(-36, -157),
	Vector2(-49, -193), Vector2(-68, -246), Vector2(-67, -293),
]
const RUE_SERVICE := 7.11 - 2.1
const LARGE_RUE := 11.0
const TALUS_RUE := 9.0

## Dessus de la butte (X est, Z sud). Le talus ouest de la Grande barre et la descente vers Marathon
## restent hors masque ; le boulevard Lavéran (x > 150) a son propre profil lissé.
const MASQUE := [
	Vector2(-38, -310), Vector2(150, -310), Vector2(150, -70), Vector2(115, -25),
	Vector2(70, -12), Vector2(25, -30), Vector2(-15, -45), Vector2(-32, -80),
]


static func lisser(q: Node) -> void:
	var gx: PackedFloat32Array = q.gx
	var gz: PackedFloat32Array = q.gz
	var alt: Array = q.alt
	var nx := gx.size()
	var nz := gz.size()
	if nx < 8 or nz < 8:
		return
	var masque := PackedVector2Array(MASQUE)
	var emprises := _emprises(q)
	# 1. champ lissé (noyau gaussien en mètres, la grille n'est pas forcément régulière aux bords)
	var tmp := []
	for j in nz:
		var row := PackedFloat32Array()
		row.resize(nx)
		for i in nx:
			row[i] = _flou(alt[j], gx, i)
		tmp.append(row)
	var cols := []
	for i in nx:
		var col := PackedFloat32Array()
		col.resize(nz)
		for j in nz:
			col[j] = tmp[j][i]
		var out := PackedFloat32Array()
		out.resize(nz)
		for j in nz:
			out[j] = _flou(col, gz, j)
		cols.append(out)
	var lisse := []
	for j in nz:
		var row := PackedFloat32Array()
		row.resize(nx)
		for i in nx:
			row[i] = cols[i][j]
		lisse.append(row)
	# 2-4. remplacement dans le masque
	var nb := 0
	for j in nz:
		var ligne: PackedFloat32Array = alt[j]
		for i in nx:
			var p := Vector2(gx[i], gz[j])
			var dm := _distance_dedans(p, masque)
			if dm <= 0.0:
				continue
			var w := smoothstep(0.0, RACCORD, dm)
			var db := INF
			for e in emprises:
				var r: Rect2 = e[0]
				if not r.grow(MARGE_BAT + RACCORD_BAT).has_point(p):
					continue
				db = minf(db, _distance_poly(p, e[1]))
			if db < MARGE_BAT + RACCORD_BAT:
				w *= smoothstep(MARGE_BAT, MARGE_BAT + RACCORD_BAT, db)
			if w <= 0.0:
				continue
			var s: float = lisse[j][i]
			# Paliers retirés (Louma, 21.11 : « le long des Lauriers c'est plein de bosses ») : l'arrondi par
			# marches de 0,5 m faisait une tôle ondulée (plat, rampe, plat…) qui fait décoller la planche.
			# Le champ lissé (σ = 22 m) est déjà doux : on le garde tel quel.
			var palier := s if PALIER <= 0.0 else (floorf(s / PALIER) + smoothstep(0.35, 0.65, s / PALIER - floorf(s / PALIER))) * PALIER
			ligne[i] = lerpf(ligne[i], palier, w)
			nb += 1
		alt[j] = ligne
	# la rue de service creusée le long du soubassement est de la Grande barre
	var axe := PackedVector2Array(BARRE_EST)
	var nr := 0
	for j in nz:
		var ligne: PackedFloat32Array = alt[j]
		for i in nx:
			var p := Vector2(gx[i], gz[j])
			if p.x < -90.0 or p.x > 20.0 or p.y < -320.0 or p.y > -40.0:
				continue
			var best := INF
			var cote_est := false
			for k in range(1, axe.size()):
				var a := axe[k - 1]
				var b := axe[k]
				var c := Geometry2D.get_closest_point_to_segment(p, a, b)
				var d := p.distance_to(c)
				if d < best:
					best = d
					var t := (b - a).normalized()
					cote_est = (p - c).dot(Vector2(-t.y, t.x)) > 0.0
			if not cote_est or best > LARGE_RUE + TALUS_RUE:
				continue
			var w := 1.0 - smoothstep(LARGE_RUE, LARGE_RUE + TALUS_RUE, best)
			ligne[i] = lerpf(ligne[i], RUE_SERVICE, w)
			nr += 1
		alt[j] = ligne
	q.alt = alt
	print("Plateau des Lauriers : %d points du sol lissés, %d pour la rue de service" % [nb, nr])


static func _flou(v: PackedFloat32Array, pos: PackedFloat32Array, i: int) -> float:
	var somme := 0.0
	var poids := 0.0
	var x0 := pos[i]
	var k := i
	while k >= 0 and x0 - pos[k] <= SIGMA * 2.5:
		var d := (x0 - pos[k]) / SIGMA
		var g := exp(-0.5 * d * d)
		somme += v[k] * g
		poids += g
		k -= 1
	k = i + 1
	while k < pos.size() and pos[k] - x0 <= SIGMA * 2.5:
		var d := (pos[k] - x0) / SIGMA
		var g := exp(-0.5 * d * d)
		somme += v[k] * g
		poids += g
		k += 1
	return somme / maxf(poids, 0.0001)


## Emprises des bâtiments de l'époque jouée, lues dans le relevé exporté (data/batiments_carte.json).
static func _emprises(q: Node) -> Array:
	var out := []
	var f := FileAccess.open("res://data/batiments_carte.json", FileAccess.READ)
	if f == null:
		return out
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Array):
		return out
	var ep := "avant"
	var imp = q.get("epoque_imposee")
	if imp is String and imp != "":
		ep = imp
	for b in data:
		var e := String(b.get("epoque", ""))
		if e != "" and e != ep:
			continue
		var poly := PackedVector2Array()
		for p in b["poly"]:
			poly.append(Vector2(p[0], p[1]))
		if poly.size() < 3:
			continue
		var r := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			r = r.expand(p)
		out.append([r, poly])
	return out


## Distance d'un point au bord d'un polygone (0 à l'intérieur).
static func _distance_poly(p: Vector2, poly: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


## Profondeur d'un point dans le masque (≤ 0 dehors).
static func _distance_dedans(p: Vector2, poly: PackedVector2Array) -> float:
	if not Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best
