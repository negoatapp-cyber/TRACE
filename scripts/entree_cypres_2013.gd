extends Node3D
## Entrée créée pour TRACE : précisée par les vues du pied de tour fournies.
## Porte, interphone, lumière et assemblages sont des choix de conception.
const TOON := preload("res://shaders/bd_toon.gdshader")
const CENTRE_TOUR := Vector3(-5.0, 0.0, -22.0)
const SOL_PARVIS := 3.5   ## = greffe_paix.gd PLATEAU_Y (21.11 : avant -0,43)
const SEUIL := 0.45 # estimation du palier visible ; accès par marches et rampe latérale
@export var orientation_tour_degres: float = 90.0
var _materiaux: Dictionary = {}

func _ready() -> void:
	construire.call_deferred()

func _mat(c: Color) -> ShaderMaterial:
	var cle := c.to_html()
	if not _materiaux.has(cle):
		var mat := ShaderMaterial.new()
		mat.shader = TOON
		mat.set_shader_parameter("couleur", c)
		mat.set_shader_parameter("grain", 0.2)
		_materiaux[cle] = mat
	return _materiaux[cle]

func _boite(nom: String, p: Vector3, taille: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	var mesh := BoxMesh.new()
	mesh.size = taille
	mi.mesh = mesh
	mi.position = p
	mi.material_override = _mat(c)
	add_child(mi)
	return mi

func construire() -> void:
	var tour := get_parent().find_child("Peint_Tour Cyprès B", true, false) as Node3D
	if tour == null:
		push_warning("Entrée Cyprès : modèle historique absent")
		return
	# La face d'entrée regarde le parking à l'est. Pivoter autour de l'emprise,
	# et non autour de l'origine du GLB (ses sommets sont en coordonnées de carte).
	var base := Basis(Vector3.UP, deg_to_rad(orientation_tour_degres))
	var correction := Transform3D(base, CENTRE_TOUR - base * CENTRE_TOUR)
	tour.transform = tour.transform * correction
	# Les descentes grimpables sont des marqueurs séparés du modèle dans CartePeinte.
	for g in get_tree().get_nodes_in_group("gouttiere"):
		if g.get_parent() == tour.get_parent() and Vector2(g.position.x + 5.0, g.position.z + 22.0).length() < 20.0:
			g.position = correction * g.position
			g.set_meta("dehors", base * (g.get_meta("dehors") as Vector3))
	# Hériter du placement du modèle, même s'il est déplacé par le chantier cartographique.
	reparent(tour, false)
	# L'ancien hall générique au nord n'est pas l'entrée documentée par la photo.
	var ancien := get_tree().current_scene.find_child("EntreeCypresB", true, false)
	if ancien:
		ancien.queue_free()
	# Remplacer l'ancien perron avec un palier et des accès raccordés au terrain final.
	for mi in tour.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) in ["bat_3_voute", "bat_3_vert", "bat_3_marche"]:
			mi.hide()
			for cs in mi.find_children("*", "CollisionShape3D", true, false):
				cs.set_deferred("disabled", true)
	# Repère natif du modèle : entrée avancée, puis orientée avec toute la tour.
	# Face extérieure après rotation : x=6 ; porte x=4,05, retrait ~1,95 m.
	position = Vector3(-5.0, SOL_PARVIS + SEUIL, -12.1)
	var acier := Color(0.23, 0.36, 0.46)
	var bronze := Color(0.44, 0.25, 0.19)
	var beton := Color(0.72, 0.64, 0.53)
	_boite("FondAncienSas", Vector3(0, 1.5, -3.83), Vector3(3.9, 3.0, 0.08), beton)
	_boite("FondSombre", Vector3(0, 1.28, -0.94), Vector3(3.12, 2.56, 0.08), Color(0.13, 0.15, 0.19))
	for s in [-1.0, 1.0]:
		_boite("Jouee", Vector3(s * 1.56, 1.35, -1.90), Vector3(0.18, 2.7, 3.98), beton)
		_boite("MontantPorte", Vector3(s * 1.04, 1.23, -0.82), Vector3(0.075, 2.46, 0.10), acier)
		_boite("VantailVitre", Vector3(s * 0.53, 1.24, -0.85), Vector3(0.94, 2.36, 0.055), Color(0.23, 0.30, 0.36))
		_boite("TraversePorte", Vector3(s * 0.53, 0.89, -0.79), Vector3(0.98, 0.065, 0.10), acier)
		for haut in [0.45, 1.35, 1.85, 2.22]:
			_boite("QuadrillageVitre", Vector3(s * 0.53, haut, -0.785), Vector3(0.98, 0.035, 0.065), acier)
		_boite("Poignee", Vector3(s * 0.14, 1.1, -0.72), Vector3(0.035, 0.36, 0.075), Color(0.70, 0.69, 0.58))
	_boite("Linteau", Vector3(0, 2.63, -1.90), Vector3(3.3, 0.15, 3.98), beton)
	_boite("CadreHaut", Vector3(0, 2.46, -0.81), Vector3(2.15, 0.07, 0.10), acier)
	_boite("CadreCentral", Vector3(0, 1.23, -0.79), Vector3(0.07, 2.46, 0.10), acier)
	_boite("Seuil", Vector3(0, 0.005, -0.25), Vector3(3.15, 0.01, 1.45), Color(0.62, 0.58, 0.51))
	_parvis()
	# Interphone inventé, dimensions modestes pour rester plausible et lisible de près.
	_boite("Interphone", Vector3(1.34, 1.32, 0.025), Vector3(0.20, 0.34, 0.06), acier)
	_boite("GrilleInterphone", Vector3(1.34, 1.39, 0.06), Vector3(0.13, 0.095, 0.02), Color(0.07, 0.09, 0.10))
	for i in 3:
		_boite("BoutonInterphone", Vector3(1.34, 1.29 - i * 0.055, 0.065), Vector3(0.10, 0.025, 0.02), Color(0.73, 0.70, 0.58))
	_boite("Plafonnier", Vector3(0, 2.52, -0.40), Vector3(0.62, 0.05, 0.16), Color(0.95, 0.85, 0.60))
	var lampe := OmniLight3D.new()
	lampe.name = "LumiereEntree"
	lampe.position = Vector3(0, 2.28, -0.25)
	lampe.light_color = Color(1.0, 0.79, 0.50)
	lampe.light_energy = 0.55
	lampe.omni_range = 3.3
	lampe.shadow_enabled = false
	add_child(lampe)
	_auvent(bronze)
	_collision()
	var pied: Node3D = (load("res://scripts/pied_cypres_2013.gd") as GDScript).new()
	tour.add_child(pied)
	pied.construire()
	var cour: Node3D = (load("res://scripts/cour_arriere_cypres.gd") as GDScript).new()
	get_tree().current_scene.add_child(cour)
	add_to_group("entree_cypres_2013")
	print("Entrée Cyprès 2013 : auvent, porte, retrait, éclairage et interphone créés")

