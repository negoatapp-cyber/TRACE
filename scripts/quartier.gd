extends Node3D
## Le quartier de la démo, construit par le code au lancement.
## Niveau FICTIF inspiré d'un grand ensemble marseillais des années 2008-2013 :
## on garde les volumes, les couleurs et les usages, pas le plan exact ni les noms.
##
## Repère : X = est, Z = sud, Y = haut. Le sol principal est à Y = 0.
##   nord (Z < -40)  : terrasse à +3 m, la grande barre blanche posée dessus
##   centre          : parkings, placette, pieds des deux tours
##   sud (Z 58 à 70) : le boulevard
##   au-delà (Z > 74): le lycée — mur du boulevard, parvis à gradins, halle vitrée
##
## Tout est en volumes simples : c'est fait pour être corrigé vite.

const FACADE := preload("res://shaders/facade.gdshader")

# Couleurs de l'époque d'origine (cf. bible visuelle).
const C_BITUME := Color(0.30, 0.30, 0.32)
const C_TROTTOIR := Color(0.62, 0.60, 0.57)
const C_BETON := Color(0.70, 0.68, 0.64)
const C_BETON_CLAIR := Color(0.80, 0.78, 0.73)
const C_BLANC := Color(0.90, 0.88, 0.83)
const C_ROSE := Color(0.84, 0.60, 0.56)
const C_OCRE := Color(0.80, 0.60, 0.34)
const C_GRISBEIGE := Color(0.70, 0.66, 0.58)
const C_TURQUOISE := Color(0.16, 0.66, 0.64)
const C_BLEU := Color(0.42, 0.70, 0.90)
const C_HERBE := Color(0.58, 0.55, 0.36)
const C_TERRE := Color(0.66, 0.56, 0.42)
const C_METAL := Color(0.35, 0.36, 0.38)
const C_JAUNE := Color(0.92, 0.78, 0.12)
const C_VERT := Color(0.22, 0.36, 0.22)

var _mats := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 13013
	_sols()
	_terrasse_et_barre()
	_barre_rose()
	_tour_ocre()
	_tour_grise()
	_centre()
	_boulevard()
	_lycee()
	_horizon()
	_limites()


# ───────────────────────── les lieux ─────────────────────────

func _sols() -> void:
	sol("Sol", -120, 120, -100, 74, 0.0, C_BITUME)
	sol("SolLyceeOuest", -120, -20, 74, 135, 0.0, C_TROTTOIR)
	sol("SolLyceeEst", 20, 120, 74, 135, 0.0, C_TROTTOIR)
	sol("Parvis", -20, 20, 74, 135, -2.0, C_BETON_CLAIR)
	# Dalles claires au pied des immeubles (dessin au sol, sans collision).
	plaque(-90, 90, -40, -30, C_TROTTOIR)
	plaque(-78, -40, 6, 44, C_TROTTOIR)
	plaque(50, 92, -26, 18, C_TROTTOIR)
	plaque(-120, 120, 52, 58, C_TROTTOIR)
	plaque(-120, 120, 70, 74, C_TROTTOIR)


