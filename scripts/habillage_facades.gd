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
## Usure des façades en 2013 (shader `usure`) : les cités sont tachées, écaillées, noircies au pied.
const USURE := {"marathon_rouge": 0.95, "impasse_beige": 0.9, "barre_lauriers": 0.7, "cypres_barre": 0.6,
	"cypres_tour": 0.5, "genets_blanc": 0.6, "tour_ocre": 0.5, "barre_rose": 0.6, "barre_blanche": 0.6, "clair": 0.35}
## Petits immeubles dont le toit porte des conduits de cheminée, des paraboles et des râteaux (image cible).
const TOITS_ENCOMBRES := ["marathon_rouge", "impasse_beige", "cypres_barre", "genets_blanc", "barre_rose", "barre_blanche"]
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


## Bâtiments refaits en modèles peints (scripts/carte_peinte.gd) : on garde leurs PRISES de grimpe
## (rebords, acrotère, descentes d'eau), mais pas leurs volumes dessinés ici, que le modèle porte déjà.
var peints: Dictionary = {}
var _muet := false


func _batiment(nom: String, hauteur: float, style: String, poly: PackedVector2Array) -> void:
	_muet = peints.has(nom)
	if peints.get(nom, true) is String and peints[nom] == "modele":
		return   # volumétrie propre (Tour Cyprès B) : prises, descentes et acrotère viennent du modèle peint
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
	if USURE.has(style) and not _muet:
		_repeindre(nom, {"usure": USURE[style]})
	if style in TOITS_ENCOMBRES and not _muet:
		_cheminees(poly, toit, mur)
	var niveaux := int(floor((hauteur - RDC - 0.6) / etage))
	if style in AVEC_BALCONS:
		niveaux = int(floor((hauteur - RDC - 2.4) / etage)) + 1   # un balcon au dernier étage aussi
	# Entre le garde-corps du dernier balcon et le haut de l'acrotère, la grimpe bondit de 3,1 m au plus :
	# au-delà, une corniche fait l'étape intermédiaire.
	var corniche := -1.0
	var haut_balcon := RDC + (niveaux - 1) * etage + GARDE_CORPS
	var peau := PEAU if (style == "barre_lauriers" and not _muet) else 0.0
	if style == "barre_lauriers":
		haut_balcon = RDC + (niveaux - 1) * etage
		if not _muet:
			_repeindre_barre(nom)
			_peau_barre(nom, poly, moy, hauteur, niveaux, etage, travee, mur, garde)
	elif style == "cypres_tour" and not _muet:
		# photos 2013-2014 : l'orange est une bande verticale en creux au milieu des grandes faces
		_repeindre(nom, {"bande_largeur": 0.0, "bande_centre": BANDE_TOUR, "bande_axe": Vector2(0.0, 1.0)})
		_ailettes_tour(poly, moy, hauteur, mur)
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
		if style == "barre_lauriers":
			# 2013 : façade plate, loggias en creux (shader) ; seuls les nez de dalle dépassent un peu,
			# assez pour s'y accrocher et monter d'étage en étage.
			if long >= 15.0:
				if n.x < -0.7:
					_soubassement_desserte(a, d, n, long, moy + RDC)
				for kk in niveaux:
					_rebord_mince(corps, a, b, d, n, long, moy + RDC + kk * etage, mur.darkened(0.05), kk < niveaux - 1, true, peau)
		elif style in AVEC_BALCONS and long >= 15.0 and not _muet:  # pas de balcons sur les pignons
			_balcons(corps, a, d, n, u, long, moy, niveaux, etage, travee, garde)
		elif long >= 2.0 and style != "lycee" and (style in AVEC_DALLES or _muet or not (style in AVEC_BALCONS)):
			# Louma (20.11) : on doit pouvoir escalader TOUS les bâtiments → un rebord à chaque étage partout
			_dalles(corps, a, b, d, n, long, moy, niveaux, etage, mur.darkened(0.08))
		if corniche > 0.0 and long >= 2.0:
			# pas de bloc caché au-dessus de la corniche : il dépassait du toit et prenait la place d'arrivée
			_rebord_mince(corps, a, b, d, n, long, corniche, mur.darkened(0.1), false)
		if hauteur >= 3.0 and not _muet:
			# (bâtiment peint : son acrotère est dans le modèle ; un bloc ici occupait l'arrivée sur le toit)
			_acrotere(corps, a, b, d, n, long, toit, mur.darkened(0.1), peau)
		u += long
	if hauteur >= 3.0:
		_descentes(_decale(poly, peau) if peau > 0.0 else poly, moy, toit)
	if hauteur >= 15.0:
		_edicules(corps, poly, toit, mur.darkened(0.06))


