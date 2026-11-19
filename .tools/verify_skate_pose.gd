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
	for nom in ["mixamorig_RightFoot", "mixamorig_LeftFoot", "mixamorig_RightHand"]:
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
	# À pied : planche dans la main droite.
	var main := os(sk, "mixamorig_RightHand")
	check(p.board.visible and p.board.global_position.distance_to(main) < 0.45, "à pied, la planche est portée à la main (%.2f m)" % p.board.global_position.distance_to(main))
	p._set_mode(p.Mode.SKATE)
	await frames(40)
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
	print("RESULT failures=", failures)
	quit(failures)
