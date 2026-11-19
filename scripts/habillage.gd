extends Node3D
## TRACE — l'habillage urbain (conversation n°2) : trottoirs, marquages, lampadaires, arbres,
## conteneurs, bancs, potelets, panneaux, abribus, équipement du stade.
## Il passe APRÈS la construction du quartier (quartier_reel.gd, conversation n°1), qu'il ne modifie pas :
## il relit le relevé (data/quartier_reel.txt) en lecture seule et pose le sol grâce à Quartier.h().
## Les emplacements sont plausibles, pas relevés. Tout est déterministe (même graine à chaque lancement).
## Créé au lancement par style_bd.gd : aucune scène à modifier.

const Q := preload("res://scripts/quartier_reel.gd")
const MARQUE := preload("res://scripts/marque_murale.gd")
const MOB_GRIS := Color(0.30, 0.34, 0.33)
const MOB_BETON := Color(0.80, 0.77, 0.71)

var quartier: Node3D
var _emprises: Array = []   # contours où l'on ne pose rien (bâtiments, stade, parkings…)
var _axes: Array = []       # [points, demi-largeur] de chaque voie
var _mats := {}
var _rng := RandomNumberGenerator.new()
var _modeles := {}          # nom → scène chargée depuis assets/decor/<nom>.glb (null si absent)
var _murs_releves: Array = []
var _textures := {}

const DECOR := "res://assets/decor/%s.glb"
## Teintes de carrosserie des années 2000-2010 (aucune marque).
const TEINTES_VOITURE := [Color(0.80, 0.80, 0.78), Color(0.58, 0.60, 0.62), Color(0.18, 0.20, 0.24),
	Color(0.62, 0.14, 0.14), Color(0.18, 0.28, 0.52), Color(0.86, 0.84, 0.76), Color(0.30, 0.40, 0.30), Color(0.72, 0.58, 0.32)]


func _ready() -> void:
	if quartier == null:
		quartier = get_parent().get_node_or_null("Quartier")
	if quartier == null:
		return
	var batiments := []
	var voies := []
	var zones := []
	var f := FileAccess.open(Q.RELEVE, FileAccess.READ)
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		var c := l.split("|")
		if c[c.size() - 1].begins_with("@"):
			if c[c.size() - 1].substr(1) != Q.epoque:
				continue
			c.remove_at(c.size() - 1)
		if c[0] == "B" and Q.demolies.has(c[1]):
			continue   # démoli à la date du jeu (temps.gd, n°1)
		match c[0]:
			"B": batiments.append(c)
			"R": voies.append(c)
			"Z": zones.append(c)
			"M": _murs_releves.append(_pts(c[1]))
			"W": _murs_releves.append(_pts(c[1]))
	for c in voies:
		_axes.append([_pts(c[3]), (Q.VOIES.get(c[1], Q.VOIES["s"]) as Array)[0] * 0.5, c[1]])
	_sol()
	_rng.seed = 13014
	_pied_des_cypres()
	for e in load("res://scripts/habillage_place.gd").emprises():
		_emprises.append(e)
	_emprises.append(PackedVector2Array([Vector2(-28, -1), Vector2(-3, -1), Vector2(-3, 96), Vector2(-28, 96)]))  # impasse PAIX
	_emprises.append(PackedVector2Array([Vector2(115, 34), Vector2(130, 34), Vector2(130, 50), Vector2(115, 50)]))  # le snack
	_mobilier(voies, batiments, zones)
	_habiller_voitures()
	_facades(batiments)
	_rue_de_marathon(batiments)
	var ly := Node3D.new()
	ly.set_script(load("res://scripts/habillage_lycee.gd"))
	ly.name = "LyceeInterieur"
	ly.set("habillage", self)
	add_child(ly)
	ly.call("construire", batiments)
	var lv := Node3D.new()
	lv.set_script(load("res://scripts/habillage_laveran.gd"))
	lv.name = "BoulevardLaveran"
	lv.set("habillage", self)
	add_child(lv)
	lv.call("construire", batiments, voies, ly.get("portes_monde"), Q.epoque)
	_mur_paix()
	_horizon()
	# le ciel peint et la lumière de chaque heure (scripts/ciel.gd)
	var ciel: Node = preload("res://scripts/ciel.gd").new()
	ciel.name = "Ciel"
	add_child(ciel)
	_vieux_murs(batiments)


func h(x: float, z: float) -> float:
	return quartier.h(x, z)


## Hauteur où POSER un objet : le sol, plus l'épaisseur de la chaussée (7 cm) ou du trottoir (10 cm),
## qui sont dessinés au-dessus du sol réel. Sans ça, les objets s'enfoncent dans le trottoir.
func sol(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var plus := 0.0
	for ax in _axes:
		var type: String = ax[2]
		if type != "b" and type != "r" and type != "s":
			continue
		var demi: float = ax[1]
		var pts: PackedVector2Array = ax[0]
		for k in pts.size() - 1:
			var d := Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1]).distance_to(p)
			if d < demi:
				plus = maxf(plus, 0.07)
			elif type != "s" and d < demi + 2.2:
				plus = maxf(plus, 0.10)
	return h(x, z) + plus


## Le sol hors chaussées : béton, enrobé, terre battue et herbe sèche au lieu du sable uniforme.
func _sol() -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/bd_sol.gdshader")
	for t in get_tree().get_nodes_in_group("terrain"):
		for mi in (t as Node).find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = m


# ───────────────────────── modèles 3D (Blender) ─────────────────────────

## Copie d'un modèle de assets/decor/, ou null si le fichier manque (on garde alors les formes simples).
func _modele(nom: String) -> Node3D:
	if not _modeles.has(nom):
		_modeles[nom] = null
		var chemin := DECOR % nom
		if ResourceLoader.exists(chemin):
			var ps := load(chemin) as PackedScene
			if ps:
				_modeles[nom] = ps.instantiate()
	var m = _modeles[nom]
	return (m as Node3D).duplicate() if m else null


## Remplace l'apparence d'un corps (ses boîtes) par un modèle, en gardant sa collision.
func _vetir(corps: Node3D, nom: String, decalage := Vector3.ZERO, rot_y := 0.0, echelle := 1.0) -> Node3D:
	var m := _modele(nom)
	if m == null:
		return null
	for mi in corps.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	m.position = decalage
	m.rotation.y = rot_y
	m.scale = Vector3.ONE * echelle
	corps.add_child(m)
	corps.set_meta("modele", m)
	return m


## Repeint les surfaces d'un modèle dont le matériau porte ce nom (ex. « Carrosserie »).
func _repeindre(m: Node3D, matiere: String, c: Color) -> void:
	var nouveau := StandardMaterial3D.new()
	nouveau.albedo_color = c
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(k)
			if orig and orig.resource_name == matiere:
				mi.set_surface_override_material(k, nouveau)


## Tout repeint (épaves brûlées).
func _bruler(m: Node3D) -> void:
	var teintes := [Color(0.13, 0.11, 0.10), Color(0.30, 0.18, 0.12), Color(0.08, 0.08, 0.08)]
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			var b := StandardMaterial3D.new()
			b.albedo_color = teintes[_rng.randi() % teintes.size()]
			mi.set_surface_override_material(k, b)


func _type_voiture() -> String:
	var r := _rng.randf()
	return "voiture_citadine" if r < 0.5 else ("voiture_compacte" if r < 0.85 else "utilitaire")


## Les voitures-boîtes posées par quartier_reel.gd (groupe « voiture ») reçoivent un vrai modèle.
func _habiller_voitures() -> void:
	for v in get_tree().get_nodes_in_group("voiture"):
		var corps := v as Node3D
		var bas := -0.37
		var formes := corps.find_children("*", "CollisionShape3D", true, false)
		if formes.size() > 0 and (formes[0] as CollisionShape3D).shape is BoxShape3D:
			bas = -((formes[0] as CollisionShape3D).shape as BoxShape3D).size.y * 0.5
		var m := _vetir(corps, _type_voiture(), Vector3(0, bas - 0.25, 0))
		if m == null:
			return
		if corps.is_in_group("epave"):
			_bruler(m)
			m.position.y -= 0.12  # pneus fondus
			m.rotation.z = _rng.randf_range(-0.05, 0.05)
		else:
			_repeindre(m, "Carrosserie", TEINTES_VOITURE[_rng.randi() % TEINTES_VOITURE.size()])


# ───────────────────────── mobilier urbain ─────────────────────────
# Placé le long des voies du relevé, à des endroits plausibles (pas des positions relevées) :
# trottoirs et bordures, lampadaires, pins et platanes, conteneurs, bancs, abribus, potelets,
# panneaux, et l'équipement du stade. Tout est déterministe (même graine à chaque lancement).



