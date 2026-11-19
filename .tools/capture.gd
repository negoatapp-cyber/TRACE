extends SceneTree
## Captures d'écran du quartier pour juger le rendu. Usage :
##   godot --path . -s .tools/capture.gd -- <dossier_sortie> [bd|brut]
var sortie := "user://"
var args_mode := "bd"
var filtre := PackedStringArray()  # noms de vues à garder (toutes si vide)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: sortie = args[0]
	if args.size() > 1: args_mode = args[1]
	if args.size() > 2: filtre = args[2].split(",")
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(10)
	var style = level.get_node_or_null("StyleBD")
	if style and args_mode == "brut":
		style.basculer(false)
	var p = level.get_node("Player")
	var q = level.get_node("Quartier")
	var piv: Node3D = p.get_node("CameraPivot")
	var arm: SpringArm3D = p.get_node("CameraPivot/SpringArm3D")
	# [nom, x, z, cap caméra (deg), inclinaison]
	var vues := [["echafaudage", -24.0, -38.0, 18.0, 0.12], ["echaf_haut", -30.0, -52.0, 10.0, -0.15, 30.0], ["escalier_lycee", 75.0, 95.0, 120.0, 0.05], ["barre_facade", -8.0, -105.0, 240.0, 0.18], ["cypresA_balcons", 62.0, -55.0, 250.0, 0.12], ["cypresA_grimpe", 49.5, -62.0, 270.0, 0.05, 6.5], ["toit_barre", -31.0, -100.0, 160.0, -0.3, 41.5], ["pied_barre", -15.0, -100.0, 255.0, -0.1], ["mur_lycee", 115.0, 70.0, 300.0, -0.1], ["loums_gros_plan", 57.0, -45.0, 0.0, -0.05], ["entree_cypres", -5.0, -47.0, 180.0, -0.12], ["entree_biais", 9.0, -45.0, 215.0, -0.15], ["marathon_garees", 57.0, -70.0, 165.0, -0.2], ["rue_marathon", 55.0, 20.0, 175.0, -0.15], ["boulevard", 130.0, -60.0, 175.0, -0.12], ["stade", 60.0, -110.0, 10.0, -0.2], ["toit_lycee_photo1", 95.0, 120.0, 55.0, 0.10, 12.0], ["toit_lycee_photo3", 105.0, 75.0, 65.0, 0.05, 12.0], ["barre_parking", -10.0, -150.0, 70.0, -0.12], ["cypres_rue", 57.0, -45.0, 160.0, -0.18], ["lycee", 120.0, 40.0, -60.0, -0.15], ["haut", 20.0, -60.0, 120.0, -0.55]]
	for v in vues:
		if filtre.size() > 0 and not filtre.has(v[0]):
			continue
		var monte: float = v[5] if v.size() > 5 else 0.0
		arm.spring_length = 2.2 if String(v[0]).begins_with("loums") else 4.5
		if String(v[0]).begins_with("loums"):
			p.visual.rotation.y = deg_to_rad(v[3]) + PI  # face à la caméra
		p.global_position = Vector3(v[1], q.h(v[1], v[2]) + 0.1 + monte, v[2])
		p.velocity = Vector3.ZERO
		piv.rotation_degrees.y = v[3]
		arm.rotation.x = v[4]
		await frames(2)
		if monte > 0.0:
			p.set_physics_process(false)
		else:
			p.set_physics_process(true)
		await frames(28)
		piv.global_position = p.global_position + Vector3.UP * 1.5
		await frames(15)
		var img := root.get_texture().get_image()
		img.save_png(sortie + "/" + v[0] + ".png")
		print("capture ", v[0])
	quit(0)
