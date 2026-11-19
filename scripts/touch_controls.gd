extends CanvasLayer
## Contrôles tactiles (autoload « TouchControls »), actifs seulement sur un écran tactile.
## Seuls les boutons utiles à l'instant s'affichent (voir _choisir_boutons).
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

## Les emplacements des boutons d'action (à gauche) : [dx, dy, rayon].
## dx > 0 : depuis le bord gauche ; dx < 0 : depuis le bord droit.
## dy < 0 : depuis le bas (vers le haut) ; dy > 0 : depuis le haut.
const PLACES := {
	"A": [180, -180, 118],  # le gros bouton principal
	"B": [405, -110, 84],
	"C": [400, -305, 84],
	"D": [190, -425, 76],
	"E": [580, -240, 78],
	"F": [600, -430, 72],
	"haut": [-80, 80, 58],
	"haut2": [-215, 80, 58],
}
## [nom, libellé, action, maintenu]. Une action qui commence par « : » est une commande
## envoyée au graffiti (choix dans le menu GRAFF).
const BOUTONS := {
	"saut": ["SAUT", "jump", false],
	"courir": ["COURIR", "push", true],
	"planche": ["PLANCHE", "toggle_board", false],
	"pousser": ["POUSSER", "push", true],
	"ollie": ["OLLIE", "jump", true],
	"flip": ["FLIP", "kickflip", false],
	"shove": ["SHOVE", "shove_it", false],
	"grind": ["GRIND", "grind", true],
	"graff": ["GRAFF", ":menu", false],
	"fouille": ["FOUILLE", "fouiller", false],
	"monter": ["MONTER", "monter", false],
	"tag": ["TAG", ":tag", false],
	"flop": ["FLOP", ":flop", false],
	"piece": ["PIÈCE", ":piece", false],
	"reprendre": ["REPRENDRE", ":reprendre", false],
	"perche": ["PERCHE", ":perche", false],
	"rouleau": ["ROULEAU", ":rouleau", false],
	"mode": ["MODE", ":mode", false],
	"couleur": ["COUL.", "graff_color", false],
	"fermer": ["✕", ":fermer", false],
	"poser": ["SUITE", "graff", false],
	"arret": ["ARRÊT", "ui_cancel", false],
	"hisser": ["MONTER", "jump", false],
	"lacher": ["LÂCHER", ":lacher", false],
	"roue": ["ROUE AR.", "jump", true],
	"frein": ["FREIN À MAIN", "jump", true],
	"grimper": ["GRIMPER", "jump", true],
	"lacher_g": ["LÂCHER", "jump", false],
	"descendre": ["DESCENDRE", "monter", false],
	"reset": ["DÉPART", "reset", false],
	"demain": ["DEMAIN", "temps_demain", false],
}
var _visibles: Array = []    ## [nom, place] des boutons affichés en ce moment
var _contexte := ""


## Ce qu'on peut faire là, tout de suite : seuls ces boutons s'affichent.
## À pied : se déplacer ; en skate : les figures ; devant un mur : GRAFF, qui ouvre ses options ;
## suspendu : monter ou lâcher ; en véhicule : roue arrière, descendre ; en train de peindre : suite, arrêt.
func _choisir_boutons() -> void:
	var j := get_tree().get_first_node_in_group("player")
	var scene := get_tree().current_scene
	var g: Node = scene.get_node_or_null("Graffiti") if scene else null
	var cond: Node = scene.find_child("Conduite", true, false) if scene else null
	var liste: Array = []
	var ctx := "pied"
	if g and g.get("_trace") != null:
		ctx = "trace"
		liste = [["poser", "A"], ["arret", "B"]]
	elif cond and cond.get("actuel") != null:
		ctx = "conduite"
		var scooter: bool = str((cond.get("actuel") as Node).get("type")) == "scooter"
		liste = [["roue" if scooter else "frein", "A"], ["descendre", "C"]]
	elif j and j.get("gouttiere") != null:
		ctx = "gouttiere"
		liste = [["lacher_g", "A"]]
	elif j and j.get("suspendu"):
		ctx = "suspendu"
		liste = [["hisser", "A"], ["lacher", "B"]]
	elif j and j.get("mode") == 1:
		ctx = "skate"
		liste = [["ollie", "A"], ["pousser", "B"], ["planche", "C"], ["flip", "D"], ["shove", "E"], ["grind", "F"]]
	else:
		# face à un rebord qu'il peut attraper, SAUT devient GRIMPER
		var grimpe: bool = j != null and j.has_method("peut_grimper") and j.call("peut_grimper")
		liste = [["grimper" if grimpe else "saut", "A"], ["courir", "B"], ["planche", "C"]]
		if g and g.call("peut_graffer"):
			liste.append(["graff", "E"])
		if g and g.call("_conteneur_proche") != null:
			liste.append(["fouille", "F"])
		if cond and cond.has_method("_vehicule_proche") and cond.call("_vehicule_proche") != null:
			liste.append(["monter", "D"])
	liste.append(["reset", "haut"])
	if ctx == "pied" or ctx == "skate":
		liste.append(["demain", "haut2"])
	if ctx + str(liste) != _contexte:
		_contexte = ctx + str(liste)
		_visibles = liste
		if _canvas:
			_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if actif:
		_choisir_boutons()


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


