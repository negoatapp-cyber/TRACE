extends Node3D
## TRACE — la rue pilote : l'impasse de la Paix (quartier des Lauriers), calée sur l'image modèle de Louma.
## Zone poussée « au maximum » pour fixer les règles du décor avant de les étendre au quartier.
## Les modèles et leurs textures peintes sont fabriqués par assets/decor/source/rue_paix/generer.py ;
## ici on les pose, on leur donne la lumière « décor peint », leurs collisions et les prises d'escalade.
## Repère : le point de vue de l'image est à l'origine, la rue file vers -Z, X à droite.

const PEINT := preload("res://shaders/decor_peint.gdshader")
const AJOURE := preload("res://shaders/decor_peint_ajoure.gdshader")
const DOSSIER := "res://assets/decor/paix/"
const PENTE := 0.02

## Modèles fixes (déjà en place dans leur fichier) : [nom, collision]
const FIXES := [["sol", true], ["immeuble_a", true], ["immeuble_b", true], ["gymnase", true],
		["soutenement", true], ["fond", true], ["tour_cypres", true], ["tour_c", true], ["ecole", true],
		["parvis_mobilier", true], ["arriere", true],
		["arbre_pignon", false]]   # le grand arbre du parvis : construit pour que SON ombre soit celle du modèle
## (les objets répétés — voitures, pins, lampadaires — sont dans POSES)

## Objets répétés : [modèle, X, D (profondeur), cap en degrés, échelle]
const POSES := [
	# voitures garées le long du gymnase et du mur (une rouge, des blanches) et la blanche de gauche
	["voiture_meshy_rouge", 4.75, 17.4, 1.5, 1.0], ["voiture_meshy_blanche", 4.75, 22.8, -1.0, 1.0], ["voiture_meshy_monospace", 4.8, 28.0, 2.0, 1.0],
	["voiture_meshy_berline", 4.7, 34.8, 0.0, 1.0], ["voiture_meshy_blanche", -0.2, 19.8, 6.0, 1.0],
	# lampadaires à boule sur le trottoir de droite, lampadaire fin au pied du mur PAIX
	["lampadaire_boule", 6.85, 14.9, 0.0, 1.0, 0.14], ["lampadaire_boule", 6.85, 28.0, 0.0, 1.0, 0.14], ["lampadaire_boule", 6.85, 40.0, 0.0, 1.0, 0.14],
	["lampadaire_fin", 1.5, 42.8, 0.0, 1.0],
	# la place haute, APRÈS le grand escalier : grands pins derrière le mur PAIX, puis les arbres en bacs sur deux files.
	# Aucun arbre contre l'immeuble ni dans l'escalier.
	["pin_a", 4.0, 49.5, 0.0, 1.0, "place"], ["pin_b", -9.5, 53.0, 40.0, 1.0, "place"], ["pin_c", 6.4, 57.0, 200.0, 1.1, "place"],
	["arbre_bac", -4.6, 54.5, 10.0, 1.0, "place"], ["arbre_bac_b", -0.2, 55.0, 80.0, 1.0, "place"],
	["arbre_bac_b", -4.6, 61.5, 150.0, 1.05, "place"], ["arbre_bac", -0.2, 62.0, 220.0, 0.95, "place"],
	["arbre_bac", -11.0, 60.0, 300.0, 1.0, "place"], ["arbre_bac_b", 4.6, 64.0, 30.0, 1.0, "place"],
	["buisson", 6.2, 45.3, 0.0, 1.0, "place"],
]
const Y_PLACE := 0.02 * 43.5 + 2.72     # niveau de la place haute (haut de l'escalier)

## Descentes d'eau où Loums peut grimper : [X, D, hauteur du haut, côté libre (X)]
const GOUTTIERES := [[7.1, 11.52, 4.4, -1.0]]

var _mats := {}


