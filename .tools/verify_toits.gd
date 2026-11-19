extends SceneTree
## Vérifie qu'on monte vraiment sur les toits par les accès de n°2 :
## l'échafaudage de la barre (zigzag de plateaux bâchés, en se hissant sur le côté)
## et les escaliers de secours (dernier palier → acrotère → toit).
var failures := 0
var p
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")


## Face à une direction, Espace : il doit se hisser. Renvoie la hauteur gagnée.
func hisser(dir: Vector3) -> float:
	var y0: float = p.global_position.y
	p.visual.rotation.y = atan2(-dir.x, -dir.z)
	await frames(2)
	Input.action_press("jump"); await frames(2); Input.action_release("jump")
	for i in 120:
		await physics_frame
		if not p._mantling and not p.suspendu and p.is_on_floor() and i > 5:
			break
	return p.global_position.y - y0


func run() -> void:
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(40)
	p = level.get_node("Player")
	var toits = null
	for n in root.get_tree().get_nodes_in_group("prise"):
		var parent = n.get_parent()
		if parent and parent.get("acces") != null:
			toits = parent
			break
	check(toits != null and toits.acces.size() > 0, "liste des accès aux toits (%d)" % (toits.acces.size() if toits else 0))
	if toits == null:
		_fin(); return
	for a in toits.acces:
		var nom: String = a[0]
		var toit: float = a[2]
		var n: Vector3 = a[3]
		if nom.begins_with("escalier"):
			var fin: Vector3 = a[4]
			p.global_position = fin + Vector3.UP * 0.1 + n * 0.25
			p.velocity = Vector3.ZERO
			await frames(10)
			var gain: float = await hisser(-n)
			check(p.global_position.y > toit - 0.3, "%s : du dernier palier sur le toit (+%.1f m, toit %.1f, Loums %.1f)" % [nom, gain, toit, p.global_position.y])
		else:
			var d: Vector3 = a[4]
			var depart: Vector3 = a[1]
			p.global_position = depart + Vector3.UP * 0.1
			p.velocity = Vector3.ZERO
			await frames(10)
			var gain: float = await hisser(-n)
			var montees := 0
			var sens := 1.0
			var essais := 0
			while p.global_position.y < toit - 2.5 and essais < 40:
				essais += 1
				var g: float = await hisser(d * sens)
				if g > 1.0:
					montees += 1
					sens = -sens
				else:
					break
			# avancer contre le mur, puis se hisser sur l'acrotère
			p.visual.rotation.y = atan2(n.x, n.z)
			p.get_node("CameraPivot").rotation.y = p.visual.rotation.y
			Input.action_press("move_forward"); await frames(25); Input.action_release("move_forward")
			await frames(5)
			var g2: float = await hisser(-n)
			check(p.global_position.y > toit - 0.3, "%s : %d plateaux puis le toit (Loums %.1f m, toit %.1f)" % [nom, montees + 1, p.global_position.y, toit])
	_fin()


func _fin() -> void:
	print("RESULT failures=", failures)
	quit(failures)
