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
## Salles de classe de 8 m x 9 m (72 m², 30 élèves), cages d'escalier de 6 m de fond.
const PROF_SALLE := 8.0
const LONG_TRAVEE := 9.0
const PROF_CAGE := 6.0
const LONG_ESCALIER := 10.0
const PALIER := 1.6
const LYCEES := ["Lycée", "Lycée sud"]
const DALLES := preload("res://shaders/dalles.gdshader")
const GRAFF := "res://assets/decor/graff/%s.png"
## Le hall sous la grande verrière (entrée côté boulevard Lavéran) : 12 m de large, 26 m de profondeur.
## Derrière la façade : un grand vide sur toute la hauteur, dalles grises, verrière au plafond ;
## au fond le CDI derrière une paroi vitrée, et le grand escalier qui monte à la coursive des étages.
var HALL_A := Vector2(149.0, 119.0)   # côté de façade du relevé qui porte l'entrée (reculé par le parvis, voir _creuser_parvis)
var HALL_B := Vector2(108.0, 64.0)
## Le parvis d'avant les travaux (Street View mars 2011, photo « Diderot tire la sonnette d'alarme ») : la verrière
## n'est pas sur le boulevard. On passe le portail, on descend des gradins (où les élèves s'assoient) ou la rampe
## à parapet blanc, et on arrive sur une cour dallée au pied du pignon vitré, devant un petit sas vitré.
const PARVIS_PROF := 13.0    # recul de la verrière derrière la façade du relevé
const PARVIS_LARGE := 26.0   # largeur du creux entre les deux ailes
var _parvis_actif := false
const HALL_LARGE := 12.0
## La nef : la longueur se règle sur la place disponible dans le contour (de 26 à 40 m).
var HALL_PROF := 26.0
const COURSIVE := 2.6
const PROF_CDI := 7.0
const RAMPE_LONG := 6.0     # du portail (sur le trottoir) à la baie de la verrière
const RAMPE_LARGE := 6.4

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
var hall_y := 0.0         # sol du hall : plus bas que le rez-de-chaussée, on y descend depuis le boulevard
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
	if nom == "Lycée":
		poly = _creuser_parvis(poly)
		HALL_PROF = _longueur_nef(poly)
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
	# Street View juillet 2013 : du trottoir, on passe le grand portail et on DESCEND tout droit dans le hall vitré.
	# Le sol du hall est donc un mètre sous le trottoir (sans passer sous le terrain naturel du hall).
	hall_y = niveaux[0] if niveaux.size() > 0 else moy
	if hall.size() > 2:
		var mh := (HALL_A + HALL_B) * 0.5
		var dh := (HALL_B - HALL_A).normalized()
		var inh := Vector2(-dh.y, dh.x)
		if not Geometry2D.is_point_in_polygon(mh + inh * 2.0, poly):
			inh = -inh
		var y_rue := h(mh.x - inh.x * 6.0, mh.y - inh.y * 6.0)
		var t_hall := -INF
		for kx in 13:
			for j in int(HALL_PROF) + 1:
				var q := mh + dh * (kx - 6.0) + inh * float(j)
				if Geometry2D.is_point_in_polygon(q, hall):
					t_hall = maxf(t_hall, h(q.x, q.y))
		hall_y = maxf(y_rue - 1.0, t_hall + 0.05)
		# Les étages se calent sur le sol de la nef (Louma, 21.11 : un vrai lycée, R+2 et le toit) : la nef est
		# le rez-de-chaussée bas ; le premier étage (R+1) passe au-dessus du terrain le plus haut, puis le R+2.
		niveaux.clear()
		var kk := 1
		while hall_y + kk * ETAGE <= toit - 3.0:
			if hall_y + kk * ETAGE >= t_max + 0.2:
				niveaux.append(hall_y + kk * ETAGE)
			kk += 1
	print("Lycée : %s, niveaux %s, toit %.2f" % [nom, str(niveaux), toit])
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
				travees.append([a + d * t, d, n_in, LONG_ESCALIER, true, i])
				t += LONG_ESCALIER
				dernier_escalier = cumul
			var reste := t1 - t
			var nb := maxi(1, int(round(reste / LONG_TRAVEE)))
			var lt := reste / nb
			if reste >= 4.0:
				for j in nb:
					travees.append([a + d * (t + j * lt), d, n_in, lt, false, i])
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
			var trou := PackedVector2Array([a - n_in, a + d * tr[3] - n_in, a + d * tr[3] + n_in * PROF_CAGE, a + n_in * PROF_CAGE])
			var suivant: Array = []
			for p in plans:
				suivant.append_array(Geometry2D.clip_polygons(p, trou))
			plans = suivant
	var etages := niveaux.duplicate()
	etages.append(toit)
	var plans_hauts: Array = plans
	if hall.size() > 2:
		plans_hauts = []
		# le trou de la nef déborde du pignon de 2 m : sinon le découpage rend un « trou » fermé (polygone
		# horaire) que la triangulation remplit, et les planchers couvraient toute la nef
		var dh := (HALL_B - HALL_A).normalized()
		var mh := (HALL_A + HALL_B) * 0.5
		var ih := Vector2(-dh.y, dh.x)
		if not Geometry2D.is_point_in_polygon(mh + ih * 2.0, poly):
			ih = -ih
		var w2 := HALL_LARGE * 0.5
		var trou_nef := PackedVector2Array([mh - dh * w2 - ih * 2.0, mh + dh * w2 - ih * 2.0, mh + dh * w2 + ih * HALL_PROF, mh - dh * w2 + ih * HALL_PROF])
		for p in plans:
			for r in Geometry2D.clip_polygons(p, trou_nef):
				if not Geometry2D.is_polygon_clockwise(r):
					plans_hauts.append(r)
	for j in etages.size():
		var y: float = etages[j]
		for p in (plans if j == 0 and niveaux.size() > 0 and niveaux[0] - hall_y < 0.3 else plans_hauts):
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
			ouvertures.append([lg * 0.5 - HALL_LARGE * 0.5, lg * 0.5 + HALL_LARGE * 0.5, hall_y, toit - 1.2])
		elif hall.size() > 2 and niveaux.size() > 0 and a.distance_to(HALL_B) < 1.0 and b.distance_to(HALL_A) < 1.0:
			ouvertures.append([lg * 0.5 - HALL_LARGE * 0.5, lg * 0.5 + HALL_LARGE * 0.5, hall_y, toit - 1.2])
		# les fenêtres des salles : une grande baie par salle et par étage, si le terrain dehors ne la couvre pas
		var d_i := (b - a) / lg
		var n_i := Vector2(-d_i.y, d_i.x)
		for tr in travees:
			if tr[5] != i or tr[4]:
				continue
			var t_deb: float = (tr[0] as Vector2 - a).dot(d_i)
			var t_fin: float = t_deb + float(tr[3])
			var porte_ici := false
			for pt in portes:
				if pt[0] == i and pt[1] > t_deb - 1.4 and pt[1] < t_fin + 1.4:
					porte_ici = true
			if porte_ici:
				continue
			var t_c := (t_deb + t_fin) * 0.5
			var w := minf(float(tr[3]) - 2.2, 5.4)
			for y_n in niveaux:
				var dehors := a + d_i * t_c - n_i * 1.2
				if h(dehors.x, dehors.y) > y_n + 0.6 or y_n + 2.8 > toit - 0.4:
					continue
				ouvertures.append([t_c - w * 0.5, t_c + w * 0.5, y_n + 0.95, y_n + 2.75])
				_fenetre(a + d_i * t_c + n_i * 0.15, d_i, n_i, w, y_n + 0.95, y_n + 2.75)
		var mat_face: Material = facade
		if hall.size() > 2 and ((a.distance_to(HALL_A)<1. and b.distance_to(HALL_B)<1.) or (a.distance_to(HALL_B)<1. and b.distance_to(HALL_A)<1.)):
			var email := ShaderMaterial.new()
			email.shader = preload("res://shaders/diderot_ceramique.gdshader")
			email.set_shader_parameter("aile",true)
			mat_face = email
		_mur_facade(a, b, bas, toit, u, moy, ouvertures, mat_face)
		u += lg
	for pt in portes:
		_marches_entree(poly, pt)
	if hall.size() > 2 and niveaux.size() > 0:
		_hall(poly, niveaux, toit)
	if nom == "Lycée":
		_sheds(poly, toit)
	# — intérieur, étage par étage —
	# le cœur des étages (salles sur la nef et le long des couloirs), puis les salles de façade qu'il recouvre
	_coeur.clear()
	if hall.size() > 2:
		_plan_coeur(poly, travees)
		var gardees2 := []
		for tr in travees:
			var garde := true
			if not tr[4]:
				for r in _coeur:
					if _recouvre(r[5], _contour_travee(tr, PROF_SALLE)):
						garde = false
						break
			if garde:
				gardees2.append(tr)
		travees = gardees2
	# le toit est une terrasse : acrotère tout autour (on y monte par les cages d'escalier)
	_acrotere(poly, toit)
	var n_cl := 0
	for j in niveaux.size():
		var y: float = niveaux[j]
		var cantine := nom == "Lycée sud" and j == 0
		var nef_ici := hall.size() > 2
		if cantine:
			_cantine(poly, y, travees)
		for tr in travees:
			if tr[4]:
				_cage(tr, etages, j)
			elif cantine:
				continue
			else:
				n_cl += 1
				var prof := _profondeur_vers_nef(tr) if nef_ici else PROF_SALLE
				if n_cl % 9 == 4 and prof == PROF_SALLE:
					_sanitaires(tr, y, j)
				else:
					_salle(tr, y, j, prof)
		if hall.size() > 2:
			_salles_nef(poly, y, j)
	# l'arrivée des cages sur le toit-terrasse : paliers et garde-corps autour de la trémie
	for tr in travees:
		if tr[4]:
			_cage(tr, etages, etages.size() - 1)


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
			if ecart > -0.4 and ecart < 1.3:   # plus d escaliers de 4 m qui sortent dans la rue ou traversent la clôture
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
	# découpe en rectangles pleins autour des ouvertures, colonne par colonne (une colonne = une même largeur,
	# avec une ouverture par étage : la porte ou les fenêtres superposées)
	var colonnes := {}
	for o in ouvertures:
		var cle := Vector2(snappedf(float(o[0]), 0.01), snappedf(float(o[1]), 0.01))
		if not colonnes.has(cle):
			colonnes[cle] = []
		colonnes[cle].append([float(o[2]), float(o[3])])
	var cles := colonnes.keys()
	cles.sort_custom(func(p, q): return p.x < q.x)
	var pieces := []
	var t := 0.0
	for cle in cles:
		if cle.x < t - 0.01:
			continue   # chevauche la colonne précédente : ignorée
		pieces.append([t, cle.x, bas, haut])
		var trous: Array = colonnes[cle]
		trous.sort_custom(func(p, q): return p[0] < q[0])
		var y := bas
		for tr in trous:
			pieces.append([cle.x, cle.y, y, maxf(y, tr[0])])
			y = maxf(y, tr[1])
		pieces.append([cle.x, cle.y, y, haut])
		t = cle.y
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
			var origine_y := h(p.x, p.y) if m is ShaderMaterial and m.shader == preload("res://shaders/diderot_ceramique.gdshader") else moy
			q.append([Vector3(p.x, c[1], p.y), Vector2(u + c[0], c[1] - origine_y), Vector2(c[0], lg)])
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

