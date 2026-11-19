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
	quit(0)
