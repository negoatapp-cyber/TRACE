extends Node3D
## Le quartier, construit au lancement à partir du RELEVÉ RÉEL (data/quartier_reel.txt) :
## contours des bâtiments et tracé des rues d'OpenStreetMap, relief de l'IGN.
## Les positions, les formes au sol et les pentes sont donc celles du terrain.
## Ce qui reste estimé : les hauteurs et les couleurs des immeubles (à corriger dans le fichier).
##
## Repère : mètres, x = est, z = sud. Altitude 0 du jeu = ALT_REF mètres réels.

const FACADE := preload("res://shaders/facade.gdshader")
const RELEVE := "res://data/quartier_reel.txt"
const ALT_REF := 90.0
const DEPART := Vector2(57, -45)  # rue de Marathon, au pied des Cyprès

const STYLES := {
	"barre_lauriers": [Color(0.93, 0.90, 0.80), true, 0.45, 2.8, 3.4, Color(0.86, 0.70, 0.36)],
	"barre_renovee": [Color(0.86, 0.83, 0.74), true, 0.30, 2.8, 3.4, Color(0.80, 0.77, 0.68)],
	"barre_blanche": [Color(0.90, 0.88, 0.83), true, 0.45, 2.8, 3.4],
	"barre_rose": [Color(0.84, 0.60, 0.56), true, 0.40, 2.8, 3.4],
	"tour_grise": [Color(0.70, 0.66, 0.58), false, 0.55, 2.8, 3.4],
	"tour_ocre": [Color(0.80, 0.60, 0.34), false, 0.50, 2.8, 3.4],
	"lycee": [Color(0.80, 0.78, 0.73), false, 0.10, 3.6, 4.2],
	"hopital": [Color(0.84, 0.82, 0.78), false, 0.10, 3.4, 3.0],
	"clair": [Color(0.82, 0.80, 0.75), false, 0.20, 3.2, 3.6],
	"recent": [Color(0.92, 0.91, 0.88), true, 0.25, 2.8, 3.2],
}
const VOIES := {
	"b": [12.0, Color(0.22, 0.22, 0.24)],
	"r": [7.0, Color(0.27, 0.27, 0.29)],
	"s": [5.0, Color(0.31, 0.31, 0.33)],
	"p": [2.6, Color(0.66, 0.63, 0.58)],
}
const ZONES := {
	"terrain": Color(0.30, 0.50, 0.30),
	"bitume": Color(0.36, 0.36, 0.40),
	"skatepark": Color(0.76, 0.46, 0.46),
	"parking": Color(0.33, 0.33, 0.35),
	"jardin": Color(0.42, 0.50, 0.30),
	"chantier": Color(0.66, 0.58, 0.46),
	"friche": Color(0.60, 0.55, 0.42),
}

## "avant" = le quartier de 2014-2015, "apres" = aujourd'hui. Touche T pour passer de l'un à l'autre.
static var epoque := "avant"