## Les trappes à deux vantaux et les soupiraux du côté terrain vague (Street View, mai 2011).
## Leur espacement est estimé. Le seuil suit la desserte, le premier balcon reste dégagé.
func _soubassement_desserte(a: Vector2, d: Vector2, n: Vector2, longueur: float, premiere_dalle: float) -> void:
	var base := _base(d, n)
	var nombre := maxi(1, roundi(longueur / 19.0))
	for i in nombre:
		var p := a + d * ((i + 0.5) * longueur / nombre) + n * PEAU
		var sol := h(p.x, p.y) + 0.08
		if sol + 1.9 > premiere_dalle:
			continue
		var pied := Vector3(p.x, sol, p.y)
		# Le cadre visible entre les vantaux et dans les ouïes donne le trait sombre à hauteur de rue.
		var cadre := Color(0.31, 0.33, 0.34)
		var tole := Color(0.71, 0.73, 0.72)
		_ajouter("trappes_cadre", _cube, cadre, Transform3D(_ech(base, Vector3(1.72, 1.46, 0.09)), pied + base.y * 0.73 + base.z * 0.045))
		for cote: float in [-1.0, 1.0]:
			var centre := pied + base.x * (0.42 * cote) + base.y * 0.73
			_ajouter("trappes_tole", _cube, tole, Transform3D(_ech(base, Vector3(0.81, 1.39, 0.035)), centre + base.z * 0.107))
			for j in 2:
				_ajouter("trappes_cadre", _cube, cadre, Transform3D(_ech(base, Vector3(0.40, 0.045, 0.02)), centre + base.y * (0.38 + j * 0.09) + base.z * 0.13))
		var voisin := p + d * 3.2
		var bouche := Vector3(voisin.x, minf(h(voisin.x, voisin.y) + 1.65, premiere_dalle - 0.3), voisin.y)
		_ajouter("trappes_cadre", _cube, cadre, Transform3D(_ech(base, Vector3(0.56, 0.20, 0.07)), bouche + base.z * 0.04))


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
			# Prises : tous les balcons, sur toute la hauteur (avant : seulement les 3 premiers niveaux,
			# sauf une colonne sur 9 ; Louma restait bloqué au 2e étage sur toutes les barres).
			if true or k < PRISES_BASSES or colonne:
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


