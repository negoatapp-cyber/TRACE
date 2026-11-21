extends Node3D
## TRACE — la place du Jardin, au pied de la barre et de la tour des Cyprès (conversation n°2).
## Formes reprises des places de grands ensembles des années 1970 (références de Louma : La Grande Borne,
## Émile Aillaud) et transposées aux Lauriers, sans copier d'œuvre :
##  - des collines de pavés posés en cercles autour de leur sommet ;
##  - un amphithéâtre de gradins ronds en « nuage » ;
##  - un mur courbe en pente, avec un panier de basket devant ;
##  - des gradins de blocs de béton autour d'une jardinière, avec un banc en bois ;
##  - des peupliers dans des bacs en béton.
## (Une mosaïque de pignon est prête dans _mosaique(), non posée : rien de tel aux Lauriers en 2014.)
## Tout se skate et se grimpe : collisions comprises.

const TOON := preload("res://shaders/bd_toon.gdshader")
const PAVES := preload("res://shaders/paves.gdshader")
const BETON := Color(0.80, 0.79, 0.75)
const BOIS := Color(0.62, 0.45, 0.30)
const FEUILLAGE := Color(0.30, 0.42, 0.28)

## Où poser chaque élément (x, z, orientation en degrés) : la bande plate entre l'avenue Saint-Paul
## et les petites barres rouges (Immeubles A et B), le seul grand terrain plat libre du secteur.
const COLLINES := Vector3(-131.0, 40.0, 90.0)
const AMPHI := Vector3(-131.0, 64.0, 0.0)
const MUR_COURBE := Vector3(-128.0, 6.0, 180.0)
const BLOCS := [Vector3(-122.0, 21.0, 0.0), Vector3(-123.0, 57.0, 90.0)]
const PEUPLIERS := [Vector2(-119.5, 28.0), Vector2(-119.5, 38.0), Vector2(-119.5, 48.0), Vector2(-137.0, 22.0), Vector2(-121.0, 70.0)]

var habillage: Node
var _paquets := {}
var _cube := BoxMesh.new()
var _cyl := CylinderMesh.new()
var _corps: StaticBody3D


## Emprises au sol (pour que le mobilier des rues ne s'y pose pas).
static func emprises() -> Array:
	var out := []
	for c in [Vector2(COLLINES.x, COLLINES.z), Vector2(AMPHI.x, AMPHI.z), Vector2(MUR_COURBE.x, MUR_COURBE.z)]:
		var r := 13.0
		out.append(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)]))
	return out


func construire(batiments: Array) -> void:
	_cube.size = Vector3.ONE
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 16
	_corps = StaticBody3D.new()
	_corps.name = "Place_collisions"
	_corps.add_to_group("prise")
	add_child(_corps)
	_collines(COLLINES)
	_amphitheatre(AMPHI)
	_mur_courbe(MUR_COURBE)
	for b in BLOCS:
		_gradins_blocs(b)
	for p in PEUPLIERS:
		_peuplier(p)
	_poser_paquets()


func h(x: float, z: float) -> float:
	return habillage.h(x, z)


# ───────────────────────── collines de pavés ─────────────────────────