var gx := PackedFloat32Array()
var gz := PackedFloat32Array()
var alt := []  # alt[j][i], j = ligne (z), i = colonne (x)
var _mats := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var batiments := []
	var voies := []
	var murs := []
	var zones := []
	var divers := []
	var f := FileAccess.open(RELEVE, FileAccess.READ)
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		var c := l.split("|")
		if c[c.size() - 1].begins_with("@"):
			if c[c.size() - 1].substr(1) != epoque:
				continue
			c.remove_at(c.size() - 1)
		match c[0]:
			"B": batiments.append(c)
			"R": voies.append(c)
			"M": murs.append(c)
			"Z": zones.append(c)
			"A": _lire_altitudes(c)
			_: divers.append(c)
	_rng.seed = 13013
	_terrain()
	for c in zones:
		_zone(c[1], _pts(c[3]))
		if c[1] == "skatepark":
			_skatepark(_pts(c[3]))
		elif c[1] == "parking":
			_voitures(_pts(c[3]))
		elif c[1] == "friche":
			_friche(_pts(c[3]))
	for c in voies:
		_voie(c[1], _pts(c[3]))
	for c in murs:
		_mur(_pts(c[1]))
	for c in batiments:
		_batiment(c[1], float(c[2]), c[3], _pts(c[4]))
	for c in divers:
		match c[0]:
			"G": _grindable(c[1], float(c[2]), _pts(c[3]))
			"W": _mur_boulevard(_pts(c[1]))
			"T": _treillis(float(c[1]), _pts(c[2]))
			"H": _halle(_pts(c[1])[0], float(c[2]), float(c[3]))
	_horizon()
	_limites()
	_etiquette()
	var joueur := get_node_or_null("../Player") as Node3D
	if joueur:
		joueur.position = Vector3(DEPART.x, h(DEPART.x, DEPART.y) + 0.1, DEPART.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		epoque = "apres" if epoque == "avant" else "avant"
		get_tree().reload_current_scene()


func _etiquette() -> void:
	var couche := CanvasLayer.new()
	var texte := Label.new()
	texte.text = ("Époque : 2014-2015" if epoque == "avant" else "Époque : aujourd'hui") + "   ·   T pour changer"
	texte.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	texte.position = Vector2(16, -44)
	texte.add_theme_font_size_override("font_size", 18)
	texte.add_theme_color_override("font_outline_color", Color.BLACK)
	texte.add_theme_constant_override("outline_size", 4)
	couche.add_child(texte)
	add_child(couche)


# ───────────────────────── relief ─────────────────────────

func _lire_altitudes(c: PackedStringArray) -> void:
	var x0 := float(c[1])
	var z0 := float(c[2])
	var pas := float(c[3])
	var cols := int(c[4])
	var v := c[5].split(" ", false)
	var lignes := v.size() / cols
	# Une bordure large autour du relevé prolonge le relief vers l'horizon.
	gx.append(x0 - 500.0)
	for i in cols:
		gx.append(x0 + i * pas)
	gx.append(x0 + (cols - 1) * pas + 500.0)
	gz.append(z0 - 500.0)
	for j in lignes:
		gz.append(z0 + j * pas)
	gz.append(z0 + (lignes - 1) * pas + 500.0)
	for j in lignes + 2:
		var jj := clampi(j - 1, 0, lignes - 1)
		var row := PackedFloat32Array()
		for i in cols + 2:
			var ii := clampi(i - 1, 0, cols - 1)
			row.append(float(v[jj * cols + ii]) - ALT_REF)
		alt.append(row)


## Hauteur du sol au point (x, z) — identique aux triangles du terrain.
func h(x: float, z: float) -> float:
	x = clampf(x, gx[0], gx[gx.size() - 1] - 0.001)
	z = clampf(z, gz[0], gz[gz.size() - 1] - 0.001)
	var i := 0
	while i < gx.size() - 2 and x >= gx[i + 1]:
		i += 1
	var j := 0
	while j < gz.size() - 2 and z >= gz[j + 1]:
		j += 1
	var fx := (x - gx[i]) / (gx[i + 1] - gx[i])
	var fz := (z - gz[j]) / (gz[j + 1] - gz[j])
	var h00: float = alt[j][i]
	var h10: float = alt[j][i + 1]
	var h01: float = alt[j + 1][i]
	var h11: float = alt[j + 1][i + 1]
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)


func _terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for j in gz.size() - 1:
		for i in gx.size() - 1:
			var p00 := Vector3(gx[i], alt[j][i], gz[j])
			var p10 := Vector3(gx[i + 1], alt[j][i + 1], gz[j])
			var p01 := Vector3(gx[i], alt[j + 1][i], gz[j + 1])
			var p11 := Vector3(gx[i + 1], alt[j + 1][i + 1], gz[j + 1])
			for tri in [[p00, p10, p01], [p10, p11, p01]]:
				var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				if n.y < 0.0:
					n = -n
				_tri(st, faces, tri[0], tri[1], tri[2], n)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.56, 0.54, 0.48)
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_corps("Terrain", st.commit(), m, faces)


# ───────────────────────── bâtiments ─────────────────────────

