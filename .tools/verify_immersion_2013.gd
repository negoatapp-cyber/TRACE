extends SceneTree
## À lancer avec APPDATA dans .tools/runtime_data : n'utilise pas la partie personnelle.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var base: Node = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(base)
	current_scene = base
	await frames(30)
	var horloge: Node = base.get_node("Temps")
	horloge.pause = true
	check(horloge.date().year == 2014, "la partie principale conserve son calendrier 2014")
	check(horloge.fichier_sauvegarde == "user://temps.json", "chemin de sauvegarde principal conservé")
	base.queue_free()
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://temps_marseille_2013.json"))
	var scene: Node = load("res://scenes/marseille_2013.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(40)
	horloge = scene.get_node("Temps")
	horloge.pause = true
	check(horloge.date().year == 2013 and horloge.date().month == 9 and horloge.date().day == 16, "l'étude démarre le 16 septembre 2013")
	check(absf(horloge.heure() - 16.5) < 0.3, "départ vers 16 h 30")
	check(horloge.fichier_sauvegarde != "user://temps.json", "l'horloge d'étude utilise un fichier distinct")
	var detail: Node = scene.get_node("Immersion2013")
	check(detail.find_children("*", "CollisionObject3D", true, false).is_empty(), "le microdécor ne crée aucune collision")
	check(detail.find_children("*", "MultiMeshInstance3D", true, false).size() == 8, "le décor de voirie est regroupé en huit lots")
	check(detail.find_children("*", "Label3D", true, false).size() == 2, "les deux affiches fictives sont présentes")
	var joueur: CharacterBody3D = scene.get_node("Player")
	var greffe: Node3D = scene.get_node("Habillage/ImpassePaix")
	for d in [-12.0, 0.0, 10.0, 30.0, 39.0]:
		var sol: Vector3 = greffe.position + Vector3(1.2, 0.02 * d, -d)
		joueur.global_position = sol + Vector3.UP * 0.3
		joueur.velocity = Vector3.ZERO
		await frames(40)
		check(joueur.is_on_floor() and absf(joueur.global_position.y - sol.y) < 0.25, "le joueur tient sur la chaussée, profondeur %.0f m" % d)
	# Valide aussi le changement de journée avec la nouvelle origine du calendrier.
	horloge.avancer_jusqu_a(1, 8.0)
	check(horloge.date().day == 17 and absf(horloge.heure() - 8.0) < 0.01, "lendemain : 17 septembre 2013, 8 h")
	horloge.minutes = 0.0
	horloge._sauver()
	check(FileAccess.file_exists(horloge.fichier_sauvegarde), "l'horloge 2013 se sauvegarde")
	print("RESULT failures=", failures)
	scene.queue_free()
	await frames(3)
	quit(failures)