func _salle(tr: Array, y: float, j: int, prof := PROF_SALLE) -> void:
	var a: Vector2 = tr[0]
	var d: Vector2 = tr[1]
	var n_in: Vector2 = tr[2]
	var lg: float = tr[3]
	var hh := ETAGE - DALLE
	var p_in := a + n_in * prof
	# mur sur le couloir avec la porte, cloison de début de travée
	_cloison(p_in, p_in + d * lg, y, hh, 1.1)
	_cloison(a + n_in * 0.15, p_in, y, hh)
	_cloison(a + d * lg + n_in * 0.15, p_in + d * lg, y, hh)
	n_salles += 1
	# tableau vert sur la cloison de début
	var bt := Basis(Vector3(n_in.x, 0, n_in.y), Vector3.UP, Vector3(d.x, 0, d.y))
	var ct := a + n_in * (prof * 0.5) + d * 0.1
	_ajouter("tableau", C_TABLEAU, Transform3D(bt * Basis.from_scale(Vector3(3.0, 1.2, 0.05)), Vector3(ct.x, y + 1.6, ct.y)))
	_ajouter("pied", C_PIED, Transform3D(bt * Basis.from_scale(Vector3(3.2, 0.06, 0.12)), Vector3(ct.x, y + 0.98, ct.y) + Vector3(d.x, 0, d.y) * 0.06))
	# bureau du prof, puis rangées de tables doubles face au tableau
	var bd := Basis(Vector3(n_in.x, 0, n_in.y), Vector3.UP, Vector3(d.x, 0, d.y))
	var cb := a + n_in * (prof * 0.5) + d * 1.4
	_table(cb, y, bd, 1.4, 0.7)
	var rangs := int((lg - 2.6) / 1.4)
	var cols := clampi(int((prof - 2.0) / 2.4), 2, 4)
	for r in rangs:
		for col in cols:
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
	var c: Color = [Color(0.10, 0.10, 0.14), Color(0.15, 0.25, 0.65), Color(0.55, 0.12, 0.45), Color(0.15, 0.45, 0.25)][_rng.randi() % 4]
	preload("res://scripts/marque_murale.gd").poser(self, load(chemin), o, le_long, dehors, _rng.randf_range(0.7, 1.4), c, 18.0, 0, "Tag_classe")


# ───────────────────────── le hall sous la verrière ─────────────────────────

func _hall(poly: PackedVector2Array, niveaux: Array[float], toit: float) -> void:
	var y0: float = hall_y
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
	_nm = m
	_nbx = Vector2(bx.x, bx.z)
	_nin = n_in
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
	# le sol du hall porte Loums (le terrain dessous peut être plus bas, creusé pour le parvis)
	var cs_sol := CollisionShape3D.new()
	cs_sol.shape = mi.mesh.create_trimesh_shape()
	_corps.add_child(cs_sol)
	var verre := _verre()
	# 2. LA VERRIÈRE (Street View mai 2011) : une galerie vitrée à profil polygonal (côtés droits,
	#    pans coupés, dessus plat) qui couvre tout le hall et dépasse du toit ; pignon avant entièrement vitré,
	#    bandeau de petits carreaux en bas, porte au milieu ; devant, deux poteaux ronds qui s'ouvrent en
	#    bras de fer vers le pignon. La lumière passe : le verre ne fait pas d'ombre.
	_verriere(c, base, bx, bz, y0, toit)
	# 3 à 5. la nef : coursives, CDI au fond, grand escalier, passerelles (voir _nef)
	_nef(c, base, y0, niveaux, toit)
	# 7. l'entrée : du trottoir (derrière le grand portail, à 6 m) une large rampe DESCEND droit dans le hall,
	#    entre deux murets carrelés à bande turquoise (Street View juillet 2013). Si le hall est plus haut que
	#    la rue, on garde un perron de marches.
	if _parvis_actif:
		_parvis(c, base, y0)
	else:
		var dehors: Vector3 = c.call(0.0, -RAMPE_LONG, 0.0)
		var y_out := h(dehors.x, dehors.z)
		if y_out > y0 + 0.15:
			var monte := y_out - y0
			var lr := sqrt(RAMPE_LONG * RAMPE_LONG + monte * monte)
			var incl := Basis(Vector3.RIGHT, atan2(monte, RAMPE_LONG))
			var o_r: Vector3 = c.call(0.0, -RAMPE_LONG * 0.5, y0 + monte * 0.5 - 0.15)
			_ajouter("hall_rampe", Color(0.64, 0.64, 0.62), Transform3D(base * incl * Basis.from_scale(Vector3(RAMPE_LARGE, 0.3, lr + 0.1)), o_r))
			_boite(base * incl, Vector3(RAMPE_LARGE, 0.3, lr + 0.1), o_r)
			# stries antidérapantes
			for k in int(RAMPE_LONG / 0.6):
				var pk := -0.3 - k * 0.6
				_ajouter("hall_rampe_strie", Color(0.52, 0.52, 0.50), Transform3D(base * Basis.from_scale(Vector3(RAMPE_LARGE - 0.4, 0.02, 0.08)), c.call(0.0, pk, y0 - pk / RAMPE_LONG * monte + 0.01)))
			# murets carrelés de part et d'autre, à hauteur constante au-dessus du trottoir
			for sx in [-1.0, 1.0]:
				var x_m: float = sx * (RAMPE_LARGE * 0.5 + 0.15)
				var haut := y_out + 0.9
				var o_m: Vector3 = c.call(x_m, -RAMPE_LONG * 0.5, (y0 - 0.4 + haut) * 0.5)
				_ajouter("hall_muret_carrelage", Color(0.90, 0.91, 0.89), Transform3D(base * Basis.from_scale(Vector3(0.3, haut - y0 + 0.4, RAMPE_LONG)), o_m))
				_boite(base, Vector3(0.3, haut - y0 + 0.4, RAMPE_LONG), o_m)
				_ajouter("hall_muret_turquoise", Color(0.36, 0.70, 0.68), Transform3D(base * Basis.from_scale(Vector3(0.32, 0.3, RAMPE_LONG + 0.02)), c.call(x_m, -RAMPE_LONG * 0.5, haut - 0.15)))
				for j in 4:
					_ajouter("hall_muret_joint", Color(0.76, 0.77, 0.76), Transform3D(base * Basis.from_scale(Vector3(0.31, 0.02, RAMPE_LONG)), c.call(x_m, -RAMPE_LONG * 0.5, haut - 0.6 - j * 0.3)))
		elif y0 - y_out > 0.1:
			var nbm := int(ceil((y0 - y_out) / 0.16))
			for k in nbm:
				var hk := y0 - k * (y0 - y_out) / nbm
				var bas := y_out - 0.4
				var taille := Vector3(HALL_LARGE, hk - bas, 0.34)
				var o: Vector3 = c.call(0.0, -0.17 - k * 0.34, bas + taille.y * 0.5)
				_ajouter("hall_perron", Color(0.66, 0.66, 0.64), Transform3D(base * Basis.from_scale(taille), o))
				_boite(base, taille, o)
	# 8. le hall est plus bas que le rez-de-chaussée : un soubassement ferme ses côtés et son fond
	if niveaux[0] - y0 > 0.3:
		for i in hall.size():
			var a2 := hall[i]
			var b2 := hall[(i + 1) % hall.size()]
			var mm := (a2 + b2) * 0.5
			if Geometry2D.get_closest_point_to_segment(mm, HALL_A, HALL_B).distance_to(mm) < 1.0:
				continue   # le côté de la verrière reste ouvert
			var dd := (b2 - a2)
			var lg2 := dd.length()
			if lg2 < 0.2:
				continue
			var nn := Vector2(-dd.y, dd.x) / lg2
			if Geometry2D.is_point_in_polygon(mm + nn * 0.5, hall):
				nn = -nn
			var bs := Basis(Vector3(dd.x / lg2, 0, dd.y / lg2), Vector3.UP, Vector3(nn.x, 0, nn.y)).orthonormalized()
			var hh2: float = niveaux[0] - y0 + 0.3
			var oc := Vector3(mm.x + nn.x * 0.15, y0 - 0.3 + hh2 * 0.5, mm.y + nn.y * 0.15)
			_ajouter("hall_soubassement", C_PLINTHE, Transform3D(bs * Basis.from_scale(Vector3(lg2, hh2, 0.3)), oc))
			_boite(bs, Vector3(lg2, hh2, 0.3), oc)
	print("Lycée : hall sous la verrière, CDI au fond, grand escalier")


