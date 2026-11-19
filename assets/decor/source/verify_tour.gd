extends SceneTree
## Vérifie qu'on s'accroche aux dalles d'étage de la tour des Cyprès B et qu'on monte d'étage en étage.
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
	# Face est de la tour (x = 7), loin de l'entrée.
	var n := Vector3(1, 0, 0)
	var face := Vector3(7.0, 0, -18.0)
	var depart := face + n * 4.0
	depart.y = q.h(depart.x, depart.z) + 0.1
	p.global_position = depart; p.velocity = Vector3.ZERO
	p.visual.rotation.y = atan2(n.x, n.z)
	await frames(10)
	p.get_node("CameraPivot").rotation.y = p.visual.rotation.y
	Input.action_press("push"); Input.action_press("move_forward")
	for i in 90:
		await physics_frame
		if (p.global_position - face).dot(n) < 0.8:
			break

	var ymax := -INF
	Input.action_press("jump")
	for i in 60:
		if i == 3: Input.action_release("move_forward")
		await physics_frame
		ymax = maxf(ymax, p.global_position.y)

	Input.action_release("push")
	check(p.suspendu, "accroché à la première dalle de la tour (bord %.1f)" % p._rebord.y)
	var y0: float = p._rebord.y
	for k in 3:
		Input.action_release("jump"); await frames(3)
		Input.action_press("jump"); await frames(2); Input.action_release("jump")
		await frames(40)
	check(p.suspendu and p._rebord.y - y0 > 7.0, "trois étages plus haut (+%.1f m)" % (p._rebord.y - y0))
	# jusqu'en haut : on bondit tant qu'il y a une dalle, puis on se hisse sur le toit
	var sol: float = q.h(depart.x, depart.z)
	for k in 30:
		var avant: float = p._rebord.y
		Input.action_release("jump"); await frames(3)
		Input.action_press("jump"); await frames(2); Input.action_release("jump")
		await frames(60)
		if not p.suspendu or p._rebord.y <= avant:
			break
	await frames(30)
	check(not p.suspendu and p.is_on_floor() and p.global_position.y - sol > 55.0, "en haut de la tour, sur le toit (%.1f m au-dessus de la rue)" % (p.global_position.y - sol))
	# Une colonne de balcons grimpable, du premier balcon jusqu'au toit.
	var colonnes := {}
	for corps in root.get_tree().get_nodes_in_group("prise"):
		if not (corps is StaticBody3D):
			continue
		for cs in corps.get_children():
			if cs is CollisionShape3D and cs.shape is BoxShape3D and absf((cs.shape as BoxShape3D).size.y - 1.16) < 0.02:
				var cle := "%d_%d" % [roundi(cs.global_position.x * 2), roundi(cs.global_position.z * 2)]
				if not colonnes.has(cle): colonnes[cle] = []
				colonnes[cle].append(cs)
	var meilleure: Array = []
	for cle in colonnes:
		if colonnes[cle].size() > meilleure.size(): meilleure = colonnes[cle]
	meilleure.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	var b0: CollisionShape3D = meilleure[0]
	var nb: Vector3 = b0.global_transform.basis.z.normalized()
	var bord: Vector3 = b0.global_position + nb * 0.55 + Vector3.UP * 0.58
	p._accrocher(bord, nb)
	await frames(10)
	var sol2: float = q.h(bord.x + nb.x * 2, bord.z + nb.z * 2)
	for k in 30:
		var avant: float = p._rebord.y
		Input.action_release("jump"); await frames(3)
		Input.action_press("jump"); await frames(2); Input.action_release("jump")
		await frames(60)
		if not p.suspendu or p._rebord.y <= avant:
			break
	await frames(30)
	check(not p.suspendu and p.is_on_floor() and p.global_position.y - sol2 > 30.0, "colonne de %d balcons jusqu'au toit (%.1f m au-dessus du sol)" % [meilleure.size(), p.global_position.y - sol2])
	print("RESULT failures=", failures)
	quit(failures)
