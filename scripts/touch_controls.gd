extends CanvasLayer
## Contrôles tactiles (autoload « TouchControls »), actifs seulement sur un écran tactile.
## Paysage : joystick de direction flottant à DROITE, boutons d'action à GAUCHE,
## glisser dans la zone libre (gauche / milieu) pour la caméra.
## Tout passe par les mêmes actions que le clavier et la manette (voir input_setup.gd).
## Pour tester sur PC : lancer avec `-- --touch`, ou ouvrir la version web avec `?touch`.

var actif := false
var _canvas: Control
var _doigts := {}            ## index du doigt -> {"role": "joy"/"look"/"bouton", ...}
var _joy_origine := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_vu := false
var _enfonces := {}          ## nom du bouton -> nombre de doigts dessus

const JOY_RAYON := 95.0
const SENS_CAMERA := 0.0055

## [nom, libellé, action, maintenu, dx, dy, rayon]
## dx > 0 : depuis le bord gauche ; dx < 0 : depuis le bord droit.
## dy < 0 : depuis le bas (vers le haut) ; dy > 0 : depuis le haut.
const BOUTONS := [
	["jump", "SAUT", "jump", false, 150, -150, 82],
	["push", "COURIR", "push", true, 330, -85, 56],
	["board", "PLANCHE", "toggle_board", false, 330, -225, 56],
	["flip", "FLIP", "kickflip", false, 175, -330, 50],
	["shove", "SHOVE", "shove_it", false, 335, -355, 50],
	["grind", "GRIND", "grind", true, 480, -225, 50],
	["graff", "GRAFF", "graff", true, 480, -85, 50],
	["couleur", "COUL.", "graff_color", false, 620, -85, 40],
	["fouille", "FOUILLE", "fouiller", false, 620, -215, 40],
	["reset", "DÉPART", "reset", false, -60, 55, 34],
	["bd", "BD", "style_bd", false, -150, 55, 34],
]


func _ready() -> void:
	layer = 100
	actif = DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")
	if OS.has_feature("web") and not actif:
		var q = JavaScriptBridge.eval("window.location.search", true)
		actif = q != null and str(q).contains("touch")
	if not actif:
		return
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_dessiner)
	add_child(_canvas)


func _centre(b: Array) -> Vector2:
	var s := _canvas.size
	var dy: float = b[5]
	var dx: float = b[4]
	return Vector2(dx if dx > 0.0 else s.x + dx, (s.y + dy) if dy < 0.0 else dy)


func _bouton_sous(p: Vector2) -> Array:
	for b in BOUTONS:
		if p.distance_to(_centre(b)) <= float(b[6]) * 1.15:
			return b
	return []


func _input(event: InputEvent) -> void:
	if not actif:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_plein_ecran_paysage()
			_debut(event.index, event.position)
		else:
			_fin(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_glisse(event.index, event.position, event.relative)
		get_viewport().set_input_as_handled()


func _debut(i: int, p: Vector2) -> void:
	var b := _bouton_sous(p)
	if not b.is_empty():
		_doigts[i] = {"role": "bouton", "b": b}
		_enfonces[b[0]] = int(_enfonces.get(b[0], 0)) + 1
		_envoyer(b[2], true)
	elif p.x > _canvas.size.x * 0.55 and not _joy_vu:
		_doigts[i] = {"role": "joy"}
		_joy_origine = p
		_joy_pos = p
		_joy_vu = true
		_appliquer_joy()
	else:
		_doigts[i] = {"role": "look"}
	_canvas.queue_redraw()


func _glisse(i: int, p: Vector2, rel: Vector2) -> void:
	if not _doigts.has(i):
		return
	match _doigts[i]["role"]:
		"joy":
			_joy_pos = p
			_appliquer_joy()
		"look":
			var joueur := get_tree().get_first_node_in_group("player")
			if joueur and joueur.has_method("touch_look"):
				joueur.touch_look(rel * SENS_CAMERA)
	_canvas.queue_redraw()


func _fin(i: int) -> void:
	if not _doigts.has(i):
		return
	var d: Dictionary = _doigts[i]
	if d["role"] == "bouton":
		var b: Array = d["b"]
		_enfonces[b[0]] = maxi(0, int(_enfonces.get(b[0], 1)) - 1)
		_envoyer(b[2], false)
	elif d["role"] == "joy":
		_joy_vu = false
		_appliquer_joy()
	_doigts.erase(i)
	_canvas.queue_redraw()


var _plein_ecran_fait := false


## Au premier toucher (un geste de l'utilisateur est exigé) : plein écran, puis verrouillage en paysage.
func _plein_ecran_paysage() -> void:
	if _plein_ecran_fait or not OS.has_feature("web"):
		return
	_plein_ecran_fait = true
	JavaScriptBridge.eval("""
		(function(){
			var c = document.documentElement;
			var r = c.requestFullscreen ? c.requestFullscreen() : Promise.resolve();
			Promise.resolve(r).then(function(){
				if (screen.orientation && screen.orientation.lock) { screen.orientation.lock('landscape').catch(function(){}); }
			}).catch(function(){});
		})();
	""")


func _envoyer(action: String, presse: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = presse
	ev.strength = 1.0 if presse else 0.0
	Input.parse_input_event(ev)


func _appliquer_joy() -> void:
	var v := Vector2.ZERO
	if _joy_vu:
		v = ((_joy_pos - _joy_origine) / JOY_RAYON).limit_length(1.0)
		if v.length() < 0.15:
			v = Vector2.ZERO
	_axe("move_left", maxf(-v.x, 0.0))
	_axe("move_right", maxf(v.x, 0.0))
	_axe("move_forward", maxf(-v.y, 0.0))
	_axe("move_back", maxf(v.y, 0.0))


func _axe(action: String, force: float) -> void:
	if force > 0.0:
		Input.action_press(action, force)
	else:
		Input.action_release(action)


func _dessiner() -> void:
	var police := ThemeDB.fallback_font
	if _canvas.size.y > _canvas.size.x:
		var m := "Tourne ton téléphone en paysage"
		var w0 := police.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		_canvas.draw_string(police, Vector2((_canvas.size.x - w0) * 0.5, _canvas.size.y * 0.5), m,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.9))
	for b in BOUTONS:
		var c := _centre(b)
		var r: float = b[6]
		var on := int(_enfonces.get(b[0], 0)) > 0
		_canvas.draw_circle(c, r, Color(1, 1, 1, 0.38 if on else 0.14))
		_canvas.draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.7), 3.0, true)
		var taille := int(r * 0.34)
		var t: String = b[1]
		var w := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		_canvas.draw_string(police, c + Vector2(-w * 0.5, taille * 0.35), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(1, 1, 1, 0.95))
	if _joy_vu:
		_canvas.draw_circle(_joy_origine, JOY_RAYON, Color(1, 1, 1, 0.10))
		_canvas.draw_arc(_joy_origine, JOY_RAYON, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 3.0, true)
		_canvas.draw_circle(_joy_origine + (_joy_pos - _joy_origine).limit_length(JOY_RAYON), 40.0, Color(1, 1, 1, 0.4))
