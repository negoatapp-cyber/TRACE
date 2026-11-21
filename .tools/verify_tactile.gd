extends SceneTree
## Vérifie les boutons du téléphone : seuls ceux utiles à l'instant s'affichent.
## Lancer avec `-- --touch`.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func noms() -> Array:
	var t = root.get_node("TouchControls")
	return t._visibles.map(func(v): return v[0])
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var t = root.get_node("TouchControls")
	check(t.actif, "contrôles tactiles actifs (--touch)")
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(40)
	var p = level.get_node("Player"); var q = level.get_node("Quartier"); var g = level.get_node("Graffiti")
	p.global_position = Vector3(57, q.h(57, -45) + 0.2, -45)
	await frames(20)
	check(noms() == ["saut", "planche", "reset", "demain"], "à pied, loin de tout (pas de COURIR : joystick à fond) : %s" % str(noms()))
	# au pied de l'échafaudage, face au premier plateau bleu : GRIMPER
	var toits = level.find_child("AccesToits", true, false)
	if toits:
		var a: Array = toits.acces[0]
		p.global_position = a[1] + Vector3.UP * 0.1
		p.visual.rotation.y = atan2((a[3] as Vector3).x, (a[3] as Vector3).z)
		await frames(15)
		check("grimper" in noms(), "face à un rebord : GRIMPER à la place de SAUT %s" % str(noms()))
	p.global_position = Vector3(-23.4, q.h(-23.4, -100) + 0.2, -100); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(30)
	check("graff" in noms(), "devant un mur : GRAFF apparaît %s" % str(noms()))
	t._commande("menu")
	await frames(3)
	check(g.choix_ouvert() and paused and not t.visible, "GRAFF ouvre le choix en grand (boutons du téléphone cachés, jeu en pause)")
	# toucher une vignette (Godot convertit le toucher en clic ; en test sans écran, on appuie sur le bouton)
	var carte: Button = g.choix._cartes.get_child(1)
	carte.pressed.emit()
	await frames(3)
	check(not g.choix_ouvert() and not paused and t.visible and g._trace != null and int(g._trace_g.get("v", -1)) == 1, "toucher la 2e vignette : le tag n°2 commence")
	check(g._trace != null and noms().has("poser") and noms().has("arret"), "TAG : on peint, boutons SUITE et ARRÊT %s" % str(noms()))
	g._trace.annule.emit()
	await frames(5)
	p._set_mode(1)
	await frames(5)
	check(noms().slice(0, 2) == ["ollie", "pied"] and not ("pousser" in noms()) and not ("flip" in noms()), "en skate au sol : OLLIE et DESCENDRE seulement %s" % str(noms()))
	p.skate.charge = 0.0
	await frames(2)
	check("flip" in noms() and "shove" in noms() and not ("pied" in noms()), "en préparant l'ollie : FLIP et SHOVE apparaissent %s" % str(noms()))
	p.skate.charge = -1.0
	print("RESULT failures=", failures)
	quit(failures)
