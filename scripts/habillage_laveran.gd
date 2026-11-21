extends Node3D
## TRACE — le boulevard Lavéran en 2013 (conversation n°2), d'après les Street View 2011-2014 de Louma.
##  - Le SNACK : la petite baraque à sandwiches, lieu central de vie. On y revient chercher de la peinture :
##    zone « ravitaillement » (Area3D, groupe « ravitaillement », meta type = "peinture") que n°1 branche
##    sur graffiti.gd. Autour : chaises, mange-debout, scooters, cagette de bombes, poubelle.
##    (Pas le vrai nom de l'enseigne : seulement « SNACK » / « SANDWICHES », règle « aucune marque réelle ».)
##  - La façade du lycée côté boulevard : mur de clôture carrelé blanc à bande turquoise, grille blanche dessus,
##    grande structure tubulaire bleu ciel en treillis, la verrière d'entrée en voûte, le lettrage, l'arrêt de bus.
##  - Le chantier de 2013 : grue à tour, palissades blanches taguées, blocs béton rouges et blancs.

const TOON := preload("res://shaders/bd_toon.gdshader")
const BLEU_TUBE := Color(0.43, 0.57, 0.69)
const BLANC_TUBE := Color(0.58, 0.67, 0.73)   # au nord de la verrière, le treillis est blanc (Street View 2013)
const CARRELAGE := Color(0.88, 0.89, 0.88)
const TURQUOISE := Color(0.28, 0.62, 0.62)
const BLANC_GRILLE := Color(0.90, 0.91, 0.90)
const GRAFF := "res://assets/decor/graff/%s.png"

## Le snack : côté lycée du boulevard, au nord de la clôture, face à la chaussée (hypothèse à confirmer).
const SNACK := Vector2(124.0, 42.0)

var habillage: Node
var _paquets := {}
var _cube := BoxMesh.new()
var _cyl := CylinderMesh.new()
var _corps: StaticBody3D


func construire(batiments: Array, voies: Array, portes: Array, epoque: String) -> void:
	_cube.size = Vector3.ONE
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 20
	_corps = StaticBody3D.new()
	_corps.name = "Laveran_collisions"
	add_child(_corps)
	var bd := PackedVector2Array()
	for c in voies:
		if c[2] == "Boulevard Lavéran":
			bd = _poly(c[3])
	var lycee := PackedVector2Array()
	for c in batiments:
		if c[1] == "Lycée":
			lycee = _poly(c[4])
	_snack(bd)
	if lycee.size() > 2:
		_facade_laveran(lycee, bd, portes, epoque)
		_stationnement(bd)
		_mur_en_face(lycee, bd)
		_mobilier_boulevard(lycee, bd)
		if epoque == "avant" and not get_parent().get_parent().has_meta("diderot_archives"):
			_chantier(lycee, bd)
	_poser_paquets()


func h(x: float, z: float) -> float:
	return habillage.h(x, z)


# ───────────────────────── le snack ─────────────────────────