## La grande barre des Lauriers telle qu'en juin 2014 (Street View, rue Raymonde Martin) :
## crème, plate, une colonne de loggias en creux pour deux colonnes de doubles fenêtres.
## Toit d'immeuble des années 60 : une file de conduits de ventilation coiffés, deux râteaux, des paraboles au bord.
func _cheminees(poly: PackedVector2Array, toit: float, mur: Color) -> void:
	var i_long := 0
	for i in poly.size():
		if poly[i].distance_to(poly[(i + 1) % poly.size()]) > poly[i_long].distance_to(poly[(i_long + 1) % poly.size()]):
			i_long = i
	var a := poly[i_long]
	var b := poly[(i_long + 1) % poly.size()]
	var long := a.distance_to(b)
	if long < 8.0:
		return
	var d := (b - a) / long
	var dedans := -_normale_dehors(a, b, poly)
	# profondeur du bâtiment, mesurée vers l'intérieur
	var prof := 4.0
	while prof < 30.0 and Geometry2D.is_point_in_polygon(a + d * long * 0.5 + dedans * (prof + 1.0), poly):
		prof += 1.0
	var base := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(dedans.x, 0, dedans.y)).orthonormalized()
	var t := 3.0
	var k := 0
	while t < long - 2.5:
		var p := a + d * t + dedans * (prof * 0.5 + (0.9 if k % 2 == 0 else -0.9))
		if Geometry2D.is_point_in_polygon(p, poly):
			var hc := _rng.randf_range(1.0, 1.6)
			var o := Vector3(p.x, toit + hc * 0.5, p.y)
			_ajouter("cheminee", _cube, mur.darkened(0.12), Transform3D(_ech(base, Vector3(0.75, hc, 0.55)), o))
			_ajouter("cheminee_chapeau", _cube, Color(0.42, 0.42, 0.44), Transform3D(_ech(base, Vector3(0.95, 0.1, 0.75)), o + Vector3.UP * (hc * 0.5 + 0.18)))
			for s2 in [-1.0, 1.0]:
				_ajouter("cheminee_pied", _cube, Color(0.42, 0.42, 0.44), Transform3D(_ech(base, Vector3(0.06, 0.18, 0.06)), o + Vector3.UP * (hc * 0.5 + 0.06) + base.x * s2 * 0.3))
		t += _rng.randf_range(4.0, 6.0)
		k += 1
	# râteaux de télé
	for f in [0.3, 0.72]:
		var p: Vector2 = a + d * long * f + dedans * prof * 0.5
		var m := Vector3(p.x, toit, p.y)
		_ajouter("antenne", _cube, Color(0.45, 0.46, 0.48), Transform3D(Basis().scaled(Vector3(0.05, 2.6, 0.05)), m + Vector3.UP * 1.3))
		var rot := Basis(Vector3.UP, _rng.randf() * TAU)
		for i in 3:
			_ajouter("antenne", _cube, Color(0.45, 0.46, 0.48), Transform3D(_ech(rot, Vector3(1.2 - i * 0.25, 0.04, 0.04)), m + Vector3.UP * (1.8 + i * 0.35)))
	# paraboles au bord du toit, tournées vers le sud-est
	for f in [0.15, 0.55, 0.85]:
		if _rng.randf() < 0.3:
			continue
		var p: Vector2 = a + d * long * f + dedans * 0.6
		var pb := Basis(Vector3.UP, deg_to_rad(150)) * Basis(Vector3.RIGHT, deg_to_rad(70))
		_ajouter("parabole", _disque, Color(0.88, 0.88, 0.86), Transform3D(_ech(pb, Vector3(0.9, 0.05, 0.9)), Vector3(p.x, toit + 1.0, p.y)))
		_ajouter("antenne", _cube, Color(0.45, 0.46, 0.48), Transform3D(Basis().scaled(Vector3(0.05, 1.0, 0.05)), Vector3(p.x, toit + 0.5, p.y)))


const PEAU := 0.7          # épaisseur de la façade rapportée de la grande barre (profondeur des loggias)
const RYTHME_BARRE := 3     # une colonne de loggias toutes les 3 travées (même valeur que _repeindre_barre)

