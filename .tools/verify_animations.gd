extends SceneTree
## Vérifie les animations de Loums : attente debout, planche, ollie chargé, flips, 50-50,
## frein, chute, grimpe, geste de la bombe.
## Nécessite assets/personnages/loums.glb (sinon le test est sauté).
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame

## Les postures et l'IK ne sont appliquées qu'à la mise à jour du squelette :
## on lit les os pendant le signal skeleton_updated.
const LUS := ["Hips", "Neck", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot",
	"LeftArm", "RightArm", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]
var po := {}
func noter(sk: Skeleton3D) -> void:
	for n in LUS:
		po[n] = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_" + n))).origin

var level: Node
var p
var perso
var q

func _initialize() -> void:
	call_deferred("run")

func placer(x: float, z: float, cap: float) -> void:
	p._respawn()
	p.global_position = Vector3(x, q.h(x, z) + 0.1, z)
	p.velocity = Vector3.ZERO
	p.visual.rotation.y = cap

## Où regarde la poitrine (à plat), d'après la ligne des épaules.
func poitrine() -> Vector3:
	var droite: Vector3 = po.RightArm - po.LeftArm
	droite.y = 0
	return Vector3.UP.cross(droite).normalized()

func run() -> void:
	level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(30)
	p = level.get_node("Player")
	perso = p.get_node("Visual/Personnage")
	q = level.get_node("Quartier")
	if perso.modele == null:
		print("pas de modèle : test sauté")
		print("RESULT failures=0"); quit(0); return
	var sk: Skeleton3D = perso.squelette
	sk.skeleton_updated.connect(noter.bind(sk))
	await attente()
	await planche()
	await ollie()
	await flips()
	await grind()
	await frein()
	print("RESULT failures=", failures)
	quit(failures)

func attente() -> void:
	placer(57, -45, 0.0)
	await frames(60)
	var sol: float = p.global_position.y
	var dos: Vector3 = (po.Neck - po.Hips).normalized()
	check(perso.etat == "debout", "à l'arrêt : état debout (%s)" % perso.etat)
	check(dos.y > 0.97, "attente : dos droit (%.3f)" % dos.y)
	check(po.Hips.y - sol > 0.85, "attente : jambes tendues, bassin à %.2f m" % (po.Hips.y - sol))
	check(absf(po.LeftFoot.y - po.RightFoot.y) < 0.03, "attente : poids sur les deux pieds (écart %.3f m)" % absf(po.LeftFoot.y - po.RightFoot.y))
	for m in ["LeftHand", "RightHand"]:
		var main: Vector3 = po[m]
		var lat := Vector2(main.x - po.Hips.x, main.z - po.Hips.z).length()
		check(main.y < po.Hips.y + 0.02 and lat < 0.32, "attente : %s le long du corps (%.2f m sous le bassin, %.2f m du flanc)" % [m, po.Hips.y - main.y, lat])
	# Fondu avec la marche.
	Input.action_press("move_forward")
	await frames(40)
	Input.action_release("move_forward")
	check(perso.pose.poids_haut < 0.05, "en marchant, l'animation de marche reprend la main")
	var vu_mi := false
	for i in 50:
		await process_frame
		if perso.pose.poids_haut > 0.2 and perso.pose.poids_haut < 0.8:
			vu_mi = true
	check(vu_mi and perso.pose.poids_haut > 0.99, "retour à l'attente en fondu (~0,2 s)")

func planche() -> void:
	placer(57, -45, 0.0)
	await frames(20)
	var hanche_debout: float = po.Hips.y - (po.LeftFoot.y + po.RightFoot.y) * 0.5
	p._set_mode(p.Mode.SKATE)
	await frames(40)
	var nez: Vector3 = p.board.to_global(Vector3(0, 0, -1)) - p.board.global_position
	nez.y = 0
	nez = nez.normalized()
	var f := poitrine()
	check(f.dot(nez) > 0.25, "planche : buste tourné vers le nose (%.2f)" % f.dot(nez))
	var mains := Vector2(po.LeftHand.x - po.RightHand.x, po.LeftHand.z - po.RightHand.z).length()
	var epaules := Vector2(po.LeftArm.x - po.RightArm.x, po.LeftArm.z - po.RightArm.z).length()
	check(mains > epaules + 0.25, "planche : bras écartés (mains %.2f m, épaules %.2f m)" % [mains, epaules])
	var hanche: float = po.Hips.y - (po.LeftFoot.y + po.RightFoot.y) * 0.5
	check(hanche < hanche_debout - 0.06, "planche : genoux fléchis (bassin %.2f m contre %.2f debout)" % [hanche, hanche_debout])
	var d1: float = po.RightFoot.distance_to(perso.cible_avant.global_position)
	var d2: float = po.LeftFoot.distance_to(perso.cible_arriere.global_position)
	check(d1 < 0.06 and d2 < 0.06, "planche : pieds sur les vis (%.3f / %.3f m)" % [d1, d2])

func hanche_pieds() -> float:
	return po.Hips.y - (po.LeftFoot.y + po.RightFoot.y) * 0.5

