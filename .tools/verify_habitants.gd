extends SceneTree
## Vérifie les habitants (J2) : ils marchent, ils voient Loums graffer, le gardien vient le faire partir.
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
	var hab = level.get_node("Habitants")
	var p = level.get_node("Player"); var q = level.get_node("Quartier"); var g = level.get_node("Graffiti")
	check(hab.habitants.size() >= 3 and hab.habitants.size() <= 4, "seulement les habitants utiles : gardien, voisine, patron (%d)" % hab.habitants.size())
	var depart := {}
	for h in hab.habitants:
		depart[h] = h.global_position
	await frames(240)
	var bougent := 0
	var tombes := 0
	for h in hab.habitants:
		if h.global_position.distance_to(depart[h]) > 1.5:
			bougent += 1
		if h.global_position.y < q.h(h.global_position.x, h.global_position.z) - 2.0:
			tombes += 1
	check(bougent >= 1, "le gardien fait sa ronde (%d ont bougé)" % bougent)
	check(tombes == 0, "aucun ne passe sous le sol (%d)" % tombes)
	# Le gardien voit Loums peindre et vient le faire partir.
	var gardien = null
	var voisine = null
	for h in hab.habitants:
		if h.role == "gardien":
			gardien = h
		if h.role == "voisine":
			voisine = h
	# sa ronde ne traverse aucun mur : rayon à hauteur de poitrine entre chaque point
	var espace := (level as Node3D).get_world_3d().direct_space_state
	var murs := 0
	for k in range(1, gardien.route.size()):
		var a: Vector3 = gardien.route[k - 1] + Vector3.UP * 1.2
		var b: Vector3 = gardien.route[k] + Vector3.UP * 1.2
		var rq := PhysicsRayQueryParameters3D.create(a, b)
		rq.exclude = [gardien.get_rid(), p.get_rid()]
		var hit := espace.intersect_ray(rq)
		if not hit.is_empty() and not (hit.collider is CharacterBody3D):
			murs += 1
			print("   mur sur la ronde : ", hit.collider.name, " ", hit.position)
	check(murs == 0, "la ronde du gardien ne traverse aucun mur")
	check(voisine.etat == "reste" and voisine.global_position.distance_to(voisine.route[0]) < 1.0, "la voisine reste à son poste")
	# il parcourt vraiment sa ronde (il n'est pas coincé contre un mur)
	var bout := 0.0
	var d0: Vector3 = gardien.global_position
	for i in 1200:
		await physics_frame
		bout = maxf(bout, gardien.global_position.distance_to(d0))
	check(bout > 15.0, "le gardien avance le long de la barre (%.0f m parcourus)" % bout)
	g.expert = true   # le tracé reste ouvert tant qu'on ne pose pas
	p.global_position = Vector3(-23.4, q.h(-23.4, -100) + 0.2, -100); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(20)
	g._cible = g._mur_devant()
	g._commencer("piece")
	var vers: Vector3 = p.global_position + Vector3(8, 0, 2)
	gardien.global_position = Vector3(vers.x, q.h(vers.x, vers.z) + 0.3, vers.z)
	gardien.etat = "marche"
	gardien.rotation.y = atan2(-(p.global_position.x - vers.x), -(p.global_position.z - vers.z))
	await frames(30)
	check(gardien.a_vu and gardien.etat == "va_vers", "le gardien voit Loums peindre et vient vers lui")
	check(g._trace_g.get("temoins", []).has("gardien"), "le témoin est noté dans le graffiti")
	for i in 600:
		await physics_frame
		if g._trace == null:
			break
	check(g._trace == null and g._message.contains("fait partir"), "le gardien le fait partir (%s)" % g._message)
	check(hab.reputation.gardien < 0, "le gardien s'en souvient (%d)" % hab.reputation.gardien)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	print("RESULT failures=", failures)
	quit(failures)
