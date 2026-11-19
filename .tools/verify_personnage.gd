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
	await frames(30)
	var p = level.get_node("Player")
	var perso = p.get_node("Visual/Personnage")
	var avec: bool = perso.modele != null
	print("modèle chargé : ", avec)
	if avec:
		check(not p.get_node("Visual/Body").visible, "la capsule est cachée")
		var boite := AABB(); var first := true
		for mi in perso.modele.find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = mi.global_transform * mi.get_aabb()
			boite = bb if first else boite.merge(bb); first = false
		check(absf(boite.size.y - 1.75) < 0.05 and absf(boite.position.y - p.global_position.y) < 0.05, "taille 1,75 m, pieds au sol (h=%.2f)" % boite.size.y)
		check(perso._clips.size() >= 3, "animations reconnues : %s" % str(perso._clips))
		Input.action_press("move_forward"); await frames(40)
		check(String(perso.anim.current_animation).to_lower().contains("walk"), "joue la marche en marchant")
		Input.action_press("push"); await frames(40)
		check(String(perso.anim.current_animation).to_lower().contains("run"), "joue la course en courant")
		Input.action_release("push"); Input.action_release("move_forward"); await frames(60)
		check(perso.anim.current_animation == perso._clips["attente"], "revient à l'attente à l'arrêt")
	else:
		check(p.get_node("Visual/Body").visible, "sans fichier, la capsule reste")
	print("RESULT failures=", failures)
	quit(failures)