## Creuse le parvis dans le contour du relevé : la façade du boulevard recule de PARVIS_PROF sur PARVIS_LARGE,
## les deux ailes l'encadrent, et le pignon de la verrière devient le fond du creux.
func _creuser_parvis(poly: PackedVector2Array) -> PackedVector2Array:
	var d0 := (HALL_B - HALL_A).normalized()
	var m0 := (HALL_A + HALL_B) * 0.5
	var in0 := Vector2(-d0.y, d0.x)
	if not Geometry2D.is_point_in_polygon(m0 + in0 * 2.0, poly):
		in0 = -in0
	var demi := PARVIS_LARGE * 0.5
	var creux := PackedVector2Array([m0 - d0 * demi - in0 * 2.0, m0 + d0 * demi - in0 * 2.0, m0 + d0 * demi + in0 * PARVIS_PROF, m0 - d0 * demi + in0 * PARVIS_PROF])
	var morceaux := Geometry2D.clip_polygons(poly, creux)
	var garde := PackedVector2Array()
	for m in morceaux:
		if not Geometry2D.is_polygon_clockwise(m) or morceaux.size() == 1:
			if m.size() > garde.size() or absf(_aire(m)) > absf(_aire(garde)):
				garde = m
	if garde.size() < 3:
		return poly
	# le découpage laisse des sommets alignés sur le fond du creux : on les retire, sinon le pignon est coupé
	# en deux côtés, la baie de la verrière n'est pas percée et l'on bute contre un mur de béton (Louma, 21.11)
	var net := PackedVector2Array()
	for i in garde.size():
		var p0 := garde[(i - 1 + garde.size()) % garde.size()]
		var p1 := garde[i]
		var p2 := garde[(i + 1) % garde.size()]
		if absf((p1 - p0).normalized().cross((p2 - p1).normalized())) > 0.02 and p1.distance_to(p0) > 0.05:
			net.append(p1)
	garde = net
	# le fond du creux porte la verrière : le plus long côté du contour posé sur la ligne du fond devient
	# HALL_A / HALL_B (le relevé a une encoche près d'un coin : le fond peut être plus court que le creux)
	var fa := HALL_A
	var fb := HALL_B
	var meilleur := 0.0
	for i in garde.size():
		var q0 := garde[i]
		var q1 := garde[(i + 1) % garde.size()]
		if absf((q0 - m0).dot(in0) - PARVIS_PROF) < 0.3 and absf((q1 - m0).dot(in0) - PARVIS_PROF) < 0.3 and q0.distance_to(q1) > meilleur:
			meilleur = q0.distance_to(q1)
			# même sens que l'ancien côté (HALL_A -> HALL_B)
			if (q1 - q0).dot(d0) > 0.0:
				fa = q0
				fb = q1
			else:
				fa = q1
				fb = q0
	print("Lycée : pignon de la verrière sur %.1f m" % meilleur)
	HALL_A = fa
	HALL_B = fb
	_parvis_actif = true
	return garde


## Avant de bâtir le terrain (appelé par quartier_reel.gd) : le creux du parvis et le hall sont abaissés de
## PARVIS_CHUTE sous le trottoir du portail ; raccord sur un mètre et demi aux bords du creux.
const PARVIS_CHUTE := 2.0
static func creuser_terrain(q: Node) -> void:
	var fa := Vector2(149.0, 119.0)
	var fb := Vector2(108.0, 64.0)
	var d0 := (fb - fa).normalized()
	var m0 := (fa + fb) * 0.5
	var in0 := Vector2(-d0.y, d0.x)
	# l'intérieur du lycée est à l'ouest du boulevard : côté opposé à la chaussée (x croissant)
	if in0.x > 0.0:
		in0 = -in0
	var porte := m0 - in0 * 4.8
	var cible: float = q.h(porte.x, porte.y) - PARVIS_CHUTE
	var gx: PackedFloat32Array = q.gx
	var gz: PackedFloat32Array = q.gz
	var alt: Array = q.alt
	var demi := PARVIS_LARGE * 0.5
	var n := 0
	for j in gz.size():
		var ligne: PackedFloat32Array = alt[j]
		for i in gx.size():
			var v := Vector2(gx[i], gz[j]) - m0
			var t := absf(v.dot(d0))
			var pp := v.dot(in0)
			# seulement derrière l'ancienne façade : le trottoir et la clôture restent à leur niveau (sinon bosse)
			if pp < -0.5 or pp > PARVIS_PROF + 40.0 or t > demi + 1.5:
				continue
			var w := 1.0 - smoothstep(demi, demi + 1.5, t)
			w *= clampf((pp + 0.5) / 0.5, 0.0, 1.0)
			if ligne[i] > cible:
				ligne[i] = lerpf(ligne[i], cible, w)
				n += 1
		alt[j] = ligne
	q.alt = alt
	print("Lycée : terrain du parvis abaissé (%d points, cote %.2f)" % [n, cible])


## Même règle que la clôture (habillage_laveran.gd) : 6 m devant la façade, ou moins pour garder 2 m de trottoir.
const AXE_LAVERAN := [Vector2(133, 52), Vector2(138, 82), Vector2(147, 100), Vector2(241, 212)]
func _retrait_cloture(p: Vector2) -> float:
	var meilleur := INF
	for k in AXE_LAVERAN.size() - 1:
		meilleur = minf(meilleur, Geometry2D.get_closest_point_to_segment(p, AXE_LAVERAN[k], AXE_LAVERAN[k + 1]).distance_to(p))
	return clampf(meilleur - 6.0 - 2.0, 0.8, 6.0)


