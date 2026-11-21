extends Node3D
## TRACE — la rue pilote « impasse de la Paix » greffée dans la grande carte (conversation décor, 20.11.2026).
## La rue pilote (scenes/rue_paix.tscn, scripts/rue_paix.gd) a été faite seule, calée sur l'image modèle.
## Ici on pose ses modèles dans le quartier, à la place de l'impasse du relevé :
##   - le repère du pilote (X à droite, la rue file vers -Z) devient un nœud placé dans la carte ;
##   - le terrain de la carte est mis à niveau sous la rue (pente de 2 %) et sous la place du fond ;
##   - les deux barres du relevé et ce qui les habillait sont retirés (le pilote les remplace) ;
##   - les modèles reçoivent la même lumière « décor peint », leurs collisions et les prises d'escalade.
## Ce qui ne vient PAS dans la carte : le mur de clôture derrière le point de vue (la rue débouche sur la
## rue de Marathon) et les deux tours dessinées du pilote (les vraies tours du relevé restent en place).

const PEINT := preload("res://shaders/decor_peint.gdshader")
const AJOURE := preload("res://shaders/decor_peint_ajoure.gdshader")
const DOSSIER := "res://assets/decor/paix/"
const PENTE := 0.02

## Où va le pilote dans la carte : son origine (le point de vue de l'image) et la cote de sa chaussée.
## La rue du pilote commence 22,4 m derrière le point de vue : ce bout-là touche la rue de Marathon (z = 95).
## L'axe de sa chaussée (X = 1,2) tombe sur l'axe de l'impasse du relevé (x = -10).
const ORIGINE := Vector3(-11.2, -3.9, 72.6)
const D_DEBUT := -22.4      # début de la rue (bord de la rue de Marathon)
const D_FOND := 43.5        # le grand mur du fond
const D_FIN := 77.5         # fin de la place haute (coupée avant la tour des Cyprès)
const Y_PLACE := 0.02 * 43.5 + 2.72

## Modèles fixes : [nom, collision]
const FIXES := [["sol_greffe", true], ["immeuble_a", true], ["immeuble_b", true], ["gymnase", true],
		["soutenement", true], ["fond_greffe", true], ["ecole", true], ["parvis_mobilier", true],
		["arbre_pignon", false]]

## Objets répétés : [modèle, X, D, cap en degrés, échelle, (hauteur en plus | "place")]
const POSES := [
	["voiture_meshy_rouge", 4.75, 17.4, 1.5, 1.0], ["voiture_meshy_blanche", 4.75, 22.8, -1.0, 1.0], ["voiture_meshy_monospace", 4.8, 28.0, 2.0, 1.0],
	["voiture_meshy_berline", 4.7, 34.8, 0.0, 1.0], ["voiture_meshy_blanche", -0.2, 19.8, 6.0, 1.0],
	["lampadaire_boule", 6.85, 14.9, 0.0, 1.0, 0.14], ["lampadaire_boule", 6.85, 28.0, 0.0, 1.0, 0.14], ["lampadaire_boule", 6.85, 40.0, 0.0, 1.0, 0.14],
	["lampadaire_fin", 1.5, 42.8, 0.0, 1.0],
	["pin_a", 4.0, 49.5, 0.0, 1.0, "place"], ["pin_b", -9.5, 53.0, 40.0, 1.0, "place"], ["pin_c", 6.4, 57.0, 200.0, 1.1, "place"],
	["arbre_bac", -4.6, 54.5, 10.0, 1.0, "place"], ["arbre_bac_b", -0.2, 55.0, 80.0, 1.0, "place"],
	["arbre_bac_b", -4.6, 61.5, 150.0, 1.05, "place"], ["arbre_bac", -0.2, 62.0, 220.0, 0.95, "place"],
	["arbre_bac", -11.0, 60.0, 300.0, 1.0, "place"], ["arbre_bac_b", 4.6, 64.0, 30.0, 1.0, "place"],
	["buisson", 6.2, 45.3, 0.0, 1.0, "place"],
]
const GOUTTIERES := [[7.1, 11.52, 4.4, -1.0]]
## Volumes grimpables du pilote (Louma : « on doit pouvoir escalader tous les bâtiments ») :
## une descente d'eau à chaque angle. [X min, X max, D min, D max, hauteur du toit au-dessus de la rue]
const GRIMPE := [[-18.7, -8.7, 13.6, 32.6, 15.0], [-15.4, -5.4, 33.1, 41.1, 15.0], [7.2, 18.0, -22.4, 7.4, 11.0], [7.2, 18.0, 7.4, 11.3, 8.7]]

