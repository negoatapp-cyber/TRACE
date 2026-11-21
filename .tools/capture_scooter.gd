extends SceneTree
## Captures du scooter : roue arrière (bavette qui racle), dérapage, vitesse.
##   godot --rendering-driver opengl3 --path . -s .tools/capture_scooter.gd -- <dossier>
var sortie := "/tmp"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: sortie = a[0]
	call_deferred("run")
func pf(n: int) -> void:
	for i in n: await physics_frame
func photo(nom: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(sortie + "/" + nom + ".png")
	print("capture ", nom)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await pf(60)
	var tps = level.get_node_or_null("Temps")
	if tps: tps.pause = true
	var c = level.find_child("Conduite", true, false)
	var sc = null
	for x in c.vehicules:
		if x.type == "scooter": sc = x
	c._monter(sc)
	Input.action_press("move_forward")
	await pf(150)
	await photo("scooter_vitesse")
	Input.action_press("jump")
	await pf(70)
	await photo("scooter_roue_arriere")
	# vue de côté, caméra libre
	var cam := Camera3D.new()
	level.add_child(cam)
	var cote: Vector3 = sc.global_position + sc.gauche() * 3.2 + Vector3.UP * 0.7 - sc.avant() * 0.4
	cam.global_position = cote
	cam.look_at(sc.global_position + Vector3.UP * 0.4 - sc.avant() * 0.4)
	cam.fov = 50
	cam.current = true
	get_root().physics_object_picking = false
	Engine.time_scale = 0.0
	await photo("scooter_bavette_cote")
	Engine.time_scale = 1.0
	quit()
