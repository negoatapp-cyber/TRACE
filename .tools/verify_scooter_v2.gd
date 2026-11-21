extends SceneTree
## Scooter (21.11, v2) : démarrage boosté, étincelles de bavette, stoppie et chute vers l'avant.
var failures := 0
var c
var p
var sc
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func lacher() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump"]: Input.action_release(a)
func remettre(ou: Vector3) -> void:
	lacher()
	if c.actuel == null:
		p.global_position = ou + Vector3(1.0, 0.2, 0)
		p.chute_t = -1.0
		await frames(20)
		sc.global_position = ou
		c._monter(sc)
	sc.global_position = ou
	sc.cap = 0.0
	sc.rotation.y = 0.0
	sc.vitesse = 0.0
	sc.velocity = Vector3.ZERO
	sc.cabre = 0.0; sc.cabre_v = 0.0; sc.pique = 0.0; sc.pique_v = 0.0
	await frames(10)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new(); sh.size = Vector3(800, 1, 800); cs.shape = sh; b.add_child(cs)
	level.add_child(b); b.position = Vector3(0, -0.5, 0)
	p = load("res://scenes/player.tscn").instantiate(); p.name = "Player"; level.add_child(p)
	p.global_position = Vector3(2, 1, -300)
	var fixe := StaticBody3D.new(); fixe.add_to_group("vehicule"); fixe.set_meta("type", "scooter")
	var m: Node3D = (load("res://assets/decor/scooter.glb") as PackedScene).instantiate(); fixe.add_child(m); fixe.set_meta("modele", m)
	level.add_child(fixe); fixe.global_position = Vector3(0, 0, -300)
	c = Node.new(); c.set_script(load("res://scripts/conduite.gd")); c.name = "Conduite"; level.add_child(c)
	await frames(30)
	for v in c.vehicules: if v.type == "scooter": sc = v
	c._monter(sc)
	await frames(5)
	print("--- démarrage")
	Input.action_press("move_forward")
	var marks := {}
	var t := 0.0
	while t < 20.0:
		await physics_frame
		t += 1.0 / 60.0
		for k in [10, 30, 50, 70, 80]:
			if not marks.has(k) and sc.vitesse * 3.6 >= k: marks[k] = snappedf(t, 0.01)
		if t > 0.3 and t < 0.32: print("    après 0,3 s : %d km/h" % roundi(sc.vitesse * 3.6))
	print("    temps pour atteindre (km/h → s) : ", marks, " ; au bout de 20 s : %d km/h" % roundi(sc.vitesse * 3.6))
	check(marks.get(30, 99.0) < 1.0, "30 km/h en moins d'une seconde")
	check(marks.get(50, 99.0) < 2.6, "50 km/h en moins de 2,6 s")
	check(not marks.has(80) or marks[80] > 8.0, "les derniers km/h sont durs à aller chercher")
	check(sc.vitesse * 3.6 < 92.0, "jamais au-delà de 90 km/h")
	print("--- roue arrière et étincelles")
	await remettre(Vector3(0, 0.05, -300))
	Input.action_press("move_forward")
	await frames(70)
	Input.action_press("jump")
	var vu_racle_bas := false
	var vu_racle := false
	var max_cabre := 0.0
	for i in 600:
		await physics_frame
		if c.actuel == null: break
		max_cabre = maxf(max_cabre, sc.cabre)
		if sc.racle > 0.0:
			vu_racle = true
			if sc.cabre < c.CABRE_RACLE: vu_racle_bas = true
	print("    cabre max %.0f°" % rad_to_deg(max_cabre))
	check(vu_racle, "étincelles quand la bavette touche (entre l'équilibre et la chute)")
	check(not vu_racle_bas, "pas d'étincelles au point d'équilibre")
	check(c.actuel == null, "plein gaz trop longtemps : chute en arrière")
	print("--- pas d'étincelles en roue arrière dosée")
	await remettre(Vector3(30, 0.05, -300))
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	Input.action_press("jump")
	var racle_dose := false
	for i in 120:
		await physics_frame
		racle_dose = racle_dose or sc.racle > 0.0
	check(sc.cabre > 0.3 and not racle_dose and c.actuel == sc, "roue arrière tenue sans gaz : équilibre, pas d'étincelles (%.0f°)" % rad_to_deg(sc.cabre))
	print("--- stoppie à vitesse modérée")
	await remettre(Vector3(60, 0.05, -300))
	Input.action_press("move_forward")
	while sc.vitesse < 7.0: await physics_frame
	Input.action_release("move_forward")
	Input.action_press("move_back")
	Input.action_press("jump")
	var max_pique := 0.0
	for i in 120:
		await physics_frame
		if c.actuel == null: break
		max_pique = maxf(max_pique, sc.pique)
	lacher()
	print("    bascule max %.0f°, vitesse finale %d km/h" % [rad_to_deg(max_pique), roundi(sc.vitesse * 3.6)])
	check(max_pique > 0.3, "l'arrière se lève au frein avant")
	check(c.actuel == sc, "à ~25 km/h, le stoppie se tient sans chute")
	await frames(60)
	check(sc.pique < 0.05, "l'arrière retombe")
	print("--- frein avant à pleine vitesse")
	await remettre(Vector3(90, 0.05, -300))
	Input.action_press("move_forward")
	while sc.vitesse < 17.0: await physics_frame
	Input.action_release("move_forward")
	Input.action_press("move_back")
	Input.action_press("jump")
	for i in 180:
		await physics_frame
		if c.actuel == null: break
	lacher()
	check(c.actuel == null, "trop vite au frein avant : par-dessus le guidon")
	check(p.chute_t >= 0.0 and p.velocity.dot(Vector3(0, 0, 1)) > 1.0, "Loums est projeté vers l'avant")
	print("--- freinage normal (S seul)")
	await remettre(Vector3(120, 0.05, -300))
	Input.action_press("move_forward")
	while sc.vitesse < 15.0: await physics_frame
	Input.action_release("move_forward")
	Input.action_press("move_back")
	var piq := 0.0
	for i in 120:
		await physics_frame
		piq = maxf(piq, sc.pique)
	lacher()
	check(piq == 0.0 and c.actuel == sc and sc.vitesse < 0.5, "S seul freine sans lever l'arrière")
	print("Failures: ", failures)
	quit(0 if failures == 0 else 1)