## Bâtiments du relevé remplacés par le pilote.
const REMPLACES := ["Immeuble impasse sud", "Immeuble impasse"]

## Emprises du pilote (repère du pilote, X et D) où rien de la carte ne doit dépasser :
## [X min, X max, D min, D max]
const EMPRISES := [
	[-19.5, 9.0, D_DEBUT, D_FOND],      # la rue, ses trottoirs, les barres A et B
	[6.5, 28.0, D_DEBUT, 11.6],         # le gymnase
	[6.5, 22.0, 11.0, 52.0],            # le soutènement et l'école au-dessus
	[-21.0, 10.5, D_FOND, D_FIN],       # l'escalier, le mur PAIX, la place haute
]

var habillage: Node3D
var _mats := {}


func local_vers_carte(x: float, d: float) -> Vector2:
	return Vector2(ORIGINE.x + x, ORIGINE.z - d)


func carte_vers_local(p: Vector2) -> Vector2:
	return Vector2(p.x - ORIGINE.x, ORIGINE.z - p.y)


## Cote du sol du pilote en un point de la carte (null hors emprise) : chaussée en pente, place haute,
## plateau du soutènement.
func cote(p: Vector2) -> float:
	var l := carte_vers_local(p)
	if l.y >= D_FOND:
		return ORIGINE.y + Y_PLACE
	return ORIGINE.y + PENTE * l.y


func dans_emprise(p: Vector2, marge := 0.0) -> bool:
	var l := carte_vers_local(p)
	for e in EMPRISES:
		if l.x >= e[0] - marge and l.x <= e[1] + marge and l.y >= e[2] - marge and l.y <= e[3] + marge:
			return true
	return false


## 1) Le terrain de la carte, mis au niveau du pilote (avant que l'habillage ne pose quoi que ce soit) :
## dans l'emprise, 12 cm sous le sol peint ; autour, un raccord progressif sur 6 m.
## Parvis de la Tour Cyprès B (x0, x1, z0, z1) : tour + parking devant, à la cote du fond de l'impasse.
const TOUR_RECT := [-27.0, 13.0, -40.0, -4.9]
## Place de la Tour Cyprès B à sa cote réelle (relief IGN sous la tour : 3,0 à 4,1 m ; Louma, 21.11 :
## « l'escalier entre la place de la Tour et l'impasse de la Paix est vraiment grand »). Avant : -0,43 m,
## au niveau de la place des pins, ce qui enfonçait la tour de 4 m dans une cuvette.
const PLATEAU_Y := 3.5       # = tour_cypres_b.py PLATEAU
const ANCIEN_PLATEAU := -0.43
## Le mur de soutènement entre la place des pins (cote du pilote) et la place de la Tour, et le grand
## escalier taillé dedans, côté ouest de la tour (voir _escalier_tour).
const MUR_PARVIS_Z := -5.2
const ESC_X := [-32.0, -18.2]           # largeur de l'escalier (13,8 m)
const ESC_MARCHES := 22                 # 22 marches de 17,5 cm environ
const ESC_GIRON := 0.29
const DALLE := [-40.0, 13.0, -15.0]     # x0, x1, z nord des dalles qui tiennent la place de la Tour
const MUR_Z := -7.2          # murets 39-42 du plan : ils bordaient l'ancien talus, on les retire


func _distance_rect(p: Vector2, r: Array) -> float:
	var c := Vector2(clampf(p.x, r[0], r[1]), clampf(p.y, r[2], r[3]))
	return c.distance_to(p)


