extends Node3D
## TRACE — les façades en relief et les toits (conversation n°2, lot 1).
## Créé par habillage.gd après la construction du quartier. Pour chaque bâtiment du relevé :
##  - barres et tours à loggias : un balcon en saillie sur deux, calé sur la grille de fenêtres du shader ;
##  - tours sans loggias (Cyprès B…) : une dalle d'étage qui dépasse, à chaque niveau ;
##  - descentes d'eau aux angles, acrotère autour du toit, édicules d'ascenseur, antennes râteau ;
##  - quelques paraboles et du linge sur les balcons.
## Tout est dessiné en « multimesh » (un seul objet par type d'élément) pour rester léger, y compris sur mobile.
## Les balcons des trois premiers niveaux, ceux de quelques « colonnes » et les toits ont une collision :
## ce sont les prises de la grimpe (groupe « prise »).

const Q := preload("res://scripts/quartier_reel.gd")
const TOON := preload("res://shaders/bd_toon.gdshader")

## Styles dont la façade porte des loggias, donc des balcons.
const AVEC_BALCONS := ["barre_lauriers", "barre_renovee", "barre_blanche", "barre_rose", "cypres_barre", "genets_blanc"]
## Styles « tour » : dalles d'étage apparentes.
const AVEC_DALLES := ["cypres_tour", "tour_ocre", "tour_grise"]
const RDC := 3.2              # hauteur du rez-de-chaussée (même valeur que facade.gdshader)
const BALCON_PROFOND := 1.1   # saillie d'un balcon (m)
const GARDE_CORPS := 1.0      # hauteur du garde-corps
const PRISES_BASSES := 3      # niveaux de balcons avec collision partout
const COLONNE_TOUS_LES := 9   # une colonne de balcons grimpable sur toute la hauteur toutes les N travées

var habillage: Node           # pour h() (hauteur du sol)
var _paquets := {}            # clé → [mesh, couleur, Array[Transform3D]]
var _cube := BoxMesh.new()
var _disque := CylinderMesh.new()
var _rng := RandomNumberGenerator.new()
var n_balcons := 0
var n_prises := 0


func construire(batiments: Array) -> void:
	_cube.size = Vector3.ONE
	_disque.top_radius = 0.5
	_disque.bottom_radius = 0.5
	_disque.height = 1.0
	_disque.radial_segments = 12
	_rng.seed = 2014
	for c in batiments:
		_batiment(c[1], float(c[2]), c[3], _pts(c[4]))
	_poser_paquets()
	print("Façades : %d balcons, %d prises de grimpe" % [n_balcons, n_prises])


func h(x: float, z: float) -> float:
	return habillage.h(x, z)


func _batiment(nom: String, hauteur: float, style: String, poly: PackedVector2Array) -> void:
	if poly.size() > 2 and poly[0].distance_to(poly[poly.size() - 1]) < 0.01:
		poly.remove_at(poly.size() - 1)
	if poly.size() < 3:
		return
	var s: Array = Q.STYLES.get(style, Q.STYLES["clair"])
	var mur: Color = s[0]
	var etage: float = s[3]
	var travee: float = s[4]
	var garde: Color = s[5] if s.size() > 5 else mur.darkened(0.12)
	# Même calcul que quartier_reel.gd : la façade part de l'altitude moyenne des sommets.
	var moy := 0.0
	for p in poly:
		moy += h(p.x, p.y)
	moy /= poly.size()
	var toit := moy + hauteur
	var corps := StaticBody3D.new()
	corps.name = "Prises_" + nom.validate_node_name()
	corps.add_to_group("prise")
	add_child(corps)
	var niveaux := int(floor((hauteur - RDC - 0.6) / etage))
	if style in AVEC_BALCONS:
		niveaux = int(floor((hauteur - RDC - 2.4) / etage)) + 1   # un balcon au dernier étage aussi
	# Entre le garde-corps du dernier balcon et le haut de l'acrotère, la grimpe bondit de 3,1 m au plus :
	# au-delà, une corniche fait l'étape intermédiaire.
	var corniche := -1.0
	var haut_balcon := RDC + (niveaux - 1) * etage + GARDE_CORPS
	if style in AVEC_BALCONS and hauteur + 0.75 - haut_balcon > 2.9:
		corniche = moy + haut_balcon + (hauteur + 0.75 - haut_balcon) * 0.5
	var u := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var long := a.distance_to(b)
		if long < 0.01:
			continue
		var d := (b - a) / long
		var n := _normale_dehors(a, b, poly)
		if style in AVEC_BALCONS and long >= 15.0:  # pas de balcons sur les pignons
			_balcons(corps, a, d, n, u, long, moy, niveaux, etage, travee, garde)
		elif style in AVEC_DALLES:
			_dalles(corps, a, b, d, n, long, moy, niveaux, etage, mur.darkened(0.08))
		if corniche > 0.0 and long >= 2.0:
			_rebord_mince(corps, a, b, d, n, long, corniche, mur.darkened(0.1))
		if hauteur >= 8.0:
			_acrotere(corps, a, b, d, n, long, toit, mur.darkened(0.1))
		u += long
	if hauteur >= 8.0:
		_descentes(poly, moy, toit)
	if hauteur >= 15.0:
		_edicules(corps, poly, toit, mur.darkened(0.06))


