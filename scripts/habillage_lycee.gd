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
const DALLES := preload("res://shaders/dalles.gdshader")
const GRAFF := "res://assets/decor/graff/%s.png"
## Le hall sous la grande verrière (entrée côté boulevard Lavéran) : 12 m de large, 26 m de profondeur.
## Derrière la façade : un grand vide sur toute la hauteur, dalles grises, verrière au plafond ;
## au fond le CDI derrière une paroi vitrée, et le grand escalier qui monte à la coursive des étages.
const HALL_A := Vector2(149.0, 119.0)   # côté de façade du relevé qui porte l'entrée
const HALL_B := Vector2(108.0, 64.0)
const HALL_LARGE := 12.0
const HALL_PROF := 26.0
const PROF_CDI := 7.0

const C_SOL := Color(0.70, 0.69, 0.63)
const C_PLAFOND := Color(0.93, 0.92, 0.88)
const C_MUR := Color(0.86, 0.84, 0.79)   # blanc sale
const C_PLINTHE := Color(0.68, 0.66, 0.60)  # bas de mur grisé par les passages
const C_TABLE := Color(0.76, 0.72, 0.62)   # stratifié beige rayé
const C_PIED := Color(0.36, 0.24, 0.17)    # métal marron
const C_CHAISE := Color(0.82, 0.74, 0.58)  # coque beige
const C_TABLEAU := Color(0.16, 0.30, 0.24)
const C_MARCHE := Color(0.62, 0.62, 0.60)

var habillage: Node
var _paquets := {}
var _cube := BoxMesh.new()
var _corps: StaticBody3D
var _rng := RandomNumberGenerator.new()
var hall := PackedVector2Array()
var n_salles := 0
var n_entrees := 0
var portes_monde := []   # [position au sol (Vector2), vers l'intérieur (Vector2), plancher] pour les abords


func construire(batiments: Array) -> void:
	_cube.size = Vector3.ONE
	_rng.seed = 1958
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
	hall = PackedVector2Array()
	if nom == "Lycée":
		var d0 := (HALL_B - HALL_A).normalized()
		var m0 := (HALL_A + HALL_B) * 0.5
		var in0 := Vector2(-d0.y, d0.x)
		if not Geometry2D.is_point_in_polygon(m0 + in0 * 2.0, poly):
			in0 = -in0
		var rect := PackedVector2Array([m0 - d0 * HALL_LARGE * 0.5 - in0 * 0.5, m0 + d0 * HALL_LARGE * 0.5 - in0 * 0.5, m0 + d0 * HALL_LARGE * 0.5 + in0 * HALL_PROF, m0 - d0 * HALL_LARGE * 0.5 + in0 * HALL_PROF])
		var inter := Geometry2D.intersect_polygons(poly, rect)
		if not inter.is_empty():
			hall = inter[0]
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
	# pas de salles ni de cage là où s'ouvre le hall
	if hall.size() > 2:
		var gardees := []
		for tr in travees:
			var ca: Vector2 = tr[0] + tr[1] * float(tr[3]) * 0.5 + tr[2] * PROF_SALLE * 0.5
			var c1: Vector2 = tr[0] + tr[2] * 1.0
			var c2: Vector2 = tr[0] + tr[1] * float(tr[3]) + tr[2] * 1.0
			if not (Geometry2D.is_point_in_polygon(ca, hall) or Geometry2D.is_point_in_polygon(c1, hall) or Geometry2D.is_point_in_polygon(c2, hall)):
				gardees.append(tr)
		travees = gardees
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
	var plans_hauts: Array = plans
	if hall.size() > 2:
		plans_hauts = []
		for p in plans:
			plans_hauts.append_array(Geometry2D.clip_polygons(p, hall))
	for j in etages.size():
		var y: float = etages[j]
		for p in (plans if j == 0 else plans_hauts):
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
		# la grande baie du hall dans la façade d'entrée
		if hall.size() > 2 and niveaux.size() > 0 and a.distance_to(HALL_A) < 1.0 and b.distance_to(HALL_B) < 1.0:
			ouvertures.append([lg * 0.5 - HALL_LARGE * 0.5, lg * 0.5 + HALL_LARGE * 0.5, niveaux[0], toit - 1.2])
		elif hall.size() > 2 and niveaux.size() > 0 and a.distance_to(HALL_B) < 1.0 and b.distance_to(HALL_A) < 1.0:
			ouvertures.append([lg * 0.5 - HALL_LARGE * 0.5, lg * 0.5 + HALL_LARGE * 0.5, niveaux[0], toit - 1.2])
		_mur_facade(a, b, bas, toit, u, moy, ouvertures, facade)
		u += lg
	for pt in portes:
		_marches_entree(poly, pt)
	if hall.size() > 2 and niveaux.size() > 0:
		_hall(poly, niveaux, toit)
	if nom == "Lycée":
		_sheds(poly, toit)
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
	_degradations(tr, y)
	# affiche (sans texte) près de la porte
	var ca := p_in + d * (lg * 0.5 + 1.1) - n_in * 0.09
	_ajouter("affiche_%d" % (j % 3), [Color(0.92, 0.80, 0.30), Color(0.85, 0.40, 0.35), Color(0.40, 0.62, 0.80)][j % 3], Transform3D(Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-n_in.x, 0, -n_in.y)) * Basis.from_scale(Vector3(0.6, 0.8, 0.02)), Vector3(ca.x, y + 1.6, ca.y)))


