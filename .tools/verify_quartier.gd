extends SceneTree
## Vérifie que le quartier réel se charge et qu'on tient debout partout.
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
	await frames(60)
	var p = level.get_node("Player")
	var q = level.get_node("Quartier")
	check(p.is_on_floor(), "posé au sol au départ (%.1f, %.2f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])
	print("éléments construits : ", q.get_child_count())
	for t in [["stade", 60, -160], ["pied de la grande barre", -15, -110], ["boulevard", 137, -40], ["devant le lycée", 120, 60], ["skatepark", 0, -280], ["rue de Marathon ouest", -60, 94], ["sud, vers les Peupliers", 20, 200]]:
		var y: float = q.h(t[1], t[2])
		p.global_position = Vector3(t[1], y + 2.0, t[2]); p.velocity = Vector3.ZERO
		await frames(90)
		check(absf(p.global_position.y - y) < 0.4, "%s : sol à %.2f (relief %.2f)" % [t[0], p.global_position.y, y])
	p.global_position = Vector3(57, q.h(57, -45) + 0.2, -45); p.velocity = Vector3.ZERO
	await frames(20)
	Input.action_press("move_forward")
	await frames(300)
	Input.action_release("move_forward")
	check(p.global_position.z < -55.0, "marche le long de la rue de Marathon (z=%.1f)" % p.global_position.z)
	print("RESULT failures=", failures)
	quit(failures)