func _snack(bd: PackedVector2Array) -> void:
	# face au boulevard
	var vers := Vector2(1, 0)
	if bd.size() > 1:
		var best := INF
		for k in bd.size() - 1:
			var cp := Geometry2D.get_closest_point_to_segment(SNACK, bd[k], bd[k + 1])
			if cp.distance_to(SNACK) < best:
				best = cp.distance_to(SNACK)
				vers = (cp - SNACK).normalized()
	var z := Vector3(vers.x, 0, vers.y)
	var base := Basis(Vector3.UP.cross(z).normalized(), Vector3.UP, z)
	var y := h(SNACK.x, SNACK.y)
	var o := Vector3(SNACK.x, y, SNACK.y)
	var gris := Color(0.46, 0.50, 0.50)
	# la baraque : un caisson, le toit qui déborde, le nez arrondi à lames côté « SANDWICHES »
	_boite_v("snack", gris, base, Vector3(4.2, 2.7, 2.6), o + Vector3.UP * 1.35)
	_ajouter("snack_toit", Color(0.30, 0.32, 0.33), Transform3D(base * Basis.from_scale(Vector3(5.0, 0.18, 3.6)), o + Vector3.UP * 2.8 + z * 0.3))
	var nez := base * Basis(Vector3.BACK, PI * 0.5)
	_ajouter_cyl("snack_nez", Color(0.70, 0.72, 0.72), Transform3D(nez * Basis.from_scale(Vector3(2.7, 1.2, 2.7)), o + Vector3.UP * 1.45 - base.x * 2.1))
	for i in 9:
		_ajouter("snack_lames", gris.darkened(0.25), Transform3D(base * Basis.from_scale(Vector3(0.04, 2.0, 0.02)), o + Vector3.UP * 1.3 - base.x * (2.2 + 0.1 * i) + z * (1.31 - 0.04 * i * i * 0.1)))
	# rideau métallique tagué et comptoir
	_ajouter("snack_rideau", Color(0.70, 0.71, 0.70), Transform3D(base * Basis.from_scale(Vector3(2.6, 1.4, 0.04)), o + Vector3.UP * 1.55 + z * 1.32 + base.x * 0.4))
	_ajouter("snack_comptoir", Color(0.62, 0.64, 0.62), Transform3D(base * Basis.from_scale(Vector3(2.8, 0.08, 0.45)), o + Vector3.UP * 0.92 + z * 1.5 + base.x * 0.4))
	_decalque("tag_%02d" % 3, o + Vector3.UP * 1.55 + z * 1.36 + base.x * 0.4, base.x, z, 2.2, Color(0.12, 0.12, 0.14))
	_decalque("enseigne_snack", o + Vector3.UP * 2.48 + z * 1.33 + base.x * 0.2, base.x, z, 2.9, Color.WHITE)
	_decalque("enseigne_sandwiches", o + Vector3.UP * 2.0 - base.x * 2.1 + z * 0.2, -z, -base.x, 2.2, Color.WHITE)
	# la vie autour : mange-debout, chaises en plastique, scooters, cagette de bombes, poubelle
	var devant := o + z * 3.2
	_ajouter_cyl("snack_table", Color(0.85, 0.85, 0.82), Transform3D(Basis.from_scale(Vector3(0.7, 0.04, 0.7)), devant + Vector3.UP * 1.1 + base.x * 1.8))
	_ajouter_cyl("snack_pied", Color(0.3, 0.3, 0.32), Transform3D(Basis.from_scale(Vector3(0.08, 1.1, 0.08)), devant + Vector3.UP * 0.55 + base.x * 1.8))
	for k in 3:
		var pc := devant + base.x * (-1.5 + k * 1.0) + z * (0.4 * (k % 2))
		var bc := Basis(Vector3.UP, randf() * TAU)
		_ajouter("snack_chaise", Color(0.94, 0.94, 0.92), Transform3D(bc * Basis.from_scale(Vector3(0.45, 0.05, 0.45)), pc + Vector3.UP * 0.45))
		_ajouter("snack_chaise", Color(0.94, 0.94, 0.92), Transform3D(bc * Basis.from_scale(Vector3(0.45, 0.45, 0.05)), pc + Vector3.UP * 0.7 + bc.z * 0.2))
		_ajouter("snack_chaise", Color(0.94, 0.94, 0.92), Transform3D(bc * Basis.from_scale(Vector3(0.38, 0.45, 0.38)), pc + Vector3.UP * 0.22))
	# cagette de bombes près du comptoir : le repère visuel du ravitaillement
	var cg := o + z * 1.9 + base.x * 1.9
	_boite_v("snack_cagette", Color(0.62, 0.45, 0.28), base, Vector3(0.6, 0.35, 0.4), cg + Vector3.UP * 0.175)
	var teintes := [Color(0.93, 0.18, 0.47), Color(0.98, 0.82, 0.10), Color(0.15, 0.55, 0.95), Color(0.1, 0.1, 0.12)]
	for i in 8:
		var pb: Vector3 = cg + base.x * (-0.22 + (i % 4) * 0.15) + z * (-0.08 + (i / 4) * 0.16) + Vector3.UP * 0.45
		_ajouter_cyl("bombe_%d" % (i % 4), teintes[i % 4], Transform3D(Basis.from_scale(Vector3(0.07, 0.24, 0.07)), pb))
	_ajouter_cyl("snack_poubelle", Color(0.25, 0.42, 0.30), Transform3D(Basis.from_scale(Vector3(0.6, 0.9, 0.6)), o + z * 2.0 - base.x * 3.4 + Vector3.UP * 0.45))
	# la zone de ravitaillement
	var zone := Area3D.new()
	zone.name = "Ravitaillement_peinture"
	zone.add_to_group("ravitaillement")
	zone.set_meta("type", "peinture")
	zone.set_meta("nom", "Le snack")
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 3.5
	cs.shape = sh
	zone.add_child(cs)
	zone.position = o + z * 2.5 + Vector3.UP * 1.0
	add_child(zone)
	# derrière : muret bas tagué et grille blanche (vue Street View 2017, déjà là en 2013)
	for k in 6:
		var pm := o - z * 2.6 + base.x * (-6.0 + k * 2.6)
		_boite_v("muret_snack", Color(0.80, 0.80, 0.76), base, Vector3(2.62, 0.9, 0.3), Vector3(pm.x, h(pm.x, pm.z) + 0.45, pm.z))
		_ajouter("grille_snack", BLANC_GRILLE, Transform3D(base * Basis.from_scale(Vector3(2.62, 0.04, 0.04)), Vector3(pm.x, h(pm.x, pm.z) + 2.1, pm.z)))
		for b in 13:
			_ajouter("grille_snack", BLANC_GRILLE, Transform3D(base * Basis.from_scale(Vector3(0.03, 1.2, 0.03)), Vector3(pm.x, h(pm.x, pm.z) + 1.5, pm.z) + base.x * (-1.25 + b * 0.2)))
		if k % 2 == 0:
			_decalque("tag_%02d" % (5 + k), Vector3(pm.x, h(pm.x, pm.z) + 0.5, pm.z) + z * 0.16, base.x, z, 1.6, Color(0.20, 0.45, 0.35))


# ───────────────────────── façade du lycée côté boulevard ─────────────────────────

## Le côté du lycée qui longe le boulevard : le côté de plus de 30 m dont le milieu est le plus près de la chaussée.
func _cote_boulevard(lycee: PackedVector2Array, bd: PackedVector2Array) -> Array:
	var best := INF
	var res := []
	for i in lycee.size():
		var a := lycee[i]
		var b := lycee[(i + 1) % lycee.size()]
		var lg := a.distance_to(b)
		var d := (b - a) / lg
		var n := Vector2(d.y, -d.x)
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + n * 0.5, lycee):
			n = -n
		if lg < 30.0:
			continue
		var m := (a + b) * 0.5
		var dist := INF
		for k in bd.size() - 1:
			dist = minf(dist, Geometry2D.get_closest_point_to_segment(m, bd[k], bd[k + 1]).distance_to(m))
		if dist < best:
			best = dist
			res = [a, b, d, n, lg]
	return res