## Un balcon sur deux travées : dalle, garde-corps de face et de côté ; parfois une parabole ou du linge.
func _balcons(corps: StaticBody3D, a: Vector2, d: Vector2, n: Vector2, u0: float, long: float, moy: float, niveaux: int, etage: float, travee: float, garde: Color) -> void:
	var larg := travee * 0.88
	var premiere := int(ceil((u0 + 0.4 + larg * 0.5) / travee - 0.5))
	var derniere := int(floor((u0 + long - 0.4 - larg * 0.5) / travee - 0.5))
	var base := _base(d, n)
	for cell in range(premiere, derniere + 1):
		if cell % 2 != 0:
			continue  # l'autre travée garde sa loggia en creux (dessinée par le shader)
		var t := (cell + 0.5) * travee - u0
		var p := a + d * t
		var colonne := cell % (COLONNE_TOUS_LES * 2) == 0
		for k in niveaux:
			var y := moy + RDC + k * etage
			var o := Vector3(p.x, y, p.y)
			_ajouter("dalle", _cube, Color(0.80, 0.78, 0.73), Transform3D(_ech(base, Vector3(larg, 0.16, BALCON_PROFOND)), o + base.z * (BALCON_PROFOND * 0.5) - Vector3.UP * 0.08))
			_ajouter("garde", _cube, garde, Transform3D(_ech(base, Vector3(larg, GARDE_CORPS, 0.07)), o + base.z * (BALCON_PROFOND - 0.035) + Vector3.UP * GARDE_CORPS * 0.5))
			for s in [-1.0, 1.0]:
				_ajouter("garde", _cube, garde, Transform3D(_ech(base, Vector3(0.07, GARDE_CORPS, BALCON_PROFOND)), o + base.x * s * (larg * 0.5 - 0.035) + base.z * (BALCON_PROFOND * 0.5) + Vector3.UP * GARDE_CORPS * 0.5))
			var r := _rng.randf()
			if r < 0.12:
				# Parabole accrochée au garde-corps, tournée vers le sud-est.
				var pb := Basis(Vector3.UP, deg_to_rad(150)) * Basis(Vector3.RIGHT, deg_to_rad(70))
				_ajouter("parabole", _disque, Color(0.88, 0.88, 0.86), Transform3D(_ech(pb, Vector3(0.75, 0.05, 0.75)), o + base.z * (BALCON_PROFOND + 0.15) + base.x * (larg * 0.3) + Vector3.UP * (GARDE_CORPS + 0.25)))
			elif r < 0.30:
				_linge(o, base, larg)
			n_balcons += 1
			# Prises : les premiers niveaux partout, puis toute la hauteur sur les colonnes.
			if k < PRISES_BASSES or colonne:
				var cs := CollisionShape3D.new()
				var sh := BoxShape3D.new()
				sh.size = Vector3(larg, GARDE_CORPS + 0.16, BALCON_PROFOND)
				cs.shape = sh
				cs.transform = Transform3D(base, o + base.z * (BALCON_PROFOND * 0.5) + Vector3.UP * (GARDE_CORPS * 0.5 - 0.08))
				corps.add_child(cs)
				n_prises += 1


## Du linge sur un fil, au-dessus du garde-corps : quelques rectangles de couleur.
func _linge(o: Vector3, base: Basis, larg: float) -> void:
	var teintes := [Color(0.95, 0.95, 0.92), Color(0.85, 0.25, 0.30), Color(0.25, 0.45, 0.80), Color(0.95, 0.80, 0.25), Color(0.40, 0.65, 0.45), Color(0.92, 0.55, 0.70)]
	var nb := 2 + _rng.randi() % 4
	for i in nb:
		var x := -larg * 0.4 + (i + 0.5) * (larg * 0.8 / nb)
		var hh := _rng.randf_range(0.35, 0.7)
		_ajouter("linge_%d" % (_rng.randi() % teintes.size()), _cube, Color.WHITE, Transform3D(_ech(base, Vector3(larg * 0.8 / nb * 0.8, hh, 0.02)), o + base.x * x + base.z * (BALCON_PROFOND - 0.05) + Vector3.UP * (GARDE_CORPS + 0.2 - hh * 0.5)), teintes)


