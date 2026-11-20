extends SceneTree
var erreurs := 0
func controle(test: bool, message: String) -> void:
	print("PASS " if test else "FAIL ",message)
	if not test: erreurs+=1

func _initialize() -> void:
	call_deferred("parcourir")

func parcourir() -> void:
	var sc = load("res://scenes/diderot.tscn").instantiate()
	root.add_child(sc)
	current_scene=sc
	for i in 40: await physics_frame
	var p=sc.get_node("Player")
	var milieu:=Vector2(128.5,91.5)
	var normale:=Vector2(55,-41).normalized()
	var debut: Vector3=p.position
	controle(p.is_on_floor(),"Loums est posé au départ boulevard Lavéran")
	controle(sc.get_node("Temps").visite_archive,"Chronologie de visite indépendante")
	if not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/joueur.png")
	p.camera_pivot.rotation.y=atan2(normale.x,normale.y)
	Input.action_press("move_forward")
	for i in 275: await physics_frame
	Input.action_release("move_forward")
	var ecart: float=(Vector2(p.position.x,p.position.z)-milieu).dot(normale)
	controle(p.position.distance_to(debut)>8.0,"Approche jouée à pied, %.2f m"%p.position.distance_to(debut))
	controle(ecart<5.8,"Franchissement de la ligne du portail, abscisse normale %.2f m"%ecart)
	controle(p.is_on_floor(),"Contact au sol après le franchissement")
	print("RESULT failures=",erreurs)
	quit(erreurs)