func _batiment(nom: String, hauteur: float, style: String, poly: PackedVector2Array) -> void:
	if poly.size() > 2 and poly[0].distance_to(poly[poly.size() - 1]) < 0.01:
		poly.remove_at(poly.size() - 1)
	if poly.size() < 3:
		return
	var aire := 0.0
	var bas := INF
	var moy := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		aire += a.x * b.y - b.x * a.y
		var y := h(a.x, a.y)
		bas = minf(bas, y)
		moy += y
	moy /= poly.size()
	var y0 := bas - 1.5
	var y1 := moy + hauteur
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var u := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var d := b - a
		var long := d.length()
		if long < 0.01:
			continue
		var n := Vector3(d.y, 0, -d.x).normalized()
		var milieu := (a + b) * 0.5 + Vector2(n.x, n.z) * 0.2
		if Geometry2D.is_point_in_polygon(milieu, poly):
			n = -n
		var p0 := Vector3(a.x, y0, a.y)
		var p1 := Vector3(b.x, y0, b.y)
		var p2 := Vector3(b.x, y1, b.y)
		var p3 := Vector3(a.x, y1, a.y)
		var u0 := Vector2(u, y0 - moy)
		var u1 := Vector2(u + long, y0 - moy)
		var u2 := Vector2(u + long, hauteur)
		var u3 := Vector2(u, hauteur)
		_tri(st, faces, p0, p1, p2, n, u0, u1, u2)
		_tri(st, faces, p0, p2, p3, n, u0, u2, u3)
		u += long
	var tri := Geometry2D.triangulate_polygon(poly)
	for t in range(0, tri.size(), 3):
		_tri(st, faces, Vector3(poly[tri[t]].x, y1, poly[tri[t]].y), Vector3(poly[tri[t + 1]].x, y1, poly[tri[t + 1]].y), Vector3(poly[tri[t + 2]].x, y1, poly[tri[t + 2]].y), Vector3.UP)
	var s: Array = STYLES.get(style, STYLES["clair"])
	var sm := ShaderMaterial.new()
	sm.shader = FACADE
	sm.set_shader_parameter("mur", s[0])
	sm.set_shader_parameter("garde_corps", s[5] if s.size() > 5 else (s[0] as Color).darkened(0.12))
	sm.set_shader_parameter("hauteur", hauteur)
	sm.set_shader_parameter("loggias", 1.0 if s[1] else 0.0)
	sm.set_shader_parameter("vie", s[2])
	sm.set_shader_parameter("etage", s[3])
	sm.set_shader_parameter("travee", s[4])
	_corps(nom, st.commit(), sm, faces)


# ───────────────────────── voies, zones, murs ─────────────────────────