func _ready() -> void:
	RenderingServer.directional_shadow_atlas_set_size(8192, false)
	for f in FIXES:
		var n := _poser(f[0])
		if n and f[1]:
			_collisions(n)
	for p in POSES:
		var n := _poser(p[0])
		if n == null:
			continue
		var y := sol(p[2])
		if p.size() > 5:
			y = Y_PLACE if p[5] is String else y + float(p[5])
		n.position = Vector3(p[1], y, -p[2])
		n.rotation_degrees.y = p[3]
		n.scale = Vector3.ONE * p[4]
		_collisions(n)
	for g in GOUTTIERES:
		var m := Marker3D.new()
		m.position = Vector3(g[0], sol(g[1]) + 0.14, -g[1])
		m.set_meta("haut", g[2])
		m.set_meta("dehors", Vector3(g[3], 0, 0))
		m.add_to_group("gouttiere")
		add_child(m)
	_ombres_hors_champ()
	_limites()
	_trait.call_deferred()


## Ombre portée par ce qui est hors champ, comme sur l'image modèle : celle d'un immeuble sur le bas de la
## chaussée. (Le feuillage sur le pignon est l'ombre du vrai arbre du parvis, arbre_pignon.) Ce sont de vraies ombres du soleil
## (elles tombent aussi sur Loums) : des pochoirs invisibles, placés entre le soleil et le décor.
func _ombres_hors_champ() -> void:
	var soleil := get_node_or_null("../Soleil") as DirectionalLight3D
	var vers := Vector3(0.218, -0.707, -0.672)   # direction des rayons (réglage du Soleil de la scène)
	if soleil:
		vers = -soleil.global_transform.basis.z
	# ombre d'immeuble sur le bas de la chaussée (dalle invisible en hauteur)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := 12.0
	var coins := [Vector3(-4.3, y, 30.0), Vector3(1.2, y, 30.0), Vector3(1.2, y, -3.4), Vector3(-4.3, y, -0.4)]
	for t in [[0, 1, 2], [0, 2, 3], [2, 1, 0], [3, 2, 0]]:
		for k in t:
			st.add_vertex(coins[k])
	var dalle := MeshInstance3D.new()
	dalle.mesh = st.commit()
	dalle.material_override = StandardMaterial3D.new()
	dalle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	dalle.name = "OmbreImmeuble"
	add_child(dalle)


## Le trait d'encre du jeu (posé par StyleBD), un peu plus appuyé dans cette rue, comme sur l'image modèle.
func _trait() -> void:
	await get_tree().create_timer(0.3).timeout
	var enc := get_tree().root.find_child("Encrage", true, false) as MeshInstance3D
	if enc and enc.material_override is ShaderMaterial:
		var m := enc.material_override as ShaderMaterial
		m.set_shader_parameter("epaisseur", 2.7)
		m.set_shader_parameter("opacite", 1.0)
		m.set_shader_parameter("assombri", 0.24)
		m.set_shader_parameter("trait_colore", 0.35)
		m.set_shader_parameter("seuil_prof", 0.02)
	_ciel()


## Le ciel peint du jeu (shaders/ciel.gdshader, celui de la carte) : le bleu franc de l'image modèle, avec les nuages.
var _ciel_mat: ShaderMaterial
var _derive := 0.0

func _ciel() -> void:
	var we := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if we == null or not ResourceLoader.exists("res://shaders/ciel.gdshader"):
		return
	_ciel_mat = ShaderMaterial.new()
	_ciel_mat.shader = load("res://shaders/ciel.gdshader")
	_ciel_mat.set_shader_parameter("haut", Color(0.294, 0.557, 0.992))
	_ciel_mat.set_shader_parameter("milieu", Color(0.40, 0.64, 0.99))
	_ciel_mat.set_shader_parameter("horizon", Color(0.86, 0.90, 0.96))
	_ciel_mat.set_shader_parameter("nuage_clair", Color(1.0, 0.98, 0.93))
	_ciel_mat.set_shader_parameter("nuage_corps", Color(0.96, 0.90, 0.90))
	_ciel_mat.set_shader_parameter("nuage_ombre", Color(0.70, 0.68, 0.88))
	_ciel_mat.set_shader_parameter("halo", Color(1.0, 0.90, 0.70))
	_ciel_mat.set_shader_parameter("couverture", 0.55)
	var sky := Sky.new()
	sky.sky_material = _ciel_mat
	we.environment.sky = sky


