extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(40)
	var p = level.get_node("Player")
	check(p.is_on_floor(), "posé au sol au départ")
	print("noeuds quartier: ", level.get_node("Quartier").get_child_count(), " grindables: ", get_nodes_in_group("grindable").size())
	# points de contrôle : on téléporte et on vérifie la hauteur du sol
	for t in [["terrasse", Vector3(10,6,-50), 3.0], ["parking", Vector3(0,3,10), 0.0], ["socle tour ocre", Vector3(58,3,0), 0.45], ["perron tour grise", Vector3(-44,4,22), 1.0], ["parvis lycee", Vector3(0,2,92), -2.0], ["boulevard", Vector3(0,3,64), 0.0], ["milieu escalier central", Vector3(2,5,-37), 1.5], ["milieu rampe est", Vector3(43,5,-30), 1.5], ["milieu rampe lycee", Vector3(16,3,81), -1.0]]:
		p.global_position = t[1]; p.velocity = Vector3.ZERO
		await frames(90)
		check(absf(p.global_position.y - t[2]) < 0.25, "%s : sol à %.2f (attendu %.2f)" % [t[0], p.global_position.y, t[2]])
	# marcher du parking jusqu'en haut de l'escalier central
	p.global_position = Vector3(2, 0.1, -30); p.velocity = Vector3.ZERO
	await frames(20)
	Input.action_press("move_forward")
	await frames(400)
	Input.action_release("move_forward")
	check(p.global_position.y > 2.8, "monte l'escalier central à pied (y=%.2f z=%.2f)" % [p.global_position.y, p.global_position.z])
	print("RESULT failures=", failures)
	quit(failures)