func _mobilier(voies: Array, batiments: Array, zones: Array) -> void:
	for c in batiments:
		_emprises.append(_pts(c[4]))
	for c in zones:
		if c[1] in ["terrain", "parking", "skatepark", "bitume"]:
			_emprises.append(_pts(c[3]))
	var n_lampe := 0
	var n_arbre := 0
	for c in voies:
		var type: String = c[1]
		var pts := _pts(c[3])
		var demi: float = (Q.VOIES.get(type, Q.VOIES["s"]) as Array)[0] * 0.5
		if type == "b" or type == "r":
			_trottoirs(pts, demi)
			for e in _jalons(pts, 9.0, 2.0):
				var q: Vector2 = e[0]
				var dq: Vector2 = e[1]
				_bande(PackedVector2Array([q, q + dq * 4.0]), 0.0, 0.14, 0.085, Color(0.93, 0.92, 0.86))
		var pas := {"b": 26.0, "r": 32.0, "s": 40.0, "p": 22.0}.get(type, 40.0) as float
		var d := _rng.randf() * pas
		var cote := 1.0
		for e in _jalons(pts, pas, d):
			var p: Vector2 = e[0]
			var dir: Vector2 = e[1]
			var lat := Vector2(-dir.y, dir.x)
			cote = -cote
			if type == "p":
				# Chemins piétons : pins et quelques bancs.
				var q := p + lat * cote * (demi + 2.5)
				if _libre(q, 2.0):
					_pin(q)
					n_arbre += 1
				if _rng.randf() < 0.25:
					var qb := p - lat * cote * (demi + 1.0)
					if _libre(qb, 1.5):
						_banc(qb, dir)
				continue
			var bord := demi + (2.6 if type != "s" else 0.8)
			var ql := p + lat * cote * bord
			if _libre(ql, 0.6):
				_lampadaire(ql, -lat * cote)
				n_lampe += 1
			# Arbres d'alignement : platanes sur le boulevard, pins ailleurs.
			var qa := p - lat * cote * (bord + 1.5) + dir * pas * 0.5
			if _rng.randf() < (0.8 if type == "b" else 0.45) and _libre(qa, 2.5):
				if type == "b":
					_platane(qa)
				else:
					_pin(qa)
				n_arbre += 1
			# Conteneurs au bord des dessertes, devant les immeubles.
			if type == "s" and _rng.randf() < 0.55:
				var qc := p + lat * cote * (demi + 1.2) + dir * 6.0
				if _libre(qc, 1.6):
					for k in 1 + _rng.randi() % 3:
						_conteneur(qc + dir * 1.5 * k, dir)
			# Bancs et potelets sur les trottoirs.
			if type != "s" and _rng.randf() < 0.18:
				var qb := p - lat * cote * (demi + 1.6) + dir * 4.0
				if _libre(qb, 1.2):
					_banc(qb, dir)
			if type != "s" and _rng.randf() < 0.2:
				for k in 5:
					var qp := p + lat * cote * (demi + 0.6) + dir * (k * 1.6 - 3.2)
					if _libre(qp, 0.3):
						_potelet(qp)
		# Panneaux en début de rue.
		if type in ["r", "s"] and pts.size() > 1:
			var dir0 := (pts[1] - pts[0]).normalized()
			var q0 := pts[0] + dir0 * 6.0 + Vector2(-dir0.y, dir0.x) * (demi + 1.0)
			if _libre(q0, 0.5):
				_panneau(q0, dir0)
	_abribus_boulevard(voies)
	for c in zones:
		var poly := _pts(c[3])
		if c[1] == "terrain" and c[2].begins_with("Stade"):
			_stade(poly)
		elif c[1] == "bitume":
			_grillage(poly, 3.0, -1)
	print("Habillage : %d lampadaires, %d arbres" % [n_lampe, n_arbre])


# ───────────────────────── le pied des Cyprès ─────────────────────────
# Zone détaillée de la démo, là où le joueur apparaît. Emplacements SUPPOSÉS, à corriger avec Louma :
# l'entrée de la tour Cyprès B est placée au milieu de sa façade nord (côté parking et place des Piérons).

const CYPRES_B_ENTREE := Vector2(-5.0, -33.0)  # pied de la façade nord de la tour Cyprès B
const MARATHON := [Vector2(61, -87), Vector2(52, 82)]  # rue de Marathon le long des Cyprès


func _reserver(p: Vector2, r: float) -> void:
	_emprises.append(PackedVector2Array([p + Vector2(-r, -r), p + Vector2(r, -r), p + Vector2(r, r), p + Vector2(-r, r)]))


func _pied_des_cypres() -> void:
	# La tour n'existe qu'en 2014-2015 (démolie en 2016) : son entrée aussi.
	if Q.epoque == "avant":
		_entree_tour(CYPRES_B_ENTREE, PI)
	# Voitures garées le long de la rue de Marathon, côté Cyprès.
	var a: Vector2 = MARATHON[0]
	var b: Vector2 = MARATHON[1]
	var dir := (b - a).normalized()
	var lat := Vector2(-dir.y, dir.x)  # vers l'ouest
	var demi: float = (Q.VOIES["r"] as Array)[0] * 0.5
	var t := 6.0
	while t < 82.0:
		var p := a + dir * t + lat * (demi - 1.05)
		# Pas de voiture autour du point de départ du joueur (Q.DEPART), qui est dans la file de stationnement.
		if _rng.randf() < 0.75 and absf(p.y - Q.DEPART.y) > 18.0:
			_voiture_garee(p, dir)
		t += 5.2
	_aire_d_essai()
	# Scooters et conteneurs devant la tour, bancs et lampadaire sur la place.
	if Q.epoque == "avant":
		var e := CYPRES_B_ENTREE
		_scooter(e + Vector2(6.2, -2.4), 1.2)
		_scooter(e + Vector2(7.0, -2.0), 1.35)
		_scooter(e + Vector2(-7.4, -2.6), -0.3)
		for k in 4:
			_conteneur_pose(e + Vector2(-10.5 - k * 1.45, -1.2), Vector2(1, 0))
		_banc(e + Vector2(3.5, -8.0), Vector2(1, 0))
		_banc(e + Vector2(-3.5, -8.0), Vector2(1, 0))
		_lampadaire(e + Vector2(0.0, -10.5), Vector2(0, -1))
		for k in 6:
			_potelet(e + Vector2(-3.75 + k * 1.5, -6.2))
		for p in [e + Vector2(-14.0, -8.0), e + Vector2(13.0, -9.0), e + Vector2(-15.0, 12.0)]:
			_pin(p)


## Au point de départ : une voiture et un scooter garés, qu'on peut conduire (conduite.gd).
## Ils sont dans le groupe « vehicule », avec la métadonnée « type » = "voiture" ou "scooter".
func _aire_d_essai() -> void:
	var a: Vector2 = MARATHON[0]
	var b: Vector2 = MARATHON[1]
	var dir := (b - a).normalized()
	var est := -Vector2(-dir.y, dir.x)
	var demi: float = (Q.VOIES["r"] as Array)[0] * 0.5
	var t := (Q.DEPART.y - a.y) / dir.y
	var axe := a + dir * t
	# La voiture, garée côté est, juste devant le joueur.
	var pv := axe + est * (demi - 1.05) - dir * 6.0
	var voiture := _boite("Voiture", pv.x, pv.y, Vector3(1.7, 0.74, 4.0), Color(0.6, 0.6, 0.6), atan2(dir.x, dir.y) + PI, -0.25)
	voiture.add_to_group("voiture")
	voiture.add_to_group("vehicule")
	voiture.set_meta("type", "voiture")
	_reserver(pv, 2.4)
	# Le scooter, sur le trottoir est, à côté.
	var ps := axe + est * (demi + 1.2) - dir * 1.5
	var sc := _scooter(ps, atan2(dir.x, dir.y) + PI)  # dans l'axe de la rue, prêt à partir
	sc.add_to_group("vehicule")
	sc.set_meta("type", "scooter")


func _voiture_garee(p: Vector2, dir: Vector2) -> void:
	# Même gabarit que les voitures de quartier_reel.gd, pour être habillée de la même façon.
	var corps := _boite("Voiture", p.x, p.y, Vector3(1.7, 0.74, 4.0), Color(0.6, 0.6, 0.6), atan2(dir.x, dir.y), -0.25)
	corps.add_to_group("voiture")  # habillée ensuite comme les autres
	_reserver(p, 2.4)


func _conteneur_pose(p: Vector2, dir: Vector2) -> void:
	_conteneur(p, dir)
	_reserver(p, 1.0)


func _scooter(p: Vector2, angle: float) -> StaticBody3D:
	var corps := _boite("Scooter", p.x, p.y, Vector3(0.4, 1.0, 1.6), Color(0.3, 0.3, 0.3), angle)
	corps.add_to_group("mobilier")
	var m := _vetir(corps, "scooter", Vector3(0, -0.5, 0))
	if m:
		m.rotation.z = 0.12  # posé sur sa béquille
		var teintes := [Color(0.12, 0.12, 0.14), Color(0.85, 0.85, 0.82), Color(0.70, 0.12, 0.12), Color(0.15, 0.30, 0.65)]
		_repeindre(m, "Carrosserie", teintes[_rng.randi() % teintes.size()])
	_reserver(p, 1.0)
	return corps


