extends SceneTree
## Vérifie la posture de Loums sur la planche (goofy), la poussée et la planche portée.
## Nécessite assets/personnages/loums.glb (sinon le test est sauté).
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
## Les modificateurs (IK) ne sont appliqués qu'au moment où le squelette se met à jour :
## on lit donc les positions des os pendant le signal skeleton_updated.
var poses := {}
func noter(sk: Skeleton3D) -> void:
	for nom in ["mixamorig_RightFoot", "mixamorig_LeftFoot", "mixamorig_RightHand", "mixamorig_Spine2", "mixamorig_LeftArm", "mixamorig_RightArm"]:
		poses[nom] = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(nom))).origin
func os(_sk: Skeleton3D, nom: String) -> Vector3:
	return poses.get(nom, Vector3.ZERO)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(30)
	var p = level.get_node("Player")
	var perso = p.get_node("Visual/Personnage")
	if perso.modele == null:
		print("pas de modèle : test sauté")
		print("RESULT failures=0"); quit(0); return
	var sk: Skeleton3D = perso.squelette
	sk.skeleton_updated.connect(noter.bind(sk))
	var q = level.get_node("Quartier")
	p.global_position = Vector3(57, q.h(57, -45) + 0.1, -45)
	await frames(20)
	# À pied : planche en diagonale dans le dos.
	var droite: Vector3 = os(sk, "mixamorig_RightArm") - os(sk, "mixamorig_LeftArm")
	droite.y = 0.0
	var devant := Vector3.UP.cross(droite).normalized()
	var derriere: float = -(p.board.global_position - os(sk, "mixamorig_Spine2")).dot(devant)
	check(p.board.visible and derriere > 0.10, "à pied, la planche est dans le dos (%.2f m derrière le buste)" % derriere)
	var long: Vector3 = p.board.global_basis.z.normalized()
	var angle := rad_to_deg(acos(absf(long.dot(Vector3.UP))))
	check(angle > 30.0 and angle < 60.0, "à pied, la planche est en diagonale (%.0f° de la verticale)" % angle)
	var grip: Vector3 = p.board.global_basis.y.normalized()
	check(grip.dot(devant) > 0.7, "à pied, le grip est contre le dos")
	# E : il prend la planche dans son dos, la pose et monte (~0,5 s).
	Input.action_press("toggle_board"); await frames(2); Input.action_release("toggle_board")
	await frames(10)
	var main := os(sk, "mixamorig_RightHand")
	var nose: Vector3 = p.board.to_global(Vector3(0, 0, -0.36))
	check(p.mode == p.Mode.WALK and p.transition == "decroche" and main.distance_to(nose) < 0.3, "E : la main passe derrière l'épaule et prend la planche (%.2f m)" % main.distance_to(nose))
	await frames(30)
	check(p.mode == p.Mode.SKATE and p.transition == "", "E : au bout d'une demi-seconde, il est dessus")
	await frames(30)
	var avant := os(sk, "mixamorig_RightFoot")
	var arriere := os(sk, "mixamorig_LeftFoot")
	var d1: float = avant.distance_to(perso.cible_avant.global_position)
	var d2: float = arriere.distance_to(perso.cible_arriere.global_position)
	check(d1 < 0.06 and d2 < 0.06, "pieds sur la planche (écarts %.3f / %.3f m)" % [d1, d2])
	var nez: Vector3 = p.board.to_global(Vector3(0, 0, -0.3))
	check(avant.distance_to(nez) < arriere.distance_to(nez), "goofy : le pied droit est devant")
	var face: Vector3 = -perso.modele.global_basis.z
	var route: Vector3 = p.skate.forward()
	check(absf(face.dot(route)) < 0.3, "de profil sur la planche (%.2f)" % face.dot(route))
	# Poussée : le pied gauche touche le sol.
	var sol: float = p.global_position.y
	var plus_bas := 99.0
	Input.action_press("push")
	for i in 60:
		await process_frame
		plus_bas = minf(plus_bas, os(sk, "mixamorig_LeftFoot").y - sol)
	Input.action_release("push")
	check(plus_bas < 0.16, "en poussant, le pied arrière descend au sol (cheville à %.2f m)" % plus_bas)
	check(p.skate.speed > 0.5, "la poussée fait avancer (%.1f m/s)" % p.skate.speed)
	# E en skate : il ramasse la planche par le tail et la remet dans le dos.
	await frames(60)
	Input.action_press("toggle_board"); await frames(2); Input.action_release("toggle_board")
	var vu_main := 9.0
	var dressee := 0.0
	for i in 25:
		await process_frame
		vu_main = minf(vu_main, os(sk, "mixamorig_RightHand").distance_to(p.board.to_global(Vector3(0, 0, -0.36))))
		dressee = maxf(dressee, p.board.global_basis.z.normalized().dot(Vector3.DOWN))
	check(p.mode == p.Mode.WALK and dressee > 0.8, "E en skate : il claque le tail, la planche se dresse (%.2f)" % dressee)
	check(vu_main < 0.3, "E en skate : la main attrape le nose (%.2f m)" % vu_main)
	await frames(30)
	var derriere2: float = -(p.board.global_position - os(sk, "mixamorig_Spine2")).dot(devant)
	check(p.transition == "" and derriere2 > 0.10, "E en skate : la planche est revenue dans le dos")
	print("RESULT failures=", failures)
	quit(failures)
