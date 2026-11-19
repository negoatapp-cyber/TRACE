extends SceneTree
## Captures des postures de Loums (attente, planche, ollie, flips, 50-50, frein, chute, grimpe, bombe).
## Usage : godot --path . -s .tools/capture_animations.gd -- <dossier_sortie> [vue1,vue2…]
var sortie := "/tmp"
var seules: PackedStringArray = []
var level: Node
var p
var perso
var q
var cam: Camera3D
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: sortie = args[0]
	if args.size() > 1: seules = args[1].split(",")
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func placer(x: float, z: float, cap: float) -> void:
	p._respawn()
	p.global_position = Vector3(x, q.h(x, z) + 0.1, z)
	p.velocity = Vector3.ZERO
	p.visual.rotation.y = cap
## Caméra posée dans le repère de Visual (le joueur regarde -Z).
func viser(decalage: Vector3, hauteur := 0.9) -> void:
	var v: Node3D = p.visual
	var cible: Vector3 = p.global_position + Vector3.UP * hauteur
	cam.global_position = v.global_transform * decalage
	cam.look_at(cible)
func photo(nom: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(sortie + "/" + nom + ".png")
	print("capture ", nom)
func veut(nom: String) -> bool:
	return seules.is_empty() or nom in seules
func run() -> void:
	level = load("res://scenes/lauriers.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(20)
	p = level.get_node("Player")
	perso = p.get_node("Visual/Personnage")
	q = level.get_node("Quartier")
	cam = Camera3D.new()
	cam.fov = 40
	level.add_child(cam)
	cam.current = true
	if veut("attente"):
		placer(57, -45, 0.0)
		await frames(60)
		viser(Vector3(0.0, 1.0, -3.6))
		await photo("01_attente_face")
		viser(Vector3(3.6, 1.0, 0.0))
		await photo("01_attente_profil")
	if veut("planche"):
		placer(57, -45, 0.0)
		p._set_mode(p.Mode.SKATE)
		p.set_physics_process(false)
		await frames(40)
		viser(Vector3(-3.4, 1.0, -0.6))
		await photo("02_planche_face")
		viser(Vector3(0.6, 1.2, -3.6))
		await photo("02_planche_nose")
		p.set_physics_process(true)
	if veut("ollie"):
		placer(57, -45, 0.0)
		p._set_mode(p.Mode.SKATE)
		await frames(30)
		Input.action_press("jump")
		await frames(30)
		await figer("03_ollie_charge", Vector3(-3.4, 0.9, -0.4))
		Input.action_release("jump")
		await frames(5)
		await figer("03_ollie_pop", Vector3(-3.4, 1.2, -0.4))
		await frames(12)
		await figer("03_ollie_air", Vector3(-3.4, 1.4, -0.4), 1.4)
		while p.skate.in_air:
			await physics_frame
		await frames(4)
		await figer("03_ollie_reception", Vector3(-3.4, 0.9, -0.4))
	for figure in ["kickflip", "shove_it"]:
		if not veut(figure):
			continue
		placer(57, -45, 0.0)
		p._set_mode(p.Mode.SKATE)
		await frames(30)
		Input.action_press("jump")
		await frames(30)
		Input.action_release("jump")
		await frames(3)
		Input.action_press(figure)
		await frames(2)
		Input.action_release(figure)
		await frames(10)
		await figer("04_" + figure, Vector3(-3.0, 1.3, -1.2), 1.1)
		while p.skate.in_air:
			await physics_frame
	if veut("grind"):
		var rail = level.get_tree().get_nodes_in_group("grindable")[0]
		var a: Vector3 = rail.top_start()
		var b: Vector3 = rail.top_end()
		var dir := (b - a).normalized()
		placer(a.x, a.z, 0.0)
		p._set_mode(p.Mode.SKATE)
		await frames(10)
		p.global_position = a + dir * 0.3 + Vector3.UP * 0.3
		p.velocity = Vector3(0, -1, 0)
		p.skate.speed = 4.0
		p.skate.heading = atan2(-dir.x, -dir.z)
		p.skate.in_air = true
		p.skate.trick_t = 1.0
		Input.action_press("grind")
		await frames(16)
		await figer("05_grind", Vector3(-3.2, 1.1, -1.0), 0.8)
		Input.action_release("grind")
		await frames(30)
	if veut("frein"):
		placer(57, -45, 0.0)
		p._set_mode(p.Mode.SKATE)
		await frames(30)
		p.skate.speed = 6.0
		Input.action_press("move_back")
		await frames(10)
		await figer("06_frein", Vector3(-3.0, 0.9, 1.4))
		Input.action_release("move_back")
	quit(0)

## Fige le joueur (plus de physique), laisse la pose se poser, photographie.
func figer(nom: String, cam_decalage: Vector3, hauteur := 0.9) -> void:
	p.set_physics_process(false)
	for i in 6:
		await process_frame
	viser(cam_decalage, hauteur)
	await photo(nom)
	p.set_physics_process(true)