## L'entrée de la tour : modèle Blender + collisions simples (hall plein, perron en pente douce,
## poteaux) et deux jardinières en béton qui se grindent.
func _entree_tour(pied: Vector2, angle: float) -> void:
	var base := Basis(Vector3.UP, angle)
	# Le vitrage est à 3,1 m devant la façade : le hall forme une avancée.
	var dehors := base * Vector3(0, 0, 1)
	var o := Vector3(pied.x, h(pied.x, pied.y), pied.y) + dehors * 3.1
	var racine := Node3D.new()
	racine.name = "EntreeCypresB"
	racine.transform = Transform3D(base, o)
	add_child(racine, true)
	var m := _modele("entree_tour")
	if m:
		racine.add_child(m)
	var corps := StaticBody3D.new()
	corps.name = "EntreeCollision"
	racine.add_child(corps)
	# En repère local : +Z = dehors, -Z = vers la tour (axes Blender -Y/+Y convertis en +Z/-Z).
	var formes := [
		[Vector3(4.7, 3.0, 3.2), Vector3(0, 1.8, -1.55)],    # hall
		[Vector3(0.28, 3.0, 0.28), Vector3(2.65, 1.66, 2.5)],  # poteaux
		[Vector3(0.28, 3.0, 0.28), Vector3(-2.65, 1.66, 2.5)],
		[Vector3(5.8, 0.3, 3.0), Vector3(0, 3.15, 1.3)],     # auvent (on peut y monter depuis le hall en grimpant)
	]
	for f in formes:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = f[0]
		cs.shape = sh
		cs.position = f[1]
		corps.add_child(cs)
	# Perron : une pente douce plutôt que des marches (on y passe à pied comme en skate).
	var pente := CollisionShape3D.new()
	var cp := ConvexPolygonShape3D.new()
	var w := 2.7
	cp.points = PackedVector3Array([Vector3(-w, 0, 2.3), Vector3(w, 0, 2.3), Vector3(-w, 0.32, 1.2), Vector3(w, 0.32, 1.2),
		Vector3(-w, 0.32, 0.0), Vector3(w, 0.32, 0.0), Vector3(-w, -0.2, 0.0), Vector3(w, -0.2, 0.0), Vector3(-w, -0.2, 2.3), Vector3(w, -0.2, 2.3)])
	pente.shape = cp
	corps.add_child(pente)
	# Jardinières = ledges de 0,5 m, grindables.
	for s in [-1.0, 1.0]:
		var r := Rail.new()
		r.length = 3.0
		r.height = 0.5
		r.thickness = 1.2
		r.color = MOB_BETON
		r.position = Vector3(s * 4.7 - 1.5, 0.0, 1.6)
		r.name = "Jardiniere"
		racine.add_child(r)
		r.add_to_group("muret")
		if m:
			for mi in r.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).visible = false
	# Petit parcours : sol → armoire électrique (1,6 m) → auvent (3,3 m) → toit du hall.
	# Chaque marche reste sous la portée de la grimpe actuelle (2,3 m).
	var armoire := StaticBody3D.new()
	armoire.name = "ArmoireElectrique"
	armoire.add_to_group("mobilier")
	armoire.add_to_group("prise")  # repère pour la grimpe (n°1)
	var cs_a := CollisionShape3D.new()
	var sh_a := BoxShape3D.new()
	sh_a.size = Vector3(1.0, 1.6, 0.55)
	cs_a.shape = sh_a
	armoire.add_child(cs_a)
	_maillage("Caisson", armoire, _bm(1.0, 1.6, 0.55), Color(0.62, 0.66, 0.60), Vector3.ZERO)
	_maillage("Toit", armoire, _bm(1.1, 0.06, 0.65), Color(0.45, 0.48, 0.44), Vector3(0, 0.83, 0))
	_maillage("Porte", armoire, _bm(0.8, 1.3, 0.02), Color(0.52, 0.56, 0.50), Vector3(0, -0.05, 0.28))
	armoire.position = Vector3(-1.6, 0.8, 3.3)
	racine.add_child(armoire)
	_reserver(Vector2(o.x, o.z) + Vector2(dehors.x, dehors.z) * 1.0, 6.5)
	_reserver(pied, 4.0)


# ───────────────────────── rue de Marathon (Street View 2013-2014) ─────────────────────────

## Les petites barres R+4 : rez-de-chaussée rouge brique, colonnes de panneaux rouges ;
## devant, des murets et des jardinières peints du même rouge (tagués), avec quelques marches.
const ROUGE_MURET := Color(0.66, 0.29, 0.25)

func _rue_de_marathon(batiments: Array) -> void:
	for b in get_tree().get_nodes_in_group("batiment"):
		if b.get_meta("style", "") != "marathon_rouge":
			continue
		for mi in b.get_children():
			if mi is MeshInstance3D and mi.material_override is ShaderMaterial:
				var m: ShaderMaterial = mi.material_override
				m.set_shader_parameter("soubassement_on", 1.0)
				m.set_shader_parameter("panneaux_part", 0.45)
	var n := 0
	for c in batiments:
		if c[3] != "marathon_rouge":
			continue
		var poly := _pts(c[4])
		if poly.size() > 2 and poly[0].distance_to(poly[poly.size() - 1]) < 0.01:
			poly.remove_at(poly.size() - 1)
		for k in poly.size():
			var a2 := poly[k]
			var b2 := poly[(k + 1) % poly.size()]
			var long := a2.distance_to(b2)
			if long < 18.0:
				continue
			var d := (b2 - a2) / long
			var nrm := _normale_dehors(a2, b2, poly)
			var angle := atan2(-d.y, d.x)
			var t := 2.0
			var i := 0
			while t < long - 6.0:
				var seg := 5.0 + _rng.randf() * 3.0
				var q := a2 + d * (t + seg * 0.5) + nrm * 3.2
				if _libre(q, 1.0):
					if i % 3 == 2:
						# trois marches qui montent vers l'entrée, entre deux murets
						for m2 in 3:
							var qm := q + nrm * (0.9 - m2 * 0.35)
							_boite("Marche_marathon", qm.x, qm.y, Vector3(2.4, 0.18 * (m2 + 1), 0.35), ROUGE_MURET.lightened(0.08), angle)
					elif i % 4 == 1:
						var bac := _boite("Jardiniere_marathon", q.x, q.y, Vector3(seg, 0.7, 1.4), ROUGE_MURET, angle)
						bac.add_to_group("muret")
					else:
						var mu := _boite("Muret_marathon", q.x, q.y, Vector3(seg, 0.95, 0.3), ROUGE_MURET, angle)
						mu.add_to_group("muret")
					n += 1
				t += seg + 2.2
				i += 1
	print("Rue de Marathon : %d murets, jardinières et marches rouges" % n)


## L'impasse « PAIX » et le grand escalier qui monte au plateau des Lauriers (Street View juin 2014,
## corrigé par Louma : l'escalier est de face, et une barre R+4 est perpendiculaire au mur, à gauche ;
## 31 rue de Marathon). En descendant la rue de Marathon, l'impasse part vers le sud et monte doucement ;
## elle bute sur le grand mur du plateau :
##  - à gauche, la barre « Immeuble impasse » (relevé) puis le grand escalier de face, entre deux murets ;
##  - un pilier blanc, puis le passage sombre ;
##  - le mur peint brun-rouge avec le grand rond jaune « PAIX » ;
##  - à droite, le mur de soutènement en béton qui monte avec la rue, grillage vert dessus, fresque
##    colorée au bout, lampadaires boules à mât orange sur le trottoir ;
##  - au-dessus, les pins du plateau, et derrière, la tour des Cyprès B.
const PAIX_AXE := -10.0     # x du milieu de l'impasse
const PAIX_MUR := 13.0      # z de la face du grand mur
const PAIX_BAS := 93.0      # z du débouché sur la rue de Marathon
const PIERRE := preload("res://shaders/pierre.gdshader")