func _facade_laveran(lycee: PackedVector2Array, bd: PackedVector2Array, portes: Array, epoque: String) -> void:
	var c := _cote_boulevard(lycee, bd)
	if c.is_empty():
		return
	var a: Vector2 = c[0]
	var d: Vector2 = c[1] - a
	var lg: float = c[4]
	d = d.normalized()
	var n: Vector2 = c[3]
	var base := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(n.x, 0, n.y))
	if base.determinant() < 0.0:
		base = Basis(-Vector3(d.x, 0, d.y), Vector3.UP, Vector3(n.x, 0, n.y))
	# ouvertures dans la clôture : la verrière au milieu, et chaque porte du lycée sur ce côté
	_trottoir_lycee(a, d, n, lg, bd)
	var t_verriere := lg * 0.5
	# la pièce OPIR (photo SAM_3391 de Louma), en grand sur le mur, juste à gauche du portail (vue du boulevard)
	_r_opir = int((t_verriere - 7.5) / 3.0)
	var trous := [[t_verriere - 4.8, t_verriere + 4.8]]
	for p in portes:
		var pos: Vector2 = p[0]
		var t := (pos - a).dot(d)
		if absf((pos - a).dot(n)) < 1.0 and t > 0.0 and t < lg:
			trous.append([t - 1.8, t + 1.8])
	# 1. mur de clôture carrelé, bande turquoise, grille blanche dessus. Il est à 6 m de la façade là où le
	#    boulevard le permet ; là où la chaussée du relevé passe plus près, il recule pour laisser au moins 2 m de
	#    trottoir (sinon il se retrouvait dans la rue et les voitures garées contre lui).
	var ofs := func(tt: float) -> float:
		return clampf(_bord(a + d * tt, n, bd) - 2.0, 0.8, 6.0)
	var t := 0.0
	while t < lg:
		var t1 := minf(t + 3.0, lg)
		var plein := true
		for tr in trous:
			if t1 > tr[0] and t < tr[1]:
				plein = false
		var p0: Vector2 = a + d * t + n * float(ofs.call(t))
		var p1: Vector2 = a + d * t1 + n * float(ofs.call(t1))
		var m := (p0 + p1) * 0.5
		var y := h(m.x, m.y)
		var ds := (p1 - p0).normalized()
		var bs := Basis(Vector3(ds.x, 0, ds.y), Vector3.UP, Vector3(-ds.y, 0, ds.x))
		if bs.z.dot(Vector3(n.x, 0, n.y)) < 0.0:
			bs = Basis(Vector3(-ds.x, 0, -ds.y), Vector3.UP, Vector3(ds.y, 0, -ds.x))
		if plein:
			var longueur := p0.distance_to(p1) + 0.04
			# Street View juillet 2013 : mur de 2,5 m tout carrelé de blanc, bande turquoise en tête
			_boite_v("cloture_carrelage", CARRELAGE, bs, Vector3(longueur, 2.5, 0.3), Vector3(m.x, y + 1.25, m.y))
			_ajouter("cloture_turquoise", TURQUOISE, Transform3D(bs * Basis.from_scale(Vector3(longueur, 0.35, 0.32)), Vector3(m.x, y + 2.3, m.y)))
			_marques_mur(int(t / 3.0), Vector3(m.x, y, m.y) + bs.z * 0.16, bs)
			var hauteur := 0.92
			var centre := Vector3(m.x, y + 2.5 + hauteur * 0.5, m.y)
			for niveau in [-0.42,0.40]:
				_ajouter("lisse_bleue",BLEU_TUBE,Transform3D(bs*Basis.from_scale(Vector3(longueur,0.055,0.07)),centre+Vector3.UP*niveau))
			var barreaux := maxi(1,roundi(longueur / 0.15))
			for j in barreaux:
				var pos := centre + bs.x * (longueur * ((j + 0.5)/barreaux - 0.5))
				_ajouter("barreaux",Color(0.50,0.54,0.55),Transform3D(bs*Basis.from_scale(Vector3(0.023,hauteur,0.03)),pos))
			_collision(bs,Vector3(longueur,hauteur,0.08),centre)
			var bas := Vector3(m.x,y + .22,m.y)
			_ajouter("cloture_turquoise",TURQUOISE,Transform3D(bs*Basis.from_scale(Vector3(longueur,0.16,0.32)),bas))
		t = t1
	# portails de grille, ouverts, dans les trous
	for tr in trous:
		for s in [0, 1]:
			var pp: Vector2 = a + d * float(tr[s]) + n * float(ofs.call(float(tr[s])))
			_ajouter("cloture_grille", Color(0.55, 0.58, 0.60), Transform3D(base * Basis.from_scale(Vector3(0.12, 2.6, 0.12)), Vector3(pp.x, h(pp.x, pp.y) + 1.3, pp.y)))
	# 2. la structure tubulaire bleue en treillis, de la clôture au toit, sur toute la longueur
	# Le faîtage de la charpente est en retrait sur la ligne de poteaux.
	# Chaque travée partage ses extrémités avec la suivante.
	for aile in [[0., t_verriere-7.2],[t_verriere+7.2,lg]]:
		var debut: float = aile[0]
		var fin: float = aile[1]
		var travees := maxi(1,roundi((fin-debut)/5.5))
		var teinte := BLEU_TUBE if debut==0. else BLANC_TUBE
		var lot := "acier_sud" if debut==0. else "acier_nord"
		var dernier := Vector3.ZERO
		var sommet_precedent := Vector3.ZERO
		var t_prec := 0.0
		for i in travees+1:
			var t_p := lerpf(debut,fin,float(i)/travees)
			var o_mur: float = ofs.call(t_p)
			# Street View mars 2011 : les portiques se dressent au bord du trottoir et enjambent le stationnement
			# en épi jusqu'à la grille ; s'il n'y a pas la place, ils restent contre la clôture.
			var o_bord := _bord(a + d * t_p, n, bd) - 0.6
			var o_p := o_mur + 0.8   # (Louma : pas d'épi sur le boulevard) les portiques restent contre la clôture
			var portee := o_p - o_mur + 5.0
			var point := a + d*t_p + n*o_p
			var pied := Vector3(point.x,h(point.x,point.y),point.y)
			var tete := pied + Vector3.UP*5.05
			var sommet := tete - base.z*2.0 + Vector3.UP*1.25
			_boite_v("tube_socle",Color(.67,.66,.61),base,Vector3(.55,.32,.55),pied+Vector3.UP*.16)
			_boite_v(lot+"_montant",teinte,base,Vector3(.16,5.05,.16),pied+Vector3.UP*2.525)
			_poutre(lot,teinte,tete,tete-base.z*portee,.105)
			_poutre(lot,teinte,tete,sommet,.082)
			_poutre(lot,teinte,sommet,tete-base.z*portee,.082)
			if i>0:
				_poutre(lot,teinte,dernier,tete,.15)
				_poutre(lot,teinte,sommet_precedent,sommet,.095)
				_poutre(lot,teinte,dernier,sommet,.075)
				_poutre(lot,teinte,sommet_precedent,tete,.075)
			# une voiture en épi sous la travée, nez vers la grille, une travée sur deux (parcimonie)
			if false:   # plus de stationnement en épi
				var tm := (t_prec + t_p) * 0.5
				var om: float = ofs.call(tm)
				var pc := a + d * tm + n * (om + 2.6)
				habillage._garer_meshy(pc, atan2(n.x, n.y), EPI[_n_epi % EPI.size()])
				_n_epi += 1
			t_prec = t_p
			dernier=tete
			sommet_precedent=sommet
	# La plaque rouge visible sur la vue oblique est illisible à cette distance.
	var panneau := a + d*(t_verriere+5.25) + n*(float(ofs.call(t_verriere+5.25))+.22)
	_ajouter("plaque_rouge",Color(.60,.18,.15),Transform3D(base*Basis.from_scale(Vector3(.7,1.38,.05)),Vector3(panneau.x,h(panneau.x,panneau.y)+1.65,panneau.y)))
	# 3. LE GRAND PORTAIL (Street View juillet 2013, 23 bd Lavéran) : une haute grille grise à barreaux sur toute
	#    l'ouverture, deux grands battants ouverts vers l'intérieur, rabattus contre les murets de la rampe qui
	#    descend droit dans le hall vitré (rampe : habillage_lycee.gd).
	var pv := a + d * t_verriere
	var yv := h(pv.x, pv.y)
	var gris := Color(0.60, 0.62, 0.63)
	var demi_porte := 3.35
	var haut_grille := 2.6
	for s in [-1.0, 1.0]:
		# grille fixe entre le portail et le mur carrelé
		var t0: float = t_verriere + s * demi_porte
		var t1: float = t_verriere + s * 4.8
		var pm: Vector2 = a + d * ((t0 + t1) * 0.5) + n * float(ofs.call((t0 + t1) * 0.5))
		var yg := h(pm.x, pm.y)
		var lgf := absf(t1 - t0)
		_collision(base, Vector3(lgf, haut_grille, 0.08), Vector3(pm.x, yg + haut_grille * 0.5, pm.y))
		for yy in [0.12, haut_grille - 0.1]:
			_ajouter("grille_entree", gris, Transform3D(base * Basis.from_scale(Vector3(lgf, 0.07, 0.07)), Vector3(pm.x, yg + yy, pm.y)))
		for b2 in int(lgf / 0.13):
			_ajouter("grille_entree", gris, Transform3D(base * Basis.from_scale(Vector3(0.035, haut_grille, 0.035)), Vector3(pm.x, yg + haut_grille * 0.5, pm.y) + base.x * (-lgf * 0.5 + (b2 + 0.5) * 0.13)))
		# gros poteaux carrés du portail
		var pp: Vector2 = a + d * t0 + n * float(ofs.call(t0))
		_boite_v("grille_pilier", gris.darkened(0.2), base, Vector3(0.24, haut_grille + 0.3, 0.24), Vector3(pp.x, h(pp.x, pp.y) + (haut_grille + 0.3) * 0.5, pp.y))
		# battant ouvert : il pivote sur le poteau et se rabat vers l'intérieur, le long du muret de la rampe
		var larg_b := 3.1
		var pb: Vector2 = a + d * (t0 - s * 0.22) + n * (float(ofs.call(t0)) - larg_b * 0.5 - 0.1)
		var yb := h(pp.x, pp.y)
		var bb := Basis(Vector3(n.x, 0, n.y), Vector3.UP, Vector3(-d.x, 0, -d.y)).orthonormalized()
		for yy in [0.15, 1.3, haut_grille - 0.1]:
			_ajouter("grille_entree", gris, Transform3D(bb * Basis.from_scale(Vector3(larg_b, 0.07, 0.07)), Vector3(pb.x, yb + yy, pb.y)))
		for b2 in int(larg_b / 0.13):
			_ajouter("grille_entree", gris, Transform3D(bb * Basis.from_scale(Vector3(0.035, haut_grille, 0.035)), Vector3(pb.x, yb + haut_grille * 0.5, pb.y) + bb.x * (-larg_b * 0.5 + (b2 + 0.5) * 0.13)))
		# barrières en U, au bord du trottoir, de part et d'autre de l'entrée (pas devant)
		var pu: Vector2 = a + d * (t_verriere + s * 5.6) + n * (float(ofs.call(t_verriere + s * 5.6)) + 1.2)
		var yu := h(pu.x, pu.y)
		for e in [-0.5, 0.5]:
			_boite_v("barriere_u", Color(0.36, 0.37, 0.40), base, Vector3(0.07, 1.0, 0.07), Vector3(pu.x, yu + 0.5, pu.y) + base.x * e)
		_ajouter("barriere_u", Color(0.36, 0.37, 0.40), Transform3D(base * Basis.from_scale(Vector3(1.0, 0.06, 0.06)), Vector3(pu.x, yu + 0.98, pu.y)))
	# bande de sécurité jaune et noire au pied du portail
	for k in 17:
		var ps: Vector2 = a + d * (t_verriere - 3.4 + k * 0.4 + 0.2) + n * (float(ofs.call(t_verriere)) + 0.2)
		_ajouter("bande_jaune" if k % 2 == 0 else "bande_noire", Color(0.92, 0.78, 0.12) if k % 2 == 0 else Color(0.12, 0.12, 0.12), Transform3D(base * Basis.from_scale(Vector3(0.4, 0.02, 0.35)), Vector3(ps.x, h(ps.x, ps.y) + 0.02, ps.y)))
	var pk := a + d * (t_verriere - 6.6) + n * (float(ofs.call(t_verriere - 6.6)) + 1.2)
	_boite_v("barriere_u", Color(0.36, 0.37, 0.40), base, Vector3(0.12, 1.0, 0.12), Vector3(pk.x, h(pk.x, pk.y) + 0.5, pk.y))
	if get_parent().get_parent().has_meta("diderot_archives"):
		return
	# 4. le lettrage du lycée est sur l'aile gauche, côté parvis (habillage_lycee.gd, _parvis)
	# 5. l'arrêt de bus « Laveran Diderot » devant la verrière, sur le trottoir
	var pa := a + d * (t_verriere + 9.0) + n * (float(ofs.call(t_verriere + 9.0)) + 1.6)
	var ya := h(pa.x, pa.y)
	_boite_v("abribus", Color(0.75, 0.76, 0.76), base, Vector3(4.0, 2.5, 0.08), Vector3(pa.x, ya + 1.25, pa.y) - base.z * 0.7)
	_ajouter("abribus_toit", Color(0.86, 0.87, 0.86), Transform3D(base * Basis.from_scale(Vector3(4.3, 0.12, 1.7)), Vector3(pa.x, ya + 2.55, pa.y)))
	_boite_v("abribus_banc", Color(0.55, 0.56, 0.58), base, Vector3(3.0, 0.45, 0.4), Vector3(pa.x, ya + 0.22, pa.y) - base.z * 0.45)
	_decalque("arret_laveran", Vector3(pa.x, ya + 2.75, pa.y) + base.z * 0.86, base.x, base.z, 2.4, Color.WHITE)