func aplanir(q: Node, reconstruire: bool = true) -> void:
	# d'abord le dessus de la butte des Lauriers, lissé en plates-formes (scripts/plateau_lauriers.gd)
	load("res://scripts/plateau_lauriers.gd").lisser(q)
	var gx: PackedFloat32Array = q.gx
	var gz: PackedFloat32Array = q.gz
	var alt: Array = q.alt
	for j in gz.size():
		var ligne: PackedFloat32Array = alt[j]
		for i in gx.size():
			var p := Vector2(gx[i], gz[j])
			# le muret du plan (z = -7.2) devient le mur de soutènement entre le fond de l'impasse et le
			# plateau de la Tour Cyprès B : on ne touche jamais au terrain derrière lui
			# la Tour Cyprès B, son parking et le fond de l'impasse sont au même niveau (Louma : « il n'y a
			# pas de dénivelé ») : rectangle aplani à la cote du fond de l'impasse, raccordé sur 10 m
			var dt := _distance_rect(p, TOUR_RECT)
			# Extension locale de la cour arrière pour le skate, dans la scène 2013.
			if q.epoque_imposee == "avant":
				dt = minf(dt, _distance_rect(p, [-38.0,-17.0,-43.0,-1.0]))
			# Raccord du parvis : 10 m côté Cyprès A (x > 13 : son modèle peint est calé sur ces cotes), 24 m ailleurs.
			# Avec 10 m partout, le parvis (4 m sous le relief IGN) faisait des falaises de 4-5 m au nord et à
			# l'ouest : « sol défoncé, tour enfoncée » (Louma, 21.11). Pente maximale du raccord ≈ 18°.
			var r_tour := 10.0 if p.x > TOUR_RECT[1] else 24.0
			# au sud du mur de soutènement, et dans la trémie de l'escalier : cote de la place des pins
			var sous_mur := p.y > MUR_PARVIS_Z and p.x > DALLE[0] - 3.0 and p.x < DALLE[1]
			var tremie := p.x > ESC_X[0] - 3.5 and p.x < ESC_X[1] + 3.5 and p.y > MUR_PARVIS_Z - ESC_MARCHES * ESC_GIRON + 1.0 and p.y < MUR_PARVIS_Z + 1.0
			if tremie:
				ligne[i] = ORIGINE.y + Y_PLACE - 0.12
				continue
			if sous_mur:
				dt = INF
			if dt < r_tour:
				var wt := 1.0 - smoothstep(0.0, r_tour, dt)
				ligne[i] = lerpf(ligne[i], PLATEAU_Y, wt)
				if dt <= 0.0:
					continue
			var d := _distance_emprise(p)
			if d > 6.0:
				continue
			# Côté est (gymnase, soutènement de l'école) : les murs des modèles tiennent le terrain, pas de
			# raccord vers la chaussée du pilote (il creusait une tranchée de 3-4 m jusqu'à l'école Bouge).
			# Le relief a un point tous les 5 m : les points du bord est, sous le dernier mètre des modèles, restent
			# aussi au naturel (la rampe passe sous le gymnase et le soutènement, invisible).
			var ll := carte_vers_local(p)
			if ll.y < 52.0 and ll.x > (25.5 if ll.y < 11.6 else 20.0):
				continue
			var cible := cote(_point_proche(p)) - 0.12
			var w := 1.0 - smoothstep(0.0, 6.0, d)
			ligne[i] = lerpf(ligne[i], cible, w)
		alt[j] = ligne
	q.alt = alt
	if not reconstruire:
		return
	# le maillage et la collision du terrain sont refaits avec les nouvelles cotes
	for t in q.get_tree().get_nodes_in_group("terrain"):
		if t.get_parent() == q:
			t.remove_from_group("terrain")
			t.queue_free()
	q.call("_terrain")


func _distance_emprise(p: Vector2) -> float:
	var l := carte_vers_local(p)
	var best := INF
	for e in EMPRISES:
		var cx := clampf(l.x, e[0], e[1])
		var cd := clampf(l.y, e[2], e[3])
		best = minf(best, Vector2(cx, cd).distance_to(l))
	return best


