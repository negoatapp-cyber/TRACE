extends SceneTree
## Vérifie le son : chaque action du jeu déclenche bien son bruit (le journal de l'autoload « Son » note
## tout ce qui est joué). On ne peut pas « écouter » en test : on contrôle que le bon son part au bon moment.
##   godot --headless --audio-driver Dummy --path . -s res://.tools/verify_son.gd

var failures := 0
var Son


func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func vu(nom: String, label: String) -> void:
	check(Son.journal.has(nom), "%s → %s" % [label, nom])


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Son = root.get_node("Son")
	Son.journaliser = true
	var nb := 0
	for k in Son.banque:
		nb += (Son.banque[k] as Array).size()
	check(Son.banque.size() >= 75, "banque chargée : %d sons, %d fichiers" % [Son.banque.size(), nb])
	check((Son.banque["roule_loop"][0] as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "les sons « _loop » bouclent")
	await ilot()
	await quartier()
	check(Son._manquants.is_empty(), "aucun son appelé n'est absent de la banque %s" % str(Son._manquants.keys()))
	print("Failures: ", failures)
	quit(0 if failures == 0 else 1)


func ilot() -> void:
	print("--- îlot gris : marche, grimpe, skate")
	var level = load("res://scenes/ilot_grey.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(30)
	var p = level.get_node("Player")
	var sk = p.skate
	Son.journal.clear()
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await frames(60)
	vu("saut_pied", "sauter")
	vu("atterri_pied", "retomber")
	Son.journal.clear()
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	vu("pas_dur", "marcher")
	Input.action_press("push")
	Input.action_press("move_forward")
	await frames(30)
	Input.action_release("push")
	Input.action_release("move_forward")
	await frames(20)
	# se hisser sur le ledge
	p._respawn()
	await frames(10)
	var ledge = level.get_node("Obstacles/Ledge")
	p.global_position = Vector3(-4.6, 0.1, 2.0)
	p.visual.rotation.y = PI * 0.5
	await frames(10)
	Son.journal.clear()
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await frames(60)
	check(p.climbs >= 1, "il se hisse sur le ledge")
	vu("hisse", "se hisser")
	p._respawn()
	await frames(10)
	Son.journal.clear()
	Input.action_press("toggle_board")
	await frames(2)
	Input.action_release("toggle_board")
	await frames(40)
	check(p.mode == p.Mode.SKATE, "il monte sur la planche")
	vu("planche_pose", "poser la planche")
	vu("planche_pied", "monter dessus")
	Son.journal.clear()
	Input.action_press("push")
	await frames(80)
	Input.action_release("push")
	vu("pousse", "pousser")
	vu("loop:roule_dur", "rouler sur le béton")
	Son.journal.clear()
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("kickflip")
	await frames(2)
	Input.action_release("kickflip")
	await frames(85)
	vu("ollie_pop", "ollie")
	vu("kickflip", "kickflip")
	check(Son.journal.has("atterri_leger") or Son.journal.has("atterri_dur"), "atterrissage de la planche")
	Son.journal.clear()
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("shove_it")
	await frames(2)
	Input.action_release("shove_it")
	await frames(85)
	vu("shoveit", "shove-it")
	for nom in ["Rail", "Ledge"]:
		var rail = level.get_node("Obstacles/" + nom)
		Son.journal.clear()
		p.global_position = rail.top_start() + Vector3(0.1, 0.2, -0.5)
		p.velocity = Vector3(0, -1, -5)
		sk.speed = 5.0
		sk.heading = 0.0
		sk.in_air = true
		sk.trick_t = 1.0
		Input.action_press("grind")
		await frames(25)
		Input.action_release("grind")
		await frames(5)
		vu("grind_debut", nom + " : accrocher")
		vu("loop:grind_beton" if nom == "Ledge" else "loop:grind_metal", nom + " : glisser")
		vu("grind_fin", nom + " : lâcher")
	# figure ratée : chute, planche qui roule seule
	p._respawn()
	await frames(10)
	p._set_mode(p.Mode.SKATE)
	p.global_position.y = 0.08
	p.velocity = Vector3(0, -2, 0)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	Son.journal.clear()
	p.global_position.y = 0.08
	p.velocity.y = -2.0
	sk.speed = 6.0
	sk.in_air = true
	sk.trick = "Kickflip"
	sk.trick_t = 0.0
	await frames(30)
	vu("chute", "chuter")
	vu("planche_chute", "la planche claque au sol")
	vu("loop:roule_planche", "la planche roule seule")
	await frames(110)   # la chute dure 1,6 s
	Son.journal.clear()
	p.global_position = p.board.global_position + Vector3(0.4, 0.1, 0)
	await frames(30)    # le temps de se poser au sol, à côté de la planche
	Son.journal.clear()
	Input.action_press("toggle_board")
	await frames(2)
	Input.action_release("toggle_board")
	await frames(30)
	vu("planche_ramasse", "ramasser la planche")
	vu("planche_range", "la ranger dans le dos")
	Son.journal.clear()
	Input.action_press("reset")
	await frames(3)
	Input.action_release("reset")
	await frames(3)
	vu("respawn", "revenir au départ")
	root.remove_child(level)
	level.free()
	await frames(5)


func quartier() -> void:
	print("--- quartier : sol, graffiti, habitants, scooter, ambiance")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(40)
	var p = level.get_node("Player")
	var q = level.get_node("Quartier")
	var g = level.get_node("Graffiti")
	var hab = level.get_node("Habitants")
	var tps = level.get_node("Temps")
	# le sol sous les pieds : il y a au moins du dur et de l'herbe dans le quartier
	var vus := {}
	for z in range(-200, 200, 7):
		for x in range(-120, 120, 7):
			vus[Son._surface(Vector3(x, 0, z))] = true
	check(vus.has("dur") and vus.has("herbe"), "le quartier a du dur et de l'herbe : %s" % str(vus.keys()))
	# ambiance
	await frames(30)
	Son.journal.clear()
	await frames(60)
	check(Son._boucles.has("amb_jour") and Son._boucles["amb_jour"].p.playing, "ambiance du jour → loop:amb_jour joue")
	tps.minutes = 6.5 * 60.0   # 23 h
	await frames(60)
	vu("loop:amb_nuit", "ambiance de nuit")
	tps.minutes = 60.0
	Son._amb_t = 0.0
	await frames(5)
	# habitants : pas et voix placés dans l'espace
	var gardien = null
	for h in hab.habitants:
		if h.role == "gardien":
			gardien = h
	var h0 = hab.habitants[0]
	p.global_position = h0.global_position + Vector3(2.5, 0.5, 0)
	p.velocity = Vector3.ZERO
	await frames(20)
	Son.journal.clear()
	await frames(240)
	vu("pas_dur", "les habitants marchent près de Loums")
	# graffiti (mode simple : Loums peint tout seul), face à la barre
	g.expert = false
	p.global_position = Vector3(-24.2, q.h(-24.2, -100) + 0.2, -100)
	p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(40)
	Son.journal.clear()
	g._cible = g._mur_devant()
	g._commencer("tag")
	await frames(120)
	vu("bombe_secoue", "secouer la bombe")
	vu("loop:spray", "le jet de peinture")
	await frames(150)
	check(g._trace == null, "le tag est posé")
	vu("graff_pose", "le tag est fini")
	# flop : deux couches
	Son.journal.clear()
	g._cible = g._mur_devant()
	g._commencer("flop")
	await frames(400)
	vu("etape_ok", "une couche finie, la suivante commence")
	vu("bombe_change", "il change de bombe")
	# bombe qui change, bombe vide
	await frames(60)
	Son.journal.clear()
	Input.action_press("graff_color")
	await frames(3)
	Input.action_release("graff_color")
	await frames(5)
	vu("bombe_change", "touche C : autre bombe")
	g.reserve[g.bombe] = 0.0
	await frames(5)
	Son.journal.clear()
	Input.action_press("graff")
	await frames(3)
	Input.action_release("graff")
	await frames(3)
	vu("bombe_vide", "bombe vide")
	# perche, rouleau
	g.reserve = [1.0, 1.0, 1.0, 1.0]
	g.pot = 1.0
	Son.journal.clear()
	g._cible = g._mur_devant()
	g._commencer("perche")
	await frames(60)
	vu("perche_deplie", "sortir la perche")
	g._interrompre()
	await frames(20)
	Son.journal.clear()
	g._cible = g._mur_devant()
	g._commencer("rouleau")
	await frames(90)
	vu("rouleau_trempe", "tremper le rouleau")
	vu("loop:rouleau", "passer le rouleau")
	g._interrompre()
	await frames(20)
	# le gardien voit Loums, puis le fait partir
	g.expert = true
	g._cible = g._mur_devant()
	g._commencer("piece")
	var vers: Vector3 = p.global_position + Vector3(8, 0, 2)
	gardien.global_position = Vector3(vers.x, q.h(vers.x, vers.z) + 0.3, vers.z)
	gardien.etat = "marche"
	gardien.rotation.y = atan2(-(p.global_position.x - vers.x), -(p.global_position.z - vers.z))
	Son.journal.clear()
	await frames(60)
	vu("vu", "quelqu'un le voit peindre")
	vu("voix_gardien", "le gardien dit quelque chose")
	await frames(240)
	vu("chasse", "le gardien le fait partir")
	g.expert = false
	await frames(10)
	# conteneur
	var cont = null
	for c in root.get_tree().get_nodes_in_group("conteneur"):
		cont = c
	if cont != null:
		p.global_position = cont.global_position + Vector3(0, 0.5, 2.5)
		await frames(20)
		Son.journal.clear()
		Input.action_press("fouiller")
		await frames(3)
		Input.action_release("fouiller")
		await frames(100)
		vu("fouille", "fouiller le conteneur")
		vu("bombes_pleines", "quatre bombes pleines")
	else:
		check(false, "un conteneur existe")
	# scooter
	var c = level.find_child("Conduite", true, false)
	check(c != null, "la conduite existe")
	if c != null:
		var sc = null
		for x in c.vehicules:
			if x.type == "scooter":
				sc = x
		p.global_position = sc.global_position + Vector3(1.2, 0.5, 0)
		await frames(20)
		Son.journal.clear()
		c._monter(sc)
		await frames(120)
		Input.action_press("move_forward")
		await frames(100)
		vu("bequille", "monter sur le scooter")
		vu("demarre_scooter", "démarrer")
		vu("loop:moteur_scooter", "le moteur tourne")
		Input.action_release("move_forward")
		await frames(10)
		c._descendre()
		await frames(10)
		vu("coupe_scooter", "couper le moteur")
	# la démolition de la tour
	Son.journal.clear()
	var Q = load("res://scripts/quartier_reel.gd")
	Q.demolies.append("Tour test")
	await frames(60)
	vu("demolition", "la tour tombe")
	Q.demolies.erase("Tour test")
	root.remove_child(level)
	level.free()
	await frames(5)
