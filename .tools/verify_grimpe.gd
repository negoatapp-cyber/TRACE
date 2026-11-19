extends SceneTree
## Vérifie courir et grimper.
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
	var q = level.get_node("Quartier")
	# 1. un mur de 1,4 m au nord du quartier : on se hisse dessus
	p.global_position = Vector3(47, q.h(47, -282.35) + 0.2, -282.35); p.velocity = Vector3.ZERO
	p.visual.rotation.y = 0.0
	await frames(40)
	var y0: float = p.global_position.y
	Input.action_press("jump"); await frames(3); Input.action_release("jump")
	await frames(60)
	check(p.climbs == 1 and p.global_position.y > y0 + 0.9, "se hisse sur un mur (monté de %.2f m)" % (p.global_position.y - y0))
	# 2. face à la grande barre : trop haut, c'est un saut normal
	p.global_position = Vector3(-24.0, q.h(-24.0, -100) + 0.2, -100); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(40)
	Input.action_press("jump"); await frames(3); Input.action_release("jump")
	await frames(90)
	check(p.climbs == 1 and p.is_on_floor(), "ne grimpe pas une façade d'immeuble")
	# 3. le muret du stade (0,45 m) : on monte dessus
	p.global_position = Vector3(56, q.h(56, -125.3) + 0.2, -125.3); p.velocity = Vector3.ZERO
	p.visual.rotation.y = 0.0
	await frames(40)
	Input.action_press("jump"); await frames(3); Input.action_release("jump")
	await frames(60)
	check(p.climbs == 2, "monte sur un muret bas")
	# 4. courir va plus vite que marcher
	p.global_position = Vector3(57, q.h(57, -45) + 0.2, -45); p.velocity = Vector3.ZERO
	await frames(30)
	Input.action_press("move_forward"); await frames(60)
	var v_marche: float = Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_press("push"); await frames(60)
	var v_course: float = Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_release("push"); Input.action_release("move_forward")
	check(v_course > v_marche * 1.5, "court (%.1f m/s) plus vite qu'il ne marche (%.1f m/s)" % [v_course, v_marche])
	print("RESULT failures=", failures)
	quit(failures)
