extends Node3D
## TRACE — décor des accès aux toits (conversation n°2, lot 2).
##  - L'échafaudage du pignon nord de la grande barre (2014-2015, pendant la réhabilitation) :
##    tubes, planchers tous les 2 m, bâches bleues, filet de chantier.
##  - Les escaliers de secours métalliques du lycée, de l'école, de l'hôpital et de l'internat.
## Tout est solide (on peut marcher sur les planchers et monter les escaliers), dans le groupe « prise ».
## La façon de grimper est le travail de n°1 : la liste « acces » donne, pour chaque accès,
## son point de départ au sol, la hauteur du toit et l'orientation du mur.
## Code couleur de la DA : le bleu bâche signale ce qui s'escalade.

const TOON := preload("res://shaders/bd_toon.gdshader")
const BACHE := Color(0.20, 0.52, 0.85)
const TUBE := Color(0.62, 0.64, 0.66)
const PLANCHER := Color(0.72, 0.58, 0.38)
const METAL := Color(0.30, 0.42, 0.40)   # escaliers de secours : vert sombre, peinture antirouille

const NIVEAU := 2.0          # écart entre deux planchers d'échafaudage
const COLONNE := 1.5         # largeur d'une travée d'échafaudage
const PROFONDEUR := 1.1      # profondeur des planchers
const ECART_MUR := 0.3       # distance entre l'échafaudage et le mur

## Escaliers de secours : nom du bâtiment, numéro du côté (0 = premier côté du relevé), position le long du côté.
const ESCALIERS := [["Lycée", -1, 0.25], ["École des Lauriers", -1, 0.3], ["Hôpital 2", -1, 0.5], ["Internat", -1, 0.5]]

var habillage: Node
var _paquets := {}
var _cube := BoxMesh.new()
var acces: Array = []        # [nom, départ au sol, altitude du toit, normale du mur, extra] pour n°1 et la carte


func construire(batiments: Array, epoque: String) -> void:
	_cube.size = Vector3.ONE
	for c in batiments:
		var nom: String = c[1]
		var poly := _poly(c[4])
		var moy := 0.0
		for p in poly:
			moy += h(p.x, p.y)
		moy /= poly.size()
		var toit := moy + float(c[2])
		if nom == "Grande barre des Lauriers" and epoque == "avant":
			_echafaudage(poly, toit)
		for e: Array in ESCALIERS:
			if e[0] == nom:
				_escalier_secours(nom, poly, int(e[1]), float(e[2]), toit)
	_poser_paquets()
	for p in acces:
		print("Accès au toit : %s (%.0f m)" % [p[0], p[2] - h(p[1].x, p[1].z)])


func h(x: float, z: float) -> float:
	return habillage.h(x, z)


# ───────────────────────── échafaudage de la barre ─────────────────────────

