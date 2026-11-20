extends SceneTree
var erreurs := 0
var capture := ""
func ok(v: bool, texte: String) -> void:
	print("PASS " if v else "FAIL ",texte)
	if not v: erreurs+=1
func temps(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty(): capture=OS.get_cmdline_user_args()[0]
	call_deferred("run")
func run() -> void:
	var sc=load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(sc);current_scene=sc
	await temps(45)
	if capture!="":
		sc.get_node("Temps").minutes=42.0
		sc.get_node("Temps").pause=true
	var joueur=sc.get_node("Player")
	var nav=root.get_node("NavigationMonde")
	nav._aller(2)
	await temps(30)
	var depart: Vector3=joueur.position
	Input.action_press("move_forward")
	Input.action_press("push")
	await temps(240)
	Input.action_release("move_forward"); Input.action_release("push")
	var delta: Vector3=joueur.position-depart
	ok(delta.z< -19.5 and delta.y>4.0,"Escalier parcouru depuis la rue jusqu’au plateau, déplacement "+str(delta))
	ok(joueur.is_on_floor(),"Contact au palier")
	nav._aller(3)
	await temps(45)
	ok(joueur.is_on_floor(),"Départ Lavéran au sol")
	nav._aller(1)
	await temps(40)
	Input.action_press("toggle_board");await temps(2);Input.action_release("toggle_board")
	await temps(45)
	Input.action_press("push");await temps(60)
	Input.action_release("push")
	var vitesse: float=joueur.skate.speed
	ok(joueur.mode==joueur.Mode.SKATE and vitesse>2.,"Poussée rue de Marathon %.2f m/s"%vitesse)
	Input.action_press("move_right");await temps(12);Input.action_release("move_right")
	ok(absf(joueur.skate.heading)>.02,"Virage sur la chaussée")
	Input.action_press("jump");await temps(9);Input.action_release("jump");await temps(5)
	ok(joueur.skate.in_air and joueur.velocity.y>0,"Ollie dans la rue")
	if capture!="":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(capture+"/04_ollie.png")
	await temps(70)
	ok(not joueur.skate.in_air,"Réception sur la chaussée")
	var avant:=absf(joueur.skate.speed)
	Input.action_press("move_back");await temps(18);Input.action_release("move_back")
	ok(absf(joueur.skate.speed)<avant,"Freinage %.2f → %.2f m/s"%[avant,absf(joueur.skate.speed)])
	print("RESULT failures=",erreurs)
	quit(erreurs)