func _mur_paix() -> void:
	var yr := sol(PAIX_AXE, PAIX_MUR + 1.0)
	var yt := maxf(yr + 4.6, h(PAIX_AXE, 2.0) + 0.3)       # haut du mur / niveau du plateau devant
	var hm := yt - yr
	var zf := PAIX_MUR                                       # face du mur (côté impasse = +z)
	var m_pierre := ShaderMaterial.new()
	m_pierre.shader = PIERRE
	# — la chaussée de l'impasse et ses trottoirs (bandes qui suivent la pente) —
	_bande_sol(Vector2(PAIX_AXE, zf + 0.5), Vector2(PAIX_AXE, PAIX_BAS), 6.5, 0.05, Color(0.40, 0.40, 0.43))
	_bande_sol(Vector2(PAIX_AXE - 4.15, zf + 0.5), Vector2(PAIX_AXE - 4.15, PAIX_BAS), 1.8, 0.15, Color(0.74, 0.72, 0.68))
	_bande_sol(Vector2(PAIX_AXE + 4.15, zf + 0.5), Vector2(PAIX_AXE + 4.15, PAIX_BAS), 1.8, 0.15, Color(0.74, 0.72, 0.68))
	# Fond de l'impasse, de gauche à droite (Street View juin 2014, 31 rue de Marathon) :
	#   pignon de la barre beige | grand escalier de pierre, de face, creusé DANS le plateau
	#   | pilier beige | passage sombre | mur brun-rouge « PAIX » | angle peint du soutènement de droite.
	var x_esc_g := -17.0      # bord gauche de l'escalier (= pignon de la barre)
	var x_esc_d := -13.0      # bord droit (pilier)
	var x_pil := -12.75
	var x_pas_d := -11.0      # fin du passage sombre
	var x_mur_d := PAIX_AXE + 4.9
	var n := int(ceil(hm / 0.16))
	var g := hm / n
	var giron := 0.34
	var prof := n * giron     # l'escalier recule de prof mètres dans le plateau
	var z_haut := zf - prof
	# — le plateau en trois blocs de pierre, qui laissent la tranchée de l'escalier —
	var p1 := _boite_y("Plateau_gauche", Vector3((x_esc_g - 30.0) * 0.5, yr - 0.5, zf - 8.0), Vector3(x_esc_g + 30.0 + 0.02, hm + 0.5, 16.0), m_pierre)
	p1.add_to_group("mur")
	var p2 := _boite_y("Plateau_droite", Vector3((x_esc_d + x_mur_d + 0.6) * 0.5, yr - 0.5, zf - 8.0), Vector3(x_mur_d + 0.6 - x_esc_d, hm + 0.5, 16.0), m_pierre)
	p2.add_to_group("mur")
	var p3 := _boite_y("Plateau_fond", Vector3((x_esc_g + x_esc_d) * 0.5, yr - 0.5, z_haut - (16.0 - prof) * 0.5), Vector3(x_esc_d - x_esc_g, hm + 0.5, 16.0 - prof + 0.02), m_pierre)
	p3.add_to_group("mur")
	# marches pour redescendre côté Cyprès si le plateau est plus bas derrière
	var yb := h(PAIX_AXE, -4.0)
	if yt - yb > 0.4:
		var n_m := int(ceil((yt - yb) / 0.3))
		for i in n_m:
			var hh := yt - (i + 1) * (yt - yb) / n_m
			_boite_y("Marche_plateau", Vector3(-12.0, yb - 0.3, zf - 16.0 - 0.2 - i * 0.4), Vector3(4.0, hh - yb + 0.3, 0.4), m_pierre)
	# — A : le grand escalier, de face, la première marche au ras de la rue —
	var le := x_esc_d - x_esc_g
	var xe := (x_esc_g + x_esc_d) * 0.5
	for i in n:
		var hh := (i + 1) * g
		var mi := MeshInstance3D.new()
		mi.mesh = _bm(le, hh, giron + 0.02)
		mi.material_override = m_pierre
		mi.position = Vector3(xe, yr + hh * 0.5, zf - (i + 0.5) * giron)
		mi.name = "Marche_grand_escalier"
		add_child(mi)
	# rampe de collision sous les marches
	var lg := sqrt(prof * prof + hm * hm)
	var pente := atan2(hm, prof)
	var rampe := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(le, 0.2, lg)
	cs.shape = sh
	rampe.add_child(cs)
	rampe.transform = Transform3D(Basis(Vector3.RIGHT, pente), Vector3(xe, yr + hm * 0.5 - 0.1, zf - prof * 0.5))
	rampe.name = "Rampe_grand_escalier"
	add_child(rampe)
	# une seule main courante fine, côté gauche, contre le pignon
	var mc := MeshInstance3D.new()
	mc.mesh = _bm(0.05, 0.05, lg)
	mc.material_override = _mat(Color(0.62, 0.62, 0.60))
	mc.transform = Transform3D(Basis(Vector3.RIGHT, pente), Vector3(x_esc_g + 0.25, yr + hm * 0.5 + 0.9, zf - prof * 0.5))
	add_child(mc)
	for k in 4:
		var t := (k + 0.5) / 4.0
		var po := MeshInstance3D.new()
		po.mesh = _bm(0.04, 0.9, 0.04)
		po.material_override = _mat(Color(0.62, 0.62, 0.60))
		po.position = Vector3(x_esc_g + 0.25, yr + hm * t + 0.45, zf - prof * t)
		add_child(po)
	# — B : le pilier beige, plus haut que le mur —
	_boite_y("Pilier_PAIX", Vector3(x_pil, yr, zf + 0.25), Vector3(0.5, hm + 1.8, 0.5), _mat(Color(0.86, 0.81, 0.70)))
	# — C : le passage sombre, sur toute la hauteur du mur —
	_boite_y("Passage_sombre", Vector3((x_pil + 0.25 + x_pas_d) * 0.5, yr, zf + 0.04), Vector3(x_pas_d - x_pil - 0.25, hm - 0.1, 0.1), _mat(Color(0.09, 0.08, 0.09)))
	# — D : le mur peint brun-rouge, le rond « PAIX » en bas au milieu —
	var xm := (x_pas_d + x_mur_d) * 0.5
	var d_mur := _boite_y("Mur_PAIX", Vector3(xm, yr, zf + 0.12), Vector3(x_mur_d - x_pas_d, hm, 0.3), _mat(Color(0.54, 0.32, 0.26)))
	d_mur.add_to_group("mur")
	_fresque("paix", Vector3(xm - 0.6, yr + 1.15, zf + 0.27), Vector3(1, 0, 0), Vector3(0, 0, 1), 2.3)
	# — E : le soutènement en béton de droite, qui monte avec la rue, grillage vert, fresque au bout —
	var x_d := PAIX_AXE + 5.2
	var pas := 6.0
	var z := zf + 0.3
	while z < Z_GYMNASE - 1.0:
		var ys := sol(x_d, z + pas * 0.5)
		var haut_mur := lerpf(hm, 0.8, clampf((z - zf) / 60.0, 0.0, 1.0))
		var seg := _boite_y("Soutenement_beton", Vector3(x_d + 0.3, ys - 0.2, z + pas * 0.5), Vector3(0.6, haut_mur + 0.2, pas + 0.02), _mat(Color(0.78, 0.74, 0.68)))
		seg.add_to_group("mur")
		# grillage vert : poteaux, lisses et barreaudage serré (lisible de loin comme une grille)
		var vert := Color(0.18, 0.40, 0.27)
		var y_g := ys + haut_mur
		for k in 2:
			var po := MeshInstance3D.new()
			po.mesh = _bm(0.07, 1.9, 0.07)
			po.material_override = _mat(vert)
			po.position = Vector3(x_d + 0.1, y_g + 0.95, z + k * pas * 0.5)
			add_child(po)
		for yy in [0.1, 1.85]:
			var li := MeshInstance3D.new()
			li.mesh = _bm(0.05, 0.05, pas)
			li.material_override = _mat(vert)
			li.position = Vector3(x_d + 0.1, y_g + yy, z + pas * 0.5)
			add_child(li)
		var b_n := int(pas / 0.25)
		for k in b_n:
			var ba := MeshInstance3D.new()
			ba.mesh = _bm(0.02, 1.75, 0.02)
			ba.material_override = _mat(vert.lightened(0.05))
			ba.position = Vector3(x_d + 0.1, y_g + 0.97, z + (k + 0.5) * 0.25)
			ba.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ba)
		z += pas
	_fresque("fresque_impasse", Vector3(x_d - 0.02, yr + 1.9, zf + 7.0), Vector3(0, 0, 1), Vector3(-1, 0, 0), 11.0)
	# lampadaires boules à mât orangé, sur le trottoir de droite
	for zl in [zf + 6.0, zf + 24.0, zf + 40.0]:
		_lampadaire_boule(Vector2(x_d - 0.7, zl))
	# — gauche : potelets blancs et muret rouge bas, comme au pied des barres —
	var zp := zf + 22.0
	while zp < PAIX_BAS - 6.0:
		_potelet_blanc(Vector2(PAIX_AXE - 5.0, zp))
		zp += 3.0
	# — la barre de gauche : grilles rouges au pied, barrière blanche au bord du trottoir —
	var zr := 16.0
	while zr < 52.0:
		var gr := _boite("Grille_rouge", -16.6, zr, Vector3(0.08, 1.1, 2.2), Color(0.66, 0.26, 0.22))
		gr.add_to_group("mur")
		zr += 2.6
	for zb in [zf + 34.0, zf + 37.0]:
		_potelet_blanc(Vector2(PAIX_AXE - 5.1, zb))
	var lisse := _boite("Barriere_blanche", PAIX_AXE - 5.1, zf + 35.5, Vector3(0.06, 0.06, 3.0), Color(0.92, 0.91, 0.88))
	lisse.position.y += 0.5
	# — voitures garées au fond : une bleue devant le passage, une sombre contre le mur de droite —
	_voiture_impasse(Vector2(-11.4, zf + 3.0), PI, Color(0.12, 0.30, 0.66))
	_voiture_impasse(Vector2(-6.4, zf + 2.8), PI + 0.08, Color(0.12, 0.13, 0.15))
	# — pins sur le plateau, derrière le mur, et un grand arbre sombre au-dessus de l'escalier —
	for q in [Vector2(-19.5, zf - 4.0), Vector2(-15.0, z_haut - 2.5), Vector2(-9.5, zf - 3.5), Vector2(-6.0, zf - 7.0)]:
		_pin(q)
	# vieux mur sali de gauche à droite : quelques coulures au pied
	_reserver(Vector2(-11.4, zf + 3.0), 2.4)
	_gymnase()
	_debouche_impasse()


# ───────────── le débouché de l'impasse sur la rue de Marathon (image cible de Louma, Street View juil. 2013) ─────────────
# C'est peut-être là que le jeu commence : on y met tout le réel qu'on peut — les vrais tags du quartier,
# la carcasse brûlée, les pneus, les parpaings, les herbes, le mur du gymnase à fenêtres grillagées.

const Z_GYMNASE := 56.0
const Z_GYMNASE_FIN := 91.0
const X_GYMNASE := -4.6        # face ouest du gymnase, sur le trottoir de droite

