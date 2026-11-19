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
	check(hab.habitants.size() >= 10, "des habitants dans le quartier (%d)" % hab.habitants.size())
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
	check(bougent >= 5, "ils marchent (%d ont bougé)" % bougent)
	check(tombes == 0, "aucun ne passe sous le sol (%d)" % tombes)
	# Le gardien voit Loums peindre et vient le faire partir.
	var gardien = null
	for h in hab.habitants:
		if h.role == "gardien":
			gardien = h
	g.expert = true   # le tracé reste ouvert tant qu'on ne pose pas
	p.global_position = Vector3(-24.2, q.h(-24.2, -100) + 0.2, -100); p.velocity = Vector3.ZERO
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
