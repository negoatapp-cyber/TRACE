extends CanvasLayer
## Le retour à la carte reste disponible dans les trois scènes, y compris au toucher.
var depart_cypres := OS.get_cmdline_user_args().has("cypres")
var retour := Button.new()

const DEPARTS := [
	["Rue de Marathon", Vector2(57,-45), 0.],
	["Impasse · escalier", Vector2(-15,23), 0.],
	["Boulevard Lavéran · Diderot", Vector2(136,55), -2.8],
	["Tour B · Les Cyprès", Vector2(13,-104), deg_to_rad(168.)],
]
var depart := OptionButton.new()
func _ready() -> void:
	layer=11
	retour.text="Atlas  ·  F1"
	add_child(retour)
	retour.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	retour.offset_left=-140
	retour.offset_right=-15
	retour.offset_top=-25
	retour.offset_bottom=25
	retour.add_theme_font_size_override("font_size",20)
	retour.pressed.connect(ouvrir)
	add_child(depart)
	depart.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	depart.offset_left=-290; depart.offset_right=-15
	depart.offset_top=31; depart.offset_bottom=75
	depart.add_item("Points de départ")
	for lieu in DEPARTS: depart.add_item(lieu[0])
	depart.item_selected.connect(_aller)

func _aller(i: int) -> void:
	if i==0: return
	var sc := get_tree().current_scene
	var joueur := sc.get_node("Player") as Player
	var pt: Vector2=DEPARTS[i-1][1]
	joueur.spawn_position=Vector3(pt.x,sc.get_node("Quartier").h(pt.x,pt.y)+.18,pt.y)
	joueur._respawn()
	joueur.camera_pivot.rotation.y=DEPARTS[i-1][2]
	joueur.visual.rotation.y=DEPARTS[i-1][2]
	joueur.spring_arm.rotation.x = 0.22 if i == 4 else -0.10
	depart.select(0)
	if not TouchControls.actif: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _process(_dt: float) -> void:
	var sc := get_tree().current_scene
	depart.visible = sc!=null and sc.name=="Lauriers"
	if depart.visible and depart_cypres:
		depart_cypres = false
		_aller(4)
	retour.visible = sc!=null and (sc.name!="Marseille" or is_instance_valid(sc.get("acteur")))

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode==KEY_F1:
		ouvrir()
		get_viewport().set_input_as_handled()

func ouvrir() -> void:
	get_tree().change_scene_to_file("res://scenes/marseille.tscn")
