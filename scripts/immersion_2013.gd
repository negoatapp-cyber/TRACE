extends Node3D
## Étude de détail : éléments plausibles de voirie, pas un relevé historique.
## Placés dans le repère de la rue pilote, sans collision pour préserver le skate.
const GREFFE := preload("res://scripts/greffe_paix.gd")
const TOON := preload("res://shaders/bd_toon.gdshader")
var _lots: Dictionary = {}
var _cube := BoxMesh.new()
var _disque := CylinderMesh.new()

func _ready() -> void:
	_cube.size = Vector3.ONE
	_disque.top_radius = 0.5
	_disque.bottom_radius = 0.5
	_disque.height = 1.0
	_disque.radial_segments = 24
	construire.call_deferred()

func _point(x: float, d: float, haut: float) -> Vector3:
	return GREFFE.ORIGINE + Vector3(x, GREFFE.PENTE * d + haut, -d)

func _piece(lot: String, mesh: Mesh, teinte: Color, p: Vector3, taille: Vector3, angle: float = 0.0) -> void:
	if not _lots.has(lot):
		_lots[lot] = {"mesh": mesh, "couleur": teinte, "poses": []}
	var base := Basis(Vector3.UP, angle).scaled(taille)
	_lots[lot]["poses"].append(Transform3D(base, p))

func construire() -> void:
	# Le StyleBD a construit la greffe avant cet appel différé.
	if not get_parent().has_node("Habillage/ImpassePaix"):
		push_error("Immersion 2013 : la rue pilote n'est pas construite")
		return
	# Avaloirs en bordure : cadre, fond noir et barreaux lisibles à pied.
	for d in [-9.0, 4.0, 16.0, 31.0, 39.0]:
		for x in [-1.12, 5.37]:
			_piece("cadres", _cube, Color(0.38, 0.37, 0.38), _point(x, d, 0.035), Vector3(0.52, 0.025, 0.78))
			_piece("creux", _cube, Color(0.12, 0.13, 0.17), _point(x, d, 0.050), Vector3(0.43, 0.012, 0.67))
			for i in 8:
				_piece("barreaux", _cube, Color(0.42, 0.40, 0.39), _point(x, d - 0.28 + i * 0.08, 0.061), Vector3(0.45, 0.015, 0.026))
	# Tampons d'accès et réparations d'enrobé : décalés du passage principal.
	for d in [-3.0, 13.0, 34.0]:
		_piece("reprises", _cube, Color(0.33, 0.31, 0.36), _point(2.3, d, 0.021), Vector3(1.05, 0.012, 1.35), 0.12)
		_piece("tampons", _disque, Color(0.26, 0.27, 0.30), _point(2.3, d, 0.037), Vector3(0.68, 0.018, 0.68))
		for i in 7:
			_piece("relief_tampon", _cube, Color(0.39, 0.37, 0.39), _point(2.3, d - 0.21 + i * 0.07, 0.049), Vector3(0.43, 0.008, 0.015))
	# Quelques feuilles et papiers aux pieds des murs, jamais un tapis de déchets.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20130916
	for i in 48:
		var d := rng.randf_range(-14.0, 40.0)
		var x := rng.randf_range(6.55, 6.95) if i % 2 == 0 else rng.randf_range(-4.55, -4.15)
		var papier := i % 7 == 0
		_piece("papier" if papier else "feuilles", _cube, Color(0.78, 0.75, 0.65) if papier else Color(0.43, 0.33, 0.21), _point(x, d, 0.17), Vector3(0.17 if papier else 0.08, 0.006, 0.22 if papier else 0.12), rng.randf_range(-PI, PI))
	# Affichage fictif : vie de quartier et date, sans marque ni événement réel inventé.
	_affiche("ATELIER VELO\nSAMEDI 21 SEPT.\n14 H - 18 H\nAU LOCAL", 7.02, 3.0, Color(0.86, 0.78, 0.56))
	_affiche("RENCONTRE\nDES HABITANTS\nSEPTEMBRE 2013\nENTREE LIBRE", 7.02, 4.0, Color(0.76, 0.83, 0.79))
	for cle in _lots:
		var lot: Dictionary = _lots[cle]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = lot["mesh"]
		mm.instance_count = lot["poses"].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, lot["poses"][i])
		var mi := MultiMeshInstance3D.new()
		mi.name = cle
		mi.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = TOON
		mat.set_shader_parameter("couleur", lot["couleur"])
		mi.material_override = mat
		mi.visibility_range_end = 95.0
		mi.visibility_range_end_margin = 15.0
		add_child(mi)
	add_to_group("detail_2013")
	# La carte de jeu reste historique ; la comparaison reste dans la scène de développement.
	var q := get_parent().get_node("Quartier")
	for label in q.find_children("*", "Label", true, false):
		if "Époque :" in label.text:
			label.text = "Marseille · septembre 2013 · quartier historique"
	print("Immersion 2013 : %d lots de voirie, 2 affiches fictives" % _lots.size())

func _affiche(texte: String, x: float, d: float, teinte: Color) -> void:
	var panneau := MeshInstance3D.new()
	var plan := QuadMesh.new()
	plan.size = Vector2(0.56, 0.76)
	panneau.mesh = plan
	panneau.position = _point(x, d, 1.65)
	panneau.rotation.y = -PI * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = teinte
	mat.roughness = 1.0
	panneau.material_override = mat
	add_child(panneau)
	var label := Label3D.new()
	label.text = texte
	label.font_size = 40
	label.pixel_size = 0.0013
	label.modulate = Color(0.17, 0.23, 0.25)
	label.outline_size = 0
	label.position.z = 0.008
	panneau.add_child(label)
