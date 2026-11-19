extends SceneTree
## Vitrine du décor : charge chaque .glb de assets/decor/ et les aligne, rendu BD, puis capture.
##   godot --path . -s assets/decor/source/vitrine.gd -- <fichier.png>
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var sortie := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://vitrine.png"
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	scene.add_child(env)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 40)
	sol.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.80, 0.72, 0.58)
	sol.material_override = sm
	scene.add_child(sol)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-40, -42, 0)
	soleil.shadow_enabled = true
	scene.add_child(soleil)
	var x := -14.0
	for f in ["voiture_citadine", "voiture_compacte", "utilitaire", "scooter", "conteneur", "banc", "lampadaire", "pin_parasol", "entree_tour"]:
		var doc := GLTFDocument.new()
		var etat := GLTFState.new()
		doc.append_from_file(ProjectSettings.globalize_path("res://assets/decor/%s.glb" % f), etat)
		var n := doc.generate_scene(etat) as Node3D
		var largeur := {"voiture_citadine": 2.4, "voiture_compacte": 2.4, "utilitaire": 2.6, "scooter": 1.4, "conteneur": 2.0, "banc": 2.4, "lampadaire": 2.4, "pin_parasol": 6.0, "entree_tour": 10.0}[f] as float
		x += largeur * 0.5
		n.position = Vector3(x, 0, 0)
		n.rotation.y = 0.5
		scene.add_child(n)
		x += largeur * 0.5 + 0.6
	var cam := Camera3D.new()
	cam.fov = 50
	scene.add_child(cam)
	cam.look_at_from_position(Vector3(4, 7, 22), Vector3(4, 2.0, 0))
	var style := Node.new()
	style.set_script(load("res://scripts/style_bd.gd"))
	scene.add_child(style)
	for i in 40: await process_frame
	root.get_texture().get_image().save_png(sortie)
	quit(0)
