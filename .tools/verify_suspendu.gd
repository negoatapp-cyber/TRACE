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
			if cs is CollisionShape3D and cs.shape is BoxShape3D and (cs.shape as BoxShape3D).size.y > 0.95 and (cs.shape as BoxShape3D).size.y < 1.3 and absf((cs.shape as BoxShape3D).size.z - 1.1) < 0.05:
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
	var perso = p.find_child("Personnage", true, false)
	Input.action_press("move_right"); await frames(12)
	var anime: bool = perso == null or perso.modele == null or perso._clip_pilote().is_empty()
	await frames(8); Input.action_release("move_right")
	check(p.suspendu, "toujours accroché après un décalage (%.2f m)" % (p.global_position - avant).length())
	check(anime, "en se décalant, les mains passent l'une après l'autre (pas la pose figée)")
	# monter en poussant vers le haut (sans Espace)
	# monter tout l'immeuble en tenant haut : on doit passer plusieurs étages, pas rester bloqué au 2e
	var y_dep: float = p._rebord.y
	var col := []
	for f in formes:
		var dd: Vector3 = f.global_position - b0.global_position
		if Vector2(dd.x, dd.z).length() < 0.2: col.append("%.1f" % (f.global_position.y + (f.shape as BoxShape3D).size.y * 0.5))
	print("  colonne de balcons, hauts : ", col)
	var rq := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 40.0 - n * 1.5, p.global_position - n * 1.5)
	var esp: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for hy in range(4, 50):
		var yy := hy * 0.5
		var o: Vector3 = Vector3(p.global_position.x, yy, p.global_position.z) + n * 0.5
		var rr := PhysicsRayQueryParameters3D.create(o, o - n * 3.0)
		rr.exclude = [p.get_rid()]
		var h: Dictionary = esp.intersect_ray(rr)
		print("  y %.1f : %s" % [yy, ("mur à %.2f m, n=%s, %s" % [(h.position - o).length(), str(h.normal.snapped(Vector3.ONE*0.01)), h.collider.name]) if not h.is_empty() else "vide"])
	print("  toit au-dessus : ", p.get_world_3d().direct_space_state.intersect_ray(rq).get("position", "rien"))
	Input.action_press("move_forward")
	for i in 240:
		await physics_frame
		if p.suspendu and p._bond_t < 0.0:
			var bb: Dictionary = p._bord_devant(p.global_position, -p._rebord_n, p.SOUS_LES_MAINS + 0.5, p.SOUS_LES_MAINS + p.BOND_MAX)
			var vb: Vector3 = (bb.point + p._rebord_n * 0.32 - Vector3.UP * p.SOUS_LES_MAINS) if not bb.is_empty() else Vector3.ZERO
			print("  bord %.1f  suivant %s  place %s  trajet %s" % [p._rebord.y, ("%.1f" % bb.haut) if not bb.is_empty() else "aucun", p.place_libre(vb) if not bb.is_empty() else "-", p.trajet_libre(p.global_position, vb) if not bb.is_empty() else "-"])
	Input.action_release("move_forward")
	await frames(30)
	var y_fin: float = p._rebord.y if p.suspendu else p.global_position.y
	check(y_fin > y_dep + 2.8 * 3 - 0.5, "haut maintenu : il enchaîne les étages (%.1f m → %.1f m)" % [y_dep, y_fin])
	var y1: float = p._rebord.y
	Input.action_press("move_forward"); await frames(45); Input.action_release("move_forward")
	await frames(30)
	check(p._rebord.y > y1 + 0.4 or (not p.suspendu and p.global_position.y > y1 - 0.5), "haut maintenu : il monte (bord %.1f → %.1f, y %.1f)" % [y1, p._rebord.y, p.global_position.y])
	if not p.suspendu:
		p._accrocher(p._rebord, p._rebord_n)   # il est monté sur le balcon : on le raccroche pour tester le lâcher
		await frames(3)
	# lâcher
	Input.action_press("move_back"); await frames(3); Input.action_release("move_back")
	for i in 400:
		await physics_frame
		if p.is_on_floor():
			break
	check(not p.suspendu and p.is_on_floor(), "lâche et retombe (y %.1f, suspendu %s, sol %s)" % [p.global_position.y, p.suspendu, p.is_on_floor()])
	# La gouttière (descente d'eau) d'un angle : on s'y agrippe, on monte, on passe sur le toit.
	var meilleure: Node3D = null
	for m in root.get_tree().get_nodes_in_group("gouttiere"):
		var hauteur: float = float(m.get_meta("haut")) - m.global_position.y
		if hauteur > 10.0 and hauteur < 20.0:
			meilleure = m
			break
	check(meilleure != null, "une gouttière à grimper")
	if meilleure:
		var dehors: Vector3 = meilleure.get_meta("dehors")
		p.global_position = meilleure.global_position + dehors * 0.6 + Vector3.UP * 0.1
		p.velocity = Vector3.ZERO
		await frames(10)
		Input.action_press("jump"); await frames(2); Input.action_release("jump")
		await frames(3)
		check(p.gouttiere == meilleure, "agrippé à la gouttière")
		Input.action_press("move_forward")
		for i in 900:
			await physics_frame
			if p.gouttiere == null and not p._mantling:
				break
		Input.action_release("move_forward")
		await frames(10)
		var toit: float = meilleure.get_meta("haut")
		check(p.global_position.y > toit - 0.3, "en haut de la gouttière, sur le toit (Loums %.1f m, toit %.1f)" % [p.global_position.y, toit])
		p.global_position = meilleure.global_position + dehors * 0.6 + Vector3.UP * 0.1
		p.velocity = Vector3.ZERO
		await frames(15)
		Input.action_press("jump"); await frames(3); Input.action_release("jump")
		Input.action_press("move_forward"); await frames(180); Input.action_release("move_forward")
		check(p.gouttiere == meilleure, "grimpe à mi-hauteur pour lâcher dans le vide")
		var avant_lacher: float = p.global_position.y
		Input.action_press("jump"); await frames(40); Input.action_release("jump")
		check(p.gouttiere == null and p.global_position.y < avant_lacher - 1.0,
			"lâche la gouttière et tombe même si Espace reste appuyé")
	_fin()
func _fin() -> void:
	print("RESULT failures=", failures)
	quit(failures)
