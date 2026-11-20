extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var sc = load("res://scenes/marseille.tscn").instantiate()
	root.add_child(sc)
	current_scene=sc
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0]+"/02_atlas.png")
	print("Capture atlas")
	for l in sc.ville.info.labels:
		if l[0]=="Hôtel-de-Ville":
			sc.point=Vector2(l[2],l[3])
	sc.echelle=620
	sc.titre.text="Hôtel-de-Ville"
	sc._cadrer()
	for i in 2400:
		await process_frame
		if sc.ville.demandes.is_empty() and not sc.ville.travail.is_started():break
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0]+"/03_port.png")
	print("Capture secteur, ",sc.ville.secteurs.size()," tuiles")
	sc._descendre()
	var limite:=Time.get_ticks_msec()+15000
	while (not sc.ville.demandes.is_empty() or sc.ville.travail.is_started()) and Time.get_ticks_msec()<limite:
		await process_frame
	for i in 35: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0]+"/05_rue_port.png")
	quit()