func _voie(type: String, pts: PackedVector2Array) -> void:
	var v: Array = VOIES.get(type, VOIES["s"])
	var demi: float = v[0] * 0.5
	var leve := 0.10 if type == "p" else 0.07
	# On recoupe la ligne tous les 3 m pour qu'elle épouse le relief.
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
		var lat := Vector2(-dir.y, dir.x) * demi
		var a := fin[k] + lat
		var b := fin[k] - lat
		g.append(Vector3(a.x, h(a.x, a.y) + leve, a.y))
		d.append(Vector3(b.x, h(b.x, b.y) + leve, b.y))
	for k in fin.size() - 1:
		for p in [g[k], d[k], d[k + 1], g[k], d[k + 1], g[k + 1]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	_decor("Voie", st.commit(), _mat(v[1]))


func _zone(type: String, poly: PackedVector2Array) -> void:
	var c: Color = ZONES.get(type, ZONES["bitume"])
	var mn := poly[0]
	var mx := poly[0]
	for p in poly:
		mn = mn.min(p)
		mx = mx.max(p)
	var pas := 4.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := mn.x
	var vide := true
	while x < mx.x:
		var z := mn.y
		while z < mx.y:
			if Geometry2D.is_point_in_polygon(Vector2(x + pas * 0.5, z + pas * 0.5), poly):
				var q := [Vector2(x, z), Vector2(x + pas, z), Vector2(x + pas, z + pas), Vector2(x, z + pas)]
				for idx in [0, 1, 2, 0, 2, 3]:
					st.set_normal(Vector3.UP)
					st.add_vertex(Vector3(q[idx].x, h(q[idx].x, q[idx].y) + 0.04, q[idx].y))
				vide = false
			z += pas
		x += pas
	if not vide:
		_decor("Zone_" + type, st.commit(), _mat(c))


## Le skatepark en béton rose au pied de la barre (il existe aujourd'hui, pas en 2008-2013).
## Première approximation : un talus incliné sur tout le tour, une bosse au centre, un rail, un muret.
func _skatepark(poly: PackedVector2Array) -> void:
	if poly[0].distance_to(poly[poly.size() - 1]) < 0.01:
		poly.remove_at(poly.size() - 1)
	var centre := Vector2.ZERO
	for p in poly:
		centre += p
	centre /= poly.size()
	var rose := _mat(Color(0.80, 0.50, 0.50))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var haut := 1.1
	var large := 3.2
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		if n.dot(centre - (a + b) * 0.5) < 0.0:
			n = -n
		var ai := a + n * large
		var bi := b + n * large
		var at := Vector3(a.x, h(a.x, a.y) + haut, a.y)
		var bt := Vector3(b.x, h(b.x, b.y) + haut, b.y)
		var a0 := Vector3(a.x, h(a.x, a.y) - 0.5, a.y)
		var b0 := Vector3(b.x, h(b.x, b.y) - 0.5, b.y)
		var a1 := Vector3(ai.x, h(ai.x, ai.y) + 0.03, ai.y)
		var b1 := Vector3(bi.x, h(bi.x, bi.y) + 0.03, bi.y)
		var pente := Vector3(n.x * haut, large, n.y * haut).normalized()
		_tri(st, faces, at, bt, b1, pente)
		_tri(st, faces, at, b1, a1, pente)
		var dehors := Vector3(-n.x, 0, -n.y)
		_tri(st, faces, a0, b0, bt, dehors)
		_tri(st, faces, a0, bt, at, dehors)
	# Bosse centrale à quatre pans.
	var c3 := Vector3(centre.x, h(centre.x, centre.y) + 0.75, centre.y)
	var r := 4.0
	var coins := []
	for q in [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]:
		var p: Vector2 = centre + q
		coins.append(Vector3(p.x, h(p.x, p.y) + 0.03, p.y))
	for k in 4:
		var e0: Vector3 = coins[k]
		var e1: Vector3 = coins[(k + 1) % 4]
		var nn := (e1 - e0).cross(c3 - e0).normalized()
		if nn.y < 0.0:
			nn = -nn
		_tri(st, faces, e0, e1, c3, nn)
	_corps("Skatepark", st.commit(), rose, faces)
	for spec in [[Vector2(-9, 6), Vector2(-3, 8), 0.4, 0.07, Color(0.35, 0.36, 0.38)], [Vector2(5, -9), Vector2(10, -8), 0.45, 0.45, Color(0.80, 0.50, 0.50)]]:
		var a: Vector2 = centre + spec[0]
		var b: Vector2 = centre + spec[1]
		var rail := Rail.new()
		var pa := Vector3(a.x, h(a.x, a.y), a.y)
		var pb := Vector3(b.x, h(b.x, b.y), b.y)
		var x := (pb - pa).normalized()
		var z := x.cross(Vector3.UP).normalized()
		rail.length = pa.distance_to(pb)
		rail.height = spec[2]
		rail.thickness = spec[3]
		rail.color = spec[4]
		rail.transform = Transform3D(Basis(x, z.cross(x), z), pa)
		rail.name = "Module"
		add_child(rail, true)


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
	body.transform = Transform3D(Basis(Vector3.UP, angle), Vector3(x, h(x, z) + taille.y * 0.5 - enfonce, z))
	add_child(body, true)
	return body


func _voiture(x: float, z: float, angle: float, c: Color, epave := false) -> void:
	var v := _boite("Epave" if epave else "Voiture", x, z, Vector3(1.7, 0.74, 4.0), c, angle, -0.25 if not epave else 0.0)
	var cab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 0.56, 2.0)
	cab.mesh = bm
	cab.material_override = _mat(Color(0.10, 0.09, 0.08) if epave else Color(0.12, 0.15, 0.2))
	cab.position = Vector3(0, 0.64, -0.2)
	v.add_child(cab)


