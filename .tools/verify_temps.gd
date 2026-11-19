extends SceneTree
## Vérifie le temps qui passe (J3) : l'horloge, la nuit, sauter au lendemain, les graffitis qui
## vieillissent, la tour Cyprès B démolie le 21 juillet 2016.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame
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
	check(absf(t.heure() - 16.5) < 0.2 and t.jour() == 0, "on commence le lundi 15 septembre 2014 vers 16 h 30 (%s)" % t.date_texte())
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
	g.expert = false
	p.global_position = Vector3(-24.2, q.h(-24.2, -100) + 0.2, -100); p.velocity = Vector3.ZERO
	p.visual.rotation.y = PI * 0.5
	await frames(20)
	g._cible = g._mur_devant()
	g._commencer("tag")
	g.vu_par("gardien")
	check(g._trace != null, "un tag commence")
	for i in 600:
		await process_frame
		if g._trace == null:
			break
	var tag: Dictionary = g.poses[g.poses.size() - 1]
	check(int(tag.get("jour", -1)) == 1 and tag.get("temoins", []).has("gardien"), "le tag est daté et son témoin noté")
	t.avancer_jusqu_a(t.jour() + 4, 8.0)
	await frames(5)
	check(tag.has("efface"), "4 jours plus tard : repeint en gris (vu par le gardien)")
	# La démolition : on saute au 22 juillet 2016.
	check(cypres(), "en 2014, la tour Cyprès B est là")
	var cible := Time.get_unix_time_from_datetime_dict({"year": 2016, "month": 7, "day": 22, "hour": 9, "minute": 0})
	t.minutes = float(cible - t._debut_unix) / 60.0
	await frames(60)
	t = current_scene.get_node("Temps")
	check(not cypres() and t.date().year == 2016, "le 22 juillet 2016, la tour Cyprès B n'est plus là (%s)" % t.date_texte())
	# on remet tout en ordre pour les autres vérifications
	load("res://scripts/quartier_reel.gd").demolies.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://temps.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graffitis.json"))
	print("RESULT failures=", failures)
	quit(failures)
