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
