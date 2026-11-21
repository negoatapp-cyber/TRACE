extends SceneTree
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var requete := PhysicsRayQueryParameters3D.create(a, b, 1)
	return root.world_3d.direct_space_state.intersect_ray(requete)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://scenes/marseille_2013.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(45)
	scene.get_node("Temps").pause = true
	check(get_nodes_in_group("entree_cypres_2013").size() == 1, "une seule nouvelle entrée dans la tour")
	check(scene.find_child("EntreeCypresB", true, false) == null, "l'ancien hall générique a été retiré")
	var entree: Node3D = get_nodes_in_group("entree_cypres_2013")[0]
	check(entree.global_basis.z.dot(Vector3.RIGHT) > 0.99, "l'entrée regarde le parking et la rue de Marathon, côté est")
	check(absf(entree.global_position.y - scene.get_node("Quartier").h(8, -22) - 0.45) < 0.02, "palier surélevé conformément aux nouvelles vues, estimation 45 cm")
	var p: CharacterBody3D = scene.get_node("Player")
	# Le rayon ignore le personnage et vérifie un vrai accès sous l'auvent.
	p.global_position = Vector3(57, 2, -45)
	var libre := ray(Vector3(12, 5.23, -22), Vector3(4.5, 5.23, -22))
	check(libre.is_empty(), "approche de la porte dégagée à hauteur humaine")
	var porte := ray(Vector3(4.5, 5.23, -22), Vector3(3.8, 5.23, -22))
	check(not porte.is_empty() and String(porte.collider.name) == "PorteFermeeCollision", "la porte fermée possède sa collision")
	var toit := ray(Vector3(6.5, 8.93, -22), Vector3(6.5, 5.63, -22))
	check(not toit.is_empty() and toit.position.y > 6.83 and toit.position.y < 7.23, "le toit courbe est solide et laisse une hauteur de passage")
	for pos0 in [Vector3(6.2, 0.02, -22), Vector3(7, 0.02, -22), Vector3(7.65, -0.28, -22), Vector3(7.3,-0.205,-27.8), Vector3(5.55,-0.219,-10), Vector3(4.1,0.02,-14.2)]:
		var pos: Vector3 = pos0 + Vector3(0, 3.93, 0)   # place de la Tour remontée à 3,5 (21.11)
		p.global_position = pos + Vector3.UP * 0.35
		p.velocity = Vector3.ZERO
		await frames(35)
		check(p.is_on_floor() and absf(p.global_position.y - pos.y) < 0.10, "sol du parvis stable à x=%.2f" % pos.x)
	check(get_nodes_in_group("details_pied_cypres").size() == 1, "les détails du pied de tour sont présents")
	# Les voies doivent suivre la cote finale, au lieu de former un pont au pied de tour.
	var chemin := ray(Vector3(0, 4, -5), Vector3(0, -2, -5))
	check(not chemin.is_empty() and absf(chemin.position.y - scene.get_node("Quartier").h(0,-5)) < 0.2, "le contournement historique suit le niveau du terrain")
	scene.queue_free()
	await frames(4)
	print("RESULT failures=", failures)
	quit(failures)