func _echafaudage(poly: PackedVector2Array, toit: float) -> void:
	# Le pignon nord : le côté le plus au nord parmi les côtés courts.
	var meilleur := -1
	var zmax := -INF
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var l := a.distance_to(b)
		if l > 6.0 and l < 16.0 and (a.y + b.y) * 0.5 > zmax:
			zmax = (a.y + b.y) * 0.5
			meilleur = k
	if meilleur < 0:
		return
	var a := poly[meilleur]
	var b := poly[(meilleur + 1) % poly.size()]
	var long := a.distance_to(b)
	var d := (b - a) / long
	var n := _normale_dehors(a, b, poly)
	var base := _base(n)
	var nb_col := int(floor((long - 0.6) / COLONNE))
	var debut := (long - nb_col * COLONNE) * 0.5
	var milieu := a + d * (long * 0.5) + n * (ECART_MUR + PROFONDEUR * 0.5)
	var y0 := h(milieu.x, milieu.y)
	# Le dernier plancher est 1,5 m sous le haut de l'acrotère : on s'y hisse pour passer sur le toit.
	var nb_niv := int(round((toit + 0.75 - 1.5 - y0) / NIVEAU))
	var niveau := (toit + 0.75 - 1.5 - y0) / nb_niv
	var corps := StaticBody3D.new()
	corps.name = "Echafaudage_barre"
	corps.add_to_group("prise")
	add_child(corps)
	var c_route := int(nb_col / 2) - 1   # le zigzag occupe deux travées au milieu
	for i in nb_col + 1:
		# Montants (intérieur et extérieur), du sol jusqu'au-dessus du toit.
		for prof: float in [ECART_MUR, ECART_MUR + PROFONDEUR]:
			var p := a + d * (debut + i * COLONNE) + n * prof
			var sol := h(p.x, p.y)
			var haut := toit + 1.2
			_ajouter("tube", TUBE, Transform3D(Basis.from_scale(Vector3(0.06, haut - sol, 0.06)), Vector3(p.x, (sol + haut) * 0.5, p.y)))
	for niv in range(1, nb_niv + 1):
		var y := y0 + niv * niveau
		for i in nb_col:
			var c := a + d * (debut + (i + 0.5) * COLONNE) + n * (ECART_MUR + PROFONDEUR * 0.5)
			var o := Vector3(c.x, y, c.y)
			var sur_route := (i == c_route and niv % 2 == 1) or (i == c_route + 1 and niv % 2 == 0)
			if sur_route:
				# Plateau bâché : la face avant (0,8 m) est la prise sur laquelle on se hisse.
				_ajouter("bache", BACHE, Transform3D(_ech(base, Vector3(COLONNE - 0.04, 0.8, PROFONDEUR)), o - Vector3.UP * 0.4))
				_boite(corps, base, Vector3(COLONNE, 0.8, PROFONDEUR), o - Vector3.UP * 0.4)
			else:
				_ajouter("plancher", PLANCHER, Transform3D(_ech(base, Vector3(COLONNE - 0.04, 0.06, PROFONDEUR)), o - Vector3.UP * 0.03))
				_boite(corps, base, Vector3(COLONNE, 0.06, PROFONDEUR), o - Vector3.UP * 0.03)
			# Lisses : garde-corps côté vide (visuel seulement) et plinthe.
			var ext := o + base.z * (PROFONDEUR * 0.5)
			_ajouter("tube", TUBE, Transform3D(_ech(base, Vector3(COLONNE, 0.05, 0.05)), ext + Vector3.UP * 1.0))
			_ajouter("tube", TUBE, Transform3D(_ech(base, Vector3(COLONNE, 0.05, 0.05)), ext + Vector3.UP * 0.5))
		# Diagonale de contreventement une travée sur trois.
		for i in range(0, nb_col, 3):
			var p := a + d * (debut + (i + 0.5) * COLONNE) + n * (ECART_MUR + PROFONDEUR)
			var diag := atan2(niveau, COLONNE)
			var bd := base * Basis(Vector3.BACK, diag)
			_ajouter("tube", TUBE, Transform3D(_ech(bd, Vector3(sqrt(niveau * niveau + COLONNE * COLONNE), 0.05, 0.05)), Vector3(p.x, y - niveau * 0.5, p.y)))
	# Filet de chantier sur le haut, pour la silhouette de loin.
	var pf := a + d * (long * 0.5) + n * (ECART_MUR + PROFONDEUR + 0.05)
	_ajouter("filet", Color(0.85, 0.88, 0.9), Transform3D(_ech(base, Vector3(nb_col * COLONNE, 1.4, 0.02)), Vector3(pf.x, toit + 0.5, pf.y)))
	var depart := a + d * (debut + (c_route + 0.5) * COLONNE) + n * (ECART_MUR + PROFONDEUR + 0.8)
	acces.append(["échafaudage de la barre", Vector3(depart.x, h(depart.x, depart.y), depart.y), toit, Vector3(n.x, 0, n.y), Vector3(d.x, 0, d.y)])
	# Panneau de chantier au pied (sans marque).
	var pp := a + d * (debut - 1.2) + n * 2.0
	_ajouter("panneau", Color(0.95, 0.93, 0.85), Transform3D(_ech(base, Vector3(2.0, 1.3, 0.05)), Vector3(pp.x, h(pp.x, pp.y) + 1.6, pp.y)))
	_ajouter("tube", TUBE, Transform3D(Basis.from_scale(Vector3(0.06, 2.2, 0.06)), Vector3(pp.x, h(pp.x, pp.y) + 1.1, pp.y)))


# ───────────────────────── escaliers de secours ─────────────────────────