func _table(c: Vector2, y: float, b: Basis, l: float, p: float) -> void:
	_ajouter("table", C_TABLE, Transform3D(b * Basis.from_scale(Vector3(l, 0.04, p)), Vector3(c.x, y + 0.74, c.y)))
	for sx in [-1.0, 1.0]:
		var o: Vector3 = Vector3(c.x, y + 0.36, c.y) + b.x * float(sx) * (l * 0.5 - 0.05)
		_ajouter("pied", C_PIED, Transform3D(b * Basis.from_scale(Vector3(0.04, 0.72, p - 0.05)), o))
	_boite(b, Vector3(l, 0.76, p), Vector3(c.x, y + 0.38, c.y))


## Chaise d'époque : coque beige, structure en tube marron. Une sur huit est renversée, une sur dix a perdu son dossier.
func _chaise(c: Vector2, y: float, b: Basis) -> void:
	var r := _rng.randf()
	var bb := b * Basis(Vector3.UP, _rng.randf_range(-0.35, 0.35))
	var o := Vector3(c.x, y, c.y)
	if r < 0.12:
		bb = bb * Basis(Vector3.RIGHT, PI * 0.5)   # couchée sur le dos
		o += Vector3.UP * 0.2 - b.z * 0.3
	elif r < 0.18:
		bb = bb * Basis(Vector3.BACK, PI)          # posée à l'envers sur la table
		o += Vector3.UP * 1.2 - b.z * 0.55
	_ajouter("chaise", C_CHAISE, Transform3D(bb * Basis.from_scale(Vector3(0.42, 0.04, 0.40)), o + bb.y * 0.45))
	if _rng.randf() > 0.1:
		_ajouter("chaise", C_CHAISE.darkened(0.05), Transform3D(bb * Basis.from_scale(Vector3(0.40, 0.30, 0.04)), o + bb.y * 0.72 + bb.z * 0.2))
	for sx in [-0.18, 0.18]:
		for sz in [-0.16, 0.16]:
			_ajouter("pied", C_PIED, Transform3D(bb * Basis.from_scale(Vector3(0.025, 0.45, 0.025)), o + bb.y * 0.225 + bb.x * sx + bb.z * sz))
	_ajouter("pied", C_PIED, Transform3D(bb * Basis.from_scale(Vector3(0.025, 0.5, 0.025)), o + bb.y * 0.7 + bb.z * 0.21 + bb.x * 0.18))
	_ajouter("pied", C_PIED, Transform3D(bb * Basis.from_scale(Vector3(0.025, 0.5, 0.025)), o + bb.y * 0.7 + bb.z * 0.21 - bb.x * 0.18))