## Le gymnase à droite de l'impasse : socle gris, bandeau d'enduit clair (où l'on tague), un ruban de fenêtres
## à barreaux blancs, puis le grand mur en blocs de pierre jusqu'au toit à bord arrondi.
func _gymnase() -> void:
	var x0 := X_GYMNASE
	var x1 := 7.0
	var z0 := Z_GYMNASE
	var z1 := Z_GYMNASE_FIN
	var ybas := minf(sol(x0, z0), sol(x0, z1)) - 0.5
	var yhaut := maxf(sol(x0, z0), sol(x0, z1)) + 8.0
	var m_bloc := ShaderMaterial.new()
	m_bloc.shader = PIERRE
	m_bloc.set_shader_parameter("pierre_a", Color(0.84, 0.74, 0.58))
	m_bloc.set_shader_parameter("pierre_b", Color(0.80, 0.70, 0.55))
	m_bloc.set_shader_parameter("pierre_c", Color(0.86, 0.78, 0.64))
	m_bloc.set_shader_parameter("joint", Color(0.66, 0.58, 0.48))
	m_bloc.set_shader_parameter("assise", 0.5)
	var corps := _boite_y("Gymnase", Vector3((x0 + x1) * 0.5, ybas, (z0 + z1) * 0.5), Vector3(x1 - x0, yhaut - ybas, z1 - z0), m_bloc)
	corps.add_to_group("mur")
	_emprises.append(PackedVector2Array([Vector2(x0 - 0.5, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0 - 0.5, z1)]))
	# bord de toit arrondi (un demi-cylindre couché le long de la façade)
	var bord := CylinderMesh.new()
	bord.top_radius = 0.45
	bord.bottom_radius = 0.45
	bord.height = z1 - z0
	bord.radial_segments = 10
	_maillage("Gymnase_bord_toit", self, bord, Color(0.80, 0.70, 0.55), Vector3(x0 + 0.3, yhaut - 0.1, (z0 + z1) * 0.5), Basis(Vector3.RIGHT, PI * 0.5))
	# bandes de la façade ouest, qui suivent la pente de la rue
	var bars := SurfaceTool.new()
	bars.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cube := BoxMesh.new()
	var pas := 1.5
	var z := z0
	while z < z1 - 0.01:
		var zm := minf(z + pas, z1)
		var y0 := sol(x0 - 0.3, (z + zm) * 0.5)
		var l := zm - z
		var c := (z + zm) * 0.5
		_bloc_mince(Vector3(x0 - 0.04, y0 - 0.3, c), Vector3(0.1, 0.95, l + 0.01), Color(0.56, 0.55, 0.53))          # socle crépi gris
		_bloc_mince(Vector3(x0 - 0.03, y0 + 0.65, c), Vector3(0.08, 1.95, l + 0.01), Color(0.88, 0.86, 0.80))        # enduit clair
		_bloc_mince(Vector3(x0 - 0.05, y0 + 2.6, c), Vector3(0.14, 0.12, l + 0.01), Color(0.80, 0.78, 0.72))         # appui
		_bloc_mince(Vector3(x0 - 0.02, y0 + 2.72, c), Vector3(0.06, 1.25, l + 0.01), Color(0.16, 0.20, 0.30))        # vitrage sombre
		_bloc_mince(Vector3(x0 - 0.06, y0 + 3.97, c), Vector3(0.16, 0.14, l + 0.01), Color(0.80, 0.78, 0.72))        # linteau
		# barreaux blancs, montant tous les 1,5 m
		var nb := int(l / 0.16)
		for k in nb + 1:
			var zk := z + k * l / maxf(nb, 1)
			var ep := 0.09 if k == 0 else 0.035
			bars.append_from(cube, 0, Transform3D(Basis.from_scale(Vector3(0.04, 1.25, ep)), Vector3(x0 - 0.12, y0 + 3.35, zk)))
		for yy in [2.78, 3.35, 3.9]:
			bars.append_from(cube, 0, Transform3D(Basis.from_scale(Vector3(0.04, 0.035, l)), Vector3(x0 - 0.12, y0 + yy, c)))
		z = zm
	var mb := MeshInstance3D.new()
	mb.mesh = bars.commit()
	mb.material_override = _mat(Color(0.93, 0.93, 0.90))
	mb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mb.name = "Gymnase_barreaux"
	add_child(mb)
	# coffret électrique et descente d'eau
	var ye := sol(x0 - 0.3, z0 + 22.0)
	_boite_y("Coffret_EDF", Vector3(x0 - 0.25, ye, z0 + 22.0), Vector3(0.4, 1.25, 0.75), _mat(Color(0.86, 0.84, 0.76)))
	_bloc_mince(Vector3(x0 - 0.1, ye - 0.2, z1 - 0.4), Vector3(0.14, yhaut - ye, 0.14), Color(0.62, 0.62, 0.62))
	# « BOUFTOU » au marqueur noir sur l'enduit clair (le vrai tag, juillet 2013)
	_tag_reel("vrai_bouftou", Vector3(x0 - 0.1, sol(x0, z0 + 15.0) + 1.65, z0 + 15.0), Vector3(0, 0, -1), Vector3(-1, 0, 0), 1.4, Color(0.10, 0.09, 0.10))
	# affiches arrachées au coin
	_tag_reel("affiche_02", Vector3(x0 - 0.1, sol(x0, z1 - 1.5) + 1.7, z1 - 1.5), Vector3(0, 0, -1), Vector3(-1, 0, 0), 0.8, Color.WHITE)