func _terrasse_et_barre() -> void:
	# Terrasse nord, 3 m au-dessus du parking, tenue par un long mur.
	sol("Terrasse", -95, 95, -100, -40, 3.0, C_BETON)
	# (habillage clair du mur, interrompu aux escaliers et à la rampe)
	for seg in [[-95.0, -52.5], [-47.5, -4.0], [4.0, 40.0], [46.0, 95.0]]:
		bloc("MurSoutenement", Vector3((seg[0] + seg[1]) * 0.5, 1.5, -39.9), Vector3(seg[1] - seg[0], 3.0, 0.2), mat(C_BETON_CLAIR))
	# La grande barre blanche à grille de balcons.
	immeuble("GrandeBarre", Vector3(0, 3, -72), Vector3(150, 33, 12), C_BLANC, true, 0.45)
	for i in 6:
		var x := -62.5 + i * 25.0
		bloc("Auvent", Vector3(x, 5.6, -64.6), Vector3(5, 0.25, 2.8), mat(C_BETON_CLAIR), false)
		bloc("Porte", Vector3(x, 4.1, -65.95), Vector3(2.2, 2.2, 0.15), mat(Color(0.12, 0.13, 0.15)), false)
		muret(Vector3(x - 6, 3, -62), Vector3(x - 2.5, 3, -62), 0.45, 0.4)

	# Escalier central avec trois mains courantes basses (à grinder).
	escalier(Vector3(0, 3, -40), Vector3(0, 0, -34), 8.0, 18)
	for x in [-4.0, 0.0, 4.0]:
		rail(Vector3(x, 3.45, -40), Vector3(x, 0.45, -34), 0.07, C_METAL)
	# Double volée côté ouest : le « set de marches » du quartier.
	escalier(Vector3(-50, 3, -40), Vector3(-50, 1.5, -37), 5.0, 9)
	sol("PalierOuest", -52.5, -47.5, -37, -33.5, 1.5, C_BETON)
	escalier(Vector3(-50, 1.5, -33.5), Vector3(-50, 0, -30.5), 5.0, 9)
	rail(Vector3(-47.5, 1.95, -33.5), Vector3(-47.5, 0.45, -30.5), 0.07, C_METAL)
	muret(Vector3(-52.5, 1.5, -37), Vector3(-52.5, 1.5, -33.5), 0.5, 0.4)
	# Grande rampe en béton côté est : la descente.
	rampe(Vector3(43, 3, -40), Vector3(43, 0, -20), 6.0, mat(C_BETON_CLAIR))
	rail(Vector3(40, 3.5, -40), Vector3(40, 0.5, -20), 0.07, C_METAL)
	rail(Vector3(46, 3.5, -40), Vector3(46, 0.5, -20), 0.07, C_METAL)
	# Garde-corps bas le long du bord de la terrasse.
	muret(Vector3(-95, 3, -40.3), Vector3(-53, 3, -40.3), 0.5, 0.35)
	muret(Vector3(-47, 3, -40.3), Vector3(-4.4, 3, -40.3), 0.5, 0.35)
	muret(Vector3(4.4, 3, -40.3), Vector3(39.6, 3, -40.3), 0.5, 0.35)
	muret(Vector3(46.4, 3, -40.3), Vector3(95, 3, -40.3), 0.5, 0.35)
	for x in [-80.0, -30.0, 20.0, 70.0]:
		lampadaire(Vector3(x, 3, -46))
		banc(Vector3(x + 6, 3, -45), 0.0)
	for x in [-70.0, -20.0, 60.0]:
		arbre(Vector3(x, 3, -52), 5.5)


func _barre_rose() -> void:
	immeuble("BarreRose", Vector3(-106, 0, -8), Vector3(12, 19, 56), C_ROSE, true, 0.4)
	for z in [-26.0, -8.0, 10.0]:
		bloc("Auvent", Vector3(-98.8, 2.6, z), Vector3(2.6, 0.2, 4), mat(C_BETON_CLAIR), false)
	muret(Vector3(-97, 0, -34), Vector3(-97, 0, -18), 0.45, 0.4)
	muret(Vector3(-97, 0, 0), Vector3(-97, 0, 16), 0.45, 0.4)


func _tour_ocre() -> void:
	# La tour ocre à l'est, sur un socle bas : toute la vie se passe à son pied.
	sol("SocleTourOcre", 54, 90, -24, 14, 0.45, C_BETON_CLAIR)
	immeuble("TourOcre", Vector3(72, 0.45, -5), Vector3(22, 48, 22), C_OCRE, false, 0.5)
	bloc("Hall", Vector3(60.2, 2.0, -5), Vector3(2.4, 3.1, 8), mat(C_BETON), true)
	bloc("AuventHall", Vector3(57.6, 3.3, -5), Vector3(4, 0.25, 10), mat(C_BETON_CLAIR), false)
	# Les bords du socle sont des rebords (ledges) ; trois marches au sud.
	arete(Vector3(54, 0.45, -24), Vector3(54, 0.45, 14))
	arete(Vector3(54, 0.45, 14), Vector3(66, 0.45, 14))
	arete(Vector3(78, 0.45, 14), Vector3(90, 0.45, 14))
	escalier(Vector3(72, 0.45, 14), Vector3(72, 0, 15.2), 12.0, 3)
	muret(Vector3(56, 0.45, 8), Vector3(56, 0.45, 12), 0.5, 0.5)
	muret(Vector3(56, 0.45, -22), Vector3(56, 0.45, -16), 0.5, 0.5)
	banc(Vector3(58, 0.45, 2), PI * 0.5)
	banc(Vector3(58, 0.45, -12), PI * 0.5)
	for z in [-22.0, -14.0, 6.0, 12.0]:
		cypres(Vector3(88, 0.45, z))
	for z in [-28.0, 18.0]:
		lampadaire(Vector3(52, 0, z))
	# Un mur aveugle bas à côté : futur mur à graffiti.
	bloc("MurAveugle", Vector3(72, 1.6, 22), Vector3(26, 3.2, 0.3), mat(C_BETON_CLAIR))
	parking(Vector3(60, 0, 28), 9, 0.0)