## Murs décrépis et tagués : plaques d'enduit tombé, traces, tags au marqueur, dalles de plafond tombées.
func _degradations(tr: Array, y: float) -> void:
	var a: Vector2 = tr[0]
	var d: Vector2 = tr[1]
	var n_in: Vector2 = tr[2]
	var lg: float = tr[3]
	var p_in := a + n_in * PROF_SALLE
	var bmur := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(n_in.x, 0, n_in.y))
	# enduit écaillé sur le mur du couloir (côté classe)
	for k in 1 + _rng.randi() % 3:
		var t := _rng.randf_range(0.6, lg - 0.6)
		var pe := p_in + d * t - n_in * 0.09
		var taille := Vector3(_rng.randf_range(0.3, 1.1), _rng.randf_range(0.2, 0.7), 0.02)
		_ajouter("ecaille", Color(0.78, 0.74, 0.66), Transform3D(bmur * Basis.from_scale(taille), Vector3(pe.x, y + _rng.randf_range(1.2, 2.8), pe.y)))
	# coulures grises en haut des murs
	var pc := p_in + d * _rng.randf_range(0.5, lg - 0.5) - n_in * 0.09
	_ajouter("coulure", Color(0.66, 0.65, 0.62), Transform3D(bmur * Basis.from_scale(Vector3(0.12, 1.4, 0.02)), Vector3(pc.x, y + 2.6, pc.y)))
	# tags au marqueur sur le mur du fond et sur le tableau
	if _rng.randf() < 0.7:
		var pt := p_in + d * _rng.randf_range(1.5, lg - 1.5) - n_in * 0.08
		_tag(Vector3(pt.x, y + _rng.randf_range(1.0, 2.0), pt.y), Vector3(d.x, 0, d.y), Vector3(-n_in.x, 0, -n_in.y))
	if _rng.randf() < 0.35:
		var ptb := a + n_in * (PROF_SALLE * 0.5 + _rng.randf_range(-1.0, 1.0)) + d * 0.14
		_tag(Vector3(ptb.x, y + 1.7, ptb.y), Vector3(n_in.x, 0, n_in.y), Vector3(d.x, 0, d.y))
	# dalle de faux plafond tombée par terre, et le trou au-dessus
	if _rng.randf() < 0.3:
		var pd := a + d * _rng.randf_range(2.0, lg - 1.0) + n_in * _rng.randf_range(1.0, PROF_SALLE - 1.0)
		_ajouter("plafond_tombe", Color(0.88, 0.87, 0.82), Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, 0.12) * Basis.from_scale(Vector3(0.6, 0.02, 0.6)), Vector3(pd.x, y + 0.04, pd.y)))
		_ajouter("trou_plafond", Color(0.22, 0.20, 0.20), Transform3D(Basis.from_scale(Vector3(0.6, 0.01, 0.6)), Vector3(pd.x + 0.3, y + ETAGE - DALLE - 0.01, pd.y)))


func _tag(o: Vector3, le_long: Vector3, dehors: Vector3) -> void:
	var chemin := GRAFF % ("tag_%02d" % (_rng.randi() % 14))
	if not ResourceLoader.exists(chemin):
		return
	var dec := Decal.new()
	dec.texture_albedo = load(chemin)
	dec.modulate = [Color(0.10, 0.10, 0.14), Color(0.15, 0.25, 0.65), Color(0.55, 0.12, 0.45), Color(0.15, 0.45, 0.25)][_rng.randi() % 4]
	var l := _rng.randf_range(0.7, 1.4)
	dec.size = Vector3(l, 0.4, l * 0.7)
	dec.distance_fade_enabled = true
	dec.distance_fade_begin = 18.0
	dec.distance_fade_length = 6.0
	dec.transform = Transform3D(Basis(le_long, dehors, le_long.cross(dehors)), o + dehors * 0.05)
	add_child(dec)


# ───────────────────────── le hall sous la verrière ─────────────────────────

