extends Node3D
## TRACE — le lycée Denis-Diderot, praticable de l'intérieur (conversation n°2).
## Le bloc plein du relevé (quartier_reel.gd) est remplacé, pour « Lycée » et « Lycée sud », par un bâtiment creux
## de même contour, de même hauteur et avec la même façade :
##  - des étages (planchers tous les 3,6 m) au-dessus du terrain ; le dessous, sur la pente, reste un socle fermé ;
##  - le long des façades, des salles de classe de 6 m de profondeur (tables, chaises, tableau vert),
##    une porte sur le couloir central ;
##  - des cages d'escalier en rampes croisées, qui montent jusqu'au toit ;
##  - des entrées là où le terrain arrive au niveau d'un plancher (avec quelques marches dehors si besoin).
## Le lycée a été construit en 1958 et restructuré par tranches de 2009 à 2016 : en 2014-2015, c'est un chantier
## en site occupé (voir la doc du décor). Le détail des lieux reste à préciser avec les souvenirs de Louma.

const TOON := preload("res://shaders/bd_toon.gdshader")
const ETAGE := 3.6
const DALLE := 0.25
const PROF_SALLE := 6.0
const LONG_TRAVEE := 8.0
const LONG_ESCALIER := 10.0
const PALIER := 1.6
const LYCEES := ["Lycée", "Lycée sud"]

const C_SOL := Color(0.70, 0.69, 0.63)
const C_PLAFOND := Color(0.93, 0.92, 0.88)
const C_MUR := Color(0.90, 0.86, 0.76)
const C_PLINTHE := Color(0.46, 0.58, 0.54)
const C_TABLE := Color(0.80, 0.66, 0.46)
const C_PIED := Color(0.32, 0.34, 0.36)
const C_CHAISE := Color(0.20, 0.42, 0.62)
const C_TABLEAU := Color(0.16, 0.30, 0.24)
const C_MARCHE := Color(0.62, 0.62, 0.60)

var habillage: Node
var _paquets := {}
var _cube := BoxMesh.new()
var _corps: StaticBody3D
var n_salles := 0
var n_entrees := 0
var portes_monde := []   # [position au sol (Vector2), vers l'intérieur (Vector2), plancher] pour les abords


func construire(batiments: Array) -> void:
	_cube.size = Vector3.ONE
	for c in batiments:
		if c[1] in LYCEES:
			_lycee(c[1], float(c[2]), _poly(c[4]))
	_poser_paquets()
	print("Lycée : %d salles de classe, %d entrées" % [n_salles, n_entrees])


func h(x: float, z: float) -> float:
	return habillage.h(x, z)