## Une peau de béton sur le terrain existant. La limite extérieure suit la chaussée du boulevard.
func _trottoir_lycee(a: Vector2, axe: Vector2, normale: Vector2, longueur: float, bd: PackedVector2Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coupes := ceili(longueur)
	for i in coupes:
		var coins: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		var t0 := longueur * i / coupes
		var central := absf(t0 + 0.5 - longueur * 0.5) < 4.8
		for j in 2:
			var t := longueur * (i + j) / coupes
			var pied := a + axe * t
			var proche := pied
			var distance := INF
			for k in bd.size() - 1:
				var point := Geometry2D.get_closest_point_to_segment(pied, bd[k], bd[k + 1])
				if point.distance_to(pied) < distance:
					proche = point
					distance = point.distance_to(pied)
			var limite := maxf(.5, (proche-pied).dot(normale) - 5.6)
			for retrait in [minf(6.25, limite) if central else .18, limite]:
				var p := pied + normale * float(retrait)
				coins.append(Vector3(p.x,habillage.sol(p.x,p.y)+.026,p.y))
				uvs.append(Vector2(t,retrait))
		for k in [0,1,2,2,1,3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k])
			st.add_vertex(coins[k])
	var surface := MeshInstance3D.new()
	var beton := ShaderMaterial.new()
	beton.shader = preload("res://shaders/diderot_parvis.gdshader")
	surface.mesh = st.commit()
	surface.material_override = beton
	surface.name = "Trottoir_Laveran"
	add_child(surface)


