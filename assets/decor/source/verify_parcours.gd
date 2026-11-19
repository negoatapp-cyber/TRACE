extends SceneTree
## Vérifie le parcours de l'entrée des Cyprès : armoire électrique, puis auvent.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func saut() -> void:
	Input.action_press("jump"); await frames(3); Input.action_release("jump"); await frames(70)
func run() -> void:
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(40)
	var p = level.get_node("Player")
	var hab = level.get_node("Habillage")
	var ent: Node3D = hab.get_node("EntreeCypresB")
	var arm: Node3D = ent.get_node("ArmoireElectrique")
	var vers_tour: Vector3 = -ent.global_basis.z
	# devant l'armoire, face à la tour
	var depart: Vector3 = arm.global_position + ent.global_basis.z * 1.0
	p.global_position = Vector3(depart.x, arm.global_position.y - 0.8 + 0.2, depart.z); p.velocity = Vector3.ZERO
	p.visual.rotation.y = atan2(-vers_tour.x, -vers_tour.z)
	await frames(30)
	var y0: float = p.global_position.y
	await saut()
	check(p.global_position.y > y0 + 1.3, "monte sur l'armoire électrique (+%.2f m)" % (p.global_position.y - y0))
	# avancer un peu vers la tour, puis se hisser sur l'auvent
	Input.action_press("move_forward"); await frames(6); Input.action_release("move_forward")
	p.visual.rotation.y = atan2(-vers_tour.x, -vers_tour.z)
	await frames(10)
	await saut()
	check(p.global_position.y > y0 + 2.9, "se hisse sur l'auvent (+%.2f m)" % (p.global_position.y - y0))
	var v = get_nodes_in_group("vehicule") if false else root.get_tree().get_nodes_in_group("vehicule")
	var types := []
	for n in v: types.append(n.get_meta("type"))
	check(types.has("voiture") and types.has("scooter"), "une voiture et un scooter près du départ (%s)" % str(types))
	print("RESULT failures=", failures)
	quit(failures)
