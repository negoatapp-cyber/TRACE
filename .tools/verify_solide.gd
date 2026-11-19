extends SceneTree
## Vérifie que le décor est solide : on ne traverse ni les véhicules ni le mobilier.
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
	var sp = p.get_world_3d().direct_space_state
	# 1. Chaque objet du décor a une collision : un rayon horizontal tiré vers lui le touche.
	for groupe in ["vehicule", "voiture", "epave", "mobilier", "banc", "arbre", "conteneur", "muret", "rail"]:
		var objets: Array = root.get_tree().get_nodes_in_group(groupe)
		var touches := 0
		var essais := 0
		var rate := ""
		for o in objets.slice(0, 12):
			var n3 := o as Node3D
			if n3 == null:
				continue
			essais += 1
			var c := n3.global_position
			var sol: float = q.h(c.x, c.z)
			var ok := false
			for hh in [0.3, 0.6, 0.9]:
				for dir in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0.7, 0, 0.7)]:
					var de: Vector3 = Vector3(c.x, sol + hh, c.z) + dir * 3.0
					var ray := PhysicsRayQueryParameters3D.create(de, de - (dir as Vector3) * 6.0)
					ray.exclude = [p.get_rid()]
					var hit = sp.intersect_ray(ray)
					if not hit.is_empty() and Vector2(hit.position.x - c.x, hit.position.z - c.z).length() < 3.0:
						ok = true
			if ok:
				touches += 1
			elif rate == "":
				rate = str(n3.name)
		check(essais == 0 or touches == essais, "%s : %d/%d solides%s" % [groupe, touches, essais, (" (ex. " + rate + ")") if rate != "" else ""])
	# 2. Loums ne traverse pas un scooter ni une voiture.
	var c = level.find_child("Conduite", true, false)
	for type in ["scooter", "voiture"]:
		var v = null
		for x in c.vehicules:
			if x.type == type:
				v = x; break
		if v == null:
			continue
		var cote: Vector3 = (v.avant() as Vector3).cross(Vector3.UP).normalized()
		p.global_position = v.global_position + cote * 3.0 + Vector3.UP * 0.2
		p.velocity = Vector3.ZERO
		await frames(10)
		for i in 90:
			p.velocity.x = -cote.x * 4.0
			p.velocity.z = -cote.z * 4.0
			p.move_and_slide()
			await physics_frame
		var d: float = Vector2(p.global_position.x - v.global_position.x, p.global_position.z - v.global_position.z).length()
		check(d > 0.5, "on bute contre le %s (reste à %.2f m du centre)" % [type, d])
	# 3. Roue arrière : Loums bascule avec le scooter.
	var sc = null
	for x in c.vehicules:
		if x.type == "scooter":
			sc = x; break
	if sc:
		p.global_position = sc.global_position + Vector3(1.2, 0.2, 0)
		await frames(5)
		c._monter(sc)
		await frames(5)
		sc.cabre = 0.5
		c._poser_modele(sc)
		await process_frame
		await process_frame
		var perso: Node3D = p.get_node("Visual/Personnage")
		var incline: float = perso.global_transform.basis.y.angle_to(Vector3.UP)
		check(incline > 0.3, "roue arrière : Loums bascule avec le scooter (%.0f°)" % rad_to_deg(incline))
		sc.cabre = 0.0
		c._descendre()
	print("RESULT failures=", failures)
	quit(failures)
