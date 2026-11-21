extends SceneTree
## Captures d'écran du quartier pour juger le rendu. Usage :
##   godot --path . -s .tools/capture.gd -- <dossier_sortie> [bd|brut]
var sortie := "user://"
var args_mode := "bd"
var filtre := PackedStringArray()  # noms de vues à garder (toutes si vide)
var heure_capture := -1.0  # heure du jeu imposée (ex. 18.3), -1 = l'heure de départ
var scene_capture := "res://scenes/lauriers.tscn"
var echecs := 0
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: sortie = args[0]
	if args.size() > 1: args_mode = args[1]
	if args.size() > 2: filtre = args[2].split(",")
	if args.size() > 3: heure_capture = float(args[3])
	if args.size() > 4: scene_capture = args[4]
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	var dossier := ProjectSettings.globalize_path(sortie)
	if DirAccess.make_dir_recursive_absolute(dossier) != OK:
		push_error("Impossible de créer le dossier de captures : " + dossier)
		quit(1)
		return
	var level = load(scene_capture).instantiate()
	root.add_child(level)
	current_scene = level
	await frames(10)
	var style = level.get_node_or_null("StyleBD")
	if style and args_mode.begins_with("brut"):
		style.basculer(false)
	if heure_capture >= 0.0 and level.get_node_or_null("Temps"):
		level.get_node("Temps").minutes = (heure_capture - 16.5) * 60.0
		level.get_node("Temps").pause = true
	var p = level.get_node("Player")
	if args_mode.contains("_nu"):
		# Vue sans interface ni personnage, pour comparer aux planches cibles.
		for n in level.find_children("*", "CanvasLayer", true, false):
			n.visible = false
		for n in level.find_children("*", "Control", true, false):
			(n as Control).visible = false
		p.visual.visible = false
	var q = level.get_node("Quartier")
	if args_mode.contains("sanspaix"):
		var ip = level.get_node_or_null("Habillage/ImpassePaix")
		if ip: ip.visible = false
	var piv: Node3D = p.get_node("CameraPivot")
	var arm: SpringArm3D = p.get_node("CameraPivot/SpringArm3D")
	# [nom, x, z, cap caméra (deg), inclinaison]
	var vues := [["barre_sv2014", -105.0, -130.0, 285.0, 0.3], ["barre_pres", -75.0, -170.0, 290.0, 0.25], ["cmp_nord", 137.0, 76.0, 12.0, 0.05], ["cmp_sud", 134.5, 58.0, 192.0, 0.05], ["verriere_sv", 139.5, 83.5, 127.0, 0.16], ["portail", 141.0, 82.2, 127.0, -0.32, 3.5], ["rampe_hall", 128.0, 88.5, 127.0, -0.1], ["verriere_dedans", 120.5, 97.5, 307.0, 0.35, 2.2], ["lycee_toits", 175.0, 60.0, 225.0, -0.55, 40.0], ["hall", 133.5, 87.5, 127.0, 0.05, 0.0], ["hall_fond", 126.5, 93.0, 127.0, 0.02, 2.2], ["hall_retour", 115.0, 101.5, 307.0, 0.05, 2.2], ["snack", 131.0, 47.0, 53.0, 0.05], ["snack_large", 136.0, 52.0, 45.0, -0.1, 1.5], ["laveran_verriere", 141.0, 82.0, 127.0, 0.12], ["laveran_sud", 157.0, 113.0, 37.0, 0.1], ["laveran_grue", 175.0, 125.0, 135.0, 0.4], ["lycee_entree", 147.9, 107.5, 127.0, 0.05], ["lycee_salle", 140.7, 112.9, 127.0, -0.05, 0.3], ["lycee_couloir", 137.1, 115.6, 217.0, 0.0, 0.3], ["lycee_couloir2", 137.1, 115.6, 37.0, 0.0, 0.3], ["lycee_aerien", 175.0, 85.0, 315.0, -0.5, 28.0], ["streetview_paix", -10.0, 52.0, 0.0, 0.1], ["esc_sommet", -15.0, 9.0, 180.0, -0.25, 4.5], ["impasse_loin", -10.0, 86.0, 0.0, 0.06], ["impasse_ciel", -10.0, 98.0, 0.0, 0.3], ["depart_marathon", -11.0, 109.0, 0.0, 0.2], ["impasse_pres", -10.0, 34.0, 0.0, 0.12], ["escalier_haut", -23.0, 13.6, 180.0, -0.25, 4.8], ["impasse_gauche", -8.0, 30.0, 340.0, 0.12], ["escalier_face", -15.2, 26.0, 0.0, 0.15], ["genets_echaf", 13.0, 88.0, 180.0, 0.25], ["aerien_lauriers", 40.0, -20.0, 225.0, -0.55, 60.0], ["aerien_ouest", -60.0, 60.0, 135.0, -0.6, 50.0], ["aerien_lycee", 40.0, 40.0, 320.0, -0.5, 45.0], ["aerien_place", -100.0, 20.0, 113.0, -0.7, 30.0], ["marathon_rouge", -80.0, 30.0, 90.0, 0.05], ["marathon_rouge2", -45.0, 90.0, 0.0, 0.0], ["collines", -112.0, 32.0, 113.0, -0.1, 1.0], ["collines_haut", -112.0, 15.0, 143.0, -0.5, 12.0], ["amphi", -131.0, 76.0, 0.0, -0.4, 4.0], ["mur_courbe", -120.0, 8.0, 83.0, -0.08], ["mosaique", 39.0, -4.0, 0.0, 0.32], ["echafaudage", -24.0, -38.0, 18.0, 0.12], ["echaf_haut", -30.0, -52.0, 10.0, -0.15, 30.0], ["escalier_lycee", 75.0, 95.0, 120.0, 0.05], ["barre_facade", -8.0, -105.0, 240.0, 0.18], ["cypresA_balcons", 62.0, -55.0, 250.0, 0.12], ["cypresA_grimpe", 49.5, -62.0, 270.0, 0.05, 6.5], ["toit_barre", -31.0, -100.0, 160.0, -0.3, 41.5], ["pied_barre", -15.0, -100.0, 255.0, -0.1], ["mur_lycee", 115.0, 70.0, 300.0, -0.1], ["loums_gros_plan", 57.0, -45.0, 0.0, -0.05], ["entree_cypres", -5.0, -47.0, 180.0, -0.12], ["entree_biais", 9.0, -45.0, 215.0, -0.15], ["marathon_garees", 57.0, -70.0, 165.0, -0.2], ["rue_marathon", 55.0, 20.0, 175.0, -0.15], ["boulevard", 130.0, -60.0, 175.0, -0.12], ["stade", 60.0, -110.0, 10.0, -0.2], ["toit_lycee_photo1", 95.0, 120.0, 55.0, 0.10, 12.0], ["toit_lycee_photo3", 105.0, 75.0, 65.0, 0.05, 12.0], ["barre_parking", -10.0, -150.0, 70.0, -0.12], ["cypres_rue", 57.0, -45.0, 160.0, -0.18], ["lycee", 120.0, 40.0, -60.0, -0.15], ["haut", 20.0, -60.0, 120.0, -0.55], ["dessus_impasse", -5.0, 130.0, 0.0, -0.9, 70.0], ["cible_marathon", -8.0, 96.0, 0.0, 0.02], ["cible_paix", -9.0, 100.0, 0.0, 0.10, 0.0, 52.0, 1.6], ["cible_paix2", -11.2, 72.6, -6.66, 0.0, 0.0, 70.0, 2.72, 0.134], ["greffe_mouth", -9.0, 104.0, 0.0, 0.0, 0.0, 62.0, 1.7, 0.12], ["greffe_air", 25.0, 120.0, 30.0, -0.5, 0.0, 60.0, 45.0], ["pv_e", -8.6, 94.8, 11.0, 0.0, 0.0, 60.0, 1.6, 0.22], ["pv_f", -10.0, 95.0, 9.0, 0.0, 0.0, 60.0, 1.6, 0.22], ["aerien_paix", 15.0, 110.0, 35.0, -0.45, 0.0, 60.0, 30.0], ["carte_barre", -2.0, -105.0, 75.0, 0.0, 0.0, 70.0, 1.7, 0.22], ["carte_cypres", 62.0, -40.0, 75.0, 0.0, 0.0, 70.0, 1.7, 0.25], ["carte_genets", 36.0, 100.0, 70.0, 0.0, 0.0, 70.0, 1.7, 0.25], ["carte_marathon", -70.0, 95.0, 330.0, 0.05, 0.0, 70.0, 1.7, 0.15], ["tourB_sud", 40.0, 30.0, 41.0, 0.35, 0.0, 70.0, 12.0], ["tourB_haut", 35.0, -60.0, 134.0, -0.08, 0.0, 65.0, 40.0], ["tourB_pied", -17.0, 6.0, 330.0, 0.28, 0.0, 70.0, 1.7], ["tourB_mur", -14.0, 8.0, 340.0, 0.32, 0.0, 72.0, 2.2], ["tourB_ouest", -50.0, -10.0, 285.0, 0.4, 0.0, 70.0, 1.7], ["porche_est", -10.0, -77.0, 90.0, 0.05, 0.0, 70.0, 1.7], ["socle_est", -17.0, -66.0, 9.0, 0.08, 0.0, 75.0, 1.7], ["barre_air", 30.0, -150.0, 95.0, -0.35, 0.0, 60.0, 32.0], ["plateau_air", 120.0, -60.0, 50.0, -0.3, 0.0, 65.0, 45.0], ["carte_air", 60.0, 40.0, 30.0, -0.35, 0.0, 60.0, 50.0], ["carte_air2", -120.0, 40.0, 250.0, -0.4, 0.0, 60.0, 60.0], ["carte_air3", 120.0, -120.0, 60.0, -0.45, 0.0, 60.0, 70.0], ["pv_a", -8.5, 97.0, 8.0, 0.08, 0.0, 60.0, 1.6], ["pv_b", -8.0, 100.0, 8.0, 0.07, 0.0, 58.0, 1.6], ["pv_c", -8.8, 95.0, 6.0, 0.08, 0.0, 62.0, 1.6], ["pv_d", -7.6, 99.0, 10.0, 0.07, 0.0, 56.0, 1.6], ["paix_facade", -4.0, 80.0, 300.0, 0.15, 0.0, 60.0, 1.6]]
	vues.append(["detail_voirie", -8.5, 55.0, 0.0, -0.45, 0.0, 65.0, 2.4])
	vues.append(["affichage_2013", -8.0, 69.6, 270.0, 0.0, 0.0, 60.0, 1.7])
	vues.append(["habillage_photos", -9.0, 57.2, 270.0, 0.02, 0.0, 68.0, 1.9])
	vues.append(["habillage_photos_large", -10.0, 64.5, 300.0, 0.12, 0.0, 70.0, 1.8])
	# Point d'essai pour la seconde photo du toit : pose approximative, à recaler.
	vues.append(["toit_lycee_photo2", 95.0, 75.0, 35.0, 0.03, 0.0, 62.0, 20.0])
	vues.append(["entree_cypres_creation", 13.8, -15.0, 58.0, 0.08, 0.0, 65.0, 1.7])
	vues.append(["entree_cypres_face", 13.8, -22.0, 90.0, 0.08, 0.0, 60.0, 1.7])
	vues.append(["cypres_reference_sol", 24.0, -5.0, 52.0, 0.24, 0.0, 70.0, 1.7])
	vues.append(["cypres_annexe_rampe", 12.0, -7.0, 60.0, 0.04, 0.0, 65.0, 1.7])
	vues.append(["cour_arriere_cypres", -40.0,-1.0,320.0,-0.18,0.0,65.0,8.0])
	vues.append(["curb_cypres", -25.0,-4.0,0.0,-0.10,0.0,65.0,1.7])
	for v in vues:
		if filtre.size() > 0 and not filtre.has(v[0]):
			continue
		var monte: float = v[5] if v.size() > 5 else 0.0
		arm.spring_length = 2.2 if String(v[0]).begins_with("loums") else 4.5
		if String(v[0]).begins_with("loums"):
			p.visual.rotation.y = deg_to_rad(v[3]) + PI  # face à la caméra
		p.global_position = Vector3(v[1], q.h(v[1], v[2]) + 0.1 + monte, v[2])
		p.velocity = Vector3.ZERO
		piv.rotation_degrees.y = v[3]
		arm.rotation.x = v[4]
		await frames(2)
		if monte > 0.0:
			p.set_physics_process(false)
		else:
			p.set_physics_process(true)
		await frames(28)
		piv.global_position = p.global_position + Vector3.UP * 1.5
		await frames(15)
		if v.size() > 6:
			# Caméra libre à hauteur d'œil (comparaison aux planches) : [.., monte, fov, hauteur œil]
			var ancienne: Camera3D = root.get_viewport().get_camera_3d()
			var cam := Camera3D.new()
			level.add_child(cam)
			cam.fov = v[6]
			if v.size() > 8:
				# objectif à décentrement (comme un dessinateur) : verticales droites, horizon abaissé
				cam.projection = Camera3D.PROJECTION_FRUSTUM
				cam.near = 0.05
				cam.size = 2.0 * cam.near * tan(deg_to_rad(v[6]) * 0.5)
				cam.frustum_offset = Vector2(0.0, cam.size * float(v[8]))
			for enfant in ancienne.get_children():
				enfant.reparent(cam, false)  # le quad d'encrage suit la caméra
			cam.make_current()
			var oeil := Vector3(v[1], q.h(v[1], v[2]) + (v[7] if v.size() > 7 else 1.6), v[2])
			var dir := Vector3(-sin(deg_to_rad(v[3])), tan(v[4]), -cos(deg_to_rad(v[3])))
			if v.size() > 8:
				dir.y = 0.0
			cam.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), oeil)
			await frames(6)
		if args_mode.contains("_nu"):
			for n in root.find_children("*", "CanvasLayer", true, false):
				n.visible = false
			for n in root.find_children("*", "CanvasItem", true, false):
				if n is Control:
					(n as Control).visible = false
			await frames(2)
		var img := root.get_texture().get_image()
		if img.save_png(sortie + "/" + v[0] + ".png") != OK:
			echecs += 1
		print("capture ", v[0])
	level.queue_free()
	await frames(3)
	quit(echecs)