func _escalier_secours(nom: String, poly: PackedVector2Array, cote: int, pos: float, toit: float) -> void:
	# Côté choisi, ou à défaut le plus long.
	var k := cote
	if k < 0:
		var lmax := 0.0
		for j in poly.size():
			var l := poly[j].distance_to(poly[(j + 1) % poly.size()])
			if l > lmax:
				lmax = l
				k = j
	var a := poly[k]
	var b := poly[(k + 1) % poly.size()]
	var long := a.distance_to(b)
	var d := (b - a) / long
	var n := _normale_dehors(a, b, poly)
	var base := _base(n)
	const RUN := 3.2       # longueur d'une volée
	const PALIER := 1.2
	const VOIE := 1.0      # largeur d'une volée
	var t0 := clampf(long * pos, PALIER + 0.5, long - RUN - PALIER * 2 - 0.5)
	var p0 := a + d * t0    # début de la première volée, contre le mur
	var y0 := h(p0.x + n.x * 1.5, p0.y + n.y * 1.5)
	var cible := toit - 1.3  # dernier palier : on se hisse ensuite sur l'acrotère (+2,05 m)
	var nb := maxi(2, int(round((cible - y0) / 1.5)))
	var r := (cible - y0) / nb
	var corps := StaticBody3D.new()
	corps.name = "Escalier_" + nom.validate_node_name()
	corps.add_to_group("prise")
	add_child(corps)
	var pente := atan2(r, RUN)
	for v in nb:
		var aller := v % 2 == 0
		var voie := 0.5 if aller else 1.5     # distance du mur au milieu de la volée
		var bas := y0 + v * r
		var dep := p0 if aller else p0 + d * RUN
		var sens := d if aller else -d
		var mid := dep + sens * (RUN * 0.5) + n * (ECART_MUR + voie)
		# Repère de la volée : x le long de la montée.
		var x := Vector3(sens.x, 0, sens.y)
		var bv := Basis(x, Vector3.UP, x.cross(Vector3.UP)) * Basis(Vector3.BACK, pente)
		var lg := sqrt(RUN * RUN + r * r)
		var centre := Vector3(mid.x, bas + r * 0.5, mid.y)
		_ajouter("metal", METAL, Transform3D(_ech(bv, Vector3(lg, 0.08, VOIE)), centre - bv.y * 0.04))
		_boite(corps, bv, Vector3(lg, 0.08, VOIE), centre - bv.y * 0.04)
		# Marches dessinées (visuel) et main courante.
		var nb_m := int(r / 0.18)
		for m in nb_m:
			var f := (m + 0.5) / nb_m
			var pm := Vector3(dep.x, bas, dep.y) + x * (RUN * f) + Vector3(n.x, 0, n.y) * (ECART_MUR + voie) + Vector3.UP * (r * f + 0.02)
			_ajouter("marche", METAL.darkened(0.25), Transform3D(_ech(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(0.04, 0.03, VOIE)), pm))
		if not aller:
			_ajouter("rampe", METAL.darkened(0.15), Transform3D(_ech(bv, Vector3(lg, 0.05, 0.05)), centre + Vector3.UP * 0.95 + Vector3(n.x, 0, n.y) * (VOIE * 0.5)))
		# Palier d'arrivée, sur les deux voies.
		var arr := dep + sens * RUN + sens * (PALIER * 0.5)
		var pc := arr + n * (ECART_MUR + 1.0)
		var yp := bas + r
		_ajouter("metal", METAL, Transform3D(_ech(base, Vector3(PALIER, 0.1, 2.0)), Vector3(pc.x, yp - 0.05, pc.y)))
		_boite(corps, base, Vector3(PALIER, 0.1, 2.0), Vector3(pc.x, yp - 0.05, pc.y))
		var bord := arr + sens * (PALIER * 0.5)
		_ajouter("rampe", METAL.darkened(0.15), Transform3D(_ech(base, Vector3(0.05, 1.0, 2.0)), Vector3(bord.x + n.x * (ECART_MUR + 1.0), yp + 0.5, bord.y + n.y * (ECART_MUR + 1.0))))
		_ajouter("rampe", METAL.darkened(0.15), Transform3D(_ech(base, Vector3(PALIER, 1.0, 0.05)), Vector3(pc.x, yp + 0.5, pc.y) + base.z * 1.0))
	# Le dernier palier est en bleu bâche : c'est là qu'on se hisse.
	var arr_fin := (p0 + d * (RUN + PALIER * 0.5)) if (nb - 1) % 2 == 0 else (p0 - d * (PALIER * 0.5))
	var pc := arr_fin + n * (ECART_MUR + 1.0)
	_ajouter("bache", BACHE, Transform3D(_ech(base, Vector3(PALIER, 0.04, 2.0)), Vector3(pc.x, cible + 0.01, pc.y)))
	var dep_sol := p0 + n * (ECART_MUR + 0.5) - d * 1.0
	var fin := pc - n * 0.6
	acces.append(["escalier de secours : " + nom, Vector3(dep_sol.x, h(dep_sol.x, dep_sol.y), dep_sol.y), toit, Vector3(n.x, 0, n.y), Vector3(fin.x, cible, fin.y)])


# ───────────────────────── briques ─────────────────────────

func _boite(corps: StaticBody3D, b: Basis, taille: Vector3, o: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	cs.transform = Transform3D(b.orthonormalized(), o)
	corps.add_child(cs)


func _ech(b: Basis, e: Vector3) -> Basis:
	return b * Basis.from_scale(e)


func _base(n: Vector2) -> Basis:
	var z := Vector3(n.x, 0, n.y).normalized()
	return Basis(Vector3.UP.cross(z), Vector3.UP, z)


func _normale_dehors(a: Vector2, b: Vector2, poly: PackedVector2Array) -> Vector2:
	var d := (b - a).normalized()
	var nrm := Vector2(d.y, -d.x)
	if Geometry2D.is_point_in_polygon((a + b) * 0.5 + nrm * 0.3, poly):
		nrm = -nrm
	return nrm


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
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("couleur", _paquets[cle][0])
		m.set_shader_parameter("grain", 0.4)
		mi.material_override = m
		mi.name = "Toits_" + cle
		add_child(mi)


func _poly(s: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in s.split(" ", false):
		var xy := p.split(",")
		out.append(Vector2(float(xy[0]), float(xy[1])))
	if out.size() > 2 and out[0].distance_to(out[out.size() - 1]) < 0.01:
		out.remove_at(out.size() - 1)
	return out