func _aire(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


## Le parvis, dans le repère du hall : t le long du pignon (largeur), p vers l'intérieur (p = 0 : le pignon vitré,
## p = -PARVIS_PROF : l'ancienne façade, p = -PARVIS_PROF - 6 : la grille et le portail du boulevard).
## À gauche (t < 6,5) : les gradins, larges et bas, où l'on s'assoit ; à droite : la rampe, bordée d'un parapet blanc.
## En bas : la cour dallée et le sas vitré à double porte au pied de la verrière.
func _parvis(c: Callable, base: Basis, y0: float) -> void:
	var demi := PARVIS_LARGE * 0.5
	var p_haut := -PARVIS_PROF            # le haut des gradins, au ras de l'ancienne façade
	var porte: Vector3 = c.call(0.0, p_haut - 4.8, 0.0)   # le portail (la clôture recule à 4,8 m ici)
	var y_rue := h(porte.x, porte.z)
	# le palier part exactement au niveau du trottoir devant le portail (sinon une marche de 20 cm bloque Loums)
	y_rue += 0.03
	# la cour : au moins au niveau du hall, jamais sous le terrain
	var y_cour := y0
	for kt in range(-12, 13, 2):
		for kp in range(-7, 1):
			var q: Vector3 = c.call(float(kt), float(kp), 0.0)
			y_cour = maxf(y_cour, h(q.x, q.z) + 0.03)
	var chute := maxf(y_rue - y_cour, 0.0)
	# le haut : un palier du portail jusqu'aux gradins, au niveau du trottoir. Il s'arrête à la clôture, qui suit le
	# boulevard (habillage_laveran.gd : 2 m de trottoir au moins) ; avant, il débordait sur le trottoir et la rue.
	var kt := -demi - 1.5
	while kt < demi + 1.5:
		var q0: Vector3 = c.call(kt + 1.0, p_haut, 0.0)
		var f := _retrait_cloture(Vector2(q0.x, q0.z))
		var prof_p := f + 0.5 - 0.2
		var o_pal: Vector3 = c.call(kt + 1.0, p_haut + 0.5 - prof_p * 0.5, y_rue - 0.2)
		_ajouter("parvis_dalle", Color(0.74, 0.72, 0.67), Transform3D(base * Basis.from_scale(Vector3(2.02, 0.4, prof_p)), o_pal))
		_boite(base, Vector3(2.02, 0.4, prof_p), o_pal)
		kt += 2.0
	# les gradins : marches de 0,40 m sur 0,90 m (assises), côté gauche
	var t_g0 := -demi
	var t_g1 := 6.2
	var lg_g := t_g1 - t_g0
	var nb := maxi(2, int(round(chute / 0.4)))
	var marche := chute / nb if chute > 0.05 else 0.0
	var prof := 0.9
	for k in nb:
		var y_top := y_rue - (k + 1) * marche
		var p_k := p_haut + 0.5 + k * prof
		var bas := y_cour - 0.6
		var taille := Vector3(lg_g, y_top - bas, prof)
		var o: Vector3 = c.call((t_g0 + t_g1) * 0.5, p_k + prof * 0.5, bas + taille.y * 0.5)
		_ajouter("parvis_gradin", Color(0.78, 0.77, 0.73), Transform3D(base * Basis.from_scale(taille), o))
		_ajouter("parvis_nez", Color(0.62, 0.61, 0.58), Transform3D(base * Basis.from_scale(Vector3(lg_g, 0.04, 0.06)), c.call((t_g0 + t_g1) * 0.5, p_k + 0.03, y_top - 0.02)))
		_boite(base, taille, o)
	var p_cour := p_haut + 0.5 + nb * prof
	# la cour dallée, des gradins au pignon, sur toute la largeur
	var lg_cour := -p_cour
	var o_c: Vector3 = c.call(0.0, p_cour + lg_cour * 0.5, y_cour - 0.2)
	_ajouter("parvis_dalle", Color(0.70, 0.69, 0.66), Transform3D(base * Basis.from_scale(Vector3(PARVIS_LARGE, 0.4, lg_cour + 0.1)), o_c))
	_boite(base, Vector3(PARVIS_LARGE, 0.4, lg_cour + 0.1), o_c)
	# calepinage : bandes grises dans le sens de la descente, comme sur la photo
	for k in 9:
		var t := -demi + 1.5 + k * 3.0
		_ajouter("parvis_bande", Color(0.55, 0.55, 0.54), Transform3D(base * Basis.from_scale(Vector3(0.35, 0.02, lg_cour)), c.call(t, p_cour + lg_cour * 0.5, y_cour + 0.005)))
	# la rampe à droite, du palier à la cour, entre le parapet blanc et l'aile
	var t_r0 := t_g1 + 0.3
	var t_r1 := demi - 0.2
	var run := p_cour - (p_haut + 0.5)
	if chute > 0.05 and run > 1.0:
		var lr := sqrt(run * run + chute * chute)
		var incl := Basis(Vector3.RIGHT, atan2(chute, run))
		var o_r: Vector3 = c.call((t_r0 + t_r1) * 0.5, p_haut + 0.5 + run * 0.5, (y_rue + y_cour) * 0.5 - 0.15)
		_ajouter("parvis_rampe", Color(0.66, 0.65, 0.62), Transform3D(base * incl * Basis.from_scale(Vector3(t_r1 - t_r0, 0.3, lr + 0.1)), o_r))
		_boite(base * incl, Vector3(t_r1 - t_r0, 0.3, lr + 0.1), o_r)
	# le parapet blanc entre gradins et rampe : haut constant, au niveau du palier + 1 m
	var haut_par := y_rue + 1.0
	var o_p: Vector3 = c.call(t_g1 + 0.15, (p_haut + 0.5 + p_cour) * 0.5, (y_cour - 0.3 + haut_par) * 0.5)
	var lp := p_cour - p_haut - 0.5
	_ajouter("parvis_parapet", Color(0.93, 0.93, 0.91), Transform3D(base * Basis.from_scale(Vector3(0.3, haut_par - y_cour + 0.3, lp)), o_p))
	_boite(base, Vector3(0.3, haut_par - y_cour + 0.3, lp), o_p)
	_ajouter("parvis_parapet_couvertine", Color(0.98, 0.98, 0.96), Transform3D(base * Basis.from_scale(Vector3(0.42, 0.08, lp + 0.1)), c.call(t_g1 + 0.15, (p_haut + 0.5 + p_cour) * 0.5, haut_par + 0.04)))
	# le sas vitré au pied de la verrière : 6 m x 2,6 m, 3 m de haut, double porte au milieu
	var sas_l := 6.0
	var sas_p := 2.6
	var sas_h := 3.0
	var cadre := Color(0.88, 0.89, 0.88)
	var verre := _verre()
	for sx in [-1.0, 1.0]:
		# montants d'angle et côtés
		_ajouter("sas_cadre", cadre, Transform3D(base * Basis.from_scale(Vector3(0.12, sas_h, 0.12)), c.call(sx * sas_l * 0.5, -sas_p, y_cour + sas_h * 0.5)))
		var o_cote: Vector3 = c.call(sx * sas_l * 0.5, -sas_p * 0.5, y_cour + sas_h * 0.5)
		var vc := MeshInstance3D.new()
		vc.mesh = _bm_v(Vector3(0.04, sas_h, sas_p))
		vc.material_override = verre
		vc.transform = Transform3D(base, o_cote)
		add_child(vc)
		_boite(base, Vector3(0.1, sas_h, sas_p), o_cote)
		# façade avant : un panneau vitré de chaque côté de la double porte (1,8 m)
		var lpan := (sas_l - 1.8) * 0.5
		var o_av: Vector3 = c.call(sx * (0.9 + lpan * 0.5), -sas_p, y_cour + sas_h * 0.5)
		var va := MeshInstance3D.new()
		va.mesh = _bm_v(Vector3(lpan, sas_h, 0.04))
		va.material_override = verre
		va.transform = Transform3D(base, o_av)
		add_child(va)
		_boite(base, Vector3(lpan, sas_h, 0.1), o_av)
		_ajouter("sas_cadre", cadre, Transform3D(base * Basis.from_scale(Vector3(0.1, 2.3, 0.1)), c.call(sx * 0.9, -sas_p, y_cour + 1.15)))
		for r in 3:
			_ajouter("sas_traverse", cadre, Transform3D(base * Basis.from_scale(Vector3(lpan, 0.06, 0.08)), c.call(sx * (0.9 + lpan * 0.5), -sas_p, y_cour + 0.9 + r * 0.8)))
	# toit du sas et linteau au-dessus des portes
	var o_toit: Vector3 = c.call(0.0, -sas_p * 0.5, y_cour + sas_h + 0.1)
	_ajouter("sas_toit", cadre, Transform3D(base * Basis.from_scale(Vector3(sas_l + 0.3, 0.2, sas_p + 0.3)), o_toit))
	_boite(base, Vector3(sas_l + 0.3, 0.2, sas_p + 0.3), o_toit)
	_ajouter("sas_cadre", cadre, Transform3D(base * Basis.from_scale(Vector3(1.8, 0.7, 0.1)), c.call(0.0, -sas_p, y_cour + 2.65)))
	# portes ouvertes (rabattues contre les panneaux), poignées-barres
	for sx in [-1.0, 1.0]:
		_ajouter("sas_porte", Color(0.30, 0.42, 0.46), Transform3D(base * Basis.from_scale(Vector3(0.05, 2.2, 0.85)), c.call(sx * 0.85, -sas_p - 0.45, y_cour + 1.1)))
	# si la cour est plus haute que le hall : deux ou trois marches dans le sas
	if y_cour - y0 > 0.08:
		var nbm := int(ceil((y_cour - y0) / 0.16))
		for k in nbm:
			var hk := y_cour - (k + 1) * (y_cour - y0) / nbm
			var o_m: Vector3 = c.call(0.0, -sas_p + 0.4 + k * 0.4 + 0.2, (hk + y0 - 0.3) * 0.5)
			_ajouter("hall_perron", Color(0.66, 0.66, 0.64), Transform3D(base * Basis.from_scale(Vector3(sas_l - 0.4, hk - y0 + 0.3, 0.4)), o_m))
	# le nom du lycée sur l'aile gauche, face au parvis (photo « Diderot tire la sonnette d'alarme »)
	var lettres := load("res://assets/decor/graff/lettrage_diderot.png") as Texture2D
	if lettres:
		var o_l: Vector3 = c.call(-demi + 0.05, -PARVIS_PROF * 0.45, y_cour + 4.6)
		var vers_parvis := base.x.normalized()
		preload("res://scripts/marque_murale.gd").poser(self, lettres, o_l, -base.z, vers_parvis, 5.5, Color.WHITE, 80.0, 0, "Lettrage_Diderot")
	print("Lycée : parvis en gradins (%d marches de %.2f m), rampe, sas vitré" % [nb, marche])


# ───────────────────────── la nef, les salles, les sanitaires, la cantine (21.11) ─────────────────────────
# Conçu comme un vrai lycée (Louma : « des grandes salles, des escaliers qui ont un sens, qui amènent aux
# terrasses et au toit, des fenêtres sur le quartier ») d'après la photo de la nef avant 2014 : une longue
# galerie sous verrière, des coursives aux étages, des salles qui donnent dessus, le grand escalier au fond
# et le CDI sous la passerelle. Le plan exact n'est pas connu : distribution plausible, à corriger avec Louma.

var _nm := Vector2.ZERO    # repère de la nef : milieu du pignon,
var _nbx := Vector2.RIGHT  # axe en travers (t),
var _nin := Vector2.DOWN   # axe en profondeur (p)
const COULOIR_NEF := 3.0   # passage entre deux paires de salles, de la coursive vers le reste de l'étage

func _q(t: float, p: float) -> Vector2:
	return _nm + _nbx * t + _nin * p


static func _dist_bord(p: Vector2, poly: PackedVector2Array) -> float:
	var m := INF
	for i in poly.size():
		m = minf(m, Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p))
	return m


## La nef va du pignon vitré jusqu'à 1,5 m du mur du fond (entre 26 et 40 m).
func _longueur_nef(poly: PackedVector2Array) -> float:
	var d0 := (HALL_B - HALL_A).normalized()
	var m0 := (HALL_A + HALL_B) * 0.5
	var in0 := Vector2(-d0.y, d0.x)
	if not Geometry2D.is_point_in_polygon(m0 + in0 * 2.0, poly):
		in0 = -in0
	var lg := 26.0
	var l := 26.0
	while l <= 40.0:
		var ok := true
		for t in [-HALL_LARGE * 0.5, 0.0, HALL_LARGE * 0.5]:
			var q: Vector2 = m0 + d0 * t + in0 * l
			if not Geometry2D.is_point_in_polygon(q, poly) or _dist_bord(q, poly) < 1.5:
				ok = false
		if not ok:
			break
		lg = l
		l += 1.0
	print("Lycée : la nef fait %.0f m de long" % lg)
	return lg


