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
	"skatepark": Color(0.74, 0.73, 0.70),
	"parking": Color(0.33, 0.33, 0.35),
	"jardin": Color(0.42, 0.50, 0.30),
	"chantier": Color(0.66, 0.58, 0.46),
}

var gx := PackedFloat32Array()
var gz := PackedFloat32Array()
var alt := []  # alt[j][i], j = ligne (z), i = colonne (x)
var _mats := {}


func _ready() -> void:
	var batiments := []
	var voies := []
	var murs := []
	var zones := []
	var f := FileAccess.open(RELEVE, FileAccess.READ)
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		var c := l.split("|")
		match c[0]:
			"B": batiments.append(c)
			"R": voies.append(c)
			"M": murs.append(c)
			"Z": zones.append(c)
			"A": _lire_altitudes(c)
	_terrain()
	for c in zones:
		_zone(c[1], _pts(c[3]))
	for c in voies:
		_voie(c[1], _pts(c[3]))
	for c in murs:
		_mur(_pts(c[1]))
	for c in batiments:
		_batiment(c[1], float(c[2]), c[3], _pts(c[4]))
	_horizon()
	_limites()
	var joueur := get_node_or_null("../Player") as Node3D
	if joueur:
		joueur.position = Vector3(DEPART.x, h(DEPART.x, DEPART.y) + 0.1, DEPART.y)


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
	sm.set_shader_parameter("garde_corps", (s[0] as Color).darkened(0.12))
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


func _mur(pts: PackedVector2Array) -> void:
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var d := b - a
		if d.length() < 0.5:
			continue
		var ya := h(a.x, a.y)
		var yb := h(b.x, b.y)
		var x := Vector3(d.x, yb - ya, d.y).normalized()
		var z := x.cross(Vector3.UP).normalized()
		var y := z.cross(x)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		var taille := Vector3(Vector3(d.x, yb - ya, d.y).length(), 1.4, 0.3)
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
		body.transform = Transform3D(Basis(x, y, z), Vector3((a.x + b.x) * 0.5, (ya + yb) * 0.5 + 0.5, (a.y + b.y) * 0.5))
		add_child(body, true)


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
