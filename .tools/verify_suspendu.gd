extends SceneTree
## Vérifie la grimpe des façades : course murale, s'accrocher à un balcon, bondir au suivant,
## se décaler, se hisser sur un toit, lâcher.
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
	# Une colonne de balcons grimpables : les prises de la grande barre, rangées par hauteur.
	var formes := []
	for corps in root.get_tree().get_nodes_in_group("prise"):
		if not (corps is StaticBody3D):
			continue
		for cs in corps.get_children():
			if cs is CollisionShape3D and cs.shape is BoxShape3D and absf((cs.shape as BoxShape3D).size.y - 1.16) < 0.02:
				formes.append(cs)
	check(formes.size() > 20, "des balcons grimpables (%d)" % formes.size())
	if formes.is_empty():
		_fin(); return
	# le balcon le plus bas, puis celui juste au-dessus
	formes.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	var b0: CollisionShape3D = null
	var b1: CollisionShape3D = null
	for f in formes:
		for g in formes:
			var d: Vector3 = g.global_position - f.global_position
			if absf(d.y - 2.8) < 0.3 and Vector2(d.x, d.z).length() < 0.1:
				b0 = f; b1 = g
				break
		if b0:
			break
	check(b0 != null, "deux balcons l'un au-dessus de l'autre")
	if b0 == null:
		_fin(); return
	var n: Vector3 = b0.global_transform.basis.z.normalized()
	var face: Vector3 = b0.global_position + n * 0.55
	var depart := face + n * 3.5
	depart.y = q.h(depart.x, depart.z) + 0.1
	p.global_position = depart
	p.velocity = Vector3.ZERO
	p.visual.rotation.y = atan2(n.x, n.z)
	await frames(10)
	# course vers le mur, saut maintenu
	p.get_node("CameraPivot").rotation.y = p.visual.rotation.y
	Input.action_press("push")
	Input.action_press("move_forward")
	for i in 90:
		await physics_frame
		if (p.global_position - face).dot(n) < 0.8:
			break
	Input.action_press("jump")
	for i in 60:
		if i == 3:
			Input.action_release("move_forward")
		await physics_frame
	Input.action_release("push")
	check(p.suspendu, "course murale puis accroché au premier balcon (y %.1f, bord %.1f)" % [p.global_position.y, p._rebord.y])
	var y0: float = p._rebord.y
	# bondir au balcon du dessus
	Input.action_release("jump"); await frames(3)
	Input.action_press("jump"); await frames(2); Input.action_release("jump")
	await frames(40)
	check(p.suspendu and p._rebord.y - y0 > 2.5, "bond au balcon du dessus (+%.1f m)" % (p._rebord.y - y0))
	# se décaler
	var avant: Vector3 = p.global_position
	Input.action_press("move_right"); await frames(20); Input.action_release("move_right")
	check(p.suspendu, "toujours accroché après un décalage (%.2f m)" % (p.global_position - avant).length())
	# lâcher
	Input.action_press("move_back"); await frames(3); Input.action_release("move_back")
	for i in 150:
		await physics_frame
		if p.is_on_floor():
			break
	check(not p.suspendu and p.is_on_floor(), "lâche et retombe (y %.1f)" % p.global_position.y)
	_fin()
func _fin() -> void:
	print("RESULT failures=", failures)
	quit(failures)
