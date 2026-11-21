class_name Aide
extends CanvasLayer
## L'aide aux commandes : quelques touches seulement, celles qui servent là où l'on est
## (à pied, en skate, devant un mur, en train de tracer un tag). Touches dessinées comme des
## petites capsules encrées, dans le style BD du jeu. Elle pâlit quand rien ne change,
## revient dès que la situation change. H la masque ou la rappelle.

const ENCRE := Color(0.10, 0.07, 0.12)
const PAPIER := Color(0.97, 0.94, 0.86)
const PALE_APRES := 5.0      ## secondes avant de pâlir
const PALE := 0.35

var graffiti: Node
var joueur: Player
var _boite: VBoxContainer
var _contexte := ""
var _depuis := 0.0
var _masquee := false


func _ready() -> void:
	layer = 5
	_boite = VBoxContainer.new()
	_boite.add_theme_constant_override("separation", 5)
	_boite.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_boite.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_boite.position = Vector2(18, -18)
	add_child(_boite)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_masquee = not _masquee
		_depuis = 0.0


func _process(delta: float) -> void:
	if joueur == null:
		return
	if TouchControls.actif:   # sur téléphone, les boutons à l'écran suffisent
		_boite.visible = false
		return
	var c := contexte()
	if c == "trace" and graffiti:
		var lc: Array = graffiti.call("consigne")
		c = "trace:" + str(lc)
	if c != _contexte:
		_contexte = c
		_depuis = 0.0
		_remplir(graffiti.call("consigne") if c.begins_with("trace:") else lignes(c))
	_depuis += delta
	_boite.visible = not _masquee
	var a := 1.0 if _depuis < PALE_APRES else lerpf(1.0, PALE, clampf((_depuis - PALE_APRES) / 1.0, 0.0, 1.0))
	_boite.modulate.a = a
	_boite.position.y = get_viewport().get_visible_rect().size.y - 46.0 - _boite.size.y
	_boite.position.x = 18.0   # jamais coupée par le bord gauche


func contexte() -> String:
	if graffiti and graffiti.get("_trace") != null:
		return "trace"
	if joueur.gouttiere != null:
		return "gouttiere"
	if joueur.suspendu:
		return "suspendu"
	if joueur.mode == Player.Mode.SKATE:
		return "skate"
	if graffiti and graffiti.has_method("_conteneur_proche") and graffiti.call("_conteneur_proche") != null:
		return "conteneur"
	if graffiti and not (graffiti.get("_cible") as Dictionary).is_empty():
		return "mur_expert" if graffiti.get("expert") else "mur"
	return "pied"


func lignes(c: String) -> Array:
	match c:
		"trace":
			return [["Clic", "peindre (maintenir)"], ["G", "poser le tag"], ["Échap", "laisser tomber"]]
		"gouttiere":
			return [["↑  ↓", "monter, descendre (en haut : passer sur le toit)"], ["Espace", "lâcher"]]
		"suspendu":
			return [["Espace", "se hisser, ou bondir au rebord du dessus"], ["←  →", "se décaler"], ["↓", "lâcher"]]
		"skate":
			return [["Espace", "ollie (maintenir, relâcher)"], ["←  →  en l'air", "tourner : 180, 360…"], ["X  C", "kickflip, shove-it"], ["Maj en l'air", "grab (↑ nose, ↓ tail)"], ["B", "manual (↑ ↓ : équilibre)"], ["sur un rail", "grind tout seul (↑ nosegrind, ↓ 5-0)"], ["E", "descendre de la planche"]]
		"conteneur":
			return [["F", "fouiller : bombes pleines"], ["E", "planche"]]
		"mur", "mur_expert":
			return [["G", "graffiti : choisir quoi peindre"], ["↑ ↓ ← →", "marcher"]]
	return [["↑ ↓ ← →", "marcher"], ["Maj", "courir"], ["Espace", "sauter ; vers un mur : grimper, s'accrocher"], ["E", "monter sur la planche"], ["N", "au lendemain matin (Maj+N : une semaine)"]]


func _remplir(l: Array) -> void:
	for n in _boite.get_children():
		n.queue_free()
	for paire in l:
		_boite.add_child(_ligne(paire[0], paire[1]))
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	_boite.add_child(_ligne("H", "aide" + ("   ·   version " + v if v != "" else ""), true))


func _ligne(touche: String, action: String, discret := false) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var cap := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PAPIER
	st.border_color = ENCRE
	st.set_border_width_all(2)
	st.border_width_bottom = 4      # l'épaisseur du bas fait une touche en relief
	st.set_corner_radius_all(5)
	st.content_margin_left = 7
	st.content_margin_right = 7
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	cap.add_theme_stylebox_override("panel", st)
	cap.custom_minimum_size = Vector2(30, 0)
	var k := Label.new()
	k.text = touche
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_theme_color_override("font_color", ENCRE)
	k.add_theme_font_size_override("font_size", 13)
	cap.add_child(k)
	h.add_child(cap)
	var t := Label.new()
	t.text = action
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", PAPIER)
	t.add_theme_color_override("font_outline_color", ENCRE)
	t.add_theme_constant_override("outline_size", 5)
	h.add_child(t)
	if discret:
		h.modulate.a = 0.6
	return h