func _collines(o: Vector3) -> void:
	const L := 26.0
	const W := 15.0
	const PAS := 0.35
	# [x, z, hauteur, rayon] en coordonnées locales
	var bosses := [[-8.0, -2.0, 2.4, 4.6], [-1.5, 3.0, 1.3, 3.2], [4.0, -1.5, 1.9, 3.9], [9.5, 3.0, 1.0, 2.7], [-11.0, 4.5, 0.9, 2.4], [2.5, -5.0, 0.7, 2.2], [11.0, -4.0, 0.6, 2.0]]
	var rot := Basis(Vector3.UP, deg_to_rad(o.z))
	var centre := Vector3(o.x, 0, o.y)
	var nx := int(L / PAS) + 1
	var nz := int(W / PAS) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for j in nz:
		for i in nx:
			var lx := -L * 0.5 + i * PAS
			var lz := -W * 0.5 + j * PAS
			var y := 0.12
			var meilleur := 0
			var dmin := INF
			for k in bosses.size():
				var b: Array = bosses[k]
				var d := Vector2(lx - b[0], lz - b[1]).length()
				var t := clampf(d / b[3], 0.0, 1.0)
				y = maxf(y, 0.12 + b[2] * (0.5 + 0.5 * cos(PI * t)))
				if d / b[3] < dmin:
					dmin = d / b[3]
					meilleur = k
			# bord : un petit chanfrein vers le sol
			var bord := minf(minf(lx + L * 0.5, L * 0.5 - lx), minf(lz + W * 0.5, W * 0.5 - lz))
			y *= clampf(bord / 0.5, 0.0, 1.0) * 0.8 + 0.2
			var w := centre + rot * Vector3(lx, 0, lz)
			w.y = h(w.x, w.z) + y - 0.05
			var bc: Array = bosses[meilleur]
			pts.append([w, Vector2(lx, lz), Color((bc[0] + 20.0) / 40.0, (bc[1] + 20.0) / 40.0, 0.0)])
	for j in nz - 1:
		for i in nx - 1:
			var a: int = j * nx + i
			for idx in [a, a + nx, a + 1, a + 1, a + nx, a + nx + 1]:
				var p: Array = pts[idx]
				st.set_color(p[2])
				st.set_uv(p[1])
				st.add_vertex(p[0] - centre)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = PAVES
	mi.material_override = m
	mi.position = centre
	mi.name = "Collines_de_paves"
	add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	cs.position = centre
	_corps.add_child(cs)
	# Bordure de pavés autour (une rangée qui dépasse à peine).
	for s in [-1.0, 1.0]:
		for a2 in [0, 1]:
			var long := L if a2 == 0 else W
			var off := (W if a2 == 0 else L) * 0.5 + 0.25
			var nrm := Vector3(0, 0, 1) if a2 == 0 else Vector3(1, 0, 0)
			var pos: Vector3 = centre + rot * (nrm * off * s)
			pos.y = h(pos.x, pos.z) + 0.03
			var b3 := rot if a2 == 0 else rot * Basis(Vector3.UP, PI * 0.5)
			_ajouter("bordure", Color(0.55, 0.53, 0.52), Transform3D(b3 * Basis.from_scale(Vector3(long + 1.0, 0.1, 0.5)), pos))


# ───────────────────────── amphithéâtre en nuage ─────────────────────────

func _amphitheatre(o: Vector3) -> void:
	var c := Vector2(o.x, o.y)
	var sol := h(c.x, c.y)
	var gradins := [[5.6, 1.35], [4.4, 0.9], [3.2, 0.45]]   # [rayon, hauteur] : le haut à l'extérieur
	for g in gradins:
		var r: float = g[0]
		var hh: float = g[1]
		var nb := int(round(TAU * r / 1.5))
		for i in nb:
			var a := TAU * i / nb + (0.2 if r < 4.0 else 0.0)
			if absf(wrapf(a - deg_to_rad(o.z + 90.0), -PI, PI)) < 0.45:
				continue   # une entrée
			var p := c + Vector2(cos(a), sin(a)) * r
			var lobe := 0.95
			var pos := Vector3(p.x, h(p.x, p.y) + hh * 0.5 - 0.05, p.y)
			_ajouter_cyl("gradin", BETON, Transform3D(Basis.from_scale(Vector3(lobe * 2.0, hh, lobe * 2.0)), pos))
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = lobe
			sh.height = hh
			cs.shape = sh
			cs.position = pos
			_corps.add_child(cs)
	# fond : sable clair
	_ajouter_cyl("sable", Color(0.86, 0.80, 0.66), Transform3D(Basis.from_scale(Vector3(6.4, 0.06, 6.4)), Vector3(c.x, sol + 0.02, c.y)))


# ───────────────────────── mur courbe en pente + panier ─────────────────────────

