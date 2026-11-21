extends SceneTree
const Q := preload("res://scripts/quartier_reel.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# État laissé par une visite du quartier contemporain / une partie après 2016.
	Q.epoque = "apres"
	Q.demolies = ["Tour Cyprès B", "Autre bâtiment"]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://temps_marseille_2013.json"))
	var chemin: String = ProjectSettings.get_setting("application/run/main_scene")
	check(chemin == "res://scenes/marseille_2013.tscn", "le lancement normal utilise la carte 2013")
	var scene: Node = load(chemin).instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(45)
	scene.get_node("Temps").pause = true
	check(scene.get_node("Temps").date().year == 2013, "date de la partie : 2013")
	check(Q.epoque == "avant", "l'époque contemporaine précédente est remplacée")
	check(not Q.demolies.has("Tour Cyprès B"), "l'ancienne démolition est annulée pour 2013")
	check(Q.demolies.has("Autre bâtiment"), "la correction ne vide pas les autres états")
	var tour: Node3D = null
	for b in get_nodes_in_group("batiment"):
		if String(b.name).begins_with("Tour Cyprès B".validate_node_name()):
			tour = b
			break
	check(tour != null, "le volume de la tour Cyprès B est construit")
	var modele: Node3D = scene.find_child("Peint_" + "Tour Cyprès B".validate_node_name(), true, false)
	check(modele != null, "le modèle peint de la grande tour est chargé")
	if modele:
		var visibles := 0
		var sommet := -INF
		for mi in modele.find_children("*", "MeshInstance3D", true, false):
			if mi.is_visible_in_tree():
				visibles += 1
				var bb: AABB = mi.global_transform * mi.get_aabb()
				sommet = maxf(sommet, bb.end.y)
		check(visibles > 0 and sommet > 50.0, "la tour est visible et conserve sa grande hauteur")
		check(not modele.find_children("*", "CollisionShape3D", true, false).is_empty(), "les collisions du modèle de tour sont présentes")
	var touche := InputEventKey.new()
	touche.physical_keycode = KEY_T
	touche.pressed = true
	scene.get_node("Quartier")._unhandled_input(touche)
	check(Q.epoque == "avant", "T ne remplace pas la carte de mission 2013 par aujourd'hui")
	scene.queue_free()
	await frames(4)
	# Second chargement : vérifie le cas avec une sauvegarde de 2013 existante.
	var f := FileAccess.open("user://temps_marseille_2013.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"minutes": 120.0}))
	f.close()
	Q.demolies.append("Tour Cyprès B")
	scene = load(chemin).instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(30)
	check(not Q.demolies.has("Tour Cyprès B"), "une sauvegarde de 2013 restaure également la tour")
	scene.queue_free()
	await frames(4)
	Q.demolies.clear()
	print("RESULT failures=", failures)
	quit(failures)