func _nef(c: Callable, base: Basis, y0: float, niveaux: Array[float], toit: float) -> void:
	var L := HALL_PROF
	var W := HALL_LARGE * 0.5
	var p_cdi := L - 8.0
	var gris := Color(0.36, 0.40, 0.44)
	var poutre := Color(0.42, 0.50, 0.58)
	var pt := func(t: float, p: float) -> Vector2:
		var v: Vector3 = c.call(t, p, 0.0)
		return Vector2(v.x, v.z)
	# — les coursives, à chaque étage, des deux côtés ; poteaux qui les portent, garde-corps sur le vide —
	for y in niveaux:
		for s in [-1.0, 1.0]:
			var tc: float = s * (W - COURSIVE * 0.5)
			var o: Vector3 = c.call(tc, (0.3 + p_cdi) * 0.5, y - DALLE * 0.5)
			var taille := Vector3(COURSIVE, DALLE, p_cdi - 0.3)
			_ajouter("nef_coursive", C_SOL, Transform3D(base * Basis.from_scale(taille), o))
			_ajouter("nef_sous_coursive", C_PLAFOND, Transform3D(base * Basis.from_scale(Vector3(COURSIVE, 0.02, p_cdi - 0.3)), o - Vector3.UP * (DALLE * 0.5 + 0.01)))
			_boite(base, taille, o)
			var bord: float = s * (W - COURSIVE)
			_rambarde(pt.call(bord, 0.3), pt.call(bord, p_cdi), y)
	for s in [-1.0, 1.0]:
		var p := 4.0
		while p < p_cdi - 1.0:
			var bord: float = s * (W - COURSIVE + 0.15)
			var haut: float = niveaux[niveaux.size() - 1] - y0
			_ajouter("nef_poteau", poutre, Transform3D(base * Basis.from_scale(Vector3(0.3, haut, 0.3)), c.call(bord, p, y0 + haut * 0.5)))
			_boite(base, Vector3(0.3, haut, 0.3), c.call(bord, p, y0 + haut * 0.5))
			p += 6.0
	# — au fond : le CDI au rez-de-chaussée, sous la passerelle du R+1 —
	var y1: float = niveaux[0]
	var h_cdi := y1 - DALLE - y0
	var verre := _verre()
	var cadre := Color(0.80, 0.82, 0.82)
	for seg in [[-W, 3.2], [5.0, W]]:   # paroi vitrée, porte entre t = 3,2 et 5,0
		var lgs: float = seg[1] - seg[0]
		var o: Vector3 = c.call((seg[0] + seg[1]) * 0.5, p_cdi, y0 + h_cdi * 0.5)
		_ajouter("vitre_cdi", Color.WHITE, Transform3D(base * Basis.from_scale(Vector3(lgs, h_cdi, 0.04)), o))
		_boite(base, Vector3(lgs, h_cdi, 0.1), o)
		var k := 0.0
		while k <= lgs + 0.01:
			_ajouter("nef_cadre", cadre, Transform3D(base * Basis.from_scale(Vector3(0.08, h_cdi, 0.1)), c.call(seg[0] + k, p_cdi, y0 + h_cdi * 0.5)))
			k += 1.5
	_ajouter("nef_cadre", cadre, Transform3D(base * Basis.from_scale(Vector3(HALL_LARGE, 0.1, 0.12)), c.call(0.0, p_cdi, y0 + 2.4)))
	_ajouter("nef_cadre", cadre, Transform3D(base * Basis.from_scale(Vector3(1.8, h_cdi - 2.4, 0.06)), c.call(4.1, p_cdi, y0 + 2.4 + (h_cdi - 2.4) * 0.5)))
	# rayonnages contre le mur du fond et en épis, tables de travail au milieu
	var couleurs := [Color(0.70, 0.25, 0.22), Color(0.22, 0.38, 0.62), Color(0.85, 0.70, 0.25), Color(0.30, 0.52, 0.35), Color(0.88, 0.86, 0.80)]
	for r in 4:
		var tr_: float = -W + 1.2 + r * 1.9
		var o: Vector3 = c.call(tr_, L - 3.2, y0 + 0.9)
		_ajouter("cdi_rayon", Color(0.52, 0.40, 0.28), Transform3D(base * Basis.from_scale(Vector3(0.45, 1.8, 4.8)), o))
		_boite(base, Vector3(0.45, 1.8, 4.8), o)
		for e in 4:
			for k in 10:
				for cote in [-1.0, 1.0]:
					var oo: Vector3 = c.call(tr_ + cote * 0.25, L - 5.4 + k * 0.48, y0 + 0.25 + e * 0.42)
					_ajouter("cdi_livres_%d" % ((k + e + r) % 5), couleurs[(k + e + r) % 5], Transform3D(base * Basis.from_scale(Vector3(0.1, 0.32, 0.4)), oo))
	var bt := base
	for r in 2:
		for col in 2:
			var cc: Vector3 = c.call(2.2 + col * 2.2, p_cdi + 2.2 + r * 2.4, y0)
			_table(Vector2(cc.x, cc.z), y0, bt, 1.6, 0.8)
			for sc in [-0.5, 0.5]:
				var ch: Vector3 = c.call(2.2 + col * 2.2 + sc, p_cdi + 2.2 + r * 2.4 + 0.65, y0)
				_chaise(Vector2(ch.x, ch.z), y0, bt)
	# — la passerelle du R+1 au-dessus du CDI, d'une coursive à l'autre ; le grand escalier y monte —
	var marche := 0.17
	var giron := 0.30
	var monte := y1 - y0
	var nb := int(round(monte / marche))
	var run := nb * giron
	var o_pas: Vector3 = c.call(0.0, (p_cdi + L) * 0.5, y1 - DALLE * 0.5)
	_ajouter("nef_coursive", C_SOL, Transform3D(base * Basis.from_scale(Vector3(HALL_LARGE, DALLE, L - p_cdi)), o_pas))
	_ajouter("nef_sous_coursive", C_PLAFOND, Transform3D(base * Basis.from_scale(Vector3(HALL_LARGE, 0.02, L - p_cdi)), o_pas - Vector3.UP * (DALLE * 0.5 + 0.01)))
	_boite(base, Vector3(HALL_LARGE, DALLE, L - p_cdi), o_pas)
	_rambarde(pt.call(-(W - COURSIVE), p_cdi), pt.call(-1.7, p_cdi), y1)
	_rambarde(pt.call(1.7, p_cdi), pt.call(W - COURSIVE, p_cdi), y1)
	_volee(c, base, 0.0, p_cdi - run, 0.0, p_cdi, 3.2, y0, y1, nb)
	# — la deuxième volée, contre le mur du fond, du R+1 au R+2 ; la passerelle du R+2 et son palier —
	if niveaux.size() > 1:
		var y2: float = niveaux[1]
		var nb2 := int(round((y2 - y1) / marche))
		var run2 := nb2 * giron
		var t_bas := -W + 0.6
		var t_haut := t_bas + run2
		var p_v := L - 1.35
		_volee(c, base, t_bas, p_v, t_haut, p_v, 2.3, y1, y2, nb2)
		# R+2 : la passerelle (sans la bande de la volée) et le palier d'arrivée
		var o2: Vector3 = c.call(0.0, (p_cdi + L - 2.6) * 0.5, y2 - DALLE * 0.5)
		_ajouter("nef_coursive", C_SOL, Transform3D(base * Basis.from_scale(Vector3(HALL_LARGE, DALLE, L - 2.6 - p_cdi)), o2))
		_boite(base, Vector3(HALL_LARGE, DALLE, L - 2.6 - p_cdi), o2)
		var o3: Vector3 = c.call((t_haut + W) * 0.5, L - 1.3, y2 - DALLE * 0.5)
		_ajouter("nef_coursive", C_SOL, Transform3D(base * Basis.from_scale(Vector3(W - t_haut, DALLE, 2.6)), o3))
		_boite(base, Vector3(W - t_haut, DALLE, 2.6), o3)
		_rambarde(pt.call(-(W - COURSIVE), p_cdi), pt.call(W - COURSIVE, p_cdi), y2)
		_rambarde(pt.call(-W, L - 2.6), pt.call(t_haut, L - 2.6), y2)
	# — au rez-de-chaussée de la nef : casiers, panneaux d'affichage, distributeur, plantes —
	for s in [-1.0, 1.0]:
		var p := 3.0
		while p < p_cdi - 9.0:
			var o: Vector3 = c.call(s * (W - 0.3), p + 1.5, y0 + 0.9)
			_ajouter("nef_casiers", Color(0.30, 0.46, 0.62) if s < 0 else Color(0.62, 0.30, 0.28), Transform3D(base * Basis.from_scale(Vector3(0.5, 1.8, 3.0)), o))
			_boite(base, Vector3(0.5, 1.8, 3.0), o)
			_ajouter("nef_panneau", Color(0.70, 0.56, 0.38), Transform3D(base * Basis.from_scale(Vector3(0.05, 1.0, 1.8)), c.call(s * (W - 0.05), p + 5.5, y0 + 1.6)))
			p += 9.0
	var od: Vector3 = c.call(W - 0.6, p_cdi - 2.0, y0 + 0.95)
	_ajouter("nef_distributeur", Color(0.75, 0.12, 0.12), Transform3D(base * Basis.from_scale(Vector3(0.9, 1.9, 0.8)), od))
	_boite(base, Vector3(0.9, 1.9, 0.8), od)
	for k in 4:   # de part et d'autre du pied de l'escalier, jamais devant
		var op: Vector3 = c.call([-4.2, -2.6, 2.6, 4.2][k], p_cdi - run + 0.6, y0 + 0.35)
		_ajouter("nef_bac", Color(0.62, 0.60, 0.56), Transform3D(base * Basis.from_scale(Vector3(1.0, 0.7, 1.0)), op))
		_ajouter("nef_plante", Color(0.28, 0.48, 0.25), Transform3D(base * Basis.from_scale(Vector3(0.9, 1.3, 0.9)), op + Vector3.UP * 0.95))
		_boite(base, Vector3(1.0, 0.7, 1.0), op)
	print("Lycée : nef de %.0f m, coursives, CDI, grand escalier (%d marches)" % [L, nb], " ; repère ", _nm, _nbx, _nin, " y0 ", y0)


