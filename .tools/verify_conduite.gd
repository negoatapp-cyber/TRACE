extends SceneTree
## Vérifie la conduite du scooter sur une grande piste plate (sol, rampe, mur) :
## vitesse, dérapage, inclinaison, roue arrière qui fait racler la bavette, saut, chute contre un mur,
## scooter couché puis relevé.
##   godot --headless --audio-driver Dummy --path . -s res://.tools/verify_conduite.gd

var failures := 0
var c
var p
var sc


func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func boite(parent: Node, taille: Vector3, ou: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	b.position = ou
	b.rotation = rot
	return b


func lacher() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "push"]:
		Input.action_release(a)


func remettre(ou: Vector3, cap: float) -> void:
	lacher()
	sc.global_position = ou
	sc.cap = cap
	sc.rotation.y = cap
	sc.vitesse = 0.0
	sc.lateral = 0.0
	sc.velocity = Vector3.ZERO
	sc.cabre = 0.0
	sc.cabre_v = 0.0
	await frames(10)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var level := Node3D.new()
	level.name = "Piste"
	root.add_child(level)
	current_scene = level
	boite(level, Vector3(800, 1, 800), Vector3(0, -0.5, 0))
	boite(level, Vector3(4, 0.4, 6), Vector3(0, 0.55, 140), Vector3(deg_to_rad(-14), 0, 0))  # tremplin
	boite(level, Vector3(10, 4, 1), Vector3(-200, 2, 60))   # mur
	p = load("res://scenes/player.tscn").instantiate()
	p.name = "Player"
	level.add_child(p)
	p.global_position = Vector3(2, 1, 0)
	var fixe := StaticBody3D.new()
	fixe.add_to_group("vehicule")
	fixe.set_meta("type", "scooter")
	var m: Node3D = (load("res://assets/decor/scooter.glb") as PackedScene).instantiate()
	fixe.add_child(m)
	fixe.set_meta("modele", m)
	level.add_child(fixe)
	fixe.global_position = Vector3(0, 0, 0)
	c = Node.new()
	c.set_script(load("res://scripts/conduite.gd"))
	c.name = "Conduite"
	level.add_child(c)
	await frames(30)
	for v in c.vehicules:
		if v.type == "scooter":
			sc = v
	check(sc != null, "le scooter est conduisible")
	check(sc.direction != null and sc.axe_ar != null and sc.bavette != null, "guidon, roues et bavette articulés")
	var son = root.get_node_or_null("Son")
	if son:
		son.journaliser = true
	c._monter(sc)
	await frames(5)

	print("--- vitesse")
	Input.action_press("move_forward")
	var t50 := -1.0
	var t := 0.0
	while t < 12.0:
		await physics_frame
		t += 1.0 / 60.0
		if t50 < 0.0 and sc.vitesse * 3.6 >= 50.0:
			t50 = t
	var kmh: float = sc.vitesse * 3.6
	print("    0 → 50 km/h en %.1f s ; vitesse au bout de 12 s : %d km/h" % [t50, kmh])
	check(t50 > 0.0 and t50 < 3.0, "ça arrache : 50 km/h en moins de 3 s")
	check(kmh > 75.0 and kmh < 100.0, "vitesse de pointe entre 75 et 100 km/h (%d)" % kmh)
	check(c._lignes.force > 0.3, "traits de vitesse affichés à pleine vitesse")
	var cam: Camera3D = c._camera()
	check(cam.fov > 80.0, "l'angle de vue s'ouvre avec la vitesse (%.0f°)" % cam.fov)
	check(sc.axe_ar.rotation.x != 0.0, "les roues tournent")
	if son:
		check(son.journal.has("loop:moteur_scooter"), "son : le moteur tourne")
		check(son.journal.has("loop:vent"), "son : le vent à pleine vitesse")

	print("--- virage et inclinaison")
	Input.action_press("move_left")
	await frames(60)
	check(sc.penche > 0.2, "penche dans le virage (%.2f rad)" % sc.penche)
	check(absf(sc.braquage) > 0.05, "le guidon braque")
	var lat_normal: float = absf(sc.lateral)
	print("--- dérapage")
	Input.action_press("push")
	await frames(40)
	check(sc.derive > 0.8, "dérapage engagé")
	check(absf(sc.lateral) > 2.0 and absf(sc.lateral) > lat_normal * 2.0, "l'arrière glisse de côté (%.1f m/s, %.1f sans dérapage)" % [absf(sc.lateral), lat_normal])
	Input.action_release("push")
	Input.action_release("move_left")
	await frames(60)
	check(absf(sc.lateral) < 1.0, "l'adhérence revient (%.1f m/s)" % absf(sc.lateral))

	print("--- roue arrière et bavette")
	await remettre(Vector3(0, 0.05, -300), 0.0)
	c.actuel = sc
	Input.action_press("move_forward")
	await frames(90)
	Input.action_press("jump")
	var max_cabre := 0.0
	var a_racle := false
	for i in 120:
		await physics_frame
		max_cabre = maxf(max_cabre, sc.cabre)
		a_racle = a_racle or sc.racle > 0.0
	check(max_cabre > 0.5, "le scooter se cabre (%.0f°)" % rad_to_deg(max_cabre))
	check(a_racle, "la bavette racle le bitume")
	if son:
		check(son.journal.has("loop:racle"), "son : la bavette racle")
	check(c.roue_arriere > 1.5, "roue arrière tenue (%.1f s)" % c.roue_arriere)
	check(c.actuel == sc, "pas de chute en dosant normalement")
	Input.action_release("jump")
	await frames(90)
	check(sc.cabre < 0.05, "la roue avant redescend")

	print("--- saut")
	await remettre(Vector3(0, 0.05, 100), 0.0)
	Input.action_press("move_forward")
	var vol := 0.0
	for i in 400:
		await physics_frame
		if not sc.is_on_floor() and sc.global_position.z > 140.0:
			vol += 1.0 / 60.0
		if sc.global_position.z > 175.0:
			break
	check(vol > 0.3, "décolle du tremplin (%.2f s en l'air)" % vol)
	check(c.actuel == sc, "réception propre")
	lacher()

	print("--- chute dans le mur")
	await remettre(Vector3(-200, 0.05, 20), 0.0)
	Input.action_press("move_forward")
	for i in 400:
		await physics_frame
		if c.actuel == null:
			break
	lacher()
	check(c.actuel == null and sc.au_sol != null, "à pleine vitesse dans le mur : chute")
	check(p.chute_t >= 0.0, "Loums est éjecté et tombe")
	await frames(200)
	var rb: RigidBody3D = sc.au_sol
	var debout: float = rb.global_basis.y.dot(Vector3.UP) if rb else 1.0
	print("    scooter au sol, axe vertical à %.0f°" % rad_to_deg(acos(clampf(debout, -1, 1))))
	check(rb != null and rb.global_position.y < 1.0, "le scooter retombe au sol (pesanteur)")
	check(debout < 0.6, "il finit couché sur le flanc")
	p.global_position = rb.global_position + Vector3(1.0, 0.3, 0)
	p.chute_t = -1.0
	await frames(30)
	check(c._vehicule_proche() == sc, "le scooter couché se relève avec V")
	c._relever(sc)
	await frames(60)
	check(sc.au_sol == null and c.actuel == sc, "relevé, Loums repart dessus")
	check(sc.modele.global_basis.y.dot(Vector3.UP) > 0.95, "debout sur ses roues")

	print("--- passer sur le dos")
	await remettre(Vector3(100, 0.05, -300), 0.0)
	c.actuel = sc
	Input.action_press("move_forward")
	await frames(120)
	Input.action_press("jump")
	for i in 600:
		await physics_frame
		if c.actuel == null:
			break
	lacher()
	check(c.actuel == null and sc.au_sol != null, "plein gaz en roue arrière trop longtemps : passe sur le dos")
	print("Failures: ", failures)
	quit(0 if failures == 0 else 1)