func _tour_grise() -> void:
	# La tour gris-beige à l'ouest : entrée surélevée, marches et rampe.
	immeuble("TourGrise", Vector3(-58, 0, 22), Vector3(20, 45, 20), C_GRISBEIGE, false, 0.55)
	sol("Perron", -48, -40, 17, 27, 1.0, C_BETON_CLAIR)
	bloc("AuventPerron", Vector3(-46, 3.6, 22), Vector3(4, 0.25, 8), mat(C_BETON), false)
	bloc("PortePerron", Vector3(-47.9, 2.1, 22), Vector3(0.15, 2.2, 2.4), mat(Color(0.12, 0.13, 0.15)), false)
	escalier(Vector3(-40, 1.0, 20), Vector3(-38.2, 0, 20), 5.0, 6, true)
	rail(Vector3(-40, 1.45, 17.6), Vector3(-38.2, 0.45, 17.6), 0.07, C_METAL)
	rail(Vector3(-40, 1.45, 22.4), Vector3(-38.2, 0.45, 22.4), 0.07, C_METAL)
	arete(Vector3(-40, 1.0, 22.6), Vector3(-40, 1.0, 27))
	# Rampe d'accès le long de la façade sud du perron.
	rampe(Vector3(-44, 1.0, 28.2), Vector3(-34, 0, 28.2), 2.2, mat(C_BETON_CLAIR), true)
	rail(Vector3(-44, 1.5, 29.4), Vector3(-34, 0.5, 29.4), 0.07, C_METAL)
	sol("PalierRampe", -48, -44, 27, 29.3, 1.0, C_BETON_CLAIR)
	lampadaire(Vector3(-36, 0, 14))
	parking(Vector3(-30, 0, 36), 7, 0.35)
	# En face : le terrain vague grillagé.
	plaque(-112, -76, 36, 56, C_TERRE)
	grillage(Vector3(-112, 0, 36), Vector3(-76, 0, 36))
	grillage(Vector3(-76, 0, 36), Vector3(-76, 0, 44))
	grillage(Vector3(-76, 0, 48), Vector3(-76, 0, 56))
	grillage(Vector3(-112, 0, 56), Vector3(-76, 0, 56))
	grillage(Vector3(-112, 0, 36), Vector3(-112, 0, 56))
	for p in [Vector3(-104, 0, 46), Vector3(-84, 0, 46)]:
		bloc("Cage", p + Vector3(0, 1.2, 0), Vector3(0.12, 2.4, 6), mat(C_BLANC), false)


func _centre() -> void:
	# Parkings ouverts partout, comme à l'époque.
	parking(Vector3(-28, 0, -24), 10, 0.0)
	parking(Vector3(-8, 0, -6), 12, 0.0)
	parking(Vector3(-8, 0, 0.5), 12, PI)
	# La placette : bancs, jardinières (rebords), une plaque basse pour les manuals.
	plaque(8, 40, 14, 44, C_TROTTOIR)
	jardiniere(Vector3(14, 0, 20), Vector3(8, 0.5, 2.4))
	jardiniere(Vector3(32, 0, 38), Vector3(8, 0.5, 2.4))
	jardiniere(Vector3(34, 0, 20), Vector3(2.4, 0.7, 8))
	bloc("PlaqueManual", Vector3(22, 0.1, 30), Vector3(7, 0.2, 2.6), mat(C_BETON_CLAIR))
	arete(Vector3(18.5, 0.2, 28.7), Vector3(25.5, 0.2, 28.7))
	arete(Vector3(18.5, 0.2, 31.3), Vector3(25.5, 0.2, 31.3))
	banc(Vector3(12, 0, 34), 0.0)
	banc(Vector3(26, 0, 16), 0.0)
	banc(Vector3(38, 0, 30), PI * 0.5)
	lampadaire(Vector3(10, 0, 28))
	lampadaire(Vector3(38, 0, 42))
	arbre(Vector3(14, 0, 20), 5.0)
	arbre(Vector3(32, 0, 38), 6.0)
	arbre(Vector3(34, 0, 21), 4.5)
	# Un plan incliné contre un transformateur : le tremplin naturel du coin.
	bloc("Transfo", Vector3(-12, 1.3, 26), Vector3(4, 2.6, 3), mat(C_BETON_CLAIR))
	rampe(Vector3(-12, 0.9, 27.5), Vector3(-12, 0, 30.5), 4.0, mat(C_BETON))
	rampe(Vector3(0, 0.55, 40), Vector3(0, 0, 43.2), 3.0, mat(C_BETON))
	rail(Vector3(-6, 0, 47), Vector3(4, 0, 47), 0.07, C_JAUNE, 0.42)
	for x in [-70.0, -20.0, 30.0, 80.0]:
		lampadaire(Vector3(x, 0, 50))