func _point_proche(p: Vector2) -> Vector2:
	var l := carte_vers_local(p)
	var best := INF
	var proche := l
	for e in EMPRISES:
		var c := Vector2(clampf(l.x, e[0], e[1]), clampf(l.y, e[2], e[3]))
		if c.distance_to(l) < best:
			best = c.distance_to(l)
			proche = c
	return local_vers_carte(proche.x, proche.y)


## 2) Les modèles du pilote.
func construire(q: Node) -> void:
	position = ORIGINE
	_escalier_tour(q)
	_retirer_releve(q)
	_mur_soutenement(q)
	for f in FIXES:
		var n := _poser(f[0])
		if n and f[1]:
			_collisions(n)
	for p in POSES:
		var n := _poser(p[0])
		if n == null:
			continue
		var y: float = PENTE * float(p[2])
		if p.size() > 5:
			y = Y_PLACE if p[5] is String else y + float(p[5])
		n.position = Vector3(p[1], y, -p[2])
		n.rotation_degrees.y = p[3]
		n.scale = Vector3.ONE * p[4]
		_collisions(n)
	for r in GRIMPE:
		var ybas: float = PENTE * float(r[2])
		for coin in [[r[0], r[2], -1, -1], [r[1], r[2], 1, -1], [r[0], r[3], -1, 1], [r[1], r[3], 1, 1]]:
			var dehors := Vector3(coin[2], 0, -coin[3]).normalized()
			var m := Marker3D.new()
			m.position = Vector3(coin[0] + coin[2] * 0.13, PENTE * float(coin[1]) + 0.14, -coin[1] + -coin[3] * 0.13)
			m.set_meta("haut", ORIGINE.y + ybas + float(r[4]))
			m.set_meta("dehors", dehors)
			m.add_to_group("gouttiere")
			add_child(m)
	for g in GOUTTIERES:
		var m := Marker3D.new()
		m.position = Vector3(g[0], PENTE * g[1] + 0.14, -g[1])
		m.set_meta("haut", ORIGINE.y + g[2])
		m.set_meta("dehors", Vector3(g[3], 0, 0))
		m.add_to_group("gouttiere")
		add_child(m)
	_spot_escalier()


## Cache les barres du relevé (et coupe leurs collisions) ; enlève ce que la carte avait posé dans
## l'emprise du pilote : arbres de la friche, potelets, boîtes… Le sol et les voies restent.
func _retirer_releve(q: Node) -> void:
	for bat in q.get_tree().get_nodes_in_group("batiment"):
		if REMPLACES.has(String(bat.name)):
			_eteindre(bat)
	var n := 0
	for racine in [q, habillage]:
		for e in (racine as Node).get_children():
			if e == self or not (e is Node3D):
				continue
			if e.is_in_group("terrain") or String(e.name).begins_with("Voie") or String(e.name).begins_with("Trottoir"):
				continue
			n += _nettoyer(e as Node3D)
	print("Greffe impasse de la Paix : %d éléments de la carte retirés de l'emprise" % n)


func _nettoyer(e: Node3D) -> int:
	if e is GeometryInstance3D:
		var gi := e as GeometryInstance3D
		var b: AABB = gi.global_transform * gi.get_aabb()
		if b.size.x > 60.0 or b.size.z > 60.0:
			return 0   # grand maillage partagé (voies, sol) : on n'y touche pas
		var c := b.get_center()
		if dans_emprise(Vector2(c.x, c.z), 0.5):
			gi.visible = false
			return 1
		return 0
	if e is CollisionObject3D and not (e is Area3D):
		var c := e.global_position
		var dedans := dans_emprise(Vector2(c.x, c.z), 0.5)
		var k := 0
		for f in e.get_children():
			if f is Node3D:
				k += _nettoyer(f)
		if dedans:
			(e as CollisionObject3D).collision_layer = 0
			k += 1
		return k
	var k2 := 0
	for f in e.get_children():
		if f is Node3D:
			k2 += _nettoyer(f)
	return k2