## LA GRANDE BARRE (Street View juin 2014) : une vraie façade épaisse posée devant le volume du relevé,
## percée de vraies loggias en creux (0,7 m) — une colonne toutes les trois travées, du premier étage au dernier.
## Le fond des loggias est le mur du relevé (porte-fenêtre peinte) ; devant, à chaque étage, la dalle et
## un garde-corps plein, parfois du linge ou une parabole. Les pignons sont pleins.
func _peau_barre(nom: String, poly: PackedVector2Array, moy: float, hauteur: float, niveaux: int, etage: float, travee: float, mur: Color, garde: Color) -> void:
	var facade: Material = null
	for bat in get_tree().get_nodes_in_group("batiment"):
		if bat.name == nom:
			for e in bat.get_children():
				if e is MeshInstance3D and e.material_override is ShaderMaterial:
					facade = e.material_override
	var ext := _decale(poly, PEAU)
	var toit := moy + hauteur
	var y_bas := INF
	for p in ext:
		y_bas = minf(y_bas, h(p.x, p.y))
	y_bas -= 1.5
	var y_t0 := moy + RDC - 0.05
	var y_t1 := toit - 0.5
	var sf := SurfaceTool.new()   # faces avant : le shader de façade (fenêtres, volets)
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sc := SurfaceTool.new()   # tranches et dessus : enduit uni
	sc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := StaticBody3D.new()
	col.name = "Peau_" + nom.validate_node_name()
	add_child(col)
	var u := 0.0
	var nb_loggias := 0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var long := a.distance_to(b)
		if long < 0.01:
			continue
		var a2 := ext[k]
		var b2 := ext[(k + 1) % poly.size()]
		var d := (b - a) / long
		var n := _normale_dehors(a, b, poly)
		var n3 := Vector3(n.x, 0, n.y)
		var trous := []
		if long >= 15.0:
			for c in range(int(floor(u / travee)), int(floor((u + long) / travee)) + 1):
				if posmod(c, RYTHME_BARRE) != 0:
					continue
				var t0 := (c + 0.05) * travee - u
				var t1 := (c + 0.95) * travee - u
				if t0 > 0.8 and t1 < long - 0.8:
					trous.append([t0, t1])
		var avant := func(t: float, y: float) -> Vector3:
			var q := a2.lerp(b2, t / long)
			return Vector3(q.x, y, q.y)
		var arriere := func(t: float, y: float) -> Vector3:
			var q := a.lerp(b, t / long)
			return Vector3(q.x, y, q.y)
		var face := func(t0: float, t1: float, y0: float, y1: float) -> void:
			_quad(sf, avant.call(t0, y0), avant.call(t1, y0), avant.call(t1, y1), avant.call(t0, y1), n3,
				[Vector2(u + t0, y0 - moy), Vector2(u + t1, y0 - moy), Vector2(u + t1, y1 - moy), Vector2(u + t0, y1 - moy)])
		var bloc := func(t0: float, t1: float, y0: float, y1: float) -> void:
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(t1 - t0, y1 - y0, PEAU)
			cs.shape = sh
			var q := a.lerp(b, (t0 + t1) * 0.5 / long) + n * (PEAU * 0.5)
			cs.transform = Transform3D(_base(d, n), Vector3(q.x, (y0 + y1) * 0.5, q.y))
			col.add_child(cs)
		# parties pleines entre les colonnes de loggias
		var bornes := [0.0]
		for tr in trous:
			bornes.append(tr[0])
			bornes.append(tr[1])
		bornes.append(long)
		for i in range(0, bornes.size(), 2):
			face.call(bornes[i], bornes[i + 1], y_bas, toit)
			bloc.call(bornes[i], bornes[i + 1], y_bas, toit)
		# dessus de la façade rapportée
		_quad(sc, arriere.call(0.0, toit), arriere.call(long, toit), avant.call(long, toit), avant.call(0.0, toit), Vector3.UP, [])
		var base := _base(d, n)
		for tr in trous:
			var t0: float = tr[0]
			var t1: float = tr[1]
			face.call(t0, t1, y_bas, y_t0)
			face.call(t0, t1, y_t1, toit)
			bloc.call(t0, t1, y_bas, y_t0)
			bloc.call(t0, t1, y_t1, toit)
			# tranches de la loggia
			_quad(sc, arriere.call(t0, y_t0), avant.call(t0, y_t0), avant.call(t0, y_t1), arriere.call(t0, y_t1), Vector3(d.x, 0, d.y), [])
			_quad(sc, avant.call(t1, y_t0), arriere.call(t1, y_t0), arriere.call(t1, y_t1), avant.call(t1, y_t1), -Vector3(d.x, 0, d.y), [])
			_quad(sc, arriere.call(t0, y_t1), avant.call(t0, y_t1), avant.call(t1, y_t1), arriere.call(t1, y_t1), Vector3.DOWN, [])
			var larg := t1 - t0
			var q: Vector2 = a.lerp(b, (t0 + t1) * 0.5 / long)
			for kk in niveaux:
				var y := moy + RDC + kk * etage
				var o := Vector3(q.x, y, q.y)
				_ajouter("loggia_dalle", _cube, mur.darkened(0.12), Transform3D(_ech(base, Vector3(larg, 0.2, PEAU)), o + base.z * (PEAU * 0.5) - Vector3.UP * 0.1))
				_ajouter("loggia_plafond", _cube, mur.darkened(0.35), Transform3D(_ech(base, Vector3(larg, 0.04, PEAU)), o + base.z * (PEAU * 0.5) + Vector3.UP * (etage - 0.24)))
				_ajouter("loggia_garde", _cube, garde, Transform3D(_ech(base, Vector3(larg, 1.0, 0.08)), o + base.z * (PEAU - 0.12) + Vector3.UP * 0.5))
				var r := _rng.randf()
				if r < 0.10:
					var pb := Basis(Vector3.UP, deg_to_rad(150)) * Basis(Vector3.RIGHT, deg_to_rad(70))
					_ajouter("parabole", _disque, Color(0.88, 0.88, 0.86), Transform3D(_ech(pb, Vector3(0.7, 0.05, 0.7)), o + base.z * (PEAU + 0.12) + base.x * (larg * 0.3) + Vector3.UP * 1.25))
				elif r < 0.32:
					# serviette ou drap sur le garde-corps
					var cle := "serviette_%d" % (int(r * 100.0) % 4)
					_ajouter(cle, _cube, [Color(0.85, 0.30, 0.28), Color(0.25, 0.45, 0.78), Color(0.95, 0.92, 0.86), Color(0.95, 0.75, 0.25)][int(r * 100.0) % 4], Transform3D(_ech(base, Vector3(larg * _rng.randf_range(0.25, 0.6), 0.75, 0.03)), o + base.z * (PEAU - 0.06) + base.x * _rng.randf_range(-0.6, 0.6) + Vector3.UP * 0.7))
				elif r < 0.40:
					# store de toile baissé
					_ajouter("loggia_store", _cube, Color(0.80, 0.52, 0.30), Transform3D(_ech(base, Vector3(larg * 0.94, etage * 0.55, 0.03)), o + base.z * (PEAU - 0.05) + Vector3.UP * (etage * 0.68)))
			nb_loggias += 1
		u += long
	var mf := MeshInstance3D.new()
	sf.generate_tangents()
	mf.mesh = sf.commit()
	mf.material_override = facade
	mf.name = "Facade_rapportee"
	add_child(mf)
	var mc := MeshInstance3D.new()
	mc.mesh = sc.commit()
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("couleur", mur.darkened(0.06))
	m.set_shader_parameter("grain", 0.5)
	mc.material_override = m
	mc.name = "Facade_rapportee_tranches"
	add_child(mc)
	print("Grande barre : façade épaisse, %d colonnes de loggias en creux" % nb_loggias)