func _boulevard() -> void:
	plaque(-120, 120, 58, 70, Color(0.22, 0.22, 0.24))
	var x := -116.0
	while x < 116.0:
		plaque(x, x + 3.0, 63.9, 64.1, Color(0.85, 0.85, 0.8))
		x += 8.0
	# Stationnement en épi et potelets jaunes le long du mur du lycée.
	parking(Vector3(-78, 0, 71.6), 9, PI, 0.5)
	parking(Vector3(56, 0, 71.6), 9, PI, 0.5)
	x = -19.0
	while x <= 19.0:
		potelet(Vector3(x, 0, 71.5))
		x += 3.8
	for xx in [-100.0, -50.0, 50.0, 100.0]:
		lampadaire(Vector3(xx, 0, 57))
	voiture(Vector3(-40, 0, 61), PI * 0.5, Color(0.75, 0.75, 0.72))
	voiture(Vector3(34, 0, 67), -PI * 0.5, Color(0.16, 0.2, 0.36))


func _lycee() -> void:
	# Mur du boulevard d'origine : carrelage clair, deux bandes turquoise, grilles.
	for s in [-1.0, 1.0]:
		var cx: float = s * 67.0
		bloc("MurBoulevard", Vector3(cx, 1.3, 74.3), Vector3(94, 2.6, 0.4), mat(C_BLANC))
		bloc("Bande", Vector3(cx, 0.7, 74.08), Vector3(94, 0.22, 0.06), mat(C_TURQUOISE), false)
		bloc("Bande", Vector3(cx, 2.0, 74.08), Vector3(94, 0.22, 0.06), mat(C_TURQUOISE), false)
		bloc("Grille", Vector3(cx, 3.1, 74.3), Vector3(94, 1.0, 0.08), mat_grille(), false)
		# Les bâtiments derrière le mur, toits plats.
		immeuble("Lycee", Vector3(s * 62.0, 0, 96), Vector3(76, 10, 30), C_BETON_CLAIR, false, 0.15, 3.6, 4.2)
		immeuble("LyceeFond", Vector3(s * 70.0, 0, 122), Vector3(60, 14, 16), C_BETON_CLAIR, false, 0.15, 3.6, 4.2)
		# Les charpentes bleues au-dessus des toits, sur toute la longueur.
		treillis(Vector3(s * 24.0, 10, 84), Vector3(s * 100.0, 10, 84), 3.2, 12)
		treillis(Vector3(s * 24.0, 10, 108), Vector3(s * 100.0, 10, 108), 3.2, 12)
		var px := 24.0
		while px <= 100.0:
			tube(Vector3(s * px, 13.2, 84), Vector3(s * px, 13.2, 108), 0.12, mat(C_BLEU))
			px += 19.0
		# Murs latéraux du parvis en contrebas (béton brut, à bomber).
		bloc("MurParvis", Vector3(s * 20.2, -0.4, 104.5), Vector3(0.4, 3.2, 61), mat(C_BETON))

	# Parvis à gradins : quatre grandes marches où l'on s'assoit.
	for k in range(1, 5):
		var top := -0.4 * k
		var z0 := 74.0 + 1.3 * (k - 1)
		bloc("Gradin", Vector3(0, (top - 2.0) * 0.5, z0 + 0.65), Vector3(24, top + 2.0, 1.3), mat(C_BETON_CLAIR))
		arete(Vector3(-12, top, z0 + 1.3), Vector3(12, top, z0 + 1.3))
	arete(Vector3(-12, 0, 74), Vector3(12, 0, 74))
	# À gauche l'escalier, à droite la rampe d'accès en béton avec son garde-corps.
	escalier(Vector3(-16, 0, 74), Vector3(-16, -2, 79.2), 8.0, 12)
	rail(Vector3(-12.2, 0.45, 74), Vector3(-12.2, -1.55, 79.2), 0.07, C_METAL)
	rampe(Vector3(16, 0, 74), Vector3(16, -2, 88), 8.0, mat(C_BETON))
	rail(Vector3(12.2, 0.5, 74), Vector3(12.2, -1.5, 88), 0.07, C_METAL)
	for x in [-9.0, -3.0, 3.0, 9.0]:
		potelet(Vector3(x, -2, 84), Color(0.9, 0.9, 0.88))

	# La grande halle vitrée en arc, repère central.
	var verre := StandardMaterial3D.new()
	verre.albedo_color = Color(0.45, 0.68, 0.80, 0.55)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	verre.metallic = 0.3
	verre.roughness = 0.08
	verre.cull_mode = BaseMaterial3D.CULL_DISABLED
	var halle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 12.0
	cyl.bottom_radius = 12.0
	cyl.height = 22.0
	cyl.radial_segments = 48
	cyl.cap_top = true
	cyl.cap_bottom = true
	halle.mesh = cyl
	halle.material_override = verre
	halle.name = "HalleVitree"
	halle.rotation = Vector3(PI * 0.5, 0, 0)
	halle.position = Vector3(0, -2, 113)
	add_child(halle)
	bloc("HalleInterieur", Vector3(0, 0.5, 118), Vector3(22, 5, 14), mat(Color(0.2, 0.22, 0.25)), false)
	bloc("HalleCollision", Vector3(0, 3, 113.5), Vector3(24, 10, 23), null)
	for i in 6:
		var z := 102.2 + i * 4.3
		arc(Vector3(0, -2, z), 12.1, 0.16, mat(C_BLEU))
	bloc("SeuilHalle", Vector3(0, -1.9, 101.4), Vector3(16, 0.2, 1.6), mat(C_BETON_CLAIR))
	arete(Vector3(-8, -1.8, 100.6), Vector3(8, -1.8, 100.6))
	bloc("FondLycee", Vector3(0, 5, 132), Vector3(40, 14, 6), mat(C_BETON_CLAIR))