## Une volée droite de (t0, p0) à (t1, p1), de y_bas à y_haut : marches, limons, main courante, collision en pente.
func _volee(c: Callable, base: Basis, t0: float, p0: float, t1: float, p1: float, larg: float, y_bas: float, y_haut: float, nb: int) -> void:
	var a3: Vector3 = c.call(t0, p0, 0.0)
	var b3: Vector3 = c.call(t1, p1, 0.0)
	var dir := (b3 - a3)
	var run := dir.length()
	dir /= run
	var cote := dir.cross(Vector3.UP).normalized()
	var bm := Basis(cote, Vector3.UP, dir)
	if bm.determinant() < 0.0:
		bm = Basis(-cote, Vector3.UP, dir)
	var monte := y_haut - y_bas
	for k in nb:
		var hk := (k + 1) * monte / nb
		var o := a3 + dir * ((k + 0.5) * run / nb) + Vector3.UP * (y_bas + hk - 0.5 * monte / nb)
		_ajouter("nef_marche", Color(0.72, 0.72, 0.70), Transform3D(bm * Basis.from_scale(Vector3(larg, monte / nb, run / nb + 0.02)), o))
	var pente := atan2(monte, run)
	var incl := bm * Basis(Vector3.RIGHT, -pente)
	var lr := sqrt(run * run + monte * monte)
	var mil := (a3 + b3) * 0.5 + Vector3.UP * (y_bas + monte * 0.5)
	_boite(incl, Vector3(larg, 0.2, lr), mil - Vector3.UP * 0.12)
	for s in [-1.0, 1.0]:
		var bordo: Vector3 = mil + bm.x * (s * (larg * 0.5 + 0.05))
		_ajouter("nef_limon", Color(0.62, 0.62, 0.60), Transform3D(incl * Basis.from_scale(Vector3(0.12, 0.4, lr)), bordo - Vector3.UP * 0.15))
		_ajouter("nef_main_courante", Color(0.30, 0.32, 0.34), Transform3D(incl * Basis.from_scale(Vector3(0.06, 0.06, lr)), bordo + Vector3.UP * 0.95))
		_boite(incl, Vector3(0.08, 1.0, lr), bordo + Vector3.UP * 0.45)


## Une salle de façade le long de la nef s'allonge jusqu'à la coursive (fenêtres sur le quartier, porte sur la
## nef) quand il ne reste entre elles que 7 m ou moins : sinon ce serait un couloir sans issue.
func _profondeur_vers_nef(tr: Array) -> float:
	var a: Vector2 = tr[0]
	var d: Vector2 = tr[1]
	var n_in: Vector2 = tr[2]
	var lg: float = tr[3]
	var W := HALL_LARGE * 0.5
	var q := a + d * (lg * 0.5) + n_in * PROF_SALLE
	var tq := (q - _nm).dot(_nbx)
	var pq := (q - _nm).dot(_nin)
	if absf(tq) <= W or pq < 1.0 or pq > HALL_PROF - 8.5:
		return PROF_SALLE
	var vers := -_nbx * signf(tq)
	var face := n_in.dot(vers)
	if face < 0.85:
		return PROF_SALLE
	var ecart := (absf(tq) - W) / face
	# toute la largeur de la salle doit tomber le long de la nef
	for f in [0.0, 1.0]:
		var pb: float = (a + d * (lg * float(f)) + n_in * PROF_SALLE - _nm).dot(_nin)
		if pb < 0.5 or pb > HALL_PROF - 8.5:
			return PROF_SALLE
	if ecart >= 7.0:
		return PROF_SALLE
	for r in _coeur:
		if _recouvre(r[5], _contour_travee(tr, PROF_SALLE + ecart - 0.3)):
			return PROF_SALLE
	return PROF_SALLE + ecart


## Le cœur des étages, calé sur la nef. En travers, à partir de la coursive : une salle qui ouvre sur la
## coursive, un couloir de 3 m, puis deux salles dos à dos qui ouvrent chacune sur un couloir, et ainsi de
## suite. En profondeur : deux salles de 9 m, un passage de 3 m. Les salles contre la nef passent en priorité :
## les salles de façade qu'elles recouvrent sont retirées ; les autres doivent laisser un couloir de 2,5 m
## derrière les salles de façade.
const TRAME_T := [[0.0, 8.0, 0], [8.0, 11.0, -1], [11.0, 19.0, 0], [19.0, 27.0, 1], [27.0, 30.0, -1]]   # [début, fin, porte : 0 côté nef, 1 côté opposé, -1 couloir]
const PERIODE_T := 30.0
var _coeur := []   # [s, t0, t1, p, porte, contour]

func _plan_coeur(poly: PackedVector2Array, travees: Array) -> void:
	_coeur.clear()
	var W := HALL_LARGE * 0.5
	for s in [-1.0, 1.0]:
		var base_t := W
		while base_t < W + 90.0:
			for bande in TRAME_T:
				if bande[2] < 0:
					continue
				var t0: float = base_t + float(bande[0])
				var t1: float = base_t + float(bande[1])
				var p := -30.0
				var k := 0
				while p < 90.0:
					var r := _salle_coeur_ok(poly, s, t0, t1, p, int(bande[2]))
					if not r.is_empty():
						# jamais sur une cage d'escalier
						var libre := true
						for tr in travees:
							if tr[4] and _recouvre(r[5], _contour_travee(tr, PROF_CAGE)):
								libre = false
						if libre:
							_coeur.append(r)
					p += LONG_TRAVEE
					k += 1
					if k % 2 == 0:
						p += COULOIR_NEF
			base_t += PERIODE_T
	print("Lycée : %d salles au cœur des étages (sur la nef et le long des couloirs)" % _coeur.size())


func _contour_travee(tr: Array, prof: float) -> PackedVector2Array:
	var a: Vector2 = tr[0]
	var d: Vector2 = tr[1]
	var n_in: Vector2 = tr[2]
	var lg: float = tr[3]
	return PackedVector2Array([a, a + d * lg, a + d * lg + n_in * prof, a + n_in * prof])


func _recouvre(p1: PackedVector2Array, p2: PackedVector2Array) -> bool:
	for r in Geometry2D.intersect_polygons(p1, p2):
		if absf(_aire(r)) > 1.0:
			return true
	return false


func _salle_coeur_ok(poly: PackedVector2Array, s: float, t0: float, t1: float, p: float, porte: int) -> Array:
	var W := HALL_LARGE * 0.5
	var contre_nef := absf(t0 - W) < 0.01 and p > -0.5 and p + LONG_TRAVEE < HALL_PROF - 8.0
	for cn in [[t0, p], [t0, p + LONG_TRAVEE], [t1, p], [t1, p + LONG_TRAVEE], [(t0 + t1) * 0.5, p + LONG_TRAVEE * 0.5]]:
		var q: Vector2 = _q(s * float(cn[0]), float(cn[1]))
		if not Geometry2D.is_point_in_polygon(q, poly):
			return []
		var sur_nef: bool = absf(float(cn[0]) - W) < 0.01
		var marge := 0.3 if contre_nef else (0.0 if sur_nef and contre_nef else PROF_SALLE + 2.5)
		if _dist_bord(q, poly) < marge:
			return []
	var c := PackedVector2Array([_q(s * t0, p), _q(s * t1, p), _q(s * t1, p + LONG_TRAVEE), _q(s * t0, p + LONG_TRAVEE)])
	return [s, t0, t1, p, porte, c]


func _salles_nef(poly: PackedVector2Array, y: float, j: int) -> void:
	var hh := ETAGE - DALLE
	var k := 0
	for r in _coeur:
		var s: float = r[0]
		var t_mur: float = r[2] if r[4] == 0 else r[1]
		var a := _q(s * t_mur, r[3])
		var n_in := _nbx * (-s if r[4] == 0 else s)
		var tr := [a, _nin, n_in, LONG_TRAVEE, false, -1]
		_cloison(a, a + _nin * LONG_TRAVEE, y, hh)
		_salle(tr, y, j + k)
		k += 1


