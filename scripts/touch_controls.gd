extends CanvasLayer
## Contrôles tactiles (autoload « TouchControls »), actifs seulement sur un écran tactile.
## Seuls les boutons utiles à l'instant s'affichent (voir _choisir_boutons).
## Paysage : joystick de direction flottant à DROITE (il naît sous le pouce et le suit), boutons d'action à GAUCHE,
## qui n'apparaissent que quand ils servent ; un doigt sur le paysage = tourner la caméra, deux doigts = zoom / pivoter.
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
const SENS_CAMERA := 2.6       ## radians pour un glissé sur toute la hauteur de l'écran (Louma 21.11 : c'était 3 fois trop nerveux)
const REMONTE := 90.0          ## Louma 21.11 : les boutons du bas remontés vers le pouce
const TAILLE := 0.68           ## taille générale des boutons (1 = la version d'origine, jugée trop grosse)
const JOY_ZONE := 0.5          ## la moitié droite de l'écran : le pouce s'y pose n'importe où
const JOY_REPOS := Vector2(-230, -200)  ## où le joystick attend (depuis le coin bas droit), dessiné en léger
var _apparus := {}             ## nom du bouton -> instant où il est apparu (petite animation d'entrée)
var _t := 0.0

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
	"planche": ["SKATE", "toggle_board", false],
	"pied": ["DESCENDRE", "toggle_board", false],
	"ramasser": ["RAMASSER", "toggle_board", false],
	"pousser": ["POUSSER", "push", true],
	"ollie": ["OLLIE", "jump", true],
	"flip": ["FLIP", "kickflip", false],
	"shove": ["SHOVE", "shove_it", false],
	"grind": ["GRIND", "grind", true],
	"manual": ["MANUAL", "grind", true],
	"grab": ["GRAB", "push", true],
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
		# Louma 21.11 : la poussée est automatique (direction vers l'avant), le grind s'accroche tout seul ;
		# FLIP et SHOVE n'apparaissent qu'en l'air, quand on peut vraiment les faire.
		ctx = "skate"
		var sk: Node = j.get("skate")
		var en_l_air: bool = sk != null and ((bool(sk.get("in_air")) and (bool(sk.get("saute")) or float(sk.get("air_t")) > 0.15)) or float(sk.get("charge")) >= 0.0) and not bool(sk.get("grinding"))
		# Louma 21.11 : en l'air le joystick fait tourner (180, 360), GRAB attrape la planche ;
		# au sol MANUAL (tenir) lève le nose, le joystick avant/arrière garde l'équilibre.
		liste = [["ollie", "A"]]
		if en_l_air:
			liste.append(["flip", "B"])
			liste.append(["shove", "C"])
			liste.append(["grab", "D"])
		else:
			liste.append(["pied", "C"])
			if sk != null and absf(float(sk.get("speed"))) > 1.5 and not bool(sk.get("grinding")):
				liste.append(["manual", "B"])
	else:
		# face à un rebord qu'il peut attraper, SAUT devient GRIMPER ; joystick à fond = courir
		var grimpe: bool = j != null and j.has_method("peut_grimper") and j.call("peut_grimper")
		liste = [["grimper" if grimpe else "saut", "A"], ["ramasser" if j and j.get("planche_libre") else "planche", "C"]]
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
		var avant := _visibles.map(func(v): return v[0])
		for v in liste:
			if not v[0] in avant:
				_apparus[v[0]] = _t
		_visibles = liste
		if _canvas:
			_canvas.queue_redraw()


func _process(delta: float) -> void:
	if actif:
		_t += delta
		_choisir_boutons()
		if _canvas and _anime():
			_canvas.queue_redraw()


## Un bouton vient d'apparaître : on redessine le temps de son animation.
func _anime() -> bool:
	for v in _visibles:
		if _t - float(_apparus.get(v[0], -9.0)) < 1.6:
			return true
	return false


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
	var k := _k()
	var dy: float = (pl[1] - REMONTE) * k if pl[1] < 0 else pl[1] * k
	if pl[1] < 0 and _canvas and _canvas.size.y > _canvas.size.x:
		dy -= _canvas.size.y * 0.1  # portrait : le pouce est plus haut sur l'écran
	return [v[0], d[0], d[1], d[2], pl[0] * k, dy, pl[2] * k]


## Échelle des commandes : plus petites en général, et encore plus en portrait (le petit côté de
## l'écran fait foi), pour qu'elles ne mangent pas la moitié de l'image.
func _k() -> float:
	if _canvas == null:
		return TAILLE
	var s := _canvas.size
	return TAILLE * clampf(minf(s.x, s.y) / 900.0, 0.62, 1.0)