func _mur_courbe(o: Vector3) -> void:
	var c := Vector2(o.x, o.y)
	var sol := h(c.x, c.y)
	const R := 8.0          # rayon intérieur (pied de la pente)
	const HAUT := 1.5
	const PENTE := 38.0
	var course := HAUT / tan(deg_to_rad(PENTE))
	var debut := deg_to_rad(o.z - 60.0)
	var nb := 14
	var pas_a := deg_to_rad(120.0) / nb
	for i in nb:
		var a := debut + (i + 0.5) * pas_a
		var radial := Vector3(cos(a), 0, sin(a))
		var tang := Vector3(-sin(a), 0, cos(a))
		var ps := Vector2(c.x, c.y) + Vector2(radial.x, radial.z) * (R + course * 0.5)
		sol = h(ps.x, ps.y) - 0.05
		var larg := 2.0 * (R + course) * sin(pas_a * 0.5) + 0.08
		# la pente : une dalle inclinée qui monte vers l'extérieur
		var bp := Basis(tang, Vector3.UP, -radial).orthonormalized()   # z = vers le centre
		var incl := bp * Basis(Vector3.RIGHT, -deg_to_rad(PENTE))
		var lg := sqrt(course * course + HAUT * HAUT)
		var milieu := Vector3(c.x, sol, c.y) + radial * (R + course * 0.5) + Vector3.UP * (HAUT * 0.5)
		var t := Transform3D(incl * Basis.from_scale(Vector3(larg, 0.3, lg)), milieu - incl.y * 0.15)
		_ajouter("pente", Color(0.74, 0.73, 0.70), t)
		_boite(incl, Vector3(larg, 0.3, lg), milieu - incl.y * 0.15)
		# le dessus plat et le dos
		var dessus := Vector3(c.x, sol, c.y) + radial * (R + course + 0.4) + Vector3.UP * (HAUT - 0.1)
		_ajouter("pente", Color(0.74, 0.73, 0.70), Transform3D(bp * Basis.from_scale(Vector3(larg, 0.2, 0.8)), dessus))
		_boite(bp, Vector3(larg, 0.2, 0.8), dessus)
		var dos := Vector3(c.x, sol, c.y) + radial * (R + course + 0.75) + Vector3.UP * (HAUT * 0.5)
		_ajouter("pente", Color(0.66, 0.65, 0.63), Transform3D(bp * Basis.from_scale(Vector3(larg, HAUT, 0.12)), dos))
		_boite(bp, Vector3(larg, HAUT, 0.12), dos)
	# le panier, devant la pente, au milieu de l'arc
	var am := deg_to_rad(o.z)
	var pp := c + Vector2(cos(am), sin(am)) * (R - 2.0)
	var vers := -Vector3(cos(am), 0, sin(am))   # le panneau regarde vers le centre de l'arc
	var bpan := Basis(vers.cross(Vector3.UP).normalized(), Vector3.UP, -vers).orthonormalized()
	var y0 := h(pp.x, pp.y)
	_ajouter("poteau", Color(0.35, 0.36, 0.38), Transform3D(Basis.from_scale(Vector3(0.12, 3.6, 0.12)), Vector3(pp.x, y0 + 1.8, pp.y)))
	var panneau := Vector3(pp.x, y0 + 3.35, pp.y) + vers * 0.5
	_ajouter("panneau", Color(0.95, 0.95, 0.93), Transform3D(bpan * Basis.from_scale(Vector3(1.8, 1.05, 0.05)), panneau))
	_ajouter("poteau", Color(0.35, 0.36, 0.38), Transform3D(bpan * Basis.from_scale(Vector3(0.08, 0.08, 0.5)), Vector3(pp.x, y0 + 3.35, pp.y) + vers * 0.25))
	var cercle := Vector3(pp.x, y0 + 3.05, pp.y) + vers * 0.78
	_ajouter_cyl("cercle", Color(0.85, 0.35, 0.15), Transform3D(Basis.from_scale(Vector3(0.46, 0.03, 0.46)), cercle))


# ───────────────────────── gradins de blocs de béton ─────────────────────────

func _gradins_blocs(o: Vector3) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(o.z))
	var base := Vector3(o.x, h(o.x, o.y), o.y)
	# [taille, centre local] — jardinière, marches et cubes décalés, comme un escalier qu'on s'invente
	var blocs := [
		[Vector3(3.4, 1.0, 1.9), Vector3(0.4, 0.5, 0.0)],
		[Vector3(3.8, 0.5, 1.0), Vector3(0.6, 0.25, 1.45)],
		[Vector3(1.1, 0.95, 1.1), Vector3(-2.3, 0.475, 0.9)],
		[Vector3(1.1, 0.45, 1.0), Vector3(-3.4, 0.225, 1.5)],
		[Vector3(1.7, 0.5, 1.1), Vector3(1.5, 0.25, 2.5)],
		[Vector3(1.2, 0.95, 1.0), Vector3(2.9, 0.475, 1.5)],
	]
	for bl in blocs:
		var taille: Vector3 = bl[0]
		var p: Vector3 = base + b * bl[1]
		_ajouter("bloc", BETON, Transform3D(b * Basis.from_scale(taille), p))
		_boite(b, taille, p)
	# terre et petit arbre dans la jardinière
	_ajouter("terre", Color(0.42, 0.33, 0.25), Transform3D(b * Basis.from_scale(Vector3(3.1, 0.04, 1.6)), base + b * Vector3(0.4, 1.0, 0.0)))
	if not _arbre("feuillu", base + b * Vector3(0.6, 1.0, 0.0), 0.55):
		_ajouter("tronc", Color(0.40, 0.32, 0.26), Transform3D(b * Basis.from_scale(Vector3(0.09, 2.6, 0.09)), base + b * Vector3(0.6, 2.3, 0.0)))
		_ajouter("feuillage", FEUILLAGE, Transform3D(b * Basis.from_scale(Vector3(1.4, 1.2, 1.4)), base + b * Vector3(0.6, 3.6, 0.0)))
	# le banc en bois glissé entre deux cubes
	for k in 4:
		_ajouter("banc", BOIS, Transform3D(b * Basis.from_scale(Vector3(1.4, 0.05, 0.09)), base + b * Vector3(-1.15, 0.45, 1.25 + k * 0.12)))
	_boite(b, Vector3(1.4, 0.06, 0.5), base + b * Vector3(-1.15, 0.45, 1.43))