func _lycee(nom: String, hauteur: float, poly: PackedVector2Array) -> void:
	# le bloc plein du relevé : on garde sa matière de façade, on le cache et on retire sa collision
	var facade: Material = null
	for b in get_tree().get_nodes_in_group("batiment"):
		if b.name == nom:
			for e in b.get_children():
				if e is MeshInstance3D:
					facade = e.material_override
					e.visible = false
				elif e is CollisionShape3D:
					e.disabled = true
	# sens du contour : l'intérieur doit être à gauche de chaque côté (n_in = (-d.y, d.x))
	var i_long := 0
	for i in poly.size():
		if poly[i].distance_to(poly[(i + 1) % poly.size()]) > poly[i_long].distance_to(poly[(i_long + 1) % poly.size()]):
			i_long = i
	var pa := poly[i_long]
	var pb := poly[(i_long + 1) % poly.size()]
	var dl := (pb - pa).normalized()
	if not Geometry2D.is_point_in_polygon((pa + pb) * 0.5 + Vector2(-dl.y, dl.x) * 0.5, poly):
		poly.reverse()
	var moy := 0.0
	for p in poly:
		moy += h(p.x, p.y)
	moy /= poly.size()
	var toit := moy + hauteur
	# terrain le plus haut sous le bâtiment : le premier plancher praticable est juste au-dessus
	var t_max := -INF
	var bb := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bb = bb.expand(p)
	var x := bb.position.x
	while x < bb.end.x:
		var z := bb.position.y
		while z < bb.end.y:
			if Geometry2D.is_point_in_polygon(Vector2(x, z), poly):
				t_max = maxf(t_max, h(x, z))
			z += 2.0
		x += 2.0
	var niveaux: Array[float] = []
	var k := int(ceil((t_max - 0.45 - moy) / ETAGE))
	while moy + k * ETAGE <= toit - 3.0:
		niveaux.append(moy + k * ETAGE)
		k += 1
	_corps = StaticBody3D.new()
	_corps.name = "Lycee_interieur_" + nom.validate_node_name()
	add_child(_corps)
	# — travées le long des façades : salles de classe, ou cages d'escalier —
	var travees := []      # [a (Vector2), dir, n_in, long, escalier?]
	var dernier_escalier := -INF
	var cumul := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var lg := a.distance_to(b)
		var d := (b - a) / lg
		var n_in := Vector2(-d.y, d.x)          # intérieur à gauche
		var t0 := 0.0
		var t1 := lg
		# coin saillant au bout : la bande du côté suivant prend le coin
		var c2 := poly[(i + 2) % poly.size()]
		var crois := (b - a).cross(c2 - b)
		if crois > 0.0:
			t1 -= PROF_SALLE
		var prev := poly[(i - 1 + poly.size()) % poly.size()]
		if (a - prev).cross(b - a) < 0.0:
			t0 += PROF_SALLE   # coin rentrant au début : on laisse le passage
		var dispo := t1 - t0
		if dispo >= 6.0 and Geometry2D.is_point_in_polygon(a + d * (t0 + dispo * 0.5) + n_in * PROF_SALLE, poly):
			var t := t0
			if dispo >= LONG_ESCALIER + 4.0 and cumul - dernier_escalier > 60.0:
				travees.append([a + d * t, d, n_in, LONG_ESCALIER, true])
				t += LONG_ESCALIER
				dernier_escalier = cumul
			var reste := t1 - t
			var nb := maxi(1, int(round(reste / LONG_TRAVEE)))
			var lt := reste / nb
			if reste >= 4.0:
				for j in nb:
					travees.append([a + d * (t + j * lt), d, n_in, lt, false])
		cumul += lg
	# — planchers et toit : le contour entier, moins les cages d'escalier —
	var plans: Array = [poly]
	for tr in travees:
		if tr[4]:
			var a: Vector2 = tr[0]
			var d: Vector2 = tr[1]
			var n_in: Vector2 = tr[2]
			var trou := PackedVector2Array([a - n_in, a + d * tr[3] - n_in, a + d * tr[3] + n_in * PROF_SALLE, a + n_in * PROF_SALLE])
			var suivant: Array = []
			for p in plans:
				suivant.append_array(Geometry2D.clip_polygons(p, trou))
			plans = suivant
	var etages := niveaux.duplicate()
	etages.append(toit)
	for j in etages.size():
		var y: float = etages[j]
		for p in plans:
			if p.size() >= 3:
				_dalle(p, y, j == etages.size() - 1)
	# — façades : murs creux sur tout le contour, du terrain au toit, avec des portes —
	var u := 0.0
	var portes := _choisir_entrees(poly, travees, niveaux)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var lg := a.distance_to(b)
		var bas := minf(h(a.x, a.y), h(b.x, b.y)) - 0.6
		var ouvertures := []
		for pt in portes:
			if pt[0] == i:
				ouvertures.append([pt[1] - 1.2, pt[1] + 1.2, pt[2], pt[2] + 2.6])
		_mur_facade(a, b, bas, toit, u, moy, ouvertures, facade)
		u += lg
	for pt in portes:
		_marches_entree(poly, pt)
	# — intérieur, étage par étage —
	for j in niveaux.size():
		var y: float = niveaux[j]
		for tr in travees:
			if tr[4]:
				_cage(tr, etages, j)
			else:
				_salle(tr, y, j)


