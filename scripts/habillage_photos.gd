extends Node3D
## Premier lot des photos de Louma : crépi, LOUMS bleu, tuyau et tuiles.
## Ajouts visuels sur les murs existants ; leurs collisions restent la référence.
const GREFFE := preload("res://scripts/greffe_paix.gd")
const MARQUE := preload("res://scripts/marque_murale.gd")
const TOON := preload("res://shaders/bd_toon.gdshader")
const DOSSIER := "res://assets/graffitis/photos_2013/"
var murs_textures := 0

func _ready() -> void:
	construire.call_deferred()

func _point(x: float, d: float, hauteur: float) -> Vector3:
	return GREFFE.ORIGINE + Vector3(x, GREFFE.PENTE * d + hauteur, -d)

func construire() -> void:
	var rue := get_parent().get_node_or_null("Habillage/ImpassePaix")
	if rue == null:
		push_warning("Habillage photos : impasse absente")
		return
	if not ResourceLoader.exists(DOSSIER + "crepi_1024.png") or not ResourceLoader.exists(DOSSIER + "loums_bleu_2048.png"):
		push_warning("Habillage photos : textures privées absentes ; consulter assets/graffitis/LISEZMOI.md")
		return
	var crepi: Texture2D = load(DOSSIER + "crepi_1024.png")
	for mi in rue.find_children("*", "MeshInstance3D", true, false):
		# Choix précis : ni vitrages, ni grilles, ni portes, ni sols.
		if String(mi.name) != "soutenement_mur":
			continue
		for s in mi.mesh.get_surface_count():
			var ancien: ShaderMaterial = mi.get_surface_override_material(s) as ShaderMaterial
			if ancien == null:
				continue
			var mat := ancien.duplicate() as ShaderMaterial
			mat.set_shader_parameter("avec_crepi_photo", true)
			mat.set_shader_parameter("crepi_photo", crepi)
			mi.set_surface_override_material(s, mat)
			murs_textures += 1
	# Sur le soutènement, au-delà du coffret et avant la première voiture.
	var bleu: Texture2D = load(DOSSIER + "loums_bleu_2048.png")
	var peinture := MARQUE.poser(self, bleu, _point(7.19, 15.4, 1.82), Vector3.BACK,
		Vector3.LEFT, 4.6, Color.WHITE, 70.0, 4, "LoumsBleuPhoto")
	if peinture is Decal:
		# Projection très mince : ne pas peindre le lampadaire devant le mur.
		peinture.size.y = 0.18
		peinture.upper_fade = 0.01
		peinture.lower_fade = 0.01
		peinture.position = _point(7.2, 15.4, 1.82)
	_tuyau()
	_tuiles()
	add_to_group("habillage_photos")
	print("Habillage photos : %d surface crépi, LOUMS bleu, tuyau et couronnement" % murs_textures)

func _mat(couleur: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("couleur", couleur)
	return m

func _tuyau() -> void:
	var tube := MeshInstance3D.new()
	tube.name = "TuyauBlancPhotos"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.045
	mesh.height = 10.0
	mesh.radial_segments = 12
	tube.mesh = mesh
	tube.rotation.x = PI * 0.5
	tube.position = _point(7.08, 21.0, 0.45)
	tube.material_override = _mat(Color(0.82, 0.79, 0.67))
	add_child(tube)
	# Colliers et attaches ponctuels, comme sur les murs des photos 0565/0738.
	for d in [16.3, 18.5, 21.0, 23.5, 25.7]:
		var collier := MeshInstance3D.new()
		collier.name = "Collier"
		var boite := BoxMesh.new()
		boite.size = Vector3(0.15, 0.14, 0.035)
		collier.mesh = boite
		collier.position = _point(7.12, d, 0.45)
		collier.material_override = _mat(Color(0.42, 0.38, 0.32))
		add_child(collier)

func _tuiles() -> void:
	# Tuiles canal en demi-cylindre : le relief existe dans la silhouette.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a := PI * float(i) / 10.0
		var b := PI * float(i + 1) / 10.0
		var p := Vector3(cos(a) * 0.24, sin(a) * 0.12, -0.14)
		var q := Vector3(cos(b) * 0.24, sin(b) * 0.12, -0.14)
		for v in [p, q + Vector3(0, 0, 0.28), q, p, p + Vector3(0, 0, 0.28), q + Vector3(0, 0, 0.28)]:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 124
	for i in mm.instance_count:
		var d := 11.42 + float(i) * 0.258
		# Le mur peint descend de 5,80 m à 3,60 m dans le repère du pilote.
		var hauteur := lerpf(5.8, 3.6, (d - 11.3) / 32.2)
		var p: Vector3 = GREFFE.ORIGINE + Vector3(7.3, hauteur + 0.02, -d)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		var nuance := 0.92 + float(i % 5) * 0.035
		mm.set_instance_color(i, Color(nuance, nuance, nuance))
	var tuiles := MultiMeshInstance3D.new()
	tuiles.name = "CouronnementTuilesPhotos"
	tuiles.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.27, 0.16)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tuiles.material_override = mat
	tuiles.visibility_range_end = 100.0
	tuiles.visibility_range_end_margin = 15.0
	add_child(tuiles)