func _horizon() -> void:
	# Collines sèches au nord-est et quelques tours lointaines.
	for h in [[260.0, -420.0, 260.0, 70.0], [60.0, -520.0, 320.0, 55.0], [-260.0, -480.0, 280.0, 45.0], [430.0, -160.0, 240.0, 60.0]]:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = h[2]
		s.height = h[2] * 2.0
		m.mesh = s
		m.material_override = mat(Color(0.52, 0.53, 0.42))
		m.position = Vector3(h[0], -h[2] * 0.25 + h[3] - h[2] * 0.3, h[1])
		m.scale = Vector3(1, 0.45, 1)
		m.name = "Colline"
		add_child(m)
	for t in [[170.0, -150.0, 46.0, C_OCRE], [210.0, -110.0, 52.0, C_GRISBEIGE], [-190.0, -170.0, 40.0, C_BLANC], [150.0, 40.0, 44.0, C_GRISBEIGE], [-200.0, 60.0, 30.0, C_ROSE]]:
		immeuble("TourLointaine", Vector3(t[0], 0, t[1]), Vector3(22, t[2], 20), t[3], false, 0.3, 2.8, 3.4, false)


func _limites() -> void:
	# Murs invisibles : on ne sort pas de la maquette.
	bloc("LimiteN", Vector3(0, 20, -100.5), Vector3(242, 60, 1), null)
	bloc("LimiteS", Vector3(0, 20, 135.5), Vector3(242, 60, 1), null)
	bloc("LimiteO", Vector3(-120.5, 20, 17), Vector3(1, 60, 236), null)
	bloc("LimiteE", Vector3(120.5, 20, 17), Vector3(1, 60, 236), null)


# ───────────────────────── les briques ─────────────────────────

func mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func mat_grille() -> StandardMaterial3D:
	if not _mats.has("grille"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.22, 0.22, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["grille"] = m
	return _mats["grille"]


## Boîte solide. `m` nul = collision invisible. `solide` faux = décor sans collision.
func bloc(nom: String, centre: Vector3, taille: Vector3, m: Material, solide := true, base := Basis.IDENTITY) -> Node3D:
	var n: Node3D
	if solide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = taille
		cs.shape = sh
		body.add_child(cs)
		n = body
	else:
		n = Node3D.new()
	if m != null:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = taille
		mi.mesh = bm
		mi.material_override = m
		n.add_child(mi)
	n.name = nom
	n.transform = Transform3D(base, centre)
	add_child(n, true)
	return n


## Dalle de sol : de x0 à x1, de z0 à z1, dessus à la hauteur `haut` (4 m d'épaisseur).
func sol(nom: String, x0: float, x1: float, z0: float, z1: float, haut: float, c: Color) -> void:
	bloc(nom, Vector3((x0 + x1) * 0.5, haut - 2.0, (z0 + z1) * 0.5), Vector3(x1 - x0, 4.0, z1 - z0), mat(c))


## Dessin au sol, sans collision (marquage, trottoir, terre).
func plaque(x0: float, x1: float, z0: float, z1: float, c: Color, y := 0.0) -> void:
	bloc("Plaque", Vector3((x0 + x1) * 0.5, y + 0.01 + _rng.randf() * 0.01, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.02, z1 - z0), mat(c), false)


## Immeuble avec façade dessinée. `pied` = centre de la base.
func immeuble(nom: String, pied: Vector3, taille: Vector3, c: Color, loggias: bool, vie: float, etage := 2.8, travee := 3.4, solide := true) -> void:
	var sm := ShaderMaterial.new()
	sm.shader = FACADE
	sm.set_shader_parameter("mur", c)
	sm.set_shader_parameter("garde_corps", c.darkened(0.12))
	sm.set_shader_parameter("hauteur", taille.y)
	sm.set_shader_parameter("etage", etage)
	sm.set_shader_parameter("travee", travee)
	sm.set_shader_parameter("loggias", 1.0 if loggias else 0.0)
	sm.set_shader_parameter("vie", vie)
	bloc(nom, pied + Vector3(0, taille.y * 0.5, 0), taille, sm, solide)
	# Édicule technique sur le toit : donne la silhouette.
	if taille.y > 15.0:
		bloc(nom + "Edicule", pied + Vector3(0, taille.y + 1.4, 0), Vector3(minf(taille.x, 8.0), 2.8, minf(taille.z, 6.0)), mat(c.darkened(0.2)), false)


## Plan incliné lisse entre le milieu du bord haut `a` et celui du bord bas `b`.
func rampe(a: Vector3, b: Vector3, largeur: float, m: Material, bords := false) -> void:
	var d := b - a
	var dir := d.normalized()
	var right := Vector3.UP.cross(dir).normalized()
	var up_n := dir.cross(right)
	var ep := 0.6
	var centre := (a + b) * 0.5 - up_n * ep * 0.5
	bloc("Rampe", centre, Vector3(largeur, ep, d.length()), m, true, Basis(right, up_n, dir))
	# Remplissage sous la rampe (visuel).
	var bas := minf(a.y, b.y)
	var hmax := absf(a.y - b.y)
	if hmax > 0.5:
		var haut_pt := a if a.y > b.y else b
		var flat := Vector3(d.x, 0, d.z)
		var n := 6
		for i in n:
			var t := (i + 0.5) / float(n)
			var p := haut_pt.lerp(b if a.y > b.y else a, t)
			var h := p.y - bas - 0.15
			if h > 0.05:
				bloc("SousRampe", Vector3(p.x, bas + h * 0.5, p.z), Vector3(largeur if absf(flat.z) > absf(flat.x) else flat.length() / n, h, flat.length() / n if absf(flat.z) > absf(flat.x) else largeur), m, false)
	if bords:
		pass


## Escalier : collision en plan incliné (on monte sans buter), marches visibles.
func escalier(a: Vector3, b: Vector3, largeur: float, marches: int, _axe_x := false) -> void:
	var d := b - a
	var dir := d.normalized()
	var right := Vector3.UP.cross(dir).normalized()
	var up_n := dir.cross(right)
	bloc("EscalierCollision", (a + b) * 0.5 - up_n * 0.3, Vector3(largeur, 0.6, d.length()), null, true, Basis(right, up_n, dir))
	var flat := Vector3(d.x, 0, d.z)
	var pas := flat / float(marches)
	var hm := absf(d.y) / float(marches)
	var bas := minf(a.y, b.y)
	var selon_z := absf(flat.z) > absf(flat.x)
	for i in marches:
		var p := a + pas * (i + 0.5)
		var top := a.y - hm * i if d.y < 0 else a.y + hm * (i + 1)
		var h := top - bas
		if h < 0.02:
			continue
		var taille := Vector3(largeur, h, pas.length()) if selon_z else Vector3(pas.length(), h, largeur)
		bloc("Marche", Vector3(p.x, bas + h * 0.5, p.z), taille, mat(C_BETON_CLAIR), false)


## Rail ou rebord à grinder, de `a` à `b` (points sur l'arête supérieure si haut = 0).
func rail(a: Vector3, b: Vector3, epaisseur: float, c: Color, haut := 0.0) -> void:
	var r := Rail.new()
	var d := b - a
	var x := d.normalized()
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x)
	r.length = d.length()
	r.thickness = epaisseur
	r.color = c
	if haut > 0.0:
		r.height = haut
		r.transform = Transform3D(Basis(x, y, z), a)
	else:
		r.height = epaisseur
		r.transform = Transform3D(Basis(x, y, z), a - y * epaisseur)
	r.name = "Rail"
	add_child(r, true)
	if haut <= 0.0:
		# Poteaux jusqu'au sol (visuel).
		var n := maxi(2, int(d.length() / 2.0) + 1)
		for i in n:
			var p := a.lerp(b, float(i) / float(n - 1))
			bloc("Poteau", p - Vector3(0, 0.25, 0), Vector3(0.05, 0.5, 0.05), mat(c), false)