## Le stationnement longitudinal est visible sur le cliché. Les emplacements sont indicatifs.
## Voitures garées le long des trottoirs du boulevard, devant le lycée, avec parcimonie (Louma, 21.11) :
## trois modèles Meshy (blanche, berline, rouge) qui alternent, chacun deux ou trois fois, des deux côtés,
## avec des trous ; rien au droit du portail ni à côté du scooter de Loums (départ du jeu, z = 62 à 72).
func _stationnement(bd: PackedVector2Array) -> void:
	var modeles := ["voiture_meshy_blanche", "voiture_meshy_berline", "voiture_meshy_rouge"]
	# [z le long du boulevard, côté (+1 lycée, -1 en face)]
	# garées droit, le long du trottoir, des deux côtés (Louma : jamais en épi sur le boulevard)
	var places := [[40., 1.], [47., -1.], [55., 1.], [79., -1.], [98., 1.], [104., -1.], [112., 1.], [121., -1.], [126., 1.]]
	for i in places.size():
		var zc: float = places[i][0]
		for k in bd.size() - 1:
			var a := bd[k]
			var b := bd[k+1]
			if a.y <= zc and zc < b.y:
				var axe := (b-a).normalized()
				var rive := Vector2(-axe.y,axe.x) * float(places[i][1])
				var centre := a.lerp(b,(zc-a.y)/(b.y-a.y)) + rive*4.95
				var cap := atan2(axe.x,axe.y) + (0.0 if float(places[i][1]) > 0.0 else PI)
				habillage._garer_meshy(centre, cap, modeles[i % modeles.size()])
				break