## Une fenêtre de façade : vitrage (on ne passe pas), cadre, montant au milieu, appui.
func _fenetre(o: Vector2, d: Vector2, n_in: Vector2, w: float, y0: float, y1: float) -> void:
	var b := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(n_in.x, 0, n_in.y)).orthonormalized()
	var c := Vector3(o.x, (y0 + y1) * 0.5, o.y)
	var hh := y1 - y0
	_ajouter("vitre_fenetre", Color.WHITE, Transform3D(b * Basis.from_scale(Vector3(w, hh, 0.04)), c))
	_boite(b, Vector3(w, hh, 0.1), c)
	var cadre := Color(0.90, 0.90, 0.88)
	for f in [-0.5, 0.0, 0.5]:
		_ajouter("fenetre_cadre", cadre, Transform3D(b * Basis.from_scale(Vector3(0.07, hh, 0.09)), c + b.x * (w * f)))
	for f in [-0.5, 0.5]:
		_ajouter("fenetre_cadre", cadre, Transform3D(b * Basis.from_scale(Vector3(w, 0.07, 0.09)), c + Vector3.UP * (hh * f)))
	_ajouter("fenetre_appui", Color(0.70, 0.69, 0.66), Transform3D(b * Basis.from_scale(Vector3(w + 0.2, 0.06, 0.35)), c + Vector3.UP * (-hh * 0.5 - 0.03) + b.z * 0.1))


## Le toit-terrasse : acrotère d'un mètre tout autour, garde-corps autour de la verrière.
func _acrotere(poly: PackedVector2Array, toit: float) -> void:
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var lg := a.distance_to(b)
		if lg < 0.3 or (hall.size() > 2 and (a + b).distance_to(HALL_A + HALL_B) < 1.0):
			continue
		var d := (b - a) / lg
		var n_in := Vector2(-d.y, d.x)
		var m := (a + b) * 0.5 + n_in * 0.15
		var bs := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(n_in.x, 0, n_in.y)).orthonormalized()
		var o := Vector3(m.x, toit + 0.5, m.y)
		_ajouter("acrotere", Color(0.80, 0.78, 0.73), Transform3D(bs * Basis.from_scale(Vector3(lg + 0.3, 1.0, 0.3)), o))
		_boite(bs, Vector3(lg + 0.3, 1.0, 0.3), o)
	if hall.size() > 2:
		for i in hall.size():
			var a := hall[i]
			var b := hall[(i + 1) % hall.size()]
			if Geometry2D.get_closest_point_to_segment((a + b) * 0.5, HALL_A, HALL_B).distance_to((a + b) * 0.5) < 1.0:
				continue
			_rambarde(a, b, toit)


## Les sanitaires : carrelage, quatre cabines, une rangée de lavabos et un miroir.
func _sanitaires(tr: Array, y: float, j: int) -> void:
	var a: Vector2 = tr[0]
	var d: Vector2 = tr[1]
	var n_in: Vector2 = tr[2]
	var lg: float = tr[3]
	var hh := ETAGE - DALLE
	var p_in := a + n_in * PROF_SALLE
	_cloison(p_in, p_in + d * lg, y, hh, 1.0)
	_cloison(a + n_in * 0.15, p_in, y, hh)
	_cloison(a + d * lg + n_in * 0.15, p_in + d * lg, y, hh)
	var b := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(n_in.x, 0, n_in.y)).orthonormalized()
	var loc := func(u: float, v: float, yy: float) -> Vector3:
		var q := a + d * u + n_in * v
		return Vector3(q.x, y + yy, q.y)
	_ajouter("wc_carrelage", Color(0.74, 0.84, 0.86), Transform3D(b * Basis.from_scale(Vector3(lg - 0.2, 0.02, PROF_SALLE - 0.3)), loc.call(lg * 0.5, PROF_SALLE * 0.5, 0.01)))
	# cabines contre la cloison de début : 1,5 m de fond, 1,1 m de large
	for k in 5:
		var v := 1.0 + k * 1.15
		_ajouter("wc_cloison", Color(0.30, 0.55, 0.62), Transform3D(b * Basis.from_scale(Vector3(1.5, 2.0, 0.05)), loc.call(0.95, v, 1.1)))
		_boite(b, Vector3(1.5, 2.0, 0.05), loc.call(0.95, v, 1.1))
		if k < 4:
			_ajouter("wc_porte", Color(0.30, 0.55, 0.62), Transform3D(b * Basis(Vector3.UP, 0.5) * Basis.from_scale(Vector3(0.04, 1.8, 0.8)), loc.call(1.95, v + 0.35, 1.05)))
			_ajouter("wc_cuvette", Color(0.95, 0.95, 0.94), Transform3D(b * Basis.from_scale(Vector3(0.45, 0.42, 0.6)), loc.call(0.5, v + 0.57, 0.21)))
	# lavabos et miroir contre l'autre cloison
	var o: Vector3 = loc.call(lg - 0.45, PROF_SALLE * 0.5, 0.85)
	_ajouter("wc_plan", Color(0.92, 0.92, 0.90), Transform3D(b * Basis.from_scale(Vector3(0.6, 0.12, 4.2)), o))
	_boite(b, Vector3(0.6, 0.9, 4.2), o - Vector3.UP * 0.4)
	_ajouter("wc_miroir", Color(0.72, 0.82, 0.88), Transform3D(b * Basis.from_scale(Vector3(0.03, 0.9, 3.8)), loc.call(lg - 0.12, PROF_SALLE * 0.5, 1.65)))
	# plaque bleue à la porte
	var pp := p_in + d * (lg * 0.5 + 0.9) - n_in * 0.09
	_ajouter("wc_plaque", Color(0.20, 0.40, 0.75), Transform3D(Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-n_in.x, 0, -n_in.y)) * Basis.from_scale(Vector3(0.35, 0.35, 0.02)), Vector3(pp.x, y + 1.7, pp.y)))


## La cantine : tout le rez-de-chaussée du bâtiment sud, des tablées et le self le long de la plus longue façade.
func _cantine(poly: PackedVector2Array, y: float, travees: Array) -> void:
	var cages := []
	for tr in travees:
		if tr[4]:
			cages.append(_contour_travee(tr, PROF_CAGE + 1.5))
	var i_l := 0
	for i in poly.size():
		if poly[i].distance_to(poly[(i + 1) % poly.size()]) > poly[i_l].distance_to(poly[(i_l + 1) % poly.size()]):
			i_l = i
	var a := poly[i_l]
	var b := poly[(i_l + 1) % poly.size()]
	var lg := a.distance_to(b)
	var e := (b - a) / lg
	var n := Vector2(-e.y, e.x)
	if not Geometry2D.is_point_in_polygon((a + b) * 0.5 + n * 2.0, poly):
		n = -n
	var bs := Basis(Vector3(e.x, 0, e.y), Vector3.UP, Vector3(n.x, 0, n.y)).orthonormalized()
	# le self : comptoir, vitre anti-postillons, glissière à plateaux
	var l_self := minf(14.0, lg - 12.0)
	if l_self > 4.0:
		var m := (a + b) * 0.5 + n * 3.2
		var o := Vector3(m.x, y + 0.45, m.y)
		_ajouter("self_comptoir", Color(0.72, 0.74, 0.76), Transform3D(bs * Basis.from_scale(Vector3(l_self, 0.9, 0.8)), o))
		_boite(bs, Vector3(l_self, 0.9, 0.8), o)
		_ajouter("vitre_self", Color.WHITE, Transform3D(bs * Basis.from_scale(Vector3(l_self, 0.45, 0.03)), o + Vector3.UP * 0.75))
		_ajouter("self_glissiere", Color(0.55, 0.57, 0.60), Transform3D(bs * Basis.from_scale(Vector3(l_self, 0.05, 0.3)), o + Vector3.UP * 0.35 + bs.z * 0.55))
		for k in int(l_self / 2.0):
			_ajouter("self_bac_%d" % (k % 3), [Color(0.80, 0.55, 0.25), Color(0.40, 0.62, 0.30), Color(0.85, 0.80, 0.55)][k % 3], Transform3D(bs * Basis.from_scale(Vector3(0.5, 0.08, 0.35)), o + Vector3.UP * 0.47 + bs.x * (-l_self * 0.5 + 1.0 + k * 2.0)))
	# les tablées : 2,6 m x 0,9 m, deux bancs, en rangs parallèles à la façade
	var n_tables := 0
	var u := 6.0
	while u < 60.0:
		var v := -lg
		while v < lg:
			var q := (a + b) * 0.5 + e * v + n * u
			var hors_cage := true
			for cg in cages:
				if Geometry2D.is_point_in_polygon(q, cg):
					hors_cage = false
			# à 2,4 m des façades au moins, et loin du self (le long de la grande façade)
			var loin_self := absf((q - (a + b) * 0.5).dot(n)) > 5.5 or absf((q - (a + b) * 0.5).dot(e)) > minf(14.0, lg - 12.0) * 0.5 + 1.5
			if hors_cage and loin_self and Geometry2D.is_point_in_polygon(q, poly) and _dist_bord(q, poly) > 2.4:
				var o := Vector3(q.x, y, q.y)
				_ajouter("cantine_table", Color(0.80, 0.72, 0.56), Transform3D(bs * Basis.from_scale(Vector3(2.6, 0.06, 0.9)), o + Vector3.UP * 0.75))
				_ajouter("cantine_pied", Color(0.40, 0.40, 0.42), Transform3D(bs * Basis.from_scale(Vector3(2.2, 0.72, 0.08)), o + Vector3.UP * 0.36))
				_boite(bs, Vector3(2.6, 0.78, 0.9), o + Vector3.UP * 0.39)
				for sb in [-1.0, 1.0]:
					var ob: Vector3 = o + bs.z * (sb * 0.75) + Vector3.UP * 0.22
					_ajouter("cantine_banc", Color(0.70, 0.30, 0.25), Transform3D(bs * Basis.from_scale(Vector3(2.6, 0.06, 0.32)), ob + Vector3.UP * 0.2))
					_ajouter("cantine_pied", Color(0.40, 0.40, 0.42), Transform3D(bs * Basis.from_scale(Vector3(2.2, 0.42, 0.06)), ob))
					_boite(bs, Vector3(2.6, 0.45, 0.32), ob)
				n_tables += 1
			v += 3.4
		u += 3.2
	print("Lycée : cantine, %d tablées" % n_tables)


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