## Arête grindable invisible posée sur le bord d'un volume existant.
func arete(a: Vector3, b: Vector3) -> void:
	var r := Rail.new()
	var d := b - a
	var x := d.normalized()
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x)
	r.length = d.length()
	r.thickness = 0.06
	r.height = 0.04
	r.color = Color(0.5, 0.5, 0.5)
	r.transform = Transform3D(Basis(x, y, z), a - y * 0.035)
	r.name = "Arete"
	add_child(r, true)


## Muret bas en béton : obstacle et rebord à la fois.
func muret(a: Vector3, b: Vector3, haut: float, epaisseur: float) -> void:
	var r := Rail.new()
	var d := b - a
	var x := d.normalized()
	var z := x.cross(Vector3.UP).normalized()
	r.length = d.length()
	r.height = haut
	r.thickness = epaisseur
	r.color = C_BETON_CLAIR
	r.transform = Transform3D(Basis(x, Vector3.UP, z), a)
	r.name = "Muret"
	add_child(r, true)


func jardiniere(pied: Vector3, taille: Vector3) -> void:
	bloc("Jardiniere", pied + Vector3(0, taille.y * 0.5, 0), taille, mat(C_BETON_CLAIR))
	bloc("Terre", pied + Vector3(0, taille.y + 0.01, 0), Vector3(taille.x - 0.4, 0.04, taille.z - 0.4), mat(C_HERBE), false)
	var hx := taille.x * 0.5
	var hz := taille.z * 0.5
	var y := pied.y + taille.y
	if taille.x >= taille.z:
		arete(Vector3(pied.x - hx, y, pied.z - hz), Vector3(pied.x + hx, y, pied.z - hz))
		arete(Vector3(pied.x - hx, y, pied.z + hz), Vector3(pied.x + hx, y, pied.z + hz))
	else:
		arete(Vector3(pied.x - hx, y, pied.z - hz), Vector3(pied.x - hx, y, pied.z + hz))
		arete(Vector3(pied.x + hx, y, pied.z - hz), Vector3(pied.x + hx, y, pied.z + hz))


func banc(pied: Vector3, angle: float) -> void:
	var base := Basis(Vector3.UP, angle)
	bloc("Banc", pied + Vector3(0, 0.22, 0), Vector3(2.4, 0.44, 0.6), mat(C_BETON), true, base)
	var x := base.x
	arete(pied + Vector3(0, 0.44, 0) - x * 1.2 + base.z * 0.3, pied + Vector3(0, 0.44, 0) + x * 1.2 + base.z * 0.3)


func lampadaire(pied: Vector3) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.08
	c.height = 4.2
	m.mesh = c
	m.material_override = mat(C_VERT.darkened(0.3))
	m.position = pied + Vector3(0, 2.1, 0)
	m.name = "Lampadaire"
	add_child(m, true)
	var g := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.32
	s.height = 0.64
	g.mesh = s
	g.material_override = mat(Color(0.95, 0.94, 0.88), 0.3)
	g.position = Vector3(0, 2.35, 0)
	m.add_child(g)


func potelet(pied: Vector3, c := C_JAUNE) -> void:
	var m := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.06
	cy.bottom_radius = 0.06
	cy.height = 0.9
	m.mesh = cy
	m.material_override = mat(c)
	m.position = pied + Vector3(0, 0.45, 0)
	m.name = "Potelet"
	add_child(m, true)


func arbre(pied: Vector3, haut: float) -> void:
	tube(pied, pied + Vector3(0, haut * 0.55, 0), 0.16, mat(Color(0.36, 0.3, 0.24)))
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = haut * 0.38
	s.height = haut * 0.62
	m.mesh = s
	m.material_override = mat(Color(0.30, 0.42, 0.24))
	m.position = pied + Vector3(0, haut * 0.75, 0)
	m.name = "Feuillage"
	add_child(m, true)


