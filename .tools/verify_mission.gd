extends SceneTree
## Mission 1 « Premier mur » jouée dans le vrai quartier : snack → tag → retour.
var failures := 0
func check(c: bool, m: String) -> void:
	print(("PASS: " if c else "FAIL: ") + m)
	if not c: failures += 1
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func secondes(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await physics_frame
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://mission.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level); current_scene = level
	await frames(30)
	var M = root.get_node("Mission")
	M.etat = "attente"; M._t = 0.0
	var p = level.get_node("Player"); var q = level.get_node("Quartier"); var g = level.get_node("Graffiti")
	g.expert = false
	await secondes(3.5)
	check(M.etat == "peinture", "l'intro passe, objectif : le snack (%s)" % M.etat)
	var snack: Node3D = M._snack()
	check(snack != null, "le snack existe (zone ravitaillement de n°2)")
	g.reserve = [0.0, 0.0, 0.0, 0.0]
	var sp := snack.global_position
	p.global_position = Vector3(sp.x, q.h(sp.x, sp.z) + 0.3, sp.z); p.velocity = Vector3.ZERO
	await frames(5)
	check(g._conteneur_proche() != null, "au snack, le bouton FOUILLE est disponible")
	await secondes(1.0)
	check(M.etat == "mur", "au snack : peinture reçue, objectif le mur (%s)" % M.etat)
	check(g.reserve[0] > 0.9, "les bombes sont pleines")
	# tag sur la façade est de la barre (près du conteneur : terrain vague)
	p.global_position = Vector3(-23.4, q.h(-23.4, -100) + 0.2, -100); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	for i in 120:
		await physics_frame
		if p.is_on_floor() and i > 10: break
	var nb0: int = g.poses.size()
	g.commande_tactile("tag")

	print("   trace en cours ", g._trace != null, " mur ", not g._mur_devant().is_empty())
	for i in 600:
		await physics_frame
		if g._trace == null: break
	await secondes(2.0)
	print("   poses ", nb0, " -> ", g.poses.size(), " base ", M._base)
	check(M.etat == "retour", "tag posé : objectif retour au snack (%s)" % M.etat)
	print("   trace ", M.trace)
	check(M.trace.get("spot", "") != "", "le lieu est reconnu : %s" % M.trace.get("spot", ""))
	p.global_position = Vector3(sp.x, q.h(sp.x, sp.z) + 0.3, sp.z); p.velocity = Vector3.ZERO
	await secondes(1.0)
	check(M.etat == "fini", "retour au snack : mission finie (%s)" % M.etat)
	check(FileAccess.file_exists("user://mission.json"), "la trace est sauvegardée")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://mission.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	print("RESULT failures=", failures)
	quit(failures)