## Remplit un parking de voitures d'époque (formes simples, aucune marque).
func _voitures(poly: PackedVector2Array) -> void:
	var teintes := [Color(0.75, 0.75, 0.72), Color(0.2, 0.22, 0.26), Color(0.55, 0.12, 0.12), Color(0.16, 0.2, 0.36), Color(0.82, 0.8, 0.74), Color(0.3, 0.38, 0.32), Color(0.5, 0.5, 0.52)]
	var mn := poly[0]
	var mx := poly[0]
	for p in poly:
		mn = mn.min(p)
		mx = mx.max(p)
	# Les voitures s'alignent sur le plus long côté du parking.
	var best := 0.0
	var dir := Vector2.RIGHT
	for k in poly.size() - 1:
		if poly[k].distance_to(poly[k + 1]) > best:
			best = poly[k].distance_to(poly[k + 1])
			dir = (poly[k + 1] - poly[k]).normalized()
	var angle := atan2(-dir.y, dir.x) + PI * 0.5
	var z := mn.y + 3.0
	while z < mx.y:
		var x := mn.x + 2.0
		while x < mx.x:
			var p := Vector2(x, z)
			if _rng.randf() < 0.6 and Geometry2D.is_point_in_polygon(p, poly) and Geometry2D.is_point_in_polygon(p + dir * 2.2, poly) and Geometry2D.is_point_in_polygon(p - dir * 2.2, poly):
				_voiture(x, z, angle + (PI if _rng.randf() < 0.3 else 0.0), teintes[_rng.randi() % teintes.size()])
			x += 3.0
		z += 6.5


## Terrain vague : arbres, enrochements, édicules, épaves brûlées.
func _friche(poly: PackedVector2Array) -> void:
	var mn := poly[0]
	var mx := poly[0]
	for p in poly:
		mn = mn.min(p)
		mx = mx.max(p)
	var poses := 0
	var essais := 0
	while poses < 46 and essais < 2000:
		essais += 1
		var p := Vector2(_rng.randf_range(mn.x, mx.x), _rng.randf_range(mn.y, mx.y))
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		poses += 1
		var y := h(p.x, p.y)
		if poses <= 4:
			_voiture(p.x, p.y, _rng.randf() * TAU, Color(0.13, 0.11, 0.10), true)
		elif poses <= 7:
			_boite("Edicule", p.x, p.y, Vector3(3.0, 2.2, 3.0), Color(0.78, 0.72, 0.60), _rng.randf() * TAU, 0.3)
		elif poses <= 22:
			var r := _rng.randf_range(0.4, 0.9)
			_boite("Rocher", p.x, p.y, Vector3(r * 1.4, r, r * 1.1), Color(0.62, 0.60, 0.56), _rng.randf() * TAU, 0.15)
		else:
			var haut := _rng.randf_range(4.5, 8.0)
			_boite("Tronc", p.x, p.y, Vector3(0.3, haut * 0.6, 0.3), Color(0.30, 0.25, 0.20))
			var f := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = haut * 0.38
			s.height = haut * 0.6
			f.mesh = s
			f.material_override = _mat(Color(0.28, 0.42, 0.22))
			f.position = Vector3(p.x, y + haut * 0.78, p.y)
			f.name = "Feuillage"
			add_child(f, true)