func _hall(poly: PackedVector2Array, niveaux: Array[float], toit: float) -> void:
	var y0: float = niveaux[0]
	var d := (HALL_B - HALL_A).normalized()
	var m := (HALL_A + HALL_B) * 0.5
	var n_in := Vector2(-d.y, d.x)
	if not Geometry2D.is_point_in_polygon(m + n_in * 2.0, poly):
		n_in = -n_in
	var bx := Vector3(d.x, 0, d.y)
	var bz := Vector3(n_in.x, 0, n_in.y)
	var base := Basis(bx, Vector3.UP, bz)
	if base.determinant() < 0.0:
		bx = -bx
		base = Basis(bx, Vector3.UP, bz)
	var c := func(t: float, p: float, yy: float) -> Vector3:
		var q := m + Vector2(bx.x, bx.z) * t + n_in * p
		return Vector3(q.x, yy, q.y)
	# 1. sol : dalles grises sur tout le hall
	var tri := Geometry2D.triangulate_polygon(hall)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in tri:
		st.add_vertex(Vector3(hall[i].x, y0 + 0.01, hall[i].y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var md := ShaderMaterial.new()
	md.shader = DALLES
	mi.material_override = md
	mi.name = "Hall_dalles"
	add_child(mi)
	# 2. la verrière au plafond : charpente en treillis et vitrage clair, la lumière passe
	var hv := toit + 0.2
	var verre := StandardMaterial3D.new()
	verre.albedo_color = Color(0.80, 0.92, 0.98, 0.18)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	verre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var vit := MeshInstance3D.new()
	vit.mesh = _bm_v(Vector3(HALL_LARGE, 0.04, HALL_PROF))
	vit.material_override = verre
	vit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vit.transform = Transform3D(base, c.call(0.0, HALL_PROF * 0.5, hv))
	vit.name = "Hall_verriere"
	add_child(vit)
	for k in int(HALL_PROF / 2.0) + 1:
		_ajouter("verriere_fer", Color(0.78, 0.80, 0.82), Transform3D(base * Basis.from_scale(Vector3(HALL_LARGE, 0.12, 0.10)), c.call(0.0, k * 2.0, hv)))
	for k in 5:
		_ajouter("verriere_fer", Color(0.78, 0.80, 0.82), Transform3D(base * Basis.from_scale(Vector3(0.10, 0.25, HALL_PROF)), c.call(-HALL_LARGE * 0.5 + k * HALL_LARGE / 4.0, HALL_PROF * 0.5, hv - 0.1)))
	# 3. le CDI au fond : paroi vitrée sur toute la largeur, rayonnages, tables, au rez-de-chaussée
	var p_cdi := HALL_PROF - PROF_CDI
	_ajouter("cdi_cadre", Color(0.55, 0.58, 0.60), Transform3D(base * Basis.from_scale(Vector3(HALL_LARGE, 0.12, 0.12)), c.call(0.0, p_cdi, y0 + 2.9)))
	for k in 7:
		_ajouter("cdi_cadre", Color(0.55, 0.58, 0.60), Transform3D(base * Basis.from_scale(Vector3(0.08, 3.0, 0.1)), c.call(-HALL_LARGE * 0.5 + k * HALL_LARGE / 6.0, p_cdi, y0 + 1.5)))
	var vcdi := MeshInstance3D.new()
	vcdi.mesh = _bm_v(Vector3(HALL_LARGE - 2.0, 2.9, 0.03))
	vcdi.material_override = verre
	vcdi.transform = Transform3D(base, c.call(1.0, p_cdi, y0 + 1.45))
	add_child(vcdi)
	_boite(base, Vector3(HALL_LARGE - 2.0, 2.9, 0.08), c.call(1.0, p_cdi, y0 + 1.45))   # on n'entre que par la porte, à gauche
	var couleurs := [Color(0.70, 0.25, 0.22), Color(0.22, 0.38, 0.62), Color(0.85, 0.70, 0.25), Color(0.30, 0.52, 0.35), Color(0.88, 0.86, 0.80)]
	for r in 3:
		var pr: float = p_cdi + 2.0 + r * 1.8
		_ajouter("cdi_rayon", Color(0.52, 0.40, 0.28), Transform3D(base * Basis.from_scale(Vector3(HALL_LARGE - 3.0, 1.8, 0.4)), c.call(0.5, pr, y0 + 0.9)))
		_boite(base, Vector3(HALL_LARGE - 3.0, 1.8, 0.4), c.call(0.5, pr, y0 + 0.9))
		for e in 4:
			for k in 18:
				var t := -HALL_LARGE * 0.5 + 2.2 + k * 0.48
				_ajouter("cdi_livres_%d" % ((k + e + r) % 5), couleurs[(k + e + r) % 5], Transform3D(base * Basis.from_scale(Vector3(0.42, 0.28, 0.42)), c.call(t, pr, y0 + 0.25 + e * 0.42) + bz * 0.0))
	# 4. le grand escalier : une large volée droite contre le côté gauche du hall, jusqu'à la coursive
	if niveaux.size() > 1:
		var y1: float = niveaux[1]
		var monte := y1 - y0
		var large := 3.2
		var x_esc := -HALL_LARGE * 0.5 + large * 0.5 + 0.3
		var p_bas := 4.0
		var p_haut := p_cdi - 0.2
		var run := p_haut - p_bas
		var nb := int(round(monte / 0.17))
		for k in nb:
			var hk := (k + 1) * monte / nb
			_ajouter("hall_marche", Color(0.70, 0.70, 0.68), Transform3D(base * Basis.from_scale(Vector3(large, 0.17, run / nb + 0.02)), c.call(x_esc, p_bas + (k + 0.5) * run / nb, y0 + hk - 0.085)))
		_ajouter("hall_limon", Color(0.62, 0.62, 0.60), Transform3D(base * Basis(Vector3.RIGHT, -atan2(monte, run)) * Basis.from_scale(Vector3(large + 0.3, 0.35, sqrt(run * run + monte * monte))), c.call(x_esc, (p_bas + p_haut) * 0.5, y0 + monte * 0.5 - 0.3)))
		var rampe := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(large, 0.2, sqrt(run * run + monte * monte))
		cs.shape = sh
		rampe.add_child(cs)
		rampe.transform = Transform3D(base * Basis(Vector3.RIGHT, -atan2(monte, run)), c.call(x_esc, (p_bas + p_haut) * 0.5, y0 + monte * 0.5 - 0.1))
		rampe.name = "Hall_grand_escalier"
		add_child(rampe)
		# rambarde côté vide
		var lr := sqrt(run * run + monte * monte)
		_ajouter("hall_rambarde", Color(0.30, 0.32, 0.34), Transform3D(base * Basis(Vector3.RIGHT, -atan2(monte, run)) * Basis.from_scale(Vector3(0.06, 0.06, lr)), c.call(x_esc + large * 0.5, (p_bas + p_haut) * 0.5, y0 + monte * 0.5 + 0.95)))
		_boite(base * Basis(Vector3.RIGHT, -atan2(monte, run)), Vector3(0.08, 1.0, lr), c.call(x_esc + large * 0.5, (p_bas + p_haut) * 0.5, y0 + monte * 0.5 + 0.5))
		# 5. la coursive à l'étage, au-dessus du CDI, avec garde-corps sur le vide du hall
		_ajouter("hall_coursive", C_SOL, Transform3D(base * Basis.from_scale(Vector3(HALL_LARGE, DALLE, PROF_CDI + 0.2)), c.call(0.0, p_cdi + PROF_CDI * 0.5 - 0.1, y1 - DALLE * 0.5)))
		_boite(base, Vector3(HALL_LARGE, DALLE, PROF_CDI + 0.2), c.call(0.0, p_cdi + PROF_CDI * 0.5 - 0.1, y1 - DALLE * 0.5))
		_ajouter("hall_coursive", C_PLAFOND, Transform3D(base * Basis.from_scale(Vector3(HALL_LARGE, 0.02, PROF_CDI)), c.call(0.0, p_cdi + PROF_CDI * 0.5, y1 - DALLE - 0.01)))
		var lg_gc := HALL_LARGE - large - 0.3
		_ajouter("hall_rambarde", Color(0.30, 0.32, 0.34), Transform3D(base * Basis.from_scale(Vector3(lg_gc, 0.06, 0.06)), c.call(HALL_LARGE * 0.5 - lg_gc * 0.5, p_cdi - 0.15, y1 + 1.0)))
		for k in int(lg_gc / 0.15):
			_ajouter("hall_rambarde", Color(0.30, 0.32, 0.34), Transform3D(base * Basis.from_scale(Vector3(0.025, 1.0, 0.025)), c.call(HALL_LARGE * 0.5 - lg_gc + k * 0.15, p_cdi - 0.15, y1 + 0.5)))
		_boite(base, Vector3(lg_gc, 1.0, 0.1), c.call(HALL_LARGE * 0.5 - lg_gc * 0.5, p_cdi - 0.15, y1 + 0.5))
	# 7. le perron devant la baie : de larges marches du trottoir au niveau du hall
	var dehors: Vector3 = c.call(0.0, -1.0, 0.0)
	var y_out := h(dehors.x, dehors.z)
	if y0 - y_out > 0.1:
		var nbm := int(ceil((y0 - y_out) / 0.16))
		for k in nbm:
			var hk := y0 - k * (y0 - y_out) / nbm
			var bas := y_out - 0.4
			var taille := Vector3(HALL_LARGE, hk - bas, 0.34)
			var o: Vector3 = c.call(0.0, -0.17 - k * 0.34, bas + taille.y * 0.5)
			_ajouter("hall_perron", Color(0.66, 0.66, 0.64), Transform3D(base * Basis.from_scale(taille), o))
			_boite(base, taille, o)
	# 6. bancs le long des murs, un grand vide au milieu
	for k in 3:
		_ajouter("hall_banc", Color(0.62, 0.60, 0.56), Transform3D(base * Basis.from_scale(Vector3(0.5, 0.45, 2.4)), c.call(HALL_LARGE * 0.5 - 0.5, 4.0 + k * 4.5, y0 + 0.225)))
		_boite(base, Vector3(0.5, 0.45, 2.4), c.call(HALL_LARGE * 0.5 - 0.5, 4.0 + k * 4.5, y0 + 0.225))
	print("Lycée : hall sous la verrière, CDI au fond, grand escalier")


## Toiture des ateliers en dents de scie (vue satellite) : derrière la façade du boulevard, sur ~60 m,
## des rangées de sheds parallèles à la façade, la face vitrée tournée vers le boulevard (nord-est).
const SHED_PAS := 6.0
const SHED_H := 2.2

func _sheds(poly: PackedVector2Array, toit: float) -> void:
	var d := (HALL_B - HALL_A).normalized()
	var n_in := Vector2(-d.y, d.x)
	if not Geometry2D.is_point_in_polygon((HALL_A + HALL_B) * 0.5 + n_in * 2.0, poly):
		n_in = -n_in
	var zone: Array = [poly]
	if hall.size() > 2:
		zone = Geometry2D.clip_polygons(poly, hall)
	var prisme := _prisme()
	var vitre := Color(0.45, 0.58, 0.66)
	var liste := []
	var verres := []
	var k := 1
	while k * SHED_PAS < 62.0:
		var off := 4.0 + (k - 1) * SHED_PAS
		var a := HALL_A + n_in * off - d * 200.0
		var b := HALL_A + n_in * off + d * 200.0
		for z in zone:
			if (z as PackedVector2Array).size() < 3:
				continue
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), z):
				if seg.size() < 2:
					continue
				var p0: Vector2 = seg[0]
				var p1: Vector2 = seg[seg.size() - 1]
				var lg := p0.distance_to(p1)
				if lg < 3.0:
					continue
				# il faut que la dent entière tienne sur le toit
				var mid := (p0 + p1) * 0.5
				if not Geometry2D.is_point_in_polygon(mid + n_in * (SHED_PAS - 0.3), z):
					continue
				var dx := (p1 - p0) / lg
				var bx := Vector3(dx.x, 0, dx.y)
				var bz := Vector3(n_in.x, 0, n_in.y)
				var base := Basis(bx, Vector3.UP, bz)
				var o := Vector3(mid.x, toit, mid.y)
				liste.append(Transform3D(base * Basis.from_scale(Vector3(lg, SHED_H, SHED_PAS)), o))
				verres.append(Transform3D(base * Basis.from_scale(Vector3(lg - 0.4, SHED_H - 0.5, 0.05)), o + Vector3.UP * (SHED_H * 0.5 + 0.05) - bz * 0.03))
		k += 1
	for lot in [["sheds", prisme, Color(0.70, 0.71, 0.70), liste], ["sheds_vitres", _cube, vitre, verres]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = lot[1]
		mm.instance_count = (lot[3] as Array).size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, lot[3][i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _mat(lot[2])
		mi.name = "Lycee_" + lot[0]
		add_child(mi)
	print("Lycée : %d rangées de sheds sur les ateliers" % liste.size())


## Prisme unité : x de -0,5 à 0,5 (longueur), face verticale en z = 0 (hauteur 1), pente jusqu'à z = 1.
func _prisme() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0), Vector3(-0.5, 0, 1), Vector3(0.5, 0, 1)]
	var faces := [[0, 2, 1], [0, 3, 2], [3, 5, 2], [3, 4, 5], [0, 4, 3], [1, 2, 5]]
	for f in faces:
		for i in f:
			st.add_vertex(v[i])
	st.generate_normals()
	return st.commit()


func _bm_v(t: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = t
	return b


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
