extends SceneTree
## Temps mural entre images dans la vue de départ. Lancer avec un affichage actif.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var chemin := "res://scenes/diderot.tscn" if "diderot" in OS.get_cmdline_user_args() else "res://scenes/lauriers.tscn"
	var scene=load(chemin).instantiate()
	root.add_child(scene)
	current_scene=scene
	for i in 18: await process_frame
	if chemin.ends_with("lauriers.tscn"):
		scene.get_node("Temps").minutes=0
	scene.get_node("Temps").pause=true
	for i in 8: await process_frame
	var mesures: Array[float]=[]
	var debut:=Time.get_ticks_usec()
	for i in 42:
		await process_frame
		var maintenant:=Time.get_ticks_usec()
		mesures.append((maintenant-debut)/1000.)
		debut=maintenant
	mesures.sort()
	print("FRAME wall ms median=",mesures[21]," p95=",mesures[39],
		" primitives=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		" draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()