const FER := Color(0.52, 0.58, 0.59)

## Profil de la verrière, en (x, hauteur au-dessus du sol du hall) : côtés droits, puis un dôme
## (arc de cercle surbaissé, 3,2 m de flèche sur 12 m), comme sur le Street View de 2011.
const DOME_FLECHE := 1.95
const DOME_SEGMENTS := 8

func _profil(h1: float) -> PackedVector2Array:
	var w := HALL_LARGE * 0.5
	var r := (w * w + DOME_FLECHE * DOME_FLECHE) / (2.0 * DOME_FLECHE)
	var cy := h1 + DOME_FLECHE - r
	var a0 := asin(w / r)
	var out := PackedVector2Array([Vector2(-w, 0)])
	for k in DOME_SEGMENTS + 1:
		var a := -a0 + 2.0 * a0 * k / DOME_SEGMENTS
		out.append(Vector2(r * sin(a), cy + r * cos(a)))
	out.append(Vector2(w, 0))
	return out


func _verre() -> StandardMaterial3D:
	var verre := StandardMaterial3D.new()
	verre.albedo_color = Color(0.32, 0.45, 0.47, 0.46)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	verre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	verre.cull_mode = BaseMaterial3D.CULL_DISABLED
	return verre


func _barre(a: Vector3, b: Vector3, ep: float, cle := "verriere_fer", col := FER) -> void:
	var d := b - a
	var lg := d.length()
	if lg < 0.01:
		return
	var y := d / lg
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_ajouter(cle, col, Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3(ep, lg, ep)), (a + b) * 0.5))


func _verriere(c: Callable, base: Basis, bx: Vector3, bz: Vector3, y0: float, toit: float) -> void:
	var h1 := toit - y0 + 0.3
	var prof := _profil(h1)
	var verre := _verre()
	var pt := func(q: Vector2, p: float) -> Vector3:
		return c.call(q.x, p, y0 + q.y)
	var p_av := 0.0
	var p_ar := HALL_PROF
	# — pignon avant : vitrage, montants tous les 1,2 m, traverses tous les 1,5 m —
	var tri := Geometry2D.triangulate_polygon(prof)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in tri:
		st.add_vertex(pt.call(prof[i], p_av))
	var gm := MeshInstance3D.new()
	gm.mesh = st.commit()
	gm.material_override = verre
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gm.name = "Verriere_pignon"
	add_child(gm)
	var haut_a := func(x: float) -> float:
		var hmax := 0.0
		for k in prof.size() - 1:
			var a: Vector2 = prof[k]
			var b: Vector2 = prof[k + 1]
			if (x - a.x) * (x - b.x) <= 0.0 and absf(b.x - a.x) > 0.01:
				hmax = maxf(hmax, lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
		return hmax
	var x := -HALL_LARGE * 0.5
	while x <= HALL_LARGE * 0.5 + 0.01:
		_barre(pt.call(Vector2(x, 0), p_av), pt.call(Vector2(x, haut_a.call(x)), p_av), 0.09)
		x += 2.0
	var y := 1.5
	while y < h1 + DOME_FLECHE:
		var demi := HALL_LARGE * 0.5
		for k in prof.size() - 1:
			var a: Vector2 = prof[k]
			var b: Vector2 = prof[k + 1]
			if (y - a.y) * (y - b.y) < 0.0 and b.x > 0.0:
				demi = lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
		_barre(pt.call(Vector2(-demi, y), p_av), pt.call(Vector2(demi, y), p_av), 0.07)
		y += 1.5
	# bandeau bas : petits carreaux blancs à vitre sombre (deux rangs), sauf la porte au milieu
	var xb := -HALL_LARGE * 0.5 + 0.3
	while xb < HALL_LARGE * 0.5 - 0.3:
		if absf(xb) < HALL_LARGE * 0.5 - 0.85:
			for r in 3:
				var o: Vector3 = pt.call(Vector2(xb, 2.62 + r * 0.52), p_av - 0.03)
				_ajouter("verriere_bandeau", Color(0.94, 0.94, 0.92), Transform3D(base * Basis.from_scale(Vector3(0.64, 0.51, 0.06)), o))
				_ajouter("verriere_carreau", Color(0.20, 0.24, 0.28), Transform3D(base * Basis.from_scale(Vector3(0.46, 0.36, 0.07)), o - bz * 0.01))
		xb += 0.62
	# collisions du pignon : deux pans pleins de part et d'autre de la porte (2,8 m)
	# (la porte monte à 4,5 m : le sol du parvis peut être plus haut que celui du hall)
	for s in [-1.0, 1.0]:
		_boite(base, Vector3(HALL_LARGE * 0.5 - 1.4, 4.5, 0.12), c.call(s * (1.4 + (HALL_LARGE * 0.5 - 1.4) * 0.5), p_av, y0 + 2.25))
	_boite(base, Vector3(HALL_LARGE, h1 - 4.5, 0.12), c.call(0.0, p_av, y0 + 4.5 + (h1 - 4.5) * 0.5))
	# portes vitrées ouvertes, rabattues contre le pignon
	for s in [-1.0, 1.0]:
		_ajouter("verriere_porte", Color(0.30, 0.34, 0.38), Transform3D(base * Basis.from_scale(Vector3(0.06, 2.4, 1.3)), c.call(s * 1.4, p_av + 0.65, y0 + 1.2)))
	# — la galerie : cadres tous les 3 m sur le profil, pannes à chaque angle, vitrage sur chaque pan —
	var nb_c := int(HALL_PROF / 3.0)
	for k in nb_c + 1:
		var p := p_av + k * HALL_PROF / nb_c
		for i in prof.size() - 1:
			if prof[i].y < h1 - 0.01 and prof[i + 1].y < h1 - 0.01:
				continue
			_barre(pt.call(prof[i], p), pt.call(prof[i + 1], p), 0.16)
	for i in range(1, prof.size() - 1):
		_barre(pt.call(prof[i], p_av), pt.call(prof[i], p_ar), 0.14)
	for i in range(1, prof.size() - 2):
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		if a.y < h1 - 0.01 or b.y < h1 - 0.01:
			continue
		var pan := MeshInstance3D.new()
		var stp := SurfaceTool.new()
		stp.begin(Mesh.PRIMITIVE_TRIANGLES)
		for q in [[a, p_av], [b, p_av], [b, p_ar], [a, p_av], [b, p_ar], [a, p_ar]]:
			stp.add_vertex(pt.call(q[0], q[1]))
		pan.mesh = stp.commit()
		pan.material_override = verre
		pan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pan)
		# petits bois du vitrage, le long de la galerie
		_barre(pt.call(a.lerp(b, 0.5), p_av), pt.call(a.lerp(b, 0.5), p_ar), 0.05)
	# les côtés de la galerie au-dessus du toit voisin : vitrés aussi
	for side in [[prof[0], prof[1]], [prof[prof.size() - 1], prof[prof.size() - 2]]]:
		var bas: Vector2 = Vector2(side[1].x, toit - y0 - 0.2)
		var pan2 := MeshInstance3D.new()
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		for q in [[bas, p_av], [side[1], p_av], [side[1], p_ar], [bas, p_av], [side[1], p_ar], [bas, p_ar]]:
			st2.add_vertex(pt.call(q[0], q[1]))
		pan2.mesh = st2.commit()
		pan2.material_override = verre
		pan2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pan2)
	# — pignon arrière : vitré au-dessus du toit —
	var haut_ar := PackedVector2Array()
	for q in prof:
		haut_ar.append(Vector2(q.x, maxf(q.y, toit - y0 - 0.2)))
	var tri2 := Geometry2D.triangulate_polygon(haut_ar)
	if not tri2.is_empty():
		var st3 := SurfaceTool.new()
		st3.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in tri2:
			st3.add_vertex(pt.call(haut_ar[i], p_ar))
		var gm2 := MeshInstance3D.new()
		gm2.mesh = st3.commit()
		gm2.material_override = verre
		gm2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(gm2)
	print("Lycée : la verrière à dôme (%.0f m de haut)" % (h1 + DOME_FLECHE))


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
	var bandes := [[0.2, 2.9], [3.1, PROF_CAGE - 0.1]]
	# cloisons de la cage (côtés), le couloir reste ouvert
	_cloison(a + n_in * 0.15, a + n_in * PROF_CAGE, y, hh)
	_cloison(a + d * lg + n_in * 0.15, a + d * lg + n_in * PROF_CAGE, y, hh)
	# planchers de la cage à ce niveau : paliers + la bande qui n'est pas ouverte
	_plaque(a, d, n_in, 0.0, PALIER, 0.0, PROF_CAGE, y)
	_plaque(a, d, n_in, lg - PALIER, lg, 0.0, PROF_CAGE, y)
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
		mi.material_override = _verre() if cle.begins_with("vitre") else _mat(_paquets[cle][0])
		if cle.begins_with("vitre"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