## Dalles d'étage apparentes sur les tours : un bandeau qui dépasse de 20 cm à chaque niveau.
## Ce sont aussi des prises : on s'y suspend et on bondit d'étage en étage (mécanique de n°1).
func _dalles(corps: StaticBody3D, a: Vector2, b: Vector2, d: Vector2, n: Vector2, long: float, moy: float, niveaux: int, etage: float, c: Color) -> void:
	for k in niveaux + 1:
		_rebord_mince(corps, a, b, d, n, long, moy + RDC + k * etage, c, k < niveaux)


## Un rebord fin le long d'un mur (dalle d'étage, corniche) : visible, et prise de grimpe.
func _rebord_mince(corps: StaticBody3D, a: Vector2, b: Vector2, d: Vector2, n: Vector2, long: float, y: float, c: Color, bloc_dessus := true) -> void:
	var base := _base(d, n)
	var m := (a + b) * 0.5
	var t := Transform3D(_ech(base, Vector3(long + 0.4, 0.18, 0.4)), Vector3(m.x, y, m.y))
	_ajouter("dalle_tour", _cube, c, t)
	# Collision : de 13 cm derrière le mur à 14 cm devant. Assez pour s'y suspendre et pour que
	# le bond trouve le rebord suivant, trop peu pour se hisser et tenir debout dessus.
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(long + 0.4, 0.18, 0.27)
	cs.shape = sh
	cs.transform = Transform3D(base, t.origin + base.z * 0.005)
	corps.add_child(cs)
	n_prises += 1
	# Bloc caché derrière la façade, au-dessus du rebord : sans lui, « se hisser » croirait
	# trouver la place de tenir debout (l'intérieur est vide) et passerait à travers le mur.
	# Il commence 18 cm derrière le mur pour ne pas fausser la recherche du rebord suivant.
	if bloc_dessus:
		var bloc := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(maxf(long - 0.6, 0.5), 1.4, 0.42)
		bloc.shape = bs
		bloc.transform = Transform3D(base, t.origin - base.z * 0.39 + Vector3.UP * 1.09)
		corps.add_child(bloc)


## Acrotère : le muret qui borde le toit. On peut s'y percher ; il empêche de tomber par mégarde.
func _acrotere(corps: StaticBody3D, a: Vector2, b: Vector2, d: Vector2, n: Vector2, long: float, toit: float, c: Color) -> void:
	var base := _base(d, n)
	var m := (a + b) * 0.5 - n * 0.1
	var t := Transform3D(_ech(base, Vector3(long + 0.2, 0.75, 0.22)), Vector3(m.x, toit + 0.375, m.y))
	_ajouter("acrotere", _cube, c, t)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(long + 0.2, 0.75, 0.22)
	cs.shape = sh
	cs.transform = Transform3D(base, t.origin)
	corps.add_child(cs)


## Descentes d'eau pluviale aux angles du bâtiment.
func _descentes(poly: PackedVector2Array, moy: float, toit: float) -> void:
	for k in poly.size():
		var p := poly[k]
		var avant := poly[(k - 1 + poly.size()) % poly.size()]
		var apres := poly[(k + 1) % poly.size()]
		if p.distance_to(avant) < 3.0 or p.distance_to(apres) < 3.0:
			continue
		var bis := ((p - avant).normalized() - (apres - p).normalized())
		if bis.length() < 0.1:
			continue
		var out := bis.normalized()
		if Geometry2D.is_point_in_polygon(p + out * 0.3, poly):
			out = -out
		var q := p + out * 0.18
		var bas := h(q.x, q.y)
		_ajouter("descente", _cube, Color(0.55, 0.56, 0.58), Transform3D(Basis().scaled(Vector3(0.12, toit - bas, 0.12)), Vector3(q.x, (toit + bas) * 0.5, q.y)))
		# Repère pour la grimpe à la gouttière (n°1, player_controller.gd) : bas, haut, côté dehors.
		var m := Marker3D.new()
		m.position = Vector3(q.x, bas, q.y)
		m.set_meta("haut", toit)
		m.set_meta("dehors", Vector3(out.x, 0.0, out.y))
		m.add_to_group("gouttiere")
		add_child(m)