## Choisit les entrées : au milieu des travées de classe, là où le terrain dehors est au niveau d'un plancher.
func _choisir_entrees(poly: PackedVector2Array, travees: Array, niveaux: Array[float]) -> Array:
	var cand := []
	for tr in travees:
		if tr[4]:
			continue
		var a: Vector2 = tr[0]
		var d: Vector2 = tr[1]
		var n_in: Vector2 = tr[2]
		var m: Vector2 = a + d * float(tr[3]) * 0.5
		var dehors: Vector2 = m - n_in * 1.5
		var sol := h(dehors.x, dehors.y)
		for y in niveaux:
			var ecart: float = y - sol
			if ecart > -0.4 and ecart < 4.6:
				# côté du polygone et position le long de ce côté
				for i in poly.size():
					var p0 := poly[i]
					var p1 := poly[(i + 1) % poly.size()]
					if Geometry2D.get_closest_point_to_segment(m, p0, p1).distance_to(m) < 0.05:
						cand.append([i, p0.distance_to(m), y, ecart, m, n_in])
						break
				break
	cand.sort_custom(func(p, q): return absf(p[3]) < absf(q[3]))
	var choisies := []
	for c in cand:
		var loin := true
		for e in choisies:
			if (e[4] as Vector2).distance_to(c[4]) < 28.0:
				loin = false
		if loin:
			choisies.append(c)
		if choisies.size() >= 6:
			break
	n_entrees += choisies.size()
	for c in choisies:
		portes_monde.append([c[4], c[5], c[2]])
	return choisies


## Quelques marches devant une entrée surélevée.
func _marches_entree(poly: PackedVector2Array, pt: Array) -> void:
	var ecart: float = pt[3]
	if ecart < 0.25:
		return
	var m: Vector2 = pt[4]
	var n_in: Vector2 = pt[5]
	var y: float = pt[2]
	var nb := int(ceil(ecart / 0.17))
	var dir := Vector3(-n_in.x, 0, -n_in.y)
	var base := Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP, dir)
	for s in nb:
		var hh := y - s * ecart / nb
		var bas := y - ecart - 0.3
		var c := Vector3(m.x, 0, m.y) + dir * (0.6 + s * 0.32)
		var taille := Vector3(2.8, hh - bas, 0.32)
		var o := Vector3(c.x, bas + taille.y * 0.5, c.z)
		_ajouter("marche", C_MARCHE, Transform3D(base * Basis.from_scale(taille), o))
		_boite(base, taille, o)


# ───────────────────────── planchers, murs ─────────────────────────

func _dalle(p: PackedVector2Array, y: float, toit: bool) -> void:
	var tri := Geometry2D.triangulate_polygon(p)
	if tri.is_empty():
		return
	for face in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var yy := y if face == 0 else y - DALLE
		st.set_normal(Vector3.UP if face == 0 else Vector3.DOWN)
		for i in tri:
			st.add_vertex(Vector3(p[i].x, yy, p[i].y))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var c := C_SOL if face == 0 else C_PLAFOND
		if toit and face == 0:
			c = Color(0.48, 0.47, 0.45)
		mi.material_override = _mat(c)
		mi.name = "Dalle"
		add_child(mi)
	var faces := PackedVector3Array()
	for i in tri:
		faces.append(Vector3(p[i].x, y, p[i].y))
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(faces)
	cs.shape = sh
	_corps.add_child(cs)


## Mur de façade (le même matériau que le bloc d'origine), avec des ouvertures [t0, t1, y0, y1].
func _mur_facade(a: Vector2, b: Vector2, bas: float, haut: float, u: float, moy: float, ouvertures: Array, m: Material) -> void:
	var lg := a.distance_to(b)
	var d := (b - a) / lg
	# découpe en rectangles pleins autour des ouvertures
	var pieces := []
	var t := 0.0
	ouvertures.sort_custom(func(p, q): return p[0] < q[0])
	for o in ouvertures:
		pieces.append([t, o[0], bas, haut])
		pieces.append([o[0], o[1], o[3], haut])
		pieces.append([o[0], o[1], bas, o[2]])
		t = o[1]
	pieces.append([t, lg, bas, haut])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nrm := Vector3(d.y, 0, -d.x)   # vers l'extérieur
	for pc in pieces:
		if pc[1] - pc[0] < 0.01 or pc[3] - pc[2] < 0.01:
			continue
		var q := []
		for c in [[pc[0], pc[2]], [pc[1], pc[2]], [pc[1], pc[3]], [pc[0], pc[3]]]:
			var p := a + d * float(c[0])
			q.append([Vector3(p.x, c[1], p.y), Vector2(u + c[0], c[1] - moy), Vector2(c[0], lg)])
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm)
			st.set_uv(q[idx][1])
			st.set_uv2(q[idx][2])
			st.add_vertex(q[idx][0])
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(pc[1] - pc[0], pc[3] - pc[2], 0.3)
		cs.shape = sh
		var mid: Vector2 = a + d * ((float(pc[0]) + float(pc[1])) * 0.5) - Vector2(nrm.x, nrm.z) * 0.15
		cs.transform = Transform3D(Basis(Vector3(d.x, 0, d.y), Vector3.UP, nrm), Vector3(mid.x, (pc[2] + pc[3]) * 0.5, mid.y))
		_corps.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m if m else _mat(C_MUR)
	mi.name = "Facade_lycee"
	add_child(mi)