func _parvis() -> void:
	var palier := _boite("PalierEntree", Vector3(0, -SEUIL * 0.5, 0.0), Vector3(4.4, SEUIL, 4.4), Color(0.66, 0.64, 0.59))
	palier.create_trimesh_collision()
	for i in 3:
		var hauteur := SEUIL - float(i + 1) * SEUIL / 3.0
		# Coordonnée du dessus dans le repère du palier : -0,15 / -0,30 / -0,45.
		var marche := _boite("MarcheEntree", Vector3(0, -SEUIL+(hauteur+0.04)*0.5-0.04, 2.2+(float(i)+0.5)*0.36), Vector3(4.4,hauteur+0.04,0.36), Color(0.66,0.64,0.59))
		marche.create_trimesh_collision()
	# Rampe latérale : 7,2 m pour 45 cm, laisse les marches frontales visibles.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(2.2, 0, 1.8)
	var b := Vector3(9.4, -SEUIL, 1.8)
	var c := Vector3(9.4, -SEUIL, 3.0)
	var d := Vector3(2.2, 0, 3.0)
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)
	st.generate_normals()
	var rampe := MeshInstance3D.new()
	rampe.name = "RampeLaterale"
	rampe.mesh = st.commit()
	rampe.material_override = _mat(Color(0.66, 0.64, 0.59))
	add_child(rampe)
	rampe.create_trimesh_collision()
	for i in 6:
		var x := 2.2 + float(i) * 7.2 / 5.0
		var y := -(x - 2.2) / 7.2 * SEUIL
		_boite("PoteauRampe", Vector3(x, y + 0.48, 3.0), Vector3(0.04, 0.96, 0.04), Color(0.54, 0.57, 0.55))
	for haut in [0.48, 0.93]:
		var rail := _boite("LisseRampe", Vector3(5.8, -SEUIL * 0.5 + haut, 3.0), Vector3(sqrt(7.2 * 7.2 + SEUIL * SEUIL), 0.035, 0.035), Color(0.54, 0.57, 0.55))
		rail.rotation.z = -atan2(SEUIL, 7.2)
	# Bande de stationnement / approche, sur la cote réelle du terrain aplani.
	var bitume := _boite("ApprocheParking", Vector3(0, -SEUIL + 0.006, 4.4), Vector3(12.0, 0.008, 1.8), Color(0.35, 0.36, 0.37))
	bitume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _auvent(c: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Arc peu bombé : 4,4 m de large, saillie de 2,1 m ; proportions de conception.
	for i in 24:
		var x0 := -2.2 + float(i) * 4.4 / 24.0
		var x1 := -2.2 + float(i + 1) * 4.4 / 24.0
		var y0 := 2.65 + 0.43 * (1.0 - pow(x0 / 2.2, 2))
		var y1 := 2.65 + 0.43 * (1.0 - pow(x1 / 2.2, 2))
		var a := Vector3(x0, y0, -0.15)
		var b := Vector3(x1, y1, -0.15)
		var avant := Vector3(0, 0, 2.25)
		var bas := Vector3(0, -0.12, 0)
		for quad in [[a, b, b + avant, a + avant], [a + bas, a + avant + bas, b + avant + bas, b + bas],
			[a + avant, b + avant, b + avant + bas, a + avant + bas]]:
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(quad[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "AuventCourbe"
	mi.mesh = st.commit()
	mi.material_override = _mat(c)
	add_child(mi)
	# Tirants fins et attaches créés pour rendre l'assemblage crédible.
	for s in [-1.0, 1.0]:
		var a := Vector3(s * 1.56, 2.55, -0.02)
		var b := Vector3(s * 1.56, 2.74, 1.72)
		var tige := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.height = a.distance_to(b)
		cyl.top_radius = 0.018
		cyl.bottom_radius = 0.018
		cyl.radial_segments = 8
		tige.mesh = cyl
		tige.position = (a + b) * 0.5
		tige.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		tige.material_override = _mat(Color(0.30, 0.26, 0.24))
		add_child(tige)

func _collision() -> void:
	var body := StaticBody3D.new()
	body.name = "PorteFermeeCollision"
	# Hall fermé pour ce lot : l'intérieur n'est pas encore une zone de mission.
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.3, 2.6, 0.16)
	cs.shape = box
	cs.position = Vector3(0, 1.3, -0.9)
	body.add_child(cs)
	add_child(body)
	# La collision de l'auvent suit le maillage courbe, sans boîte bloquant le passage.
	var toit := get_node("AuventCourbe") as MeshInstance3D
	toit.create_trimesh_collision()
