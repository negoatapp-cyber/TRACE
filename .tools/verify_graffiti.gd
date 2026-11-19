extends SceneTree
## Vérifie le graffiti : face à la grande barre, un tag, un flop, une pièce.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(40)
	var p = level.get_node("Player")
	var q = level.get_node("Quartier")
	var g = level.get_node("Graffiti")
	# au pied de la façade est de la barre, tourné vers elle (vers l'ouest)
	p.global_position = Vector3(-24.2, q.h(-24.2, -100) + 0.2, -100); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(40)
	check(not g._mur_devant().is_empty(), "un mur est détecté devant le personnage")
	for essai in [["tag", 60], ["flop", 200], ["piece", 440]]:
		Input.action_press("graff")
		await frames(essai[1])
		Input.action_release("graff")
		await frames(5)
		check(g.compte[essai[0]] == 1, "%s posé" % essai[0])
		p.global_position.z -= 9.0
		await frames(20)
	check(g.poses.size() == 3 and FileAccess.file_exists("user://graffitis.json"), "3 graffitis sauvegardés")
	Input.action_press("graff"); await frames(20); Input.action_release("graff"); await frames(5)
	check(g.poses.size() == 3, "un appui trop court ne pose rien")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	print("RESULT failures=", failures)
	quit(failures)