## Un mur intérieur de a à b (plan), du plancher y sur hh, avec une porte au milieu si porte > 0.
func _cloison(a: Vector2, b: Vector2, y: float, hh: float, porte := 0.0) -> void:
	var lg := a.distance_to(b)
	if lg < 0.2:
		return
	var d := (b - a) / lg
	var morceaux := [[0.0, lg]]
	if porte > 0.0 and lg > porte + 0.6:
		var mil := lg * 0.5
		morceaux = [[0.0, mil - porte * 0.5], [mil + porte * 0.5, lg]]
		# imposte au-dessus de la porte
		var pm := a + d * mil
		var bi := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-d.y, 0, d.x))
		_ajouter("mur", C_MUR, Transform3D(bi * Basis.from_scale(Vector3(porte, hh - 2.2, 0.14)), Vector3(pm.x, y + 2.2 + (hh - 2.2) * 0.5, pm.y)))
	for mo in morceaux:
		var l2: float = mo[1] - mo[0]
		var c: Vector2 = a + d * ((float(mo[0]) + float(mo[1])) * 0.5)
		var bi := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-d.y, 0, d.x))
		_ajouter("mur", C_MUR, Transform3D(bi * Basis.from_scale(Vector3(l2, hh, 0.14)), Vector3(c.x, y + hh * 0.5, c.y)))
		_ajouter("plinthe", C_PLINTHE, Transform3D(bi * Basis.from_scale(Vector3(l2, 1.1, 0.16)), Vector3(c.x, y + 0.55, c.y)))
		_boite(bi, Vector3(l2, hh, 0.14), Vector3(c.x, y + hh * 0.5, c.y))


# ───────────────────────── salles de classe ─────────────────────────

func _salle(tr: Array, y: float, j: int) -> void:
	var a: Vector2 = tr[0]
	var d: Vector2 = tr[1]
	var n_in: Vector2 = tr[2]
	var lg: float = tr[3]
	var hh := ETAGE - DALLE
	var p_in := a + n_in * PROF_SALLE
	# mur sur le couloir avec la porte, cloison de début de travée
	_cloison(p_in, p_in + d * lg, y, hh, 1.1)
	_cloison(a + n_in * 0.15, p_in, y, hh)
	_cloison(a + d * lg + n_in * 0.15, p_in + d * lg, y, hh)
	n_salles += 1
	# tableau vert sur la cloison de début
	var bt := Basis(Vector3(n_in.x, 0, n_in.y), Vector3.UP, Vector3(d.x, 0, d.y))
	var ct := a + n_in * (PROF_SALLE * 0.5) + d * 0.1
	_ajouter("tableau", C_TABLEAU, Transform3D(bt * Basis.from_scale(Vector3(3.0, 1.2, 0.05)), Vector3(ct.x, y + 1.6, ct.y)))
	_ajouter("pied", C_PIED, Transform3D(bt * Basis.from_scale(Vector3(3.2, 0.06, 0.12)), Vector3(ct.x, y + 0.98, ct.y) + Vector3(d.x, 0, d.y) * 0.06))
	# bureau du prof, puis rangées de tables doubles face au tableau
	var bd := Basis(Vector3(n_in.x, 0, n_in.y), Vector3.UP, Vector3(d.x, 0, d.y))
	var cb := a + n_in * 3.0 + d * 1.4
	_table(cb, y, bd, 1.4, 0.7)
	var rangs := int((lg - 2.6) / 1.4)
	for r in rangs:
		for col in 2:
			var c := a + d * (2.6 + r * 1.4 + 0.5) + n_in * (1.4 + col * 2.4)
			_table(c, y, bd, 1.3, 0.55)
			for s in [-0.33, 0.33]:
				_chaise(c + Vector2(n_in.x, n_in.y) * s + d * 0.55, y, bd)
	# affiche (sans texte) près de la porte
	var ca := p_in + d * (lg * 0.5 + 1.1) - n_in * 0.09
	_ajouter("affiche_%d" % (j % 3), [Color(0.92, 0.80, 0.30), Color(0.85, 0.40, 0.35), Color(0.40, 0.62, 0.80)][j % 3], Transform3D(Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-n_in.x, 0, -n_in.y)) * Basis.from_scale(Vector3(0.6, 0.8, 0.02)), Vector3(ca.x, y + 1.6, ca.y)))