func _eteindre(n: Node) -> void:
	for e in n.find_children("*", "GeometryInstance3D", true, false):
		(e as GeometryInstance3D).visible = false
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visible = false
	for e in n.find_children("*", "CollisionObject3D", true, false):
		(e as CollisionObject3D).collision_layer = 0
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 0


func _poser(nom: String) -> Node3D:
	var chemin := DOSSIER + nom + ".glb"
	if not ResourceLoader.exists(chemin):
		push_warning("Greffe : modèle absent " + chemin)
		return null
	var scene: PackedScene = load(chemin)
	var n: Node3D = scene.instantiate()
	n.name = nom.capitalize().replace(" ", "")
	add_child(n)
	_peindre(n)
	return n


## Même lumière « décor peint » que la rue pilote (rue_paix.gd).
func _peindre(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var std := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if std == null:
				continue
			if not _mats.has(std):
				var ajoure := std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				var t := ShaderMaterial.new()
				t.shader = AJOURE if ajoure else PEINT
				t.set_shader_parameter("couleur", std.albedo_color)
				if std.albedo_texture:
					t.set_shader_parameter("texture_couleur", std.albedo_texture)
					t.set_shader_parameter("avec_texture", true)
				var nom := String(std.resource_name)
				var sombre := 0.78
				for cle in ["beton", "dessus", "marche", "gris", "caisse", "pierre", "coffret", "souche", "edicule", "corniche", "orange"]:
					if nom.begins_with(cle):
						sombre = 0.62
				t.set_shader_parameter("face_detournee", sombre)
				if nom.begins_with("feuilles") or nom.begins_with("carrosserie"):
					t.set_shader_parameter("sans_ombre", true)
				if nom.begins_with("carrosserie"):
					t.set_shader_parameter("voiture", true)
				_mats[std] = t
			mi.set_surface_override_material(s, _mats[std])
			if String(std.resource_name).begins_with("feuilles"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for e in n.get_children():
		_peindre(e)


func _collisions(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if not String(mi.name).contains("grille") and not String(mi.name).contains("feuilles") and not String(mi.name).contains("coeur"):
			mi.create_trimesh_collision()
			for e in mi.get_children():
				if e is StaticBody3D:
					e.add_to_group("mur")
	for e in n.get_children():
		if not (e is StaticBody3D):
			_collisions(e)


## Plus de talus devant la tour : les murets du plan qui le bordaient sont masqués (image et collision).
func _mur_soutenement(q: Node) -> void:
	for mu in q.get_children():
		if not String(mu.name).begins_with("Muret"):
			continue
		for mi in (mu as Node).find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			var c := bb.get_center()
			if absf(c.z - MUR_Z) > 0.6 or c.x < TOUR_RECT[0] or c.x > TOUR_RECT[1]:
				continue
			(mi as MeshInstance3D).visible = false
			for cs0 in (mu as Node).find_children("*", "CollisionShape3D", true, false):
				(cs0 as CollisionShape3D).disabled = true


## Le grand escalier devient un spot de skate (Louma 21.11, conversation gameplay) :
## la main courante du milieu se grinde, et deux curbs de pierre descendent le long des murs, de chaque côté.
## Mesures reprises de faire_fond() (assets/decor/source/rue_paix/generer.py) : 16 marches de 2,72/16 m, giron 0,32 m,
## de X -5,4 à 0,55, main courante au milieu (haut à 1,0 m au-dessus de chaque marche).
const ESC_X0 := -5.4
const ESC_X1 := 0.55
const ESC_N := 16
const ESC_HM := 2.72 / 16.0
const ESC_GM := 0.32


func _spot_escalier() -> void:
	var y0 := PENTE * D_FOND
	var xc := (ESC_X0 + ESC_X1) * 0.5
	# la main courante : posée exactement sur celle du modèle, en un peu plus épais
	var a := Vector3(xc, y0 + 1.0 - 0.06, -(D_FOND + 0.15))
	var b := Vector3(xc, y0 + 16.0 * ESC_HM + 1.0 - 0.06, -(D_FOND + 15.0 * ESC_GM + 0.15))
	_grindable("Rail_grand_escalier", a, b, 0.06, 0.07, Color(0.42, 0.36, 0.44))
	# les curbs : 42 cm au-dessus du nez des marches, enterrés dessous ; ils finissent au bord de la place
	var pente := ESC_HM / ESC_GM
	var bas := 0.35
	var haut := 0.42
	var d_fin := D_FOND + 15.0 * ESC_GM + 0.32
	for x in [ESC_X0 + 0.26, ESC_X1 - 0.26]:
		var c_a := Vector3(x, y0 + ESC_HM - bas, -D_FOND)
		var c_b := Vector3(x, y0 + ESC_HM + (d_fin - D_FOND) * pente - bas, -d_fin)
		var cos_p := cos(atan(pente))
		_grindable("Curb_grand_escalier", c_a, c_b, (bas + haut) * cos_p, 0.5, Color(0.74, 0.64, 0.62))


func _grindable(nom: String, a: Vector3, b: Vector3, hauteur: float, epaisseur: float, couleur: Color) -> void:
	var r := Rail.new()
	r.name = nom
	var x := (b - a).normalized()
	var y := (Vector3.UP - x * x.dot(Vector3.UP)).normalized()
	r.transform = Transform3D(Basis(x, y, x.cross(y)), a)
	add_child(r, true)
	r.length = a.distance_to(b)
	r.height = hauteur
	r.thickness = epaisseur
	r.color = couleur


## ── Le grand escalier de la place de la Tour (Louma, 21.11) ──
## La place de la Tour est à sa cote réelle (PLATEAU_Y), 3,8 m au-dessus de la place des pins du pilote.
## Un mur de soutènement en pierre court le long de z = MUR_PARVIS_Z ; le grand escalier est taillé dedans,
## à l'ouest de la tour, sur 13,8 m de large, avec une main courante grindable au milieu. Des dalles pleines
## tiennent le dessus (le relief a un point tous les 5 m : elles cachent les rampes du terrain).
func _escalier_tour(q: Node) -> void:
	var e := Node3D.new()
	e.name = "EscalierTourCypres"
	q.add_child(e)
	var bas: float = ORIGINE.y + Y_PLACE            # sol de la place des pins
	var haut: float = PLATEAU_Y
	var n := ESC_MARCHES
	var hm := (haut - bas) / n
	var z_bas := MUR_PARVIS_Z
	var z_haut := MUR_PARVIS_Z - n * ESC_GIRON
	var pierre := Color(0.66, 0.58, 0.56)
	var marche := Color(0.80, 0.73, 0.68)
	var dalle := Color(0.62, 0.61, 0.58)
	var metal := Color(0.34, 0.28, 0.36)
	# dalles : ouest de l'escalier, est (devant la tour), palier en haut
	_bloc(e, "DalleOuest", Vector3(DALLE[0], -1.0, DALLE[2]), Vector3(ESC_X[0], haut, z_bas), dalle, pierre)
	_bloc(e, "DalleEst", Vector3(ESC_X[1], -1.0, DALLE[2]), Vector3(DALLE[1], haut, z_bas), dalle, pierre)
	_bloc(e, "PalierHaut", Vector3(ESC_X[0], -1.0, DALLE[2]), Vector3(ESC_X[1], haut, z_haut), dalle, pierre)
	# marches pleines (chaque marche descend jusqu'au sol : pas de vide dessous)
	for k in n:
		var zf := z_bas - k * ESC_GIRON
		_bloc(e, "Marche", Vector3(ESC_X[0], bas - 0.6, z_haut), Vector3(ESC_X[1], bas + (k + 1) * hm, zf), marche, pierre)
	# couvertine du mur et garde-corps le long du vide
	for seg in [[DALLE[0], ESC_X[0]], [ESC_X[1], DALLE[1]]]:
		_bloc(e, "Couvertine", Vector3(seg[0], haut, z_bas - 0.35), Vector3(seg[1], haut + 0.12, z_bas + 0.05), marche, marche, false)
		_garde_corps(e, Vector3(seg[0], haut, z_bas - 0.2), Vector3(seg[1], haut, z_bas - 0.2), metal)
	for x in ESC_X:
		_garde_corps(e, Vector3(x, haut + 0.12, z_haut), Vector3(x, haut + 0.12, z_bas - 0.2), metal)
		_bloc(e, "Echiffre", Vector3(x - 0.18, haut, z_haut), Vector3(x + 0.18, haut + 0.12, z_bas), marche, marche, false)
	# main courante au milieu : un rail en pente, grindable
	var xc := (ESC_X[0] + ESC_X[1]) * 0.5
	var a := Vector3(xc, bas + 0.35, z_bas + 0.2)
	var b := Vector3(xc, haut + 0.35 + hm, z_haut - 0.4)
	var rail := Rail.new()
	rail.name = "RampeGrandEscalier"
	rail.length = a.distance_to(b)
	rail.height = 0.55
	rail.thickness = 0.07
	rail.color = metal
	var dx := (b - a).normalized()
	var dz := dx.cross(Vector3.UP).normalized()
	rail.transform = Transform3D(Basis(dx, dz.cross(dx), dz), a)
	e.add_child(rail)
	rail.add_to_group("rail")
	# ce qui poussait dans la trémie (arbres, buissons) n'a plus de sol
	for g in ["arbre", "vegetation"]:
		for t in q.get_tree().get_nodes_in_group(g):
			var pt: Vector3 = (t as Node3D).global_position
			if pt.x > ESC_X[0] - 0.5 and pt.x < ESC_X[1] + 0.5 and pt.z > z_haut - 0.5 and pt.z < z_bas + 0.5:
				t.queue_free()


func _bloc(parent: Node3D, nom: String, a: Vector3, b: Vector3, dessus: Color, cote_: Color, solide := true) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var taille := hi - lo
	var mi := MeshInstance3D.new()
	mi.name = nom
	var box := BoxMesh.new()
	box.size = taille
	mi.mesh = box
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/bd_toon.gdshader")
	m.set_shader_parameter("couleur", cote_ if taille.y > 1.0 else dessus)
	m.set_shader_parameter("grain", 0.12)
	mi.material_override = m
	mi.position = (lo + hi) * 0.5
	if solide:
		var corps := StaticBody3D.new()
		corps.name = nom
		corps.position = mi.position
		var cs := CollisionShape3D.new()
		var forme := BoxShape3D.new()
		forme.size = taille
		cs.shape = forme
		corps.add_child(cs)
		parent.add_child(corps)
		mi.position = Vector3.ZERO
		corps.add_child(mi)
		# le dessus des grandes dalles est un sol : couleur de dalle, les côtés en pierre
		if taille.y > 1.0:
			var dessus_mi := MeshInstance3D.new()
			var plaque := BoxMesh.new()
			plaque.size = Vector3(taille.x, 0.02, taille.z)
			dessus_mi.mesh = plaque
			var md := ShaderMaterial.new()
			md.shader = m.shader
			md.set_shader_parameter("couleur", dessus)
			md.set_shader_parameter("grain", 0.12)
			dessus_mi.material_override = md
			dessus_mi.position = Vector3(0, taille.y * 0.5 + 0.005, 0)
			corps.add_child(dessus_mi)
	else:
		parent.add_child(mi)


func _garde_corps(parent: Node3D, a: Vector3, b: Vector3, c: Color) -> void:
	var l := a.distance_to(b)
	var n := maxi(2, int(l / 1.6) + 1)
	for i in n:
		var p := a.lerp(b, float(i) / float(n - 1))
		_bloc(parent, "Poteau", p + Vector3(-0.025, 0.12, -0.025), p + Vector3(0.025, 1.1, 0.025), c, c, false)
	_bloc(parent, "Lisse", a + Vector3(0, 1.06, -0.03), b + Vector3(0, 1.12, 0.03), c, c, true)