func _joy_r() -> float:
	return JOY_RAYON * _k() / TAILLE * 0.8


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
	elif p.x > _canvas.size.x * JOY_ZONE and not _joy_vu:
		_doigts[i] = {"role": "joy"}
		_joy_origine = p
		_joy_pos = p
		_joy_vu = true
		_appliquer_joy()
	else:
		_doigts[i] = {"role": "look", "p": p}
		_deux_ecart = -1.0
	_canvas.queue_redraw()


var _deux_ecart := -1.0
var _deux_angle := 0.0


func _doigts_regard() -> Array:
	var r: Array = []
	for k in _doigts:
		if _doigts[k]["role"] == "look":
			r.append(k)
	return r


func _glisse(i: int, p: Vector2, rel: Vector2) -> void:
	if not _doigts.has(i):
		return
	match _doigts[i]["role"]:
		"joy":
			_joy_pos = p
			# le pouce dépasse le cercle : le joystick le suit (on ne « sort » jamais de la zone)
			var ecart := _joy_pos - _joy_origine
			if ecart.length() > _joy_r():
				_joy_origine = _joy_pos - ecart.normalized() * _joy_r()
			_appliquer_joy()
		"look":
			_doigts[i]["p"] = p
			var joueur := get_tree().get_first_node_in_group("player")
			var regards := _doigts_regard()
			if regards.size() >= 2:
				# deux doigts sur le paysage : pincer = zoom, tourner = pivoter (comme une carte)
				var a: Vector2 = _doigts[regards[0]]["p"]
				var b: Vector2 = _doigts[regards[1]]["p"]
				var ecart_d := a.distance_to(b)
				var angle_d := (b - a).angle()
				if _deux_ecart > 1.0 and ecart_d > 1.0 and joueur and joueur.has_method("touch_zoom"):
					joueur.touch_zoom(_deux_ecart / ecart_d)
				if _deux_ecart > 1.0 and joueur and joueur.has_method("touch_twist"):
					joueur.touch_twist(-wrapf(angle_d - _deux_angle, -PI, PI))
				_deux_ecart = ecart_d
				_deux_angle = angle_d
			elif joueur and joueur.has_method("touch_look"):
				joueur.touch_look(rel * SENS_CAMERA / maxf(minf(_canvas.size.x, _canvas.size.y), 1.0))
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
	_deux_ecart = -1.0
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
		v = ((_joy_pos - _joy_origine) / _joy_r()).limit_length(1.0)
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
	# (Louma 21.11 : plus de texte en haut à gauche, le rappel « Tourne ton téléphone » est retiré.)
	for v in _visibles:
		var b := _bouton(v)
		var c := _centre(b)
		var r: float = b[6]
		var on := int(_enfonces.get(b[0], 0)) > 0
		# entrée : le bouton surgit avec un petit rebond, puis une onde jaune invite à l'essayer
		var age := _t - float(_apparus.get(b[0], -9.0))
		if age < 0.35:
			var k := age / 0.35
			r *= 0.55 + 0.45 * k + 0.18 * sin(k * PI)
		if age < 1.6 and not on:
			var o := fmod(age, 0.8) / 0.8
			_canvas.draw_arc(c, r * (1.0 + 0.45 * o), 0.0, TAU, 48, Color(0.98, 0.82, 0.10, 0.8 * (1.0 - o)), 5.0, true)
		# un disque sombre sous le texte : lisible sur n'importe quel décor
		_canvas.draw_circle(c, r, Color(0.98, 0.82, 0.10, 0.85) if on else Color(0.08, 0.06, 0.10, 0.62))
		_canvas.draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 2.5, true)
		var t: String = b[1]
		var taille := int(clampf(r * 0.38, 13.0, 34.0))
		var w := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		while w > r * 1.75 and taille > 11:
			taille -= 2
			w = police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var pos := c + Vector2(-w * 0.5, taille * 0.36)
		_canvas.draw_string_outline(police, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 4, Color(0.05, 0.04, 0.07, 0.9))
		_canvas.draw_string(police, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(0.08, 0.06, 0.10) if on else Color(1, 1, 1))
	if not _joy_vu:
		# au repos : on voit où poser le pouce (mais le joystick naît là où on touche, dans toute la moitié droite)
		var repos := _canvas.size + JOY_REPOS * _k() / TAILLE * 0.8
		_canvas.draw_circle(repos, _joy_r(), Color(1, 1, 1, 0.05))
		_canvas.draw_arc(repos, _joy_r(), 0.0, TAU, 40, Color(1, 1, 1, 0.22), 2.0, true)
		_canvas.draw_circle(repos, _joy_r() * 0.36, Color(1, 1, 1, 0.16))
	if _joy_vu:
		_canvas.draw_circle(_joy_origine, _joy_r(), Color(1, 1, 1, 0.10))
		_canvas.draw_arc(_joy_origine, _joy_r(), 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.5, true)
		_canvas.draw_circle(_joy_origine + (_joy_pos - _joy_origine).limit_length(_joy_r()), _joy_r() * 0.4, Color(1, 1, 1, 0.4))