## Tags et affiches sur le mur carrelé du boulevard (Street View 2011 et 2017 : un gros chrome, des tags,
## un pan d'affiches syndicales près du portail). Les tags sont ceux du dossier « tag » de Louma
## (mur_loums_*) et les vrais blazes du quartier (vrai_*) ; peu nombreux, jamais deux voisins identiques.
## + les pièces et tags photographiés par Louma (SAM_0796, SAM_3389, SAM_3365, SAM_3402), redessinés en aplats.
const TAGS_MUR := ["vrai_piece_tesr", "vrai_lycee_tag_b", "vrai_piece_vert", "vrai_lycee_tag_a", "vrai_piece_loums",
	"mur_loums_01", "vrai_bouftou", "mur_loums_06", "vrai_malbok", "mur_loums_03", "mur_loums_10", "mur_loums_13"]

const EPI := ["voiture_meshy_berline", "voiture_meshy_blanche", "voiture_meshy_rouge"]
var _n_epi := 0

## Distance, le long de la normale n, du point p (façade) au bord de la chaussée du boulevard (demi-largeur 6 m).
func _bord(p: Vector2, n: Vector2, bd: PackedVector2Array) -> float:
	var meilleur := INF
	for k in bd.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, bd[k], bd[k + 1])
		var dist := q.distance_to(p)
		if dist < meilleur:
			meilleur = dist
	return meilleur - 6.0

var _r_opir := -99
var _i_marque := 0
var _r_piece := -99

func _marques_mur(r: int, pied: Vector3, base: Basis) -> void:
	if r == _r_opir:
		_decalque("vrai_piece_opir", pied + Vector3.UP * 1.25, base.x, base.z, 2.7, Color.WHITE)
		return
	if absf(r - _r_opir) == 1:
		return   # de l'air autour de la pièce
	if r % 3 == 1 or r % 7 == 5:
		if absi(r - _r_piece) <= 1:
			return   # le pan voisin porte déjà une marque
		var nom: String = TAGS_MUR[_i_marque % TAGS_MUR.size()]   # dans l'ordre : toutes les pièces passent
		_i_marque += 1
		_r_piece = r   # jamais deux marques sur deux pans voisins
		var large := 3.4 if nom.begins_with("vrai_piece") else (1.5 if nom.begins_with("vrai_lycee") else (2.4 if nom.begins_with("vrai") else 1.9))
		var haut := 1.2 if nom.begins_with("vrai_piece") else 1.05 + 0.18 * (r % 3)
		_decalque(nom, pied + Vector3.UP * haut, base.x, base.z, large, Color.WHITE)
	elif r % 9 == 3 and absi(r - _r_piece) > 1:
		_r_piece = r
		# un pan d'affiches collées, côte à côte, un peu de travers
		for q in 4:
			_decalque("affiche_%02d" % ((r + q) % 6), pied + base.x * (-0.95 + q * 0.62) + Vector3.UP * (1.35 + 0.06 * (q % 2)), base.x, base.z, 0.6, Color.WHITE)


func _poutre(cle: String, teinte: Color, a: Vector3, b: Vector3, ep: float) -> void:
	var axe := (b-a).normalized()
	var normal := axe.cross(Vector3.UP).normalized()
	var cadre := Basis(axe,normal.cross(axe),normal)
	_ajouter(cle,teinte,Transform3D(cadre*Basis.from_scale(Vector3(a.distance_to(b),ep,ep)),(a+b)*0.5))


# ───────────────────────── en face du lycée (Street View juillet 2013) ─────────────────────────

## Le long mur gris d'en face, ~3 m, couvert de tags, avec des poteaux qui dépassent : un spot à graff.
func _mur_en_face(lycee: PackedVector2Array, bd: PackedVector2Array) -> void:
	var cen := Vector2.ZERO
	for p in lycee:
		cen += p
	cen /= lycee.size()
	var gris := Color(0.66, 0.66, 0.64)
	var n_mur := 0
	for k in bd.size() - 1:
		var a := bd[k]
		var b := bd[k + 1]
		var lg := a.distance_to(b)
		var d := (b - a) / lg
		var lat := Vector2(-d.y, d.x)
		if (a.lerp(b, 0.5) + lat * 10.0).distance_to(cen) < (a.lerp(b, 0.5) - lat * 10.0).distance_to(cen):
			lat = -lat   # côté opposé au lycée
		var t := 0.0
		while t < lg:
			var p := a + d * (t + 2.0)
			if p.y > 60.0 and p.y < 215.0:
				var q := p + lat * 9.2
				var y := h(q.x, q.y)
				var bm := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-lat.x, 0, -lat.y)).orthonormalized()
				_boite_v("mur_face", gris.darkened(0.04 * (n_mur % 3)), bm, Vector3(4.02, 3.0, 0.3), Vector3(q.x, y + 1.2, q.y))
				if n_mur % 2 == 0:
					_ajouter("mur_face_poteau", Color(0.48, 0.48, 0.47), Transform3D(bm * Basis.from_scale(Vector3(0.08, 1.6, 0.08)), Vector3(q.x, y + 3.5, q.y)))
				if n_mur % 3 != 2:
					var c: Color = [Color(0.08, 0.08, 0.10), Color(0.75, 0.12, 0.15), Color(0.20, 0.25, 0.65), Color(0.95, 0.95, 0.95)][n_mur % 4]
					_decalque("tag_%02d" % (n_mur % 14), Vector3(q.x, y + 1.3, q.y) - Vector3(lat.x, 0, lat.y) * 0.16, bm.x, bm.z, 2.4, c)
				if n_mur % 5 == 3:
					_decalque("flop_%02d" % (n_mur % 6), Vector3(q.x, y + 1.0, q.y) - Vector3(lat.x, 0, lat.y) * 0.17, bm.x, bm.z, 3.4, Color.WHITE)
				n_mur += 1
			t += 4.0
	print("Boulevard Lavéran : mur tagué en face du lycée (%d panneaux)" % n_mur)