# ───────────────────────── peupliers en bac ─────────────────────────

func _peuplier(p: Vector2) -> void:
	var y := h(p.x, p.y)
	_ajouter("bloc", BETON, Transform3D(Basis.from_scale(Vector3(1.5, 0.55, 1.5)), Vector3(p.x, y + 0.275, p.y)))
	_boite(Basis(), Vector3(1.5, 0.55, 1.5), Vector3(p.x, y + 0.275, p.y))
	_ajouter("terre", Color(0.42, 0.33, 0.25), Transform3D(Basis.from_scale(Vector3(1.2, 0.04, 1.2)), Vector3(p.x, y + 0.55, p.y)))
	# arbre généré en fuseau (cyprès, arbres.gd) ; à défaut, trois volumes empilés
	if _arbre("cypres", Vector3(p.x, y + 0.55, p.y), 0.8):
		return
	_ajouter("tronc", Color(0.40, 0.32, 0.26), Transform3D(Basis.from_scale(Vector3(0.14, 2.0, 0.14)), Vector3(p.x, y + 1.5, p.y)))
	# silhouette en fuseau : trois volumes empilés, de plus en plus fins
	var hauts := [[1.6, 2.6, 3.2], [1.3, 2.4, 5.6], [0.8, 2.0, 7.6]]
	for e in hauts:
		_ajouter_cyl("peuplier", FEUILLAGE.darkened(0.08), Transform3D(Basis(Vector3.UP, randf()) * Basis.from_scale(Vector3(e[0], e[1], e[0])), Vector3(p.x, y + e[2], p.y)))


# ───────────────────────── mosaïque du pignon de Cyprès A ─────────────────────────

