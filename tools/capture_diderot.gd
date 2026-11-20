extends SceneTree
## Même focale, mêmes positions et même heure pour comparer les versions du boulevard.
func _initialize() -> void:
	call_deferred("photographier")

func photographier() -> void:
	var sortie := OS.get_cmdline_user_args()[0]
	var scene = load("res://scenes/diderot.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 8: await process_frame
	var temps = scene.get_node("Temps")
	temps.minutes = -180
	temps.pause = true
	for layer in root.find_children("*","CanvasLayer",true,false):
		layer.hide()
	var joueur = scene.get_node("Player")
	joueur.hide()
	joueur.set_physics_process(false)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.make_current()
	camera.fov = 61
	var sol = scene.get_node("Quartier")
	var milieu := Vector2(128.5,91.5)
	var axe := Vector2(41,55).normalized()
	var rue := Vector2(axe.y,-axe.x)
	for cadrage in [["boulevard",-26,13,2.2,2,4,3.1],["nef",0,20,2.0,0,0,3.1],["ceramique",18,10.6,1.7,10,5,1.9]]:
		var oeil: Vector2 = milieu + axe * float(cadrage[1]) + rue * float(cadrage[2])
		var mire: Vector2 = milieu + axe * float(cadrage[4]) + rue * float(cadrage[5])
		camera.position = Vector3(oeil.x, sol.h(oeil.x,oeil.y)+float(cadrage[3]), oeil.y)
		camera.look_at(Vector3(mire.x, sol.h(mire.x,mire.y)+float(cadrage[6]), mire.y))
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var erreur := root.get_texture().get_image().save_png(sortie+"/"+str(cadrage[0])+".png")
		if erreur != OK: quit(1); return
	quit()