## Un bouton affiché, sous la forme [nom, libellé, action, maintenu, dx, dy, rayon].
func _bouton(v: Array) -> Array:
	var d: Array = BOUTONS[v[0]].duplicate()
	if v[0] == "mode":
		var scene := get_tree().current_scene
		var g: Node = scene.get_node_or_null("Graffiti") if scene else null
		d[0] = "EXPERT" if g and g.get("expert") else "SIMPLE"
	var pl: Array = PLACES[v[1]]
	return [v[0], d[0], d[1], d[2], pl[0], pl[1], pl[2]]


func _centre(b: Array) -> Vector2:
	var s := _canvas.size
	var dy: float = b[5]
	var dx: float = b[4]
	return Vector2(dx if dx > 0.0 else s.x + dx, (s.y + dy) if dy < 0.0 else dy)


func _bouton_sous(p: Vector2) -> Array:
	if _canvas == null:
		return []
	for v in _visibles:
		var b := _bouton(v)
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
	if action.begins_with(":"):
		if presse:
			_commande(action.substr(1))
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = presse
	ev.strength = 1.0 if presse else 0.0
	Input.parse_input_event(ev)


## Les boutons du menu GRAFF et quelques gestes qui ne sont pas des actions du clavier.
func _commande(c: String) -> void:
	var scene := get_tree().current_scene
	var g: Node = scene.get_node_or_null("Graffiti") if scene else null
	match c:
		"menu":
			if g and g.has_method("ouvrir_choix"):
				g.call("ouvrir_choix")
		"tag", "flop", "piece", "perche", "rouleau", "reprendre":
			if g:
				g.call("commande_tactile", c)
		"mode":
			if g:
				g.call("basculer_mode")
		"lacher":
			Input.action_press("move_back")
			await get_tree().create_timer(0.1).timeout
			Input.action_release("move_back")
	_choisir_boutons()


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
	for v in _visibles:
		var b := _bouton(v)
		var c := _centre(b)
		var r: float = b[6]
		var on := int(_enfonces.get(b[0], 0)) > 0
		# un disque sombre sous le texte : lisible sur n'importe quel décor
		_canvas.draw_circle(c, r, Color(0.98, 0.82, 0.10, 0.85) if on else Color(0.08, 0.06, 0.10, 0.62))
		_canvas.draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.95), 4.0, true)
		var t: String = b[1]
		var taille := int(clampf(r * 0.36, 22.0, 40.0))
		var w := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		while w > r * 1.75 and taille > 16:
			taille -= 2
			w = police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var pos := c + Vector2(-w * 0.5, taille * 0.36)
		_canvas.draw_string_outline(police, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 6, Color(0.05, 0.04, 0.07, 0.9))
		_canvas.draw_string(police, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(0.08, 0.06, 0.10) if on else Color(1, 1, 1))
	if _joy_vu:
		_canvas.draw_circle(_joy_origine, JOY_RAYON, Color(1, 1, 1, 0.10))
		_canvas.draw_arc(_joy_origine, JOY_RAYON, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 3.0, true)
		_canvas.draw_circle(_joy_origine + (_joy_pos - _joy_origine).limit_length(JOY_RAYON), 40.0, Color(1, 1, 1, 0.4))