## Une sardine qui plonge, en carreaux de céramique, sur fond de carreaux terre cuite.
func _mosaique(poly: PackedVector2Array, hauteur: float) -> void:
	# le pignon nord : le côté court le plus au nord (z le plus grand)
	var k_best := 0
	var zmax := -INF
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		if a.distance_to(b) < 16.0 and (a.y + b.y) * 0.5 > zmax:
			zmax = (a.y + b.y) * 0.5
			k_best = k
	var a := poly[k_best]
	var b := poly[(k_best + 1) % poly.size()]
	var long := a.distance_to(b)
	var d := (b - a) / long
	var nrm := Vector2(d.y, -d.x)
	if Geometry2D.is_point_in_polygon((a + b) * 0.5 + nrm * 0.3, poly):
		nrm = -nrm
	var moy := 0.0
	for p in poly:
		moy += h(p.x, p.y)
	moy /= poly.size()
	var base := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(nrm.x, 0, nrm.y))
	if base.determinant() < 0.0:
		base = Basis(-Vector3(d.x, 0, d.y), Vector3.UP, Vector3(nrm.x, 0, nrm.y))
	const PIX := 0.5
	var nx := int((long - 1.6) / PIX)
	var ny := int(minf(hauteur - 14.0, 26.0) / PIX)
	var bas := moy + 9.0
	var centre_mur := (a + b) * 0.5 + nrm * 0.06
	var fond1 := Color(0.80, 0.50, 0.32)
	var fond2 := Color(0.74, 0.45, 0.29)
	var dos := Color(0.18, 0.30, 0.52)
	var flanc := Color(0.55, 0.68, 0.80)
	var ventre := Color(0.93, 0.94, 0.92)
	var noir_trait := Color(0.15, 0.17, 0.22)
	var cols := []
	for j in ny:
		for i in nx:
			# coordonnées normalisées : u de -1 à 1 sur la largeur, v de 0 (bas) à 1 (haut)
			var u := (i + 0.5) / nx * 2.0 - 1.0
			var v := (j + 0.5) / ny
			var c := fond1 if ((i / 4 + j / 4) % 2 == 0) else fond2
			# le corps : un fuseau vertical, la tête en bas (elle plonge), légèrement penché
			var vv := v - 0.06
			var uu := u + (vv - 0.5) * 0.25
			var demi := 0.62 * sin(PI * clampf(vv / 0.8, 0.0, 1.0))
			if vv > 0.0 and vv < 0.8 and absf(uu) < demi:
				var x := uu / maxf(demi, 0.01)
				c = flanc
				if x < -0.35: c = dos
				if x > 0.45: c = ventre
				# l'œil, près de la tête
				if Vector2(uu + 0.12, (vv - 0.12) * 1.6).length() < 0.11: c = ventre
				if Vector2(uu + 0.12, (vv - 0.12) * 1.6).length() < 0.055: c = noir_trait
				# l'ouïe
				if absf(vv - 0.24 - uu * 0.15) < 0.012 and absf(uu) < demi * 0.8: c = noir_trait
				# petites taches le long du dos
				if x < -0.1 and x > -0.35 and int(vv * 30.0) % 3 == 0 and int(uu * 30.0) % 2 == 0: c = dos
			# la queue en fourche, en haut
			var q := v - 0.84
			if q > 0.0 and q < 0.14 and absf(absf(u + 0.1) - q * 2.6) < 0.16: c = dos
			cols.append([c, i, j])
	for e in cols:
		var p: Vector2 = centre_mur + d * ((e[1] + 0.5) * PIX - nx * PIX * 0.5)
		var pos := Vector3(p.x, bas + (e[2] + 0.5) * PIX, p.y)
		_ajouter("mosaique", e[0], Transform3D(base * Basis.from_scale(Vector3(PIX * 0.94, PIX * 0.94, 0.06)), pos), true)
	# un cadre de carreaux sombres
	var cadre := Color(0.42, 0.26, 0.20)
	var hm := ny * PIX
	var lm := nx * PIX
	for s in [-1.0, 1.0]:
		var pc: Vector2 = centre_mur + d * (s * (lm * 0.5 + 0.2))
		_ajouter("mosaique", cadre, Transform3D(base * Basis.from_scale(Vector3(0.4, hm + 0.8, 0.07)), Vector3(pc.x, bas + hm * 0.5, pc.y)), true)
		var py: float = bas + hm * 0.5 + s * (hm * 0.5 + 0.2)
		_ajouter("mosaique", cadre, Transform3D(base * Basis.from_scale(Vector3(lm + 0.8, 0.4, 0.07)), Vector3(centre_mur.x, py, centre_mur.y)), true)


# ───────────────────────── briques ─────────────────────────

func _boite(b: Basis, taille: Vector3, o: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	cs.transform = Transform3D(b.orthonormalized(), o)
	_corps.add_child(cs)


func _ajouter(cle: String, c: Color, t: Transform3D, instance := false) -> void:
	if not _paquets.has(cle):
		_paquets[cle] = [_cube, c, [], instance]
	(_paquets[cle][2] as Array).append([t, c])


func _ajouter_cyl(cle: String, c: Color, t: Transform3D) -> void:
	if not _paquets.has(cle):
		_paquets[cle] = [_cyl, c, [], false]
	(_paquets[cle][2] as Array).append([t, c])


func _poser_paquets() -> void:
	for cle in _paquets:
		var pq: Array = _paquets[cle]
		var liste: Array = pq[2]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = pq[3]
		mm.mesh = pq[0]
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i][0])
			if pq[3]:
				mm.set_instance_color(i, liste[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("couleur", pq[1])
		m.set_shader_parameter("couleur_instance", pq[3])
		m.set_shader_parameter("grain", 0.5)
		mi.material_override = m
		mi.name = "Place_" + cle
		add_child(mi)


func _poly(s: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in s.split(" ", false):
		var xy := p.split(",")
		out.append(Vector2(float(xy[0]), float(xy[1])))
	if out.size() > 2 and out[0].distance_to(out[out.size() - 1]) < 0.01:
		out.remove_at(out.size() - 1)
	return out


## Un arbre généré (scripts/arbres.gd) posé à « pied », en coordonnées du monde. false si les modèles manquent.
func _arbre(espece: String, pied: Vector3, echelle: float) -> bool:
	var a: Node3D = load("res://scripts/arbres.gd").arbre(espece, int(pied.x * 7.0 + pied.z * 13.0))
	if a == null:
		return false
	a.position = pied
	a.rotation.y = fposmod(pied.x * 1.7 + pied.z, TAU)
	a.scale = Vector3.ONE * echelle
	add_child(a)
	return true
