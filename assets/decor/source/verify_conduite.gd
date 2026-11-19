extends SceneTree
## Vérifie la conduite (conduite.gd) : monter, rouler, roue arrière, descendre ; puis la voiture.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func appui(action: String) -> void:
	Input.action_press(action); await frames(2); Input.action_release(action); await frames(2)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(40)
	var p = level.get_node("Player")
	var c = level.get_node("Conduite")
	var sc = null
	var vo = null
	for v in c.vehicules:
		if v.type == "scooter": sc = v
		else: vo = v
	check(sc != null and vo != null, "un scooter et une voiture conduisibles")
	# Scooter : se placer à côté, monter.
	p.global_position = sc.global_position + Vector3(0.9, 0.3, 0); p.velocity = Vector3.ZERO
	await frames(30)
	await appui("monter")
	check(c.actuel == sc and p.visual.visible and p.get_node("Visual/Personnage").etat == "assis", "monte sur le scooter, assis dessus")
	var depart: Vector3 = sc.global_position
	Input.action_press("move_forward"); await frames(120); Input.action_release("move_forward")
	check(sc.global_position.distance_to(depart) > 8.0, "le scooter avance (%.1f m, %.0f km/h)" % [sc.global_position.distance_to(depart), sc.vitesse * 3.6])
	Input.action_press("jump"); await frames(45)
	check(sc.cabre > 0.3 and c.roue_arriere > 0.3, "roue arrière (%.0f°, %.1f s)" % [rad_to_deg(sc.cabre), c.roue_arriere])
	Input.action_release("jump"); await frames(70)
	check(sc.cabre < 0.1, "redescend quand on lâche")
	Input.action_press("move_back"); await frames(75); Input.action_release("move_back"); await frames(10)
	print("avant descente : vitesse %.2f cabre %.2f" % [sc.vitesse, sc.cabre])
	await appui("monter")
	print("après : actuel=%s visible=%s dist=%.2f" % [c.actuel, p.visual.visible, p.global_position.distance_to(sc.global_position)])
	check(c.actuel == null and p.visual.visible and p.global_position.distance_to(sc.global_position) < 3.0, "descend du scooter")
	# Roue arrière trop forte : chute.
	await appui("monter")
	Input.action_press("move_forward"); await frames(90)
	Input.action_press("jump"); await frames(60)
	sc.cabre = 1.3   # forcé au-delà de la limite (en jeu : 3 à 4 s plein gaz sans doser)
	await frames(5)
	Input.action_release("jump"); Input.action_release("move_forward")
	await frames(5)
	check(c.actuel == null and c.record > 0.0, "trop cabré : chute (record %.1f s)" % c.record)
	# Voiture.
	p.global_position = vo.global_position + Vector3(1.6, 0.3, 0); p.velocity = Vector3.ZERO
	await frames(30)
	await appui("monter")
	check(c.actuel == vo, "monte dans la voiture")
	var d2: Vector3 = vo.global_position
	Input.action_press("move_forward"); await frames(120)
	Input.action_press("move_left"); await frames(40); Input.action_release("move_left")
	Input.action_release("move_forward")
	check(vo.global_position.distance_to(d2) > 8.0, "la voiture avance et tourne (%.1f m)" % vo.global_position.distance_to(d2))
	print("RESULT failures=", failures)
	quit(failures)
