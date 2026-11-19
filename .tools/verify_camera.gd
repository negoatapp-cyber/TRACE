extends SceneTree
## Vérifie le suivi de caméra : elle se replace dans le dos en mouvement, reste libre à l'arrêt.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func ecart(a: float, b: float) -> float:
	return absf(rad_to_deg(angle_difference(a, b)))
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(40)
	var p = level.get_node("Player")
	var piv: Node3D = p.get_node("CameraPivot")
	# 1. à pied : courir en diagonale ; la caméra doit pivoter pour accompagner la trajectoire
	var r_depart := piv.rotation.y
	Input.action_press("move_forward"); Input.action_press("move_right"); Input.action_press("push")
	await frames(180)
	Input.action_release("move_forward"); Input.action_release("move_right"); Input.action_release("push")
	check(ecart(piv.rotation.y, r_depart) > 30.0, "à pied, la caméra accompagne la course (a tourné de %.0f°)" % ecart(piv.rotation.y, r_depart))
	await frames(60)
	# 2. à l'arrêt : on tourne la caméra de 120°, elle ne bouge plus d'elle-même
	piv.rotation.y += deg_to_rad(120)
	var r0 := piv.rotation.y
	await frames(150)
	check(ecart(piv.rotation.y, r0) < 1.0, "à l'arrêt, la caméra reste où on l'a mise")
	# 3. en skate : on pousse et on tourne ; la caméra suit le virage
	p.global_position.z += 0.0
	Input.action_press("toggle_board"); await frames(3); Input.action_release("toggle_board")
	await frames(20)
	Input.action_press("push"); await frames(80)
	Input.action_press("move_left"); await frames(50); Input.action_release("move_left")
	await frames(60)
	Input.action_release("push")
	check(p.mode == p.Mode.SKATE and ecart(piv.rotation.y, p.visual.rotation.y) < 25.0, "en skate, la caméra suit le virage (écart %.0f°)" % ecart(piv.rotation.y, p.visual.rotation.y))
	print("RESULT failures=", failures)
	quit(failures)
