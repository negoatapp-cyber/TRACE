extends SceneTree
## Captures d'écran du quartier pour juger le rendu. Usage :
##   godot --path . -s .tools/capture.gd -- <dossier_sortie> [bd|brut]
var sortie := "user://"
var args_mode := "bd"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: sortie = args[0]
	if args.size() > 1: args_mode = args[1]
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
	var vues := [["toit_lycee_photo1", 95.0, 120.0, 55.0, 0.10, 12.0], ["toit_lycee_photo3", 105.0, 75.0, 65.0, 0.05, 12.0], ["barre_parking", -10.0, -150.0, 70.0, -0.12], ["cypres_rue", 57.0, -45.0, 160.0, -0.18], ["lycee", 120.0, 40.0, -60.0, -0.15], ["haut", 20.0, -60.0, 120.0, -0.55]]
	for v in vues:
		var monte: float = v[5] if v.size() > 5 else 0.0
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
