extends SceneTree
## Vérifie le temps qui passe (J3) : l'horloge, la nuit, sauter au lendemain, les graffitis qui
## vieillissent, la permanence du décor de 2013 après rechargement.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	call_deferred("run")
func cypres() -> bool:
	for n in current_scene.find_children("*", "StaticBody3D", true, false):
		if str(n.name).contains("Cyprès B") or str(n.name).contains("Cypres B"):
			return true
	return false
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://temps.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	change_scene_to_file("res://scenes/lauriers.tscn")
	await frames(40)
	var t = current_scene.get_node("Temps")
	check(absf(t.heure() - 16.5) < 0.2 and t.jour() == 0 and t.date().year == 2013, "on commence le lundi 16 septembre 2013 vers 16 h 30 (%s)" % t.date_texte())
	var m0: float = t.minutes
	await frames(60)
	check(t.minutes > m0, "l'horloge avance (%.1f min)" % (t.minutes - m0))
	check(t.nuit() == 0.0, "l'après-midi : pas la nuit")
	var soleil_jour: float = current_scene.get_node("Soleil").light_energy
	t.minutes = (22.0 - 16.5) * 60.0
	await frames(3)
	check(t.nuit() > 0.99 and current_scene.get_node("Soleil").light_energy < soleil_jour * 0.5, "22 h : la nuit tombe, le soleil s'éteint (%.2f → %.2f)" % [soleil_jour, current_scene.get_node("Soleil").light_energy])
	t.avancer_jusqu_a(t.jour() + 1, 8.0)
	await frames(3)
	check(t.jour() == 1 and absf(t.heure() - 8.0) < 0.1, "N : au lendemain matin (%s)" % t.date_texte())
	# Un graffiti vu par le gardien est repeint en gris quelques jours après.
	var g = current_scene.get_node("Graffiti")
	var p = current_scene.get_node("Player"); var q = current_scene.get_node("Quartier")
	# Les lettrages photographiques sont privés. Un trait de test suffit pour dater la peinture.
	if g._texture("tag_1") == null:
		var guide := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
		guide.fill_rect(Rect2i(3, 6, 26, 2), Color.WHITE)
		g._textures["tag_1"] = ImageTexture.create_from_image(guide)
	g.expert = false
	p.global_position = Vector3(-23.4, q.h(-23.4, -100) + 0.2, -100); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(20)
	g._cible = g._mur_devant()
	g._commencer("tag", -1, 0)
	g.vu_par("gardien")
	check(g._trace != null, "un tag commence")
	for i in 600:
		await process_frame
		if g._trace == null:
			break
	if g.poses.is_empty():
		check(false, "le tag doit être enregistré")
		quit(failures)
		return
	var tag: Dictionary = g.poses[g.poses.size() - 1]
	check(int(tag.get("jour", -1)) == 1 and tag.get("temoins", []).has("gardien"), "le tag est daté et son témoin noté")
	t.avancer_jusqu_a(t.jour() + 4, 8.0)
	await frames(5)
	check(tag.has("efface"), "4 jours plus tard : repeint en gris (vu par le gardien)")
	check(cypres(), "la tour est présente au départ")
	t.avancer_jusqu_a(1300, 9.0)
	await frames(5)
	t._sauver()
	check(t.date().year == 2013 and cypres(), "le décor reste en 2013 après 1300 jours")
	reload_current_scene()
	await frames(40)
	t = current_scene.get_node("Temps")
	var scene_id := current_scene.get_instance_id()
	var touche := InputEventKey.new()
	touche.physical_keycode = KEY_T
	touche.pressed = true
	Input.parse_input_event(touche)
	await frames(10)
	check(t.jour() == 1300 and t.date().year == 2013 and cypres(), "ancienne sauvegarde chargée, âge conservé, tour présente")
	check(scene_id == current_scene.get_instance_id(), "T conserve la scène historique")
	print("RESULT failures=", failures)
	quit(failures)