## Mobilier 2013 : potelets rouges et blancs, barrières en U, poteau électrique en bois.
func _mobilier_boulevard(lycee: PackedVector2Array, bd: PackedVector2Array) -> void:
	var cen := Vector2.ZERO
	for p in lycee:
		cen += p
	cen /= lycee.size()
	var n := 0
	for k in bd.size() - 1:
		var a := bd[k]
		var b := bd[k + 1]
		var lg := a.distance_to(b)
		var d := (b - a) / lg
		var lat := Vector2(-d.y, d.x)
		if (a.lerp(b, 0.5) + lat * 10.0).distance_to(cen) > (a.lerp(b, 0.5) - lat * 10.0).distance_to(cen):
			lat = -lat   # côté lycée
		var t := 3.0
		while t < lg:
			var p := a + d * t
			if p.y > 40.0 and p.y < 215.0:
				var q := p + lat * 6.4
				var y := h(q.x, q.y)
				var bm := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(lat.x, 0, lat.y)).orthonormalized()
				if n % 3 == 1:
					for e in [-0.45, 0.45]:
						_boite_v("u_rouge", Color(0.85, 0.85, 0.84), bm, Vector3(0.07, 1.0, 0.07), Vector3(q.x, y + 0.5, q.y) + bm.x * e)
					_ajouter("u_rouge_bande", Color(0.80, 0.18, 0.16), Transform3D(bm * Basis.from_scale(Vector3(0.95, 0.12, 0.08)), Vector3(q.x, y + 0.92, q.y)))
				else:
					_boite_v("potelet_rb", Color(0.92, 0.92, 0.90), bm, Vector3(0.1, 0.9, 0.1), Vector3(q.x, y + 0.45, q.y))
					_ajouter("potelet_rb_bande", Color(0.82, 0.18, 0.16), Transform3D(bm * Basis.from_scale(Vector3(0.11, 0.15, 0.11)), Vector3(q.x, y + 0.72, q.y)))
				if n % 6 == 4:
					var po := p - lat * 7.4
					_boite_v("poteau_bois", Color(0.40, 0.30, 0.22), Basis(), Vector3(0.26, 9.0, 0.26), Vector3(po.x, h(po.x, po.y) + 4.5, po.y))
					_ajouter("poteau_bois", Color(0.40, 0.30, 0.22), Transform3D(bm * Basis.from_scale(Vector3(1.4, 0.1, 0.1)), Vector3(po.x, h(po.x, po.y) + 8.4, po.y)))
				n += 1
			t += 7.0


# ───────────────────────── chantier 2013 ─────────────────────────

