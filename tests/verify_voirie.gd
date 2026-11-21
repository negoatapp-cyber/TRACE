extends SceneTree
## Rejoue la construction du quartier et détecte le relief traversant les chaussées.

func _initialize() -> void:
	call_deferred("verifier")


func verifier() -> void:
	var scene: Node = load("res://scenes/marseille_2013.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var quartier: Node = scene.get_node("Quartier")
	var voies := 0
	var triangles := 0
	var traverses := 0
	var max_traversee := 0.0
	var uv_invalides := 0
	var pires := []
	var total_bandes := 0
	for node in get_nodes_in_group("sol_voie"):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		voies += 1
		var tableaux := mi.mesh.surface_get_arrays(0)
		var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = tableaux[Mesh.ARRAY_TEX_UV]
		var bandes: int = mi.get_meta("bandes_transversales", 0)
		total_bandes += bandes
		if uv.size() != sommets.size():
			uv_invalides += 1
		elif bandes < 1 or sommets.size() % (6 * bandes) != 0:
			uv_invalides += 1
		else:
			var precedent := -1.0
			for k in range(0, sommets.size(), 6 * bandes):
				if uv[k].y + 0.001 < precedent or absf(uv[k].x) > 0.001 or absf(uv[k + 6 * bandes - 5].x - 1.0) > 0.001:
					uv_invalides += 1
					break
				precedent = uv[k].y
		for i in range(0, sommets.size(), 3):
			triangles += 1
			var a: Vector3 = mi.global_transform * sommets[i]
			var b: Vector3 = mi.global_transform * sommets[i + 1]
			var c: Vector3 = mi.global_transform * sommets[i + 2]
			for p: Vector3 in [(a + b + c) / 3.0, (a + b) * 0.5,
					(b + c) * 0.5, (c + a) * 0.5]:
				var delta: float = quartier.h(p.x, p.z) - p.y
				if delta > 0.03:
					traverses += 1
					max_traversee = maxf(max_traversee, delta)
					pires.append([delta, mi.get_meta("type", "?"), p.x, p.z])
	pires.sort_custom(func(a, b): return a[0] > b[0])
	print("PIRES : ", pires.slice(0, 12))
	print("VOIRIE : %d voies, %d bandes, %d triangles, %d traversées (>3 cm), max %.3f m, %d UV invalides" % [voies, total_bandes, triangles, traverses, max_traversee, uv_invalides])
	quit(1 if voies == 0 or uv_invalides > 0 or traverses > 0 else 0)