## Une plaque fine posée contre un mur, sans collision (bandeaux, appuis, vitrages).
func _bloc_mince(centre_bas: Vector3, taille: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _bm(taille.x, taille.y, taille.z)
	mi.material_override = _mat(c)
	mi.position = centre_bas + Vector3.UP * taille.y * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Un vrai tag du quartier (photo Street View 2013, détouré) posé sur un mur : centre, sens de lecture, normale.
func _tag_reel(nom: String, centre: Vector3, le_long: Vector3, dehors: Vector3, largeur: float, teinte: Color) -> void:
	var tex := _texture(nom)
	if tex == null:
		return
	MARQUE.poser(self, tex, centre + dehors * 0.03, le_long, dehors, largeur, teinte, 70.0, 1, "Tag_" + nom)


func _debouche_impasse() -> void:
	# — POUTOULAND, sur le pignon sud de la barre du débouché : un panneau d'enduit repeint plus clair,
	#   au-dessus du soubassement rouge, et le tag au marqueur noir —
	var zg := 89.0
	var yg := sol(-22.7, zg + 0.3)
	_bloc_mince(Vector3(-22.4, yg + 1.05, zg + 0.04), Vector3(6.2, 1.7, 0.08), Color(0.90, 0.86, 0.76))
	_tag_reel("vrai_poutouland", Vector3(-22.2, yg + 1.85, zg + 0.09), Vector3(1, 0, 0), Vector3(0, 0, 1), 4.6, Color(0.08, 0.08, 0.09))
	# — le pignon est de l'immeuble de la rue de Marathon : le mur des blazes (« Anss » Kintchou, D.Bedo, HMD,
	#   Kiké, le Nounz, MAB MAD, IZI…) et MALBO.K sur le muret rouge devant —
	var xp := -30.0
	var zp := 69.0
	var yp := sol(xp + 0.4, zp)
	_tag_reel("vrai_mur_kintchou", Vector3(xp + 0.02, yp + 1.65, zp), Vector3(0, 0, -1), Vector3(1, 0, 0), 5.2, Color(0.10, 0.09, 0.11))
	var mu := _boite("Muret_malbo", xp + 2.2, zp + 0.5, Vector3(0.35, 0.95, 6.0), ROUGE_MURET)
	mu.add_to_group("muret")
	_tag_reel("vrai_malbok", Vector3(xp + 2.4, yp + 0.5, zp + 0.8), Vector3(0, 0, -1), Vector3(1, 0, 0), 1.6, Color(0.12, 0.08, 0.08))
	_reserver(Vector2(xp + 2.2, zp + 0.5), 3.2)
	# — la carcasse brûlée contre le gymnase, ses pneus, des parpaings et des herbes —
	_epave(Vector2(X_GYMNASE - 1.35, 80.0), PI + 0.06)
	for k in 3:
		var pn := _pneu(Vector2(X_GYMNASE - 0.9 + (k % 2) * 0.15, 85.8 + (k / 2) * 0.1))
		pn.position.y += k * 0.24
	for q in [Vector2(-6.2, 86.9), Vector2(-5.6, 87.6), Vector2(-7.0, 75.2), Vector2(-12.9, 84.0), Vector2(-5.4, 70.0)]:
		var pa := _boite("Parpaing", q.x, q.y, Vector3(0.5, 0.2, 0.2), Color(0.70, 0.69, 0.66), _rng.randf() * TAU)
		pa.add_to_group("mobilier")
	for k in 26:
		var zz := _rng.randf_range(58.0, 92.0)
		var xx: float = [X_GYMNASE - 0.25, -16.7, -14.6][k % 3]
		_herbe(Vector2(xx + _rng.randf_range(-0.15, 0.15), zz))
	# papiers et détritus au pied du mur
	for k in 10:
		var q := Vector2(X_GYMNASE - _rng.randf_range(0.2, 1.4), _rng.randf_range(72.0, 90.0))
		_bloc_mince(Vector3(q.x, sol(q.x, q.y) + 0.005, q.y), Vector3(_rng.randf_range(0.15, 0.35), 0.01, _rng.randf_range(0.1, 0.25)), [Color(0.92, 0.91, 0.88), Color(0.80, 0.30, 0.25), Color(0.30, 0.45, 0.75)][k % 3])


## Une voiture brûlée, rouillée orange et noire, sans roues, posée sur ses jantes.
func _epave(p: Vector2, angle: float) -> void:
	var corps := _boite("Epave", p.x, p.y, Vector3(1.7, 1.2, 3.9), Color(0.6, 0.6, 0.6), angle, 0.18)
	corps.add_to_group("mobilier")
	var m := _vetir(corps, "voiture_citadine", Vector3(0, -0.78, 0))
	if m == null:
		return
	var teintes := [Color(0.62, 0.32, 0.16), Color(0.46, 0.22, 0.12), Color(0.14, 0.11, 0.10), Color(0.72, 0.42, 0.20)]
	var i := 0
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			var b := StandardMaterial3D.new()
			b.albedo_color = teintes[i % teintes.size()]
			mi.set_surface_override_material(k, b)
			i += 1


func _pneu(p: Vector2) -> Node3D:
	var t := TorusMesh.new()
	t.inner_radius = 0.2
	t.outer_radius = 0.34
	var b := _boite("Pneu", p.x, p.y, Vector3(0.66, 0.24, 0.66), Color(0.1, 0.1, 0.1))
	for e in b.get_children():
		if e is MeshInstance3D:
			(e as MeshInstance3D).mesh = t
	b.add_to_group("mobilier")
	return b


## Une touffe d'herbe sèche entre le trottoir et le mur.
func _herbe(p: Vector2) -> void:
	var y := sol(p.x, p.y)
	for k in 4:
		var mi := MeshInstance3D.new()
		mi.mesh = _bm(0.04, _rng.randf_range(0.25, 0.6), 0.04)
		mi.material_override = _mat([Color(0.52, 0.58, 0.28), Color(0.66, 0.62, 0.34), Color(0.42, 0.50, 0.26)][k % 3])
		var hh: float = (mi.mesh as BoxMesh).size.y
		mi.transform = Transform3D(Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.15, 0.45)), Vector3(p.x + _rng.randf_range(-0.12, 0.12), y + hh * 0.5, p.y + _rng.randf_range(-0.12, 0.12)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _voiture_impasse(p: Vector2, angle: float, c: Color) -> void:
	var corps := _boite("Voiture_impasse", p.x, p.y, Vector3(1.7, 0.74, 4.0), Color(0.6, 0.6, 0.6), angle, -0.25)
	var m := _vetir(corps, "voiture_citadine", Vector3(0, -0.62, 0))
	if m:
		_repeindre(m, "Carrosserie", c)


## Une boîte posée à une altitude donnée (y = bas de la boîte), avec collision.
func _boite_y(nom: String, bas: Vector3, taille: Vector3, m: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _bm(taille.x, taille.y, taille.z)
	mi.material_override = m
	body.add_child(mi)
	body.name = nom
	body.position = bas + Vector3.UP * taille.y * 0.5
	add_child(body, true)
	return body


## Une bande au sol qui suit le terrain (chaussée, trottoir), de a à b.
func _bande_sol(a: Vector2, b: Vector2, largeur: float, dessus: float, c: Color) -> void:
	var d := (b - a).normalized()
	var nrm := Vector2(-d.y, d.x)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var long := a.distance_to(b)
	var k := 0.0
	while k <= long + 0.01:
		var p := a + d * k
		for s2 in [-1.0, 1.0]:
			var q: Vector2 = p + nrm * largeur * 0.5 * s2
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(q.x, h(q.x, q.y) + dessus, q.y))
		k += 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(c)
	mi.name = "Bande_sol"
	add_child(mi)


## Une fresque peinte (décalque) sur un mur : centre, direction le long du mur, normale vers l'extérieur.
func _fresque(nom: String, centre: Vector3, le_long: Vector3, dehors: Vector3, largeur: float) -> void:
	var tex := _texture(nom)
	if tex == null:
		return
	MARQUE.poser(self, tex, centre + dehors * 0.05, le_long, dehors, largeur, Color.WHITE, 110.0, 0, "Fresque_" + nom)


func _lampadaire_boule(p: Vector2) -> void:
	var mat := _boite("Lampadaire_boule", p.x, p.y, Vector3(0.14, 4.2, 0.14), Color(0.78, 0.48, 0.34))
	mat.add_to_group("mobilier")
	var boule := SphereMesh.new()
	boule.radius = 0.32
	boule.height = 0.64
	_maillage("Boule", mat, boule, Color(0.96, 0.95, 0.92), Vector3(0, 2.4, 0))
	_boite("Socle_lampadaire", p.x, p.y, Vector3(0.6, 0.5, 0.6), Color(0.80, 0.78, 0.74))


func _potelet_blanc(p: Vector2) -> void:
	var b := _boite("Potelet_blanc", p.x, p.y, Vector3(0.12, 1.0, 0.12), Color(0.92, 0.91, 0.88))
	b.add_to_group("mobilier")


## L'horizon : les quartiers nord tout autour, en silhouettes simples (pavillons à toits de tuiles,
## petits immeubles, quelques tours), pour que la cité ne flotte plus au milieu d'une plaine vide.
## Rien n'y est jouable : pas de collision, pas d'ombre, un seul objet par type.
func _horizon() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	var centre := Vector2(40.0, 20.0)
	var murs := []
	var toits := []
	var teintes_mur := [Color(0.93, 0.89, 0.80), Color(0.90, 0.84, 0.72), Color(0.95, 0.93, 0.88), Color(0.88, 0.78, 0.62), Color(0.92, 0.80, 0.70)]
	var tuile := Color(0.78, 0.45, 0.32)
	for i in 2600:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(430.0 * 430.0, 1300.0 * 1300.0))
		var p := centre + Vector2(cos(a), sin(a)) * r
		var y := h(p.x, p.y)
		var rot := Basis(Vector3.UP, a + rng.randf_range(-0.3, 0.3))
		var t := rng.randf()
		var c: Color = teintes_mur[rng.randi() % teintes_mur.size()]
		if t < 0.8:
			# pavillon : un cube et un toit de tuiles
			var taille := Vector3(rng.randf_range(7, 11), rng.randf_range(4.5, 7.0), rng.randf_range(6, 9))
			murs.append([Transform3D(rot * Basis.from_scale(taille), Vector3(p.x, y + taille.y * 0.5 - 0.3, p.y)), c])
			toits.append([Transform3D(rot * Basis.from_scale(Vector3(taille.x + 0.6, 0.9, taille.z + 0.6)), Vector3(p.x, y + taille.y, p.y)), tuile.darkened(rng.randf() * 0.15)])
		elif t < 0.97:
			var taille := Vector3(rng.randf_range(18, 40), rng.randf_range(10, 16), rng.randf_range(10, 13))
			murs.append([Transform3D(rot * Basis.from_scale(taille), Vector3(p.x, y + taille.y * 0.5 - 0.3, p.y)), c])
		else:
			var taille := Vector3(rng.randf_range(14, 20), rng.randf_range(30, 50), rng.randf_range(14, 20))
			murs.append([Transform3D(rot * Basis.from_scale(taille), Vector3(p.x, y + taille.y * 0.5 - 0.3, p.y)), c])
	for lot in [["Horizon_murs", murs], ["Horizon_toits", toits]]:
		var liste: Array = lot[1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var cube := BoxMesh.new()
		mm.mesh = cube
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i][0])
			mm.set_instance_color(i, liste[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/bd_toon.gdshader")
		m.set_shader_parameter("couleur_instance", true)
		m.set_shader_parameter("grain", 0.3)
		mi.material_override = m
		mi.name = lot[0]
		add_child(mi)
	print("Horizon : %d silhouettes" % murs.size())


# ───────────────────────── façades en relief et toits ─────────────────────────

func _facades(batiments: Array) -> void:
	var f := Node3D.new()
	f.set_script(load("res://scripts/habillage_facades.gd"))
	f.name = "Facades"
	f.set("habillage", self)
	add_child(f)
	f.call("construire", batiments)
	var g := Node3D.new()
	g.set_script(load("res://scripts/habillage_toits.gd"))
	g.name = "AccesToits"
	g.set("habillage", self)
	add_child(g)
	g.call("construire", batiments, Q.epoque)
	var pl := Node3D.new()
	pl.set_script(load("res://scripts/habillage_place.gd"))
	pl.name = "PlaceDuJardin"
	pl.set("habillage", self)
	add_child(pl)
	pl.call("construire", batiments)


# ───────────────────────── vieux graffitis, affiches, effacements ─────────────────────────
# Le quartier a déjà une histoire : au pied des murs, des tags et des flops d'autres graffeurs
# (inventés, illisibles), des affiches arrachées, et des rectangles de peinture grise passés par-dessus.
# Ce sont des décalques (Decal) : ils épousent le mur et prennent la lumière BD.
# Distincts des graffitis du joueur (graffiti.gd, n°1).

const GRAFF := "res://assets/decor/graff/%s.png"
const ENCRES_TAG := [Color(0.10, 0.10, 0.12), Color(0.10, 0.10, 0.12), Color(0.72, 0.12, 0.15), Color(0.13, 0.26, 0.62),
	Color(0.80, 0.81, 0.83), Color(0.20, 0.42, 0.24), Color(0.95, 0.95, 0.92), Color(0.55, 0.18, 0.55)]


func _texture(nom: String) -> Texture2D:
	if not _textures.has(nom):
		var chemin: String = GRAFF % nom
		_textures[nom] = (load(chemin) as Texture2D) if ResourceLoader.exists(chemin) else null
	return _textures[nom]


func _vieux_murs(batiments: Array) -> void:
	if not ResourceLoader.exists(GRAFF % "tag_00"):
		return
	var n := 0
	for c in batiments:
		var style: String = c[3]
		var poly := _pts(c[4])
		if poly[0].distance_to(poly[poly.size() - 1]) < 0.01:
			poly.remove_at(poly.size() - 1)
		var densite := 0.45 if style in ["lycee", "barre_lauriers", "barre_renovee", "cypres_tour", "cypres_barre", "genets_blanc", "tour_ocre", "barre_rose", "clair"] else 0.15
		for k in poly.size():
			var a := poly[k]
			var b := poly[(k + 1) % poly.size()]
			var dehors := _normale_dehors(a, b, poly)
			# murs des vrais tags (Poutouland, le mur des blazes) : on n'y ajoute rien d'inventé
			if (c[1] == "Immeuble impasse sud" and dehors.y > 0.7) or (style == "marathon_rouge" and absf(a.x + 30.0) < 1.0 and absf(b.x + 30.0) < 1.0):
				continue
			# la grande barre porte une façade épaisse (habillage_facades.gd) : les tags vont sur sa face avant
			n += _couvrir_mur(a, b, dehors, densite, 0.7 if style == "barre_lauriers" else 0.0)
	for m in _murs_releves:
		for k in m.size() - 1:
			var d: Vector2 = (m[k + 1] - m[k]).normalized()
			for cote in [-1.0, 1.0]:
				n += _couvrir_mur(m[k], m[k + 1], Vector2(-d.y, d.x) * float(cote), 0.5, 0.17)
	print("Habillage : %d graffitis et affiches de décor" % n)


func _normale_dehors(a: Vector2, b: Vector2, poly: PackedVector2Array) -> Vector2:
	var d := (b - a).normalized()
	var nrm := Vector2(d.y, -d.x)
	if Geometry2D.is_point_in_polygon((a + b) * 0.5 + nrm * 0.3, poly):
		nrm = -nrm
	return nrm


## Pose des décalques le long d'un mur ; `ecart` = distance du mur au plan de pose (épaisseur d'un muret).
func _couvrir_mur(a: Vector2, b: Vector2, dehors: Vector2, densite: float, ecart := 0.0) -> int:
	var l := a.distance_to(b)
	if l < 4.0:
		return 0
	var d := (b - a) / l
	var n := 0
	var t := _rng.randf_range(1.0, 5.0)
	while t < l - 1.0:
		if _rng.randf() < densite:
			var p := a + d * t + dehors * ecart
			if p.distance_to(CYPRES_B_ENTREE) > 8.0:
				_decalque(p, d, dehors)
				n += 1
		t += _rng.randf_range(3.0, 8.0)
	return n


func _decalque(p: Vector2, le_long: Vector2, dehors: Vector2) -> void:
	var r := _rng.randf()
	var nom: String
	var largeur: float
	var haut: float
	var couleur := Color.WHITE
	var ordre := 2
	if r < 0.48:
		nom = "tag_%02d" % (_rng.randi() % 14)
		largeur = _rng.randf_range(0.9, 1.8)
		haut = _rng.randf_range(1.3, 2.3)
		couleur = ENCRES_TAG[_rng.randi() % ENCRES_TAG.size()]
	elif r < 0.66:
		nom = "flop_%02d" % (_rng.randi() % 6)
		largeur = _rng.randf_range(2.2, 3.6)
		haut = _rng.randf_range(1.2, 1.6)
		ordre = 1
	elif r < 0.80:
		nom = "affiche_%02d" % (_rng.randi() % 6)
		largeur = 0.8
		haut = 1.55
		ordre = 1
	else:
		nom = "efface_%02d" % (_rng.randi() % 4)
		largeur = _rng.randf_range(1.6, 2.8)
		haut = 1.3
		var g := _rng.randf_range(0.62, 0.78)
		couleur = Color(g, g * 0.98, g * 0.94)
		ordre = 3 if _rng.randf() < 0.5 else 0  # parfois par-dessus un tag, parfois dessous
	var tex := _texture(nom)
	if tex == null:
		return
	var x := Vector3(le_long.x, 0, le_long.y)
	var y := Vector3(dehors.x, 0, dehors.y)
	MARQUE.poser(self, tex, Vector3(p.x, h(p.x, p.y) + haut, p.y), x, y, largeur, couleur, 55.0, ordre, "Vieux_" + nom.get_slice("_", 0))


## Points régulièrement espacés le long d'une ligne : [position, direction].
func _jalons(pts: PackedVector2Array, pas: float, depart: float) -> Array:
	var out := []
	var reste := depart
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var l := a.distance_to(b)
		if l < 0.01:
			continue
		var dir := (b - a) / l
		var t := reste
		while t < l:
			out.append([a + dir * t, dir])
			t += pas
		reste = t - l
	return out


## Vrai si l'on peut poser un objet de rayon `r` en p : hors bâtiments, stade, parkings et chaussées.
func _libre(p: Vector2, r: float) -> bool:
	for poly in _emprises:
		for q in [p, p + Vector2(r, 0), p - Vector2(r, 0), p + Vector2(0, r), p - Vector2(0, r)]:
			if Geometry2D.is_point_in_polygon(q, poly):
				return false
	for ax in _axes:
		var pts: PackedVector2Array = ax[0]
		for k in pts.size() - 1:
			var cp := Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])
			if cp.distance_to(p) < float(ax[1]) + r * 0.5:
				return false
	return true