## Édicules d'ascenseur sur les toits (un tous les ~40 m), avec antennes râteau.
func _edicules(corps: StaticBody3D, poly: PackedVector2Array, toit: float, c: Color) -> void:
	var places: Array[Vector2] = []
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var long := a.distance_to(b)
		if long < 12.0:
			continue
		var d := (b - a) / long
		var dedans := -_normale_dehors(a, b, poly)
		var t := 10.0
		while t < long - 6.0:
			var p := a + d * t + dedans * 4.5
			var libre := Geometry2D.is_point_in_polygon(p, poly)
			for q in places:
				if q.distance_to(p) < 25.0:
					libre = false
			if libre:
				places.append(p)
			t += 40.0
	if places.is_empty():
		var cen := Vector2.ZERO
		for p in poly:
			cen += p
		cen /= poly.size()
		if Geometry2D.is_point_in_polygon(cen, poly):
			places.append(cen)
	for p in places:
		var taille := Vector3(3.4, 2.6, 3.4)
		var o := Vector3(p.x, toit + taille.y * 0.5, p.y)
		_ajouter("edicule", _cube, c, Transform3D(Basis().scaled(taille), o))
		_ajouter("edicule_toit", _cube, c.darkened(0.25), Transform3D(Basis().scaled(Vector3(3.6, 0.12, 3.6)), o + Vector3.UP * (taille.y * 0.5 + 0.06)))
		_ajouter("porte", _cube, Color(0.35, 0.36, 0.38), Transform3D(Basis().scaled(Vector3(0.9, 2.0, 0.04)), o + Vector3(0, -0.3, taille.z * 0.5 + 0.02)))
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = taille
		cs.shape = sh
		cs.position = o
		corps.add_child(cs)
		# Antenne râteau : un mât et trois barres.
		if _rng.randf() < 0.8:
			var m := o + Vector3(_rng.randf_range(-1.0, 1.0), taille.y * 0.5, _rng.randf_range(-1.0, 1.0))
			_ajouter("antenne", _cube, Color(0.45, 0.46, 0.48), Transform3D(Basis().scaled(Vector3(0.06, 3.2, 0.06)), m + Vector3.UP * 1.6))
			var rot := Basis(Vector3.UP, _rng.randf() * TAU)
			for i in 3:
				_ajouter("antenne", _cube, Color(0.45, 0.46, 0.48), Transform3D(_ech(rot, Vector3(1.4 - i * 0.3, 0.04, 0.04)), m + Vector3.UP * (2.2 + i * 0.4)))


# ───────────────────────── briques ─────────────────────────

## Mise à l'échelle dans le repère de l'objet (largeur, hauteur, profondeur).
func _ech(b: Basis, e: Vector3) -> Basis:
	return b * Basis.from_scale(e)


## Repère d'un mur : x le long du mur, y vers le haut, z vers l'extérieur.
func _base(d: Vector2, n: Vector2) -> Basis:
	var z := Vector3(n.x, 0, n.y).normalized()
	return Basis(Vector3.UP.cross(z), Vector3.UP, z)


func _normale_dehors(a: Vector2, b: Vector2, poly: PackedVector2Array) -> Vector2:
	var d := (b - a).normalized()
	var nrm := Vector2(d.y, -d.x)
	if Geometry2D.is_point_in_polygon((a + b) * 0.5 + nrm * 0.3, poly):
		nrm = -nrm
	return nrm


func _ajouter(cle: String, mesh: Mesh, c: Color, t: Transform3D, teintes := []) -> void:
	if not _paquets.has(cle):
		var couleur := c
		if cle.begins_with("linge_"):
			couleur = teintes[int(cle.get_slice("_", 1))]
		_paquets[cle] = [mesh, couleur, []]
	(_paquets[cle][2] as Array).append(t)


## Un MultiMeshInstance3D par type d'élément, avec le matériau BD.
func _poser_paquets() -> void:
	for cle in _paquets:
		var p: Array = _paquets[cle]
		var liste: Array = p[2]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = p[0]
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("couleur", p[1])
		m.set_shader_parameter("grain", 0.5)
		mi.material_override = m
		mi.name = "Facades_" + cle
		if cle.begins_with("linge") or cle == "antenne" or cle == "parabole":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _pts(s: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in s.split(" ", false):
		var xy := p.split(",")
		out.append(Vector2(float(xy[0]), float(xy[1])))
	return out