func ollie() -> void:
	placer(57, -45, 0.0)
	p._set_mode(p.Mode.SKATE)
	await frames(40)
	var h0 := hanche_pieds()
	Input.action_press("jump")
	await frames(24)
	var h_charge := hanche_pieds()
	check(not p.skate.in_air and p.skate.charge > 0.3, "ollie : Espace tenu = accroupi, pas encore en l'air")
	check(h_charge < h0 - 0.12, "ollie : le bassin descend en chargeant (%.2f → %.2f m)" % [h0, h_charge])
	var d1: float = po.RightFoot.distance_to(perso.cible_avant.global_position)
	var d2: float = po.LeftFoot.distance_to(perso.cible_arriere.global_position)
	check(d1 < 0.06 and d2 < 0.06, "ollie : les pieds restent sur la planche en chargeant (%.3f / %.3f)" % [d1, d2])
	Input.action_release("jump")
	await frames(2)
	check(p.skate.in_air and absf(p.skate.ollie_v - 5.0) < 0.3, "ollie : décolle au relâché, 0,4 s → %.2f m/s" % p.skate.ollie_v)
	var pop := 0.0
	var h_air := 99.0
	while p.skate.in_air:
		pop = maxf(pop, p.board.rotation.x)
		h_air = minf(h_air, hanche_pieds())
		await physics_frame
	check(pop > 0.3, "ollie : le tail claque, le nose se lève (%.2f rad)" % pop)
	check(h_air < h0 - 0.12, "ollie : genoux remontés en l'air (%.2f m)" % h_air)
	var h_rec := 99.0
	for i in 20:
		await physics_frame
		h_rec = minf(h_rec, hanche_pieds())
	check(h_rec < h0 - 0.08, "ollie : flexion à la réception (%.2f m)" % h_rec)
	# hauteur selon le temps d'appui
	for essai in [[2, 4.0], [50, 6.0]]:
		await frames(20)
		Input.action_press("jump")
		await frames(essai[0])
		Input.action_release("jump")
		await frames(2)
		check(absf(p.skate.ollie_v - essai[1]) < 0.15, "ollie : appui de %d images → %.2f m/s (attendu %.1f)" % [essai[0], p.skate.ollie_v, essai[1]])
		while p.skate.in_air:
			await physics_frame

func flips() -> void:
	for figure in ["kickflip", "shove_it"]:
		placer(57, -45, 0.0)
		p._set_mode(p.Mode.SKATE)
		await frames(30)
		Input.action_press("jump")
		await frames(20)
		Input.action_release("jump")
		await frames(3)
		Input.action_press(figure)
		await frames(2)
		Input.action_release(figure)
		var leve := 0.0
		while p.skate.trick_t < 1.0 and p.skate.in_air:
			var cadre: Vector3 = p.visual.global_transform * p.board.position
			leve = maxf(leve, minf(po.RightFoot.y, po.LeftFoot.y) - cadre.y)
			await physics_frame
		check(leve > 0.2, "%s : les pieds quittent la planche (%.2f m au-dessus)" % [figure, leve])
		while p.skate.in_air:
			await physics_frame
		await frames(2)
		var d1: float = po.RightFoot.distance_to(perso.cible_avant.global_position)
		var d2: float = po.LeftFoot.distance_to(perso.cible_arriere.global_position)
		var dc: float = perso.cible_avant.global_position.distance_to(p.board.to_global(perso.PIED_AVANT))
		check(not p.skate.last_event.begins_with("Chute") and d1 < 0.06 and d2 < 0.06 and dc < 0.01, "%s : les pieds rattrapent la planche (%s)" % [figure, p.skate.last_event])

func grind() -> void:
	var rails: Array = root.get_tree().get_nodes_in_group("grindable")
	check(rails.size() > 0, "50-50 : il y a des rails dans le quartier")
	if rails.is_empty():
		return
	var rail = rails[0]
	var a: Vector3 = rail.top_start()
	var b: Vector3 = rail.top_end()
	var dir := (b - a).normalized()
	placer(a.x, a.z, 0.0)
	p._set_mode(p.Mode.SKATE)
	await frames(20)
	var h_sol := hanche_pieds()
	p.global_position = a + dir * 0.3 + Vector3.UP * 0.3
	p.velocity = Vector3(0, -1, 0)
	p.skate.speed = 5.0
	p.skate.heading = atan2(-dir.x, -dir.z)
	p.skate.in_air = true
	p.skate.trick_t = 1.0
	Input.action_press("grind")
	await frames(14)
	check(p.skate.grinding, "50-50 : sur le rail")
	var long: Vector3 = p.board.global_basis.z
	long.y = 0
	var aligne: float = absf(long.normalized().dot(Vector3(dir.x, 0, dir.z).normalized()))
	check(aligne > 0.98, "50-50 : planche dans l'axe du rail (%.3f)" % aligne)
	var mains := Vector2(po.LeftHand.x - po.RightHand.x, po.LeftHand.z - po.RightHand.z).length()
	check(mains > 1.0, "50-50 : bras écartés (%.2f m entre les mains)" % mains)
	check(hanche_pieds() < h_sol - 0.03, "50-50 : genoux fléchis (%.2f contre %.2f)" % [hanche_pieds(), h_sol])
	Input.action_release("grind")
	await frames(40)

func frein() -> void:
	placer(57, -45, 0.0)
	p._set_mode(p.Mode.SKATE)
	await frames(30)
	p.skate.speed = 6.0
	Input.action_press("move_back")
	await frames(12)
	var sol: float = p.global_position.y
	var pied: Vector3 = po.LeftFoot
	var centre: Vector3 = p.board.global_position
	var arriere: float = (pied - centre).dot(-p.skate.forward())
	var ecart: float = pied.distance_to(perso.cible_arriere.global_position)
	check(p.skate.freine and pied.y - sol < 0.16 and ecart < 0.06, "frein : le pied arrière touche le sol (cheville à %.2f m, %.3f m de la cible)" % [pied.y - sol, ecart])
	check(arriere > 0.35, "frein : le pied traîne derrière le tail (%.2f m)" % arriere)
	Input.action_release("move_back")
	await frames(10)
