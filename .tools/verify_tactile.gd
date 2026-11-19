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
	check(noms() == ["saut", "courir", "planche", "reset", "demain"], "à pied, loin de tout : %s" % str(noms()))
	# au pied de l'échafaudage, face au premier plateau bleu : GRIMPER
	var toits = level.find_child("AccesToits", true, false)
	if toits:
		var a: Array = toits.acces[0]
		p.global_position = a[1] + Vector3.UP * 0.1
		p.visual.rotation.y = atan2((a[3] as Vector3).x, (a[3] as Vector3).z)
		await frames(15)
		check("grimper" in noms(), "face à un rebord : GRIMPER à la place de SAUT %s" % str(noms()))
	p.global_position = Vector3(-24.2, q.h(-24.2, -100) + 0.2, -100); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(30)
	check("graff" in noms(), "devant un mur : GRAFF apparaît %s" % str(noms()))
	t._commande("menu")
	await frames(3)
	check("tag" in noms() and "flop" in noms() and "piece" in noms() and not ("saut" in noms()), "GRAFF ouvre ses options %s" % str(noms()))
	t._commande("tag")
	await frames(3)
	check(g._trace != null and noms().has("poser") and noms().has("arret"), "TAG : on peint, boutons SUITE et ARRÊT %s" % str(noms()))
	g._trace.annule.emit()
	await frames(5)
	p._set_mode(1)
	await frames(5)
	check("ollie" in noms() and "flip" in noms() and not ("graff" in noms()), "en skate : les figures %s" % str(noms()))
	print("RESULT failures=", failures)
	quit(failures)