func _process(delta: float) -> void:
	if _ciel_mat:
		_derive += delta * 1.5
		_ciel_mat.set_shader_parameter("derive", _derive)


## Altitude de la chaussée (la rue monte de 2 % vers le fond).
func sol(d: float) -> float:
	return PENTE * d


## Même question que quartier.h(x, z), pour les scripts qui la posent.
func h(_x: float, z: float) -> float:
	return PENTE * -z


func _poser(nom: String) -> Node3D:
	var chemin := DOSSIER + nom + ".glb"
	if not ResourceLoader.exists(chemin):
		return null
	var scene: PackedScene = load(chemin)
	var n: Node3D = scene.instantiate()
	n.name = nom.capitalize().replace(" ", "")
	add_child(n)
	_peindre(n)
	return n


## Matériaux importés → lumière « décor peint » (texture ou couleur conservée telle quelle).
func _peindre(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var std := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if std == null:
				continue
			if not _mats.has(std):
				var ajoure := std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				var t := ShaderMaterial.new()
				t.shader = AJOURE if ajoure else PEINT
				t.set_shader_parameter("couleur", std.albedo_color)
				if std.albedo_texture:
					t.set_shader_parameter("texture_couleur", std.albedo_texture)
					t.set_shader_parameter("avec_texture", true)
				# la face à l'ombre : franchement plus sombre et plus violette sur les petits volumes (murets,
				# marches, voitures), à peine sur une façade entière
				var nom := String(std.resource_name)
				var sombre := 0.78
				for cle in ["beton", "dessus", "marche", "gris", "caisse", "pierre", "coffret", "souche", "edicule", "corniche", "orange"]:
					if nom.begins_with(cle):
						sombre = 0.62
				t.set_shader_parameter("face_detournee", sombre)
				if nom.begins_with("feuilles") or nom.begins_with("carrosserie"):
					t.set_shader_parameter("sans_ombre", true)   # (les voitures Meshy portent déjà leur ombre peinte)
				if nom.begins_with("carrosserie"):
					t.set_shader_parameter("voiture", true)
				_mats[std] = t
			mi.set_surface_override_material(s, _mats[std])
			if String(std.resource_name).begins_with("feuilles"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for e in n.get_children():
		_peindre(e)


## Limites de la zone jouable : des murs invisibles (sans prise d'escalade ni graffiti) autour de la rue,
## du parvis, de la rampe du soutènement et de la place haute. Au-delà, le décor n'est qu'une façade
## (pas de dos, place haute sans dessous) : on n'y va pas.
## Segments en (X, D) ; la place haute s'arrête devant la barre du fond (D = 77) et à x = 10,4 (bord de la terrasse).
const LIMITES := [[-24.0, -22.0, 21.2, -22.0], [21.2, -22.0, 21.2, 43.5], [21.2, 43.5, 10.4, 43.5],
		[10.4, 43.5, 10.4, 77.0], [10.4, 77.0, -24.0, 77.0], [-24.0, 77.0, -24.0, -22.0]]

func _limites() -> void:
	for l in LIMITES:
		var a := Vector3(l[0], 0, -l[1])
		var b := Vector3(l[2], 0, -l[3])
		var corps := StaticBody3D.new()
		corps.name = "Limite"
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = Vector3((b - a).length() + 1.0, 90.0, 1.0)
		forme.shape = boite
		corps.add_child(forme)
		add_child(corps)
		corps.position = (a + b) / 2.0 + Vector3(0, 35.0, 0)
		corps.rotation.y = atan2(-(b - a).z, (b - a).x)


func _collisions(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if not String(mi.name).contains("grille") and not String(mi.name).contains("feuilles") and not String(mi.name).contains("coeur"):
			mi.create_trimesh_collision()
			for e in mi.get_children():
				if e is StaticBody3D:
					e.add_to_group("mur")
					# un mur fait d'une seule face doit arrêter Loums des deux côtés (sinon on le traverse par-derrière)
					for f in e.get_children():
						if f is CollisionShape3D and f.shape is ConcavePolygonShape3D:
							(f.shape as ConcavePolygonShape3D).backface_collision = true
	for e in n.get_children():
		if not (e is StaticBody3D):
			_collisions(e)
