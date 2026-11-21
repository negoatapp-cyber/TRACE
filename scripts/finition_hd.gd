extends Node
## Présentation et collision des scènes de rue déjà construites.
const ENDUIT := "res://assets/decor/matieres/enduit_chaud_hd.webp"
var enduit: ImageTexture
var menu: CanvasLayer
var fluide := OS.get_cmdline_user_args().has("fluide")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_scene)
	get_tree().node_added.connect(_nouveau)
	get_viewport().size_changed.connect(_redimensionner)

func _scene() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_node("Quartier"):
		return
	_redimensionner()
	var rendu := get_viewport()
	if not fluide and not (OS.has_feature("web") or OS.has_feature("mobile")):
		rendu.msaa_3d = Viewport.MSAA_2X
	RenderingServer.global_shader_parameter_set("bd_grain", 0.105)
	RenderingServer.global_shader_parameter_set("bd_trame", 0.026)
	var shader := load("res://shaders/facade.gdshader") as Shader
	if enduit == null:
		var image := Image.new()
		if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(ENDUIT)) == OK:
			image.generate_mipmaps()
			enduit = ImageTexture.create_from_image(image)
	if enduit:
		shader.set_default_texture_parameter("enduit_hd", enduit)
	_ouvrir_place(scene.get_node("Quartier"))

func _redimensionner() -> void:
	var sc := get_tree().current_scene
	if sc and sc.has_node("Quartier"):
		var taille := Vector2(get_window().size)
		var pixels := maxf(taille.x * taille.y, 1.)
		var budget := 921600.0 if fluide else 2073600.0
		get_viewport().scaling_3d_scale = clampf(sqrt(budget / pixels), 0.4, 1.)
	if is_instance_valid(menu):
		_cadrer_menu.call_deferred()

func _nouveau(n: Node) -> void:
	if n is CanvasLayer and n.has_method("_choisir_onglet") and n.has_method("ouvrir"):
		menu = n
		menu.visibility_changed.connect(_cadrer_menu, CONNECT_DEFERRED)
		_cadrer_menu.call_deferred()

func _cadrer_menu() -> void:
	if not is_instance_valid(menu) or not menu.visible:
		return
	var panel: Control = menu.get("_racine")
	if not panel:
		return
	var v := get_viewport().get_visible_rect().size
	var marge := minf(v.x, v.y) * 0.025
	var largeur := clampf(v.x - 2. * marge, 930., 1280.)
	var facteur := minf(1., minf((v.x - 2.*marge) / largeur, (v.y - 2.*marge) / 560.))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(largeur, 552.)
	panel.scale = Vector2.ONE * facteur
	panel.position = Vector2((v.x - panel.size.x * facteur) / 2., v.y - marge - panel.size.y * facteur)

func _ouvrir_place(q: Node) -> void:
	var limite := q.get_node_or_null("Limite3") as StaticBody3D
	if not limite or not is_equal_approx(limite.position.x, -125.):
		return
	var collision := limite.get_child(0) as CollisionShape3D
	if not collision or not collision.shape is BoxShape3D:
		return
	var taille := (collision.shape as BoxShape3D).size
	var origine := limite.position
	var contour := PackedVector2Array([
		Vector2(origine.x, origine.z - taille.z/2.), Vector2(-125,-8),
		Vector2(-146,-8), Vector2(-146,78), Vector2(-125,78),
		Vector2(origine.x, origine.z + taille.z/2.)])
	for i in range(1, contour.size()):
		var a := contour[i-1]
		var b := contour[i]
		var milieu := (a+b)*0.5
		var forme := BoxShape3D.new()
		var ecart := (a-b).abs()
		forme.size = Vector3(maxf(taille.x,ecart.x), taille.y, maxf(taille.x,ecart.y))
		var morceau := CollisionShape3D.new()
		morceau.shape = forme
		limite.add_child(morceau)
		morceau.position = Vector3(milieu.x-origine.x,0,milieu.y-origine.z)
	collision.queue_free()