func _table(c: Vector2, y: float, b: Basis, l: float, p: float) -> void:
	_ajouter("table", C_TABLE, Transform3D(b * Basis.from_scale(Vector3(l, 0.04, p)), Vector3(c.x, y + 0.74, c.y)))
	for sx in [-1.0, 1.0]:
		var o: Vector3 = Vector3(c.x, y + 0.36, c.y) + b.x * float(sx) * (l * 0.5 - 0.05)
		_ajouter("pied", C_PIED, Transform3D(b * Basis.from_scale(Vector3(0.04, 0.72, p - 0.05)), o))
	_boite(b, Vector3(l, 0.76, p), Vector3(c.x, y + 0.38, c.y))


func _chaise(c: Vector2, y: float, b: Basis) -> void:
	_ajouter("chaise", C_CHAISE, Transform3D(b * Basis.from_scale(Vector3(0.4, 0.04, 0.4)), Vector3(c.x, y + 0.45, c.y)))
	_ajouter("chaise", C_CHAISE, Transform3D(b * Basis.from_scale(Vector3(0.4, 0.4, 0.04)), Vector3(c.x, y + 0.67, c.y) + b.z * 0.2))
	_ajouter("pied", C_PIED, Transform3D(b * Basis.from_scale(Vector3(0.36, 0.44, 0.36)), Vector3(c.x, y + 0.22, c.y)))


# ───────────────────────── cages d'escalier ─────────────────────────

## Deux bandes : A contre la façade, B côté couloir. Volée j (du niveau j au niveau j+1) : A si j pair, B sinon.
## Paliers aux deux bouts ; au niveau j+1, la bande de la volée j est ouverte au-dessus de la rampe.
func _cage(tr: Array, etages: Array, j: int) -> void:
	var a: Vector2 = tr[0]
	var d: Vector2 = tr[1]
	var n_in: Vector2 = tr[2]
	var lg: float = tr[3]
	var y: float = etages[j]
	var hh := ETAGE - DALLE
	var bandes := [[0.2, 2.9], [3.1, PROF_SALLE - 0.1]]
	# cloisons de la cage (côtés), le couloir reste ouvert
	_cloison(a + n_in * 0.15, a + n_in * PROF_SALLE, y, hh)
	_cloison(a + d * lg + n_in * 0.15, a + d * lg + n_in * PROF_SALLE, y, hh)
	# planchers de la cage à ce niveau : paliers + la bande qui n'est pas ouverte
	_plaque(a, d, n_in, 0.0, PALIER, 0.0, PROF_SALLE, y)
	_plaque(a, d, n_in, lg - PALIER, lg, 0.0, PROF_SALLE, y)
	var ouverte := -1 if j == 0 else (j - 1) % 2
	for s in 2:
		if s != ouverte:
			_plaque(a, d, n_in, PALIER, lg - PALIER, bandes[s][0] - 0.2 if s == 0 else bandes[s][0] - 0.2, bandes[s][1] + (0.1 if s == 1 else 0.2), y)
	if ouverte >= 0:
		# garde-corps autour de la trémie
		var b0: float = bandes[ouverte][0]
		var b1: float = bandes[ouverte][1]
		var lim := b1 + 0.1 if ouverte == 0 else b0 - 0.1
		_rambarde(a + d * PALIER + n_in * lim, a + d * (lg - PALIER) + n_in * lim, y)
	# la volée qui part de ce niveau
	if j + 1 < etages.size():
		var s := j % 2
		var y1: float = etages[j + 1]
		var monte := y1 - y
		var t_bas := PALIER if s == 0 else lg - PALIER
		var t_haut := lg - PALIER if s == 0 else PALIER
		var c0: float = (bandes[s][0] + bandes[s][1]) * 0.5
		var larg: float = bandes[s][1] - bandes[s][0]
		var run := absf(t_haut - t_bas)
		var nb := int(round(monte / 0.18))
		var sens := signf(t_haut - t_bas)
		for m in nb:
			var tm := t_bas + sens * (m + 0.5) * run / nb
			var hm := (m + 1) * monte / nb
			var p := a + d * tm + n_in * c0
			var bm := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-n_in.x, 0, -n_in.y))
			_ajouter("marche", C_MARCHE, Transform3D(bm * Basis.from_scale(Vector3(run / nb + 0.02, 0.18, larg)), Vector3(p.x, y + hm - 0.09, p.y)))
		# rampe de collision
		var lg_r := sqrt(run * run + monte * monte)
		var pente := atan2(monte, run) * sens
		var pm := a + d * ((t_bas + t_haut) * 0.5) + n_in * c0
		var bx := Vector3(d.x, 0, d.y)
		var bz := Vector3(-n_in.x, 0, -n_in.y)
		var br := Basis(bx, Vector3.UP, bz).orthonormalized() * Basis(Vector3.BACK, pente)
		_boite(br, Vector3(lg_r, 0.2, larg), Vector3(pm.x, y + monte * 0.5 - 0.1, pm.y))
		# muret entre les deux bandes
		var mid := a + n_in * 3.0
		_ajouter("plinthe", C_PLINTHE, Transform3D(Basis(bx, Vector3.UP, bz) * Basis.from_scale(Vector3(run, 1.0, 0.12)), Vector3(mid.x, y + 0.5, mid.y) + bx * ((PALIER + lg - PALIER) * 0.5)))
		_boite(Basis(bx, Vector3.UP, bz), Vector3(run, 1.0, 0.12), Vector3(mid.x, y + 0.5, mid.y) + bx * (lg * 0.5))