func cypres(pied: Vector3) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.05
	c.bottom_radius = 0.9
	c.height = 9.0
	m.mesh = c
	m.material_override = mat(C_VERT)
	m.position = pied + Vector3(0, 4.5, 0)
	m.name = "Cypres"
	add_child(m, true)


func grillage(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var x := d.normalized()
	var z := x.cross(Vector3.UP).normalized()
	bloc("Grillage", (a + b) * 0.5 + Vector3(0, 1.5, 0), Vector3(d.length(), 3.0, 0.06), mat_grille(), true, Basis(x, Vector3.UP, z))


## Tube entre deux points (charpentes, troncs).
func tube(a: Vector3, b: Vector3, rayon: float, m: Material) -> void:
	var d := b - a
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon
	c.height = d.length()
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	var y := d.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := y.cross(ref).normalized()
	var x := y.cross(z)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	mi.name = "Tube"
	add_child(mi, true)


## Poutre en treillis bleue : deux membrures et des diagonales.
func treillis(a: Vector3, b: Vector3, haut: float, travees: int) -> void:
	var m := mat(C_BLEU, 0.5)
	var up := Vector3(0, haut, 0)
	tube(a, b, 0.14, m)
	tube(a + up, b + up, 0.14, m)
	for i in travees:
		var p0 := a.lerp(b, float(i) / travees)
		var p1 := a.lerp(b, float(i + 1) / travees)
		tube(p0, p0 + up, 0.09, m)
		if i % 2 == 0:
			tube(p0, p1 + up, 0.08, m)
		else:
			tube(p0 + up, p1, 0.08, m)
	tube(b, b + up, 0.09, m)
	# Poteaux porteurs jusqu'au toit.
	tube(a - Vector3(0, 0.2, 0), a, 0.2, m)


## Arc (demi-cercle vertical dans le plan X-Y) : les cintres bleus de la halle.
func arc(centre: Vector3, rayon: float, epaisseur: float, m: Material) -> void:
	var n := 16
	for i in n:
		var a0 := PI * float(i) / n
		var a1 := PI * float(i + 1) / n
		tube(centre + Vector3(cos(a0), sin(a0), 0) * rayon, centre + Vector3(cos(a1), sin(a1), 0) * rayon, epaisseur, m)


## Rangée de places avec des voitures d'époque (formes simples, aucune marque).
func parking(depart: Vector3, places: int, angle: float, epi := 0.0) -> void:
	var base := Basis(Vector3.UP, angle)
	var teintes := [Color(0.75, 0.75, 0.72), Color(0.2, 0.22, 0.26), Color(0.55, 0.12, 0.12), Color(0.16, 0.2, 0.36), Color(0.82, 0.8, 0.74), Color(0.3, 0.38, 0.32), Color(0.5, 0.5, 0.52)]
	for i in places + 1:
		var p := depart + base.x * (i * 2.6 - 1.3)
		bloc("Ligne", p + Vector3(0, 0.012, 0), Vector3(0.1, 0.02, 4.6), mat(Color(0.8, 0.8, 0.76)), false, base * Basis(Vector3.UP, epi))
	for i in places:
		if _rng.randf() < 0.3:
			continue
		var p := depart + base.x * (i * 2.6) + base.z * _rng.randf_range(-0.2, 0.2)
		voiture(p, angle + epi + (PI if _rng.randf() < 0.3 else 0.0), teintes[_rng.randi() % teintes.size()])


func voiture(pied: Vector3, angle: float, c: Color) -> void:
	var base := Basis(Vector3.UP, angle)
	var v := bloc("Voiture", pied + Vector3(0, 0.62, 0), Vector3(1.7, 0.74, 4.0), mat(c, 0.35), true, base)
	var cab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 0.56, 2.0)
	cab.mesh = bm
	cab.material_override = mat(Color(0.12, 0.15, 0.2), 0.15)
	cab.position = Vector3(0, 0.64, -0.2)
	v.add_child(cab)
	for sx in [-0.8, 0.8]:
		for sz in [-1.25, 1.25]:
			var w := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.3
			cy.bottom_radius = 0.3
			cy.height = 0.2
			w.mesh = cy
			w.material_override = mat(Color(0.08, 0.08, 0.09))
			w.rotation.z = PI * 0.5
			w.position = Vector3(sx, -0.32, sz)
			v.add_child(w)