## Deux triangles d'un quadrilatère, tournés vers `nrm` ; uv = 4 coordonnées (UV2 = position sur le mur).
func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, nrm: Vector3, uv: Array) -> void:
	var pts := [p0, p1, p2, p3]
	var uvs: Array = uv if uv.size() == 4 else [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var long := 0.0
	if uv.size() == 4:
		long = absf((uv[1] as Vector2).x - (uv[0] as Vector2).x)
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var ordre: Array = tri
		if ((pts[ordre[2]] as Vector3) - pts[ordre[0]]).cross((pts[ordre[1]] as Vector3) - pts[ordre[0]]).dot(nrm) < 0.0:
			ordre = [ordre[0], ordre[2], ordre[1]]
		for i in ordre:
			st.set_normal(nrm)
			st.set_uv(uvs[i])
			st.set_uv2(Vector2(-1.0, -1.0))
			st.add_vertex(pts[i])


## Le contour décalé de `e` m vers l'extérieur, coins en onglet.
func _decale(poly: PackedVector2Array, e: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var nb := poly.size()
	for k in nb:
		var p := poly[k]
		var avant := poly[(k - 1 + nb) % nb]
		var apres := poly[(k + 1) % nb]
		var n1 := _normale_dehors(avant, p, poly)
		var n2 := _normale_dehors(p, apres, poly)
		var mi := (n1 + n2).normalized()
		out.append(p + mi * e / maxf(mi.dot(n1), 0.35))
	return out


const BANDE_TOUR := 4.6   # largeur de la bande orange de la tour Cyprès B (m)

## Les deux joues de la bande orange : de fins voiles de béton qui dépassent, d'un bout à l'autre de la hauteur,
## et creusent la bande dans la façade.
func _ailettes_tour(poly: PackedVector2Array, moy: float, hauteur: float, mur: Color) -> void:
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var long := a.distance_to(b)
		if long < 10.0:
			continue
		var n := _normale_dehors(a, b, poly)
		if absf(n.y) < 0.7:
			continue
		var d := (b - a) / long
		var base := _base(d, n)
		var m := (a + b) * 0.5
		for s in [-1.0, 1.0]:
			var p: Vector2 = m + d * s * (BANDE_TOUR * 0.5 + 0.2)
			var bas := h(p.x, p.y) - 0.5
			var haut := moy + hauteur + 0.4
			_ajouter("ailette", _cube, mur.darkened(0.03), Transform3D(_ech(base, Vector3(0.4, haut - bas, 0.55)), Vector3(p.x, (haut + bas) * 0.5, p.y) + base.z * 0.27))


func _repeindre(nom: String, params: Dictionary) -> void:
	for bat in get_tree().get_nodes_in_group("batiment"):
		if bat.name != nom:
			continue
		for e in bat.get_children():
			if e is MeshInstance3D and e.material_override is ShaderMaterial:
				for cle in params:
					(e.material_override as ShaderMaterial).set_shader_parameter(cle, params[cle])


func _repeindre_barre(nom: String) -> void:
	for bat in get_tree().get_nodes_in_group("batiment"):
		if bat.name != nom:
			continue
		for e in bat.get_children():
			if e is MeshInstance3D and e.material_override is ShaderMaterial:
				var m: ShaderMaterial = e.material_override
				m.set_shader_parameter("rythme", 3.0)
				m.set_shader_parameter("mur", Color(0.90, 0.86, 0.75))
				m.set_shader_parameter("garde_corps", Color(0.84, 0.80, 0.70))
				m.set_shader_parameter("vie", 0.6)


## Un rebord fin le long d'un mur (dalle d'étage, corniche) : visible, et prise de grimpe.
func _rebord_mince(corps: StaticBody3D, a: Vector2, b: Vector2, d: Vector2, n: Vector2, long: float, y: float, c: Color, bloc_dessus := true, discret := false, devant := 0.0) -> void:
	var base := _base(d, n)
	var m := (a + b) * 0.5 + n * devant
	var t := Transform3D(_ech(base, Vector3(long + 0.4, 0.18, 0.4)), Vector3(m.x, y, m.y))
	if discret:
		t = Transform3D(_ech(base, Vector3(long, 0.12, 0.26)), Vector3(m.x, y, m.y))
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
func _acrotere(corps: StaticBody3D, a: Vector2, b: Vector2, d: Vector2, n: Vector2, long: float, toit: float, c: Color, devant := 0.0) -> void:
	var base := _base(d, n)
	var m := (a + b) * 0.5 - n * 0.1 + n * devant
	var t := Transform3D(_ech(base, Vector3(long + 0.2, 0.75, 0.22)), Vector3(m.x, toit + 0.375, m.y))
	_ajouter("acrotere", _cube, c, t)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	# collision plus mince que le muret dessiné (12 cm côté extérieur) : en haut d'une gouttière d'angle,
	# Loums se pose 0,7 m à l'intérieur du coin, l'acrotère épais lui prenait la place (bloqué en haut)
	sh.size = Vector3(long + 0.2, 0.75, 0.12)
	cs.shape = sh
	var mc := (a + b) * 0.5 - n * 0.06 + n * devant
	cs.transform = Transform3D(base, Vector3(mc.x, toit + 0.375, mc.y))
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
	if _muet:
		return   # bâtiment peint : le modèle porte déjà ce détail (seules les prises et l'acrotère restent)
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
		# Seuls les volumes du toit portent une ombre : les balcons et nez de dalle, eux, dessinaient au sol
		# un damier d'ombres (vu sur mobile, 19.11) alors que l'immeuble lui-même projette déjà la sienne.
		if not (cle.begins_with("edicule") or cle == "acrotere"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _pts(s: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in s.split(" ", false):
		var xy := p.split(",")
		out.append(Vector2(float(xy[0]), float(xy[1])))
	return out
