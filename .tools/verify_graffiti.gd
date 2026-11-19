extends SceneTree
## Vérifie le graffiti : face à la grande barre, un tag, un flop, une pièce.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
## Simule la main du joueur. bien = suit le tag ligne par ligne en levant la bombe entre les traits ;
## sinon gribouille au hasard sur toute la zone.
func tracer(t, bien: bool) -> Dictionary:
	var w: int = t.guide.get_width()
	var h: int = t.guide.get_height()
	if bien:
		for y in range(4, h, 9):
			var xs := range(0, w, 7) if (y / 9) % 2 == 0 else range(w - 1, -1, -7)
			var precedent := -100
			for x in xs:
				if t.guide.get_pixel(x, y).a > 0.5:
					if absi(x - precedent) > 8:
						t.appuye = false
						t.peindre(1.0 / 60.0)
					t.curseur = Vector2(x, y)
					t.appuye = true
					t.peindre(1.0 / 60.0)
					precedent = x
			t.appuye = false
			t.peindre(1.0 / 60.0)
	else:
		seed(7)
		t.appuye = true
		for i in 400:
			t.curseur = Vector2(randf() * w, randf() * h)
			t.peindre(1.0 / 60.0)
		t.appuye = false
	await process_frame
	return t.qualite()
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(40)
	var p = level.get_node("Player")
	var q = level.get_node("Quartier")
	var g = level.get_node("Graffiti")
	# au pied de la façade est de la barre, tourné vers elle (vers l'ouest)
	p.global_position = Vector3(-24.2, q.h(-24.2, -100) + 0.2, -100); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(40)
	check(not g._mur_devant().is_empty(), "un mur est détecté devant le personnage")
	# Tag tracé à la main : appui bref sur G.
	Input.action_press("graff"); await frames(8); Input.action_release("graff"); await frames(5)
	var t = g._trace
	check(t != null, "appui bref : le tag est prêt à être tracé")
	if t:
		t.camera = null
		t.set_process(false)
		var bon := await tracer(t, true)
		check(bon.couverture > 0.65 and bon.debordement < 0.15 and bon.note > 0.45, "trait suivi : %d %% couvert, %d %% de débord, %s" % [int(bon.couverture * 100), int(bon.debordement * 100), bon.mot])
		# Rester immobile fait couler la peinture.
		t.curseur = Vector2(200, 60); t.appuye = true
		for i in 70: t.peindre(1.0 / 60.0)
		t.appuye = false
		for i in 60: t.peindre(1.0 / 60.0)
		check(t.qualite().coulures > 0, "bombe immobile : la peinture coule (%d coulures)" % t.qualite().coulures)
		g._finir_trace(t.peinture, t.qualite())
		await frames(5)
		var dernier: Dictionary = g.poses[g.poses.size() - 1]
		check(g._trace == null and dernier.t == "tag" and FileAccess.file_exists(dernier.img), "tag tracé posé et sauvegardé (note %.2f)" % dernier.q)
		check(p.is_physics_processing(), "Loums reprend la main")
	# Un gribouillis au hasard donne un mauvais tag.
	p.global_position.z -= 4.0
	await frames(20)
	Input.action_press("graff"); await frames(8); Input.action_release("graff"); await frames(5)
	t = g._trace
	if t:
		t.camera = null
		t.set_process(false)
		var mauvais := await tracer(t, false)
		check(mauvais.note < 0.35, "gribouillis : note %.2f (%s)" % [mauvais.note, mauvais.mot])
		t.annule.emit()
		await frames(3)
		check(g._trace == null, "Échap annule le tracé")
	# Flop : maintenir ~1,3 s, puis fond balayé et contour tracé.
	g.reserve = [1.0, 1.0, 1.0, 1.0]
	p.global_position.z -= 5.0
	await frames(20)
	Input.action_press("graff"); await frames(80); Input.action_release("graff"); await frames(5)
	check(g._trace != null and g._trace_g.get("t") == "flop", "maintenir ~1 s : un flop commence")
	if g._trace:
		for etape in ["fond", "contour"]:
			t = g._trace
			t.camera = null
			t.set_process(false)
			var qf: Dictionary = await tracer(t, true)
			check(qf.couverture > 0.5, "flop, %s : %d %% couvert" % [etape, int(qf.couverture * 100)])
			g._etape_finie(t.peinture, t.qualite())
			await frames(3)
		var f: Dictionary = g.poses[g.poses.size() - 1]
		check(g._trace == null and f.t == "flop" and f.fini and f.imgs.size() == 2, "flop posé, deux couches enregistrées")
		check(g.get_node_or_null("Graff_flop") != null or g.compte.flop >= 1, "flop dessiné au mur")
	# Pièce : maintenir ~2,8 s ; on fait le fond, on s'arrête, on revient la finir.
	g.reserve = [1.0, 1.0, 1.0, 1.0]
	p.global_position = Vector3(-24.8, q.h(-24.8, -72) + 0.2, -72); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(30)
	Input.action_press("graff"); await frames(170); Input.action_release("graff"); await frames(5)
	check(g._trace != null and g._trace_g.get("t") == "piece", "maintenir ~2,6 s : une pièce commence")
	if g._trace:
		t = g._trace
		t.camera = null
		t.set_process(false)
		await tracer(t, true)
		g._etape_finie(t.peinture, t.qualite())
		await frames(3)
		g._trace.annule.emit()
		await frames(3)
		var pc: Dictionary = g.poses[g.poses.size() - 1]
		check(g._trace == null and pc.t == "piece" and not pc.fini and int(pc.e) == 1, "pièce interrompue après le fond (étape %d)" % int(pc.get("e", -1)))
		var nb_avant: int = g.poses.size()
		p.global_position = Vector3(-24.8, q.h(-24.8, -72) + 0.2, -72); p.visual.rotation.y = PI * 0.5
		await frames(10)
		Input.action_press("graff"); await frames(6); Input.action_release("graff"); await frames(5)
		check(g._trace != null and g._etape_i == 1, "appui bref devant la pièce : on reprend au contour")
		while g._trace:
			t = g._trace
			t.camera = null
			t.set_process(false)
			if t.mode == "taper":
				# les lights : taper chaque cible quand elle s'allume
				for i in 20:
					if t.fini_de_taper():
						break
					t.curseur = t._cibles[t._cible_i][0]
					t.appuye = true; t.peindre(1.0 / 60.0)
					t.appuye = false; t.peindre(1.0 / 60.0)
				check(t.qualite().note > 0.9, "lights tapées en rythme : %d %%" % int(t.qualite().note * 100))
			else:
				await tracer(t, true)
			g._etape_finie(t.peinture, t.qualite())
			await frames(3)
		pc = g.poses[g.poses.size() - 1]
		check(g.poses.size() == nb_avant and pc.fini and pc.imgs.size() == 5, "pièce reprise et finie : %d couches, note %.2f" % [pc.imgs.size(), float(pc.get("q", 0))])
	var nb: int = g.poses.size()
	Input.action_press("graff"); await frames(40); Input.action_release("graff"); await frames(5)
	check(g.poses.size() == nb and g._trace == null, "un appui moyen (ni bref ni flop) ne pose rien")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	print("RESULT failures=", failures)
	quit(failures)