func _mur(pts: PackedVector2Array) -> void:
	for t in _troncons(pts, 8.0):
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var x := (b - a).normalized()
		var z := x.cross(Vector3.UP).normalized()
		var taille := Vector3(a.distance_to(b) + 0.05, 1.6, 0.3)
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
		mi.material_override = _mat(Color(0.74, 0.72, 0.67))
		body.add_child(mi)
		body.name = "Mur"
		body.transform = Transform3D(Basis(x, z.cross(x), z), (a + b) * 0.5 + Vector3(0, 0.5, 0))
		add_child(body, true)


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


## Rail (tube) ou muret (béton) à grinder, posé sur le sol.
func _grindable(type: String, haut: float, pts: PackedVector2Array) -> void:
	for t in _troncons(pts, 10.0):
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var x := (b - a).normalized()
		var z := x.cross(Vector3.UP).normalized()
		var r := Rail.new()
		r.length = a.distance_to(b)
		r.height = haut
		r.thickness = 0.07 if type == "rail" else 0.4
		r.color = Color(0.35, 0.36, 0.38) if type == "rail" else Color(0.78, 0.76, 0.71)
		r.transform = Transform3D(Basis(x, z.cross(x), z), a - Vector3(0, 0.05, 0))
		r.name = "Rail" if type == "rail" else "Muret"
		add_child(r, true)


## Le mur du lycée côté boulevard : carrelage clair et deux bandes turquoise (état d'origine).
func _mur_boulevard(pts: PackedVector2Array) -> void:
	for t in _troncons(pts, 8.0):
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var x := (b - a).normalized()
		var z := x.cross(Vector3.UP).normalized()
		var base := Basis(x, z.cross(x), z)
		var long := a.distance_to(b) + 0.05
		var milieu := (a + b) * 0.5
		for couche in [[2.9, 0.30, 1.2, Color(0.90, 0.88, 0.83), true], [0.22, 0.36, 0.7, Color(0.16, 0.66, 0.64), false], [0.22, 0.36, 2.0, Color(0.16, 0.66, 0.64), false]]:
			var n: Node3D = StaticBody3D.new() if couche[4] else Node3D.new()
			if couche[4]:
				var cs := CollisionShape3D.new()
				var sh := BoxShape3D.new()
				sh.size = Vector3(long, couche[0], couche[1])
				cs.shape = sh
				n.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(long, couche[0], couche[1])
			mi.mesh = bm
			mi.material_override = _mat(couche[3])
			n.add_child(mi)
			n.name = "MurBoulevard"
			n.transform = Transform3D(base, milieu + Vector3(0, couche[2], 0))
			add_child(n, true)


func _tube(a: Vector3, b: Vector3, rayon: float, m: Material) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon
	c.height = d.length()
	c.radial_segments = 6
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	var y := d.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := y.cross(ref).normalized()
	mi.transform = Transform3D(Basis(y.cross(z), y, z), (a + b) * 0.5)
	mi.name = "Tube"
	add_child(mi, true)


## Charpente bleue en treillis au-dessus des toits du lycée.
func _treillis(au_dessus: float, pts: PackedVector2Array) -> void:
	var bleu := _mat(Color(0.42, 0.70, 0.90))
	var y0 := h(pts[0].x, pts[0].y) + au_dessus + 1.0
	var up := Vector3(0, 3.2, 0)
	for k in pts.size() - 1:
		var a := Vector3(pts[k].x, y0, pts[k].y)
		var b := Vector3(pts[k + 1].x, y0, pts[k + 1].y)
		var n := maxi(2, int(a.distance_to(b) / 6.0))
		_tube(a, b, 0.14, bleu)
		_tube(a + up, b + up, 0.14, bleu)
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			_tube(p, p + up, 0.09, bleu)
			if i < n:
				var q := a.lerp(b, float(i + 1) / n)
				if i % 2 == 0:
					_tube(p, q + up, 0.08, bleu)
				else:
					_tube(p + up, q, 0.08, bleu)
			if i % 3 == 0:
				_tube(p - Vector3(0, 4.0, 0), p, 0.16, bleu)