func _chantier(lycee: PackedVector2Array, bd: PackedVector2Array) -> void:
	# la grue à tour, au cœur du lycée
	var cen := Vector2.ZERO
	for p in lycee:
		cen += p
	cen /= lycee.size()
	var pg: Vector2 = Vector2(150.0, 150.0)
	if not Geometry2D.is_point_in_polygon(pg, lycee):
		pg = cen
	var yg := h(pg.x, pg.y)
	var jaune := Color(0.92, 0.72, 0.15)
	var mat := 38.0
	_boite_v("grue_mat", jaune, Basis(), Vector3(1.6, mat, 1.6), Vector3(pg.x, yg + mat * 0.5, pg.y))
	for k in int(mat / 1.6):
		var yk := yg + k * 1.6 + 0.8
		for s in 4:
			var r := Basis(Vector3.UP, s * PI * 0.5)
			_ajouter("grue_treillis", jaune.darkened(0.2), Transform3D(r * Basis(Vector3.BACK, PI * 0.25) * Basis.from_scale(Vector3(2.2, 0.06, 0.06)), Vector3(pg.x, yk, pg.y) + r.z * 0.82))
	var rot := Basis(Vector3.UP, deg_to_rad(35.0))
	var rouge := Color(0.78, 0.16, 0.16)
	var top := Vector3(pg.x, yg + mat, pg.y)
	_ajouter("grue_fleche", Color(0.92, 0.92, 0.90), Transform3D(rot * Basis.from_scale(Vector3(40.0, 1.3, 1.2)), top + rot.x * 18.0 + Vector3.UP * 0.65))
	for k in 14:
		_ajouter("grue_fleche_rouge", rouge, Transform3D(rot * Basis.from_scale(Vector3(1.2, 1.35, 1.25)), top + rot.x * (2.0 + k * 2.8) + Vector3.UP * 0.65))
	_ajouter("grue_fleche_rouge", rouge, Transform3D(rot * Basis.from_scale(Vector3(12.0, 1.4, 1.4)), top - rot.x * 6.0 + Vector3.UP * 0.7))
	_ajouter("grue_contrepoids", Color(0.6, 0.6, 0.58), Transform3D(rot * Basis.from_scale(Vector3(3.0, 2.2, 2.0)), top - rot.x * 10.5 - Vector3.UP * 0.6))
	_ajouter("grue_cabine", Color(0.9, 0.9, 0.88), Transform3D(rot * Basis.from_scale(Vector3(2.0, 2.2, 2.0)), top + rot.z * 1.6 - Vector3.UP * 1.0))
	_ajouter("grue_mat_haut", rouge, Transform3D(Basis.from_scale(Vector3(1.0, 6.0, 1.0)), top + Vector3.UP * 3.0))
	_ajouter("grue_cable", Color(0.2, 0.2, 0.2), Transform3D(Basis.from_scale(Vector3(0.04, 20.0, 0.04)), top + rot.x * 28.0 - Vector3.UP * 10.0))
	# palissades blanches taguées et blocs béton le long du boulevard, sur la moitié sud du lycée
	if bd.size() < 2:
		return
	var n_pal := 0
	for k in bd.size() - 1:
		var a := bd[k]
		var b := bd[k + 1]
		var lg := a.distance_to(b)
		var d := (b - a) / lg
		var lat := Vector2(-d.y, d.x)
		if Geometry2D.is_point_in_polygon(a.lerp(b, 0.5) - lat * 25.0, lycee) or (a.lerp(b, 0.5) - lat * 12.0).distance_to(Vector2(150, 160)) < 60.0:
			lat = -lat
		var t := 0.0
		while t < lg:
			var p := a + d * t
			var cote := p - lat * 8.5
			var fond := p - lat * 30.0
			if p.y > 110.0 and p.y < 230.0 and (Geometry2D.is_point_in_polygon(fond, lycee) or Geometry2D.is_point_in_polygon(p - lat * 18.0, lycee)):
				var bp := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-lat.x, 0, -lat.y)).orthonormalized()
				var yp := h(cote.x, cote.y)
				_boite_v("palissade", Color(0.92, 0.92, 0.90), bp, Vector3(3.5, 2.0, 0.06), Vector3(cote.x, yp + 1.0, cote.y))
				for nerv in 7:
					_ajouter("palissade_nervure", Color(0.80, 0.80, 0.78), Transform3D(bp * Basis.from_scale(Vector3(0.04, 2.0, 0.08)), Vector3(cote.x, yp + 1.0, cote.y) + bp.x * (-1.5 + nerv * 0.5)))
				var bloc := cote + lat * 0.7
				var c := Color(0.86, 0.85, 0.82) if n_pal % 3 != 1 else Color(0.84, 0.32, 0.26)
				_boite_v("bloc_beton", c, bp, Vector3(2.0, 0.8, 0.6), Vector3(bloc.x, h(bloc.x, bloc.y) + 0.4, bloc.y))
				# les vrais tags des palissades (Street View juillet 2013 et juin 2014) : AZE et ZEYO côte à côte,
				# RINO et VLS 13 près de l'arrêt Laveran Diderot ; puis des signatures inventées
				var vrais := {0: ["vrai_aze", 1.5], 1: ["vrai_zeyo", 2.0], 3: ["vrai_rino", 1.3], 4: ["vrai_vls13", 1.1]}
				if vrais.has(n_pal):
					_decalque(vrais[n_pal][0], Vector3(cote.x, yp + 1.15, cote.y) + bp.z * 0.05, bp.x, bp.z, vrais[n_pal][1], Color(0.07, 0.07, 0.08))
				elif n_pal % 2 == 0:
					_decalque("tag_%02d" % (n_pal % 14), Vector3(cote.x, yp + 1.1, cote.y) + bp.z * 0.05, bp.x, bp.z, 1.8, [Color(0.1, 0.1, 0.12), Color(0.2, 0.3, 0.7), Color(0.6, 0.15, 0.5)][n_pal % 3])
				n_pal += 1
			t += 3.5
	print("Boulevard Lavéran 2013 : snack, façade du lycée, grue et %d palissades" % n_pal)


# ───────────────────────── briques ─────────────────────────

func _decalque(nom: String, centre: Vector3, le_long: Vector3, dehors: Vector3, largeur: float, c: Color) -> void:
	var chemin := GRAFF % nom
	if not ResourceLoader.exists(chemin):
		return
	var tex := load(chemin) as Texture2D
	preload("res://scripts/marque_murale.gd").poser(self, tex, centre, le_long, dehors, largeur, c, 80.0, 0, "Marque_" + nom)


## Une collision seule (grilles à barreaux : on voit à travers, on ne passe pas).
func _collision(b: Basis, taille: Vector3, o: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	cs.transform = Transform3D(b.orthonormalized(), o)
	_corps.add_child(cs)


func _boite_v(cle: String, c: Color, b: Basis, taille: Vector3, o: Vector3) -> void:
	_ajouter(cle, c, Transform3D(b * Basis.from_scale(taille), o))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	cs.transform = Transform3D(b.orthonormalized(), o)
	_corps.add_child(cs)


func _ajouter(cle: String, c: Color, t: Transform3D) -> void:
	if not _paquets.has(cle):
		_paquets[cle] = [_cube, c, []]
	(_paquets[cle][2] as Array).append(t)


func _ajouter_cyl(cle: String, c: Color, t: Transform3D) -> void:
	if not _paquets.has(cle):
		_paquets[cle] = [_cyl, c, []]
	(_paquets[cle][2] as Array).append(t)


func _poser_paquets() -> void:
	for cle in _paquets:
		var pq: Array = _paquets[cle]
		var liste: Array = pq[2]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pq[0]
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("couleur", pq[1])
		m.set_shader_parameter("grain", 0.4)
		mi.material_override = m
		if cle == "cloture_carrelage":
			var email := ShaderMaterial.new()
			email.shader = preload("res://shaders/diderot_ceramique.gdshader")
			mi.material_override = email
		if cle.begins_with("verriere_vitre"):
			var verre := StandardMaterial3D.new()
			verre.albedo_color = Color(0.80, 0.92, 0.98, 0.22)
			verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			verre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = verre
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Laveran_" + cle
		add_child(mi)


func _poly(s: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in s.split(" ", false):
		var xy := p.split(",")
		out.append(Vector2(float(xy[0]), float(xy[1])))
	if out.size() > 2 and out[0].distance_to(out[out.size() - 1]) < 0.01:
		out.remove_at(out.size() - 1)
	return out
