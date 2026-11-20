extends SceneTree
var erreurs:=0
func ok(val: bool, message: String) -> void:
	print("PASS " if val else "FAIL ",message)
	if not val: erreurs+=1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var start:=Time.get_ticks_msec()
	var sc=load("res://scenes/marseille.tscn").instantiate()
	root.add_child(sc); current_scene=sc
	await process_frame
	ok(sc.ville.info.labels.size()==111,"111 quartiers présents")
	ok(sc.ville.secteurs.is_empty(),"Vue d'ensemble sans volumes de proximité")
	print("Construction initiale ",Time.get_ticks_msec()-start," ms")
	for nom in ["L'Estaque","Hôtel-de-Ville"]:
		for l in sc.ville.info.labels:
			if l[0]==nom: sc.point=Vector2(l[2],l[3])
		sc.echelle=820;sc._cadrer()
		var debut:=Time.get_ticks_msec()
		while (not sc.ville.demandes.is_empty() or sc.ville.travail.is_started()) and Time.get_ticks_msec()-debut<20000:
			await process_frame
		ok(sc.ville.secteurs.size()>0 and sc.ville.secteurs.size()<=9,"Tuiles chargées à "+nom+" : "+str(sc.ville.secteurs.size()))
		print("Chargement ",nom," ",Time.get_ticks_msec()-debut," ms")
	sc._descendre()
	var p=sc.acteur
	ok(is_instance_valid(p),"Départ dans une rue proche du Vieux-Port")
	var limite:=Time.get_ticks_msec()+20000
	while not p.is_physics_processing() and Time.get_ticks_msec()<limite: await process_frame
	for i in 80: await physics_frame
	ok(p.is_on_floor() and p.position.y< -20, "Collision au sol sous l'ancien seuil de réapparition "+str(p.position))
	var pos: Vector3 = p.position
	Input.action_press("move_forward")
	for i in 30: await physics_frame
	Input.action_release("move_forward")
	ok(p.position.distance_to(pos)>.4,"Marche dans le deuxième arrondissement "+str(p.position.distance_to(pos))+" m")
	# Contrôle physique sur deux côtés d'une limite commune de tuiles réellement chargées.
	while (not sc.ville.demandes.is_empty() or sc.ville.travail.is_started()) and Time.get_ticks_msec()<limite: await process_frame
	var centre: Vector2i=sc.ville.centre_tuile
	var pos_lim:=Vector2((centre.x+1)*512,centre.y*512+256)
	var hits:=0
	for offset in [-.2,.2]:
		var pt:=pos_lim+Vector2(offset,0)
		var sol: float=sc.ville.altitude(pt.x,pt.y)
		var q:=PhysicsRayQueryParameters3D.create(Vector3(pt.x,sol+.5,pt.y),Vector3(pt.x,sol-.5,pt.y))
		if not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty(): hits+=1
	ok(hits==2,"Continuité physique de part et d'autre d'une limite de secteur")
	sc.queue_free()
	for i in 3: await process_frame
	print("RESULT failures=",erreurs)
	quit(erreurs)