## Trottoirs clairs de part et d'autre, avec une bordure de béton côté chaussée (décor, sans collision).
func _trottoirs(pts: PackedVector2Array, demi: float) -> void:
	for cote in [-1.0, 1.0]:
		_bande(pts, cote * (demi + 1.1), 2.2, 0.10, Color(0.80, 0.76, 0.68))
		_bande(pts, cote * (demi + 0.12), 0.24, 0.16, MOB_BETON)


func _bande(pts: PackedVector2Array, decal: float, large: float, leve: float, c: Color) -> void:
	var fin := PackedVector2Array()
	for k in pts.size() - 1:
		var n := maxi(1, int(pts[k].distance_to(pts[k + 1]) / 3.0))
		for t in n:
			fin.append(pts[k].lerp(pts[k + 1], float(t) / n))
	fin.append(pts[pts.size() - 1])
	if fin.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := []
	var d := []
	for k in fin.size():
		var dir := (fin[mini(k + 1, fin.size() - 1)] - fin[maxi(k - 1, 0)]).normalized()
		var lat := Vector2(-dir.y, dir.x)
		var a := fin[k] + lat * (decal - large * 0.5)
		var b := fin[k] + lat * (decal + large * 0.5)
		g.append(Vector3(a.x, h(a.x, a.y) + leve, a.y))
		d.append(Vector3(b.x, h(b.x, b.y) + leve, b.y))
	for k in fin.size() - 1:
		for p in [g[k], d[k], d[k + 1], g[k], d[k + 1], g[k + 1]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	_decor("Trottoir", st.commit(), _mat(c))


func _maillage(nom: String, parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, basis := Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.transform = Transform3D(basis, pos)
	mi.name = nom
	parent.add_child(mi, true)
	return mi


func _bm(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _lampadaire(p: Vector2, vers_route: Vector2) -> void:
	var haut := 7.5
	var mat := _boite("Lampadaire", p.x, p.y, Vector3(0.18, haut, 0.18), MOB_GRIS)
	mat.add_to_group("mobilier")
	var a := atan2(vers_route.x, vers_route.y)
	if _vetir(mat, "lampadaire", Vector3(0, -haut * 0.5, 0), a):
		return
	var bras := Basis(Vector3.UP, a)
	_maillage("Bras", mat, _bm(0.1, 0.1, 1.6), MOB_GRIS, Vector3(0, haut * 0.5 - 0.1, 0) + bras * Vector3(0, 0, 0.8), bras)
	_maillage("Lanterne", mat, _bm(0.45, 0.18, 0.7), Color(0.22, 0.24, 0.24), Vector3(0, haut * 0.5 - 0.25, 0) + bras * Vector3(0, 0, 1.5), bras)


func _pin(p: Vector2) -> void:
	# Pin parasol : tronc penché, houppier large et plat.
	var haut := _rng.randf_range(7.0, 11.0)
	var t := _boite("Pin", p.x, p.y, Vector3(0.35, haut, 0.35), Color(0.42, 0.30, 0.22), 0.0, 0.2)
	t.add_to_group("arbre")
	if _vetir(t, "pin_parasol", Vector3(0, -haut * 0.5 + 0.2, 0), _rng.randf() * TAU, haut / 8.6):
		return
	t.rotation = Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf() * TAU, _rng.randf_range(-0.12, 0.12))
	var s := SphereMesh.new()
	var r := _rng.randf_range(3.2, 4.8)
	s.radius = r
	s.height = r * 0.9
	s.radial_segments = 12
	s.rings = 5
	_maillage("Houppier", t, s, Color(0.27, 0.43, 0.22), Vector3(0, haut * 0.5 + 0.4, 0))


func _platane(p: Vector2) -> void:
	var haut := _rng.randf_range(8.0, 12.0)
	var t := _boite("Platane", p.x, p.y, Vector3(0.45, haut * 0.65, 0.45), Color(0.66, 0.62, 0.48))
	t.add_to_group("arbre")
	var s := SphereMesh.new()
	var r := _rng.randf_range(3.5, 5.0)
	s.radius = r
	s.height = r * 1.6
	s.radial_segments = 12
	s.rings = 6
	_maillage("Feuillage", t, s, Color(0.42, 0.56, 0.26), Vector3(0, haut * 0.33 + r * 0.5, 0))


func _conteneur(p: Vector2, dir: Vector2) -> void:
	var a := atan2(dir.x, dir.y)
	var teintes := [Color(0.22, 0.46, 0.30), Color(0.40, 0.42, 0.44), Color(0.78, 0.62, 0.18)]
	var c: Color = teintes[_rng.randi() % teintes.size()]
	var b := _boite("Conteneur", p.x, p.y, Vector3(1.3, 1.15, 1.0), c, a)
	b.add_to_group("mobilier")
	var m := _vetir(b, "conteneur", Vector3(0, -0.575, 0), _rng.randf_range(-0.15, 0.15))
	if m:
		_repeindre(m, "Conteneur", c)
		return
	_maillage("Couvercle", b, _bm(1.36, 0.1, 1.08), c.darkened(0.3), Vector3(0, 0.62, -0.02))


func _banc(p: Vector2, dir: Vector2) -> void:
	# Un banc se grinde : c'est un rail bas et large, avec un dossier.
	var a := Vector3(p.x, sol(p.x, p.y), p.y)
	var x := Vector3(dir.x, 0, dir.y).normalized()
	var z := x.cross(Vector3.UP).normalized()
	var r := Rail.new()
	r.length = 1.9
	r.height = 0.45
	r.thickness = 0.45
	r.color = Color(0.62, 0.42, 0.26)
	r.transform = Transform3D(Basis(x, z.cross(x), z), a - x * 0.95)
	r.name = "Banc"
	r.add_to_group("banc")
	add_child(r, true)
	if _vetir(r, "banc", Vector3(0.95, 0, 0)) == null:
		_maillage("Dossier", r, _bm(1.9, 0.4, 0.06), Color(0.62, 0.42, 0.26), Vector3(0.95, 0.75, -0.22))


func _potelet(p: Vector2) -> void:
	var b := _boite("Potelet", p.x, p.y, Vector3(0.12, 0.9, 0.12), Color(0.36, 0.20, 0.16))
	_maillage("Tete", b, _bm(0.16, 0.06, 0.16), Color(0.85, 0.85, 0.82), Vector3(0, 0.42, 0))


func _panneau(p: Vector2, dir: Vector2) -> void:
	var b := _boite("Panneau", p.x, p.y, Vector3(0.07, 2.6, 0.07), MOB_GRIS)
	var a := atan2(dir.x, dir.y)
	var cy := CylinderMesh.new()
	cy.top_radius = 0.33
	cy.bottom_radius = 0.33
	cy.height = 0.03
	cy.radial_segments = 16
	var rouge := _rng.randf() < 0.5
	var disque := _maillage("Disque", b, cy, Color(0.82, 0.14, 0.14) if rouge else Color(0.12, 0.34, 0.72), Vector3(0, 1.05, 0), Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5))
	_maillage("Barre", disque, _bm(0.4, 0.035, 0.1), Color(0.95, 0.95, 0.93), Vector3(0, 0.02, 0))


func _abribus_boulevard(voies: Array) -> void:
	for c in voies:
		if c[1] != "b":
			continue
		var pts := _pts(c[3])
		var n := 0
		for e in _jalons(pts, 140.0, 60.0):
			var dir: Vector2 = e[1]
			var lat := Vector2(-dir.y, dir.x)
			for cote in [1.0, -1.0]:
				var q: Vector2 = e[0] + lat * cote * 8.6
				if not _libre(q, 2.2):
					continue
				var a := atan2(dir.x, dir.y)
				var b := _boite("Abribus", q.x, q.y, Vector3(0.12, 2.5, 4.0), MOB_GRIS, a)
				_maillage("Toit", b, _bm(1.7, 0.12, 4.2), Color(0.88, 0.88, 0.86), Vector3(cote * -0.75, 1.25, 0) * 0.0 + Vector3(0, 1.28, 0))
				_maillage("Affiche", b, _bm(0.06, 1.6, 1.1), Color(0.95, 0.80, 0.25), Vector3(0.08, 0.0, 1.3))
				_maillage("Banc", b, _bm(0.4, 0.08, 2.0), MOB_GRIS, Vector3(0.3, -0.75, 0))
				n += 1
				break
		break


## Grillage autour d'une zone (poteaux + panneau sombre) ; `porte` = index du côté laissé ouvert.
func _grillage(poly: PackedVector2Array, haut: float, porte: int) -> void:
	if poly[0].distance_to(poly[poly.size() - 1]) < 0.01:
		poly.remove_at(poly.size() - 1)
	var vert := Color(0.24, 0.38, 0.30)
	for k in poly.size():
		if k == porte:
			continue
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		for t in _troncons(PackedVector2Array([a, b]), 3.0):
			var p0: Vector3 = t[0]
			var p1: Vector3 = t[1]
			var x := (p1 - p0).normalized()
			var z := x.cross(Vector3.UP).normalized()
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(p0.distance_to(p1), haut, 0.05)
			cs.shape = sh
			body.add_child(cs)
			body.transform = Transform3D(Basis(x, z.cross(x), z), (p0 + p1) * 0.5 + Vector3(0, haut * 0.5, 0))
			body.name = "Grillage"
			body.add_to_group("mur")
			add_child(body, true)
			_maillage("Poteau", body, _bm(0.08, haut, 0.08), vert, Vector3(-p0.distance_to(p1) * 0.5, 0, 0))
			_maillage("Lisse", body, _bm(p0.distance_to(p1), 0.06, 0.06), vert, Vector3(0, haut * 0.5, 0))
			# Le treillis : un aplat sombre en bas, à moitié transparent au-dessus.
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.20, 0.30, 0.26, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			var tr := MeshInstance3D.new()
			tr.mesh = _bm(p0.distance_to(p1), haut, 0.02)
			tr.material_override = m
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(tr)


func _stade(poly: PackedVector2Array) -> void:
	_grillage(poly, 4.0, 0)
	if poly[0].distance_to(poly[poly.size() - 1]) < 0.01:
		poly.remove_at(poly.size() - 1)
	# Les buts aux deux bouts du grand axe.
	var long := 0.0
	var ia := 0
	for k in poly.size():
		var l := poly[k].distance_to(poly[(k + 1) % poly.size()])
		if l > long:
			long = l
			ia = k
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= poly.size()
	var axe := (poly[(ia + 1) % poly.size()] - poly[ia]).normalized()
	for s in [-1.0, 1.0]:
		var q: Vector2 = c + axe * s * (long * 0.5 - 4.0)
		var a := atan2(axe.x, axe.y)
		var but := _boite("But", q.x, q.y, Vector3(7.3, 0.12, 0.12), Color(0.95, 0.95, 0.93), a + PI * 0.5)
		but.position.y += 2.3
		for m in [-1.0, 1.0]:
			_maillage("Montant", but, _bm(0.12, 2.44, 0.12), Color(0.95, 0.95, 0.93), Vector3(m * 3.66, -1.2, 0))
	# Lignes blanches.
	_bande(PackedVector2Array([c - Vector2(-axe.y, axe.x) * 30.0, c + Vector2(-axe.y, axe.x) * 30.0]), 0.0, 0.15, 0.07, Color(0.95, 0.95, 0.92))


# ───────────────────────── briques ─────────────────────────

func _pts(s: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in s.split(" ", false):
		var xy := p.split(",")
		out.append(Vector2(float(xy[0]), float(xy[1])))
	return out


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.92
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


## Boîte solide posée sur le sol, tournée de `angle` autour de la verticale.
func _boite(nom: String, x: float, z: float, taille: Vector3, c: Color, angle := 0.0, enfonce := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = _mat(c)
	body.add_child(mi)
	body.name = nom
	body.transform = Transform3D(Basis(Vector3.UP, angle), Vector3(x, sol(x, z) + taille.y * 0.5 - enfonce, z))
	add_child(body, true)
	return body


func _decor(nom: String, mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.name = nom
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi, true)
	return mi


## Découpe une ligne en tronçons courts posés sur le relief.
func _troncons(pts: PackedVector2Array, pas: float) -> Array:
	var out := []
	for k in pts.size() - 1:
		var n := maxi(1, int(ceil(pts[k].distance_to(pts[k + 1]) / pas)))
		for t in n:
			var a := pts[k].lerp(pts[k + 1], float(t) / n)
			var b := pts[k].lerp(pts[k + 1], float(t + 1) / n)
			out.append([Vector3(a.x, h(a.x, a.y), a.y), Vector3(b.x, h(b.x, b.y), b.y)])
	return out