func _plaque(a: Vector2, d: Vector2, n_in: Vector2, t0: float, t1: float, p0: float, p1: float, y: float) -> void:
	var c := a + d * ((t0 + t1) * 0.5) + n_in * ((p0 + p1) * 0.5)
	var b := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-n_in.x, 0, -n_in.y))
	var taille := Vector3(t1 - t0, DALLE, p1 - p0)
	_ajouter("sol_cage", C_SOL, Transform3D(b * Basis.from_scale(taille), Vector3(c.x, y - DALLE * 0.5, c.y)))
	_boite(b, taille, Vector3(c.x, y - DALLE * 0.5, c.y))


func _rambarde(a: Vector2, b: Vector2, y: float) -> void:
	var lg := a.distance_to(b)
	var d := (b - a) / lg
	var c := (a + b) * 0.5
	var bi := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-d.y, 0, d.x))
	_ajouter("rambarde", C_PIED, Transform3D(bi * Basis.from_scale(Vector3(lg, 0.05, 0.05)), Vector3(c.x, y + 1.0, c.y)))
	_ajouter("rambarde", C_PIED, Transform3D(bi * Basis.from_scale(Vector3(lg, 0.04, 0.04)), Vector3(c.x, y + 0.5, c.y)))
	_boite(bi, Vector3(lg, 1.0, 0.1), Vector3(c.x, y + 0.5, c.y))


# ───────────────────────── briques ─────────────────────────

func _boite(b: Basis, taille: Vector3, o: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	cs.transform = Transform3D(b.orthonormalized(), o)
	_corps.add_child(cs)


func _mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("couleur", c)
	m.set_shader_parameter("grain", 0.35)
	return m


func _ajouter(cle: String, c: Color, t: Transform3D) -> void:
	if not _paquets.has(cle):
		_paquets[cle] = [c, []]
	(_paquets[cle][1] as Array).append(t)


func _poser_paquets() -> void:
	for cle in _paquets:
		var liste: Array = _paquets[cle][1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _cube
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _mat(_paquets[cle][0])
		mi.name = "Lycee_" + cle
		add_child(mi)


func _poly(s: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in s.split(" ", false):
		var xy := p.split(",")
		out.append(Vector2(float(xy[0]), float(xy[1])))
	if out.size() > 2 and out[0].distance_to(out[out.size() - 1]) < 0.01:
		out.remove_at(out.size() - 1)
	return out