## La halle vitrée en arc de l'entrée.
func _halle(centre: Vector2, rayon: float, angle_deg: float) -> void:
	var y := h(centre.x, centre.y)
	var base := Basis(Vector3.UP, deg_to_rad(angle_deg))
	var verre := StandardMaterial3D.new()
	verre.albedo_color = Color(0.45, 0.68, 0.80, 0.55)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	verre.metallic = 0.3
	verre.roughness = 0.08
	verre.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rayon
	cyl.bottom_radius = rayon
	cyl.height = rayon * 1.8
	cyl.radial_segments = 40
	mi.mesh = cyl
	mi.material_override = verre
	mi.transform = Transform3D(base * Basis(Vector3.RIGHT, PI * 0.5), Vector3(centre.x, y, centre.y))
	mi.name = "HalleVitree"
	add_child(mi, true)
	var bleu := _mat(Color(0.42, 0.70, 0.90))
	for i in 5:
		var dz := (i - 2) * rayon * 0.42
		for k in 14:
			var a0 := PI * float(k) / 14.0
			var a1 := PI * float(k + 1) / 14.0
			var p0 := Vector3(centre.x, y, centre.y) + base * Vector3(cos(a0) * (rayon + 0.1), sin(a0) * (rayon + 0.1), dz)
			var p1 := Vector3(centre.x, y, centre.y) + base * Vector3(cos(a1) * (rayon + 0.1), sin(a1) * (rayon + 0.1), dz)
			_tube(p0, p1, 0.14, bleu)
	var corps := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(rayon * 1.9, rayon * 1.6, rayon * 1.8)
	cs.shape = sh
	corps.add_child(cs)
	corps.transform = Transform3D(base, Vector3(centre.x, y + rayon * 0.5, centre.y))
	corps.name = "HalleCollision"
	add_child(corps, true)


func _horizon() -> void:
	# Collines sèches au nord-est, comme vues depuis le quartier.
	for c in [[520.0, -620.0, 300.0], [150.0, -780.0, 340.0], [-380.0, -700.0, 300.0], [760.0, -200.0, 280.0]]:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = c[2]
		s.height = c[2] * 2.0
		m.mesh = s
		m.material_override = _mat(Color(0.52, 0.53, 0.42))
		m.position = Vector3(c[0], -40.0, c[1])
		m.scale = Vector3(1, 0.42, 1)
		m.name = "Colline"
		add_child(m, true)


func _limites() -> void:
	# Murs invisibles au bord du relevé.
	var x0 := gx[1]
	var x1 := gx[gx.size() - 2]
	var z0 := gz[1]
	var z1 := gz[gz.size() - 2]
	for l in [[Vector3((x0 + x1) * 0.5, 20, z0), Vector3(x1 - x0, 120, 1)], [Vector3((x0 + x1) * 0.5, 20, z1), Vector3(x1 - x0, 120, 1)], [Vector3(x0, 20, (z0 + z1) * 0.5), Vector3(1, 120, z1 - z0)], [Vector3(x1, 20, (z0 + z1) * 0.5), Vector3(1, 120, z1 - z0)]]:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = l[1]
		cs.shape = sh
		body.add_child(cs)
		body.position = l[0]
		body.name = "Limite"
		add_child(body, true)


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


## Ajoute un triangle dont la face visible regarde du côté de `n`.
func _tri(st: SurfaceTool, faces: PackedVector3Array, p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3, u0 := Vector2.ZERO, u1 := Vector2.ZERO, u2 := Vector2.ZERO) -> void:
	if (p2 - p0).cross(p1 - p0).dot(n) < 0.0:
		var tp := p1
		p1 = p2
		p2 = tp
		var tu := u1
		u1 = u2
		u2 = tu
	for e in [[p0, u0], [p1, u1], [p2, u2]]:
		st.set_normal(n)
		st.set_uv(e[1])
		st.add_vertex(e[0])
		faces.append(e[0])


## Volume solide : maillage + collision calquée sur ses triangles.
func _corps(nom: String, mesh: Mesh, m: Material, faces: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(faces)
	cs.shape = sh
	body.add_child(cs)
	body.name = nom
	add_child(body, true)


func _decor(nom: String, mesh: Mesh, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.name = nom
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi, true)
