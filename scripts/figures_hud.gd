extends CanvasLayer
## Le nom des figures à l'écran (Louma 21.11) : « Kickflip FS 180 + 50-50 + Manual ».
## Lit le combo du SkateController ; le dessine en grand, avec un rebond à chaque ajout.
## Vert = propre, orange = rattrapé de justesse, rouge = chute. La jauge du manual en dessous.
## Aussi les petits messages utiles (« Va chercher ta planche ») qui remplacent l'ancien texte en haut à gauche.

var skate: SkateController
var _texte: Label
var _jauge: Control
var _message: Label
var _maj_vue := -1
var _rebond := 0.0
var _vie := 0.0             ## secondes avant que le combo fini s'efface
var _message_vie := 0.0
var _dernier_event := ""

const JAUNE := Color(1.0, 0.84, 0.15)
const VERT := Color(0.45, 1.0, 0.45)
const ORANGE := Color(1.0, 0.6, 0.15)
const ROUGE := Color(1.0, 0.3, 0.3)
## Les messages de skate.last_event qu'on montre (les autres ne servaient qu'à la mise au point).
const MESSAGES := ["chercher ta planche", "Planche ramassée", "Ta planche est"]


func _ready() -> void:
	layer = 3
	_texte = _label(46, 12)
	_texte.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_texte.offset_top = 150
	add_child(_texte)
	_message = _label(24, 7)
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.offset_top = -150
	_message.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(_message)
	_jauge = Control.new()
	_jauge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_jauge.offset_top = 215
	_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jauge.draw.connect(_dessiner_jauge)
	add_child(_jauge)


func _label(taille: int, contour: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_outline_color", Color(0.07, 0.04, 0.10))
	l.add_theme_constant_override("outline_size", contour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	if skate == null:
		return
	if skate.combo_maj != _maj_vue:
		_maj_vue = skate.combo_maj
		_rebond = 1.0
		_vie = 2.2
		var etat := skate.combo_etat
		var t := " + ".join(skate.combo)
		if etat == "chute":
			t = (t + "  ·  " if t != "" else "") + "CHUTE"
		_texte.text = t
		var c := JAUNE
		match etat:
			"propre":
				c = VERT
			"juste":
				c = ORANGE
			"chute":
				c = ROUGE
		_texte.add_theme_color_override("font_color", c)
	if skate.combo_etat != "en_cours":
		_vie -= delta
	_rebond = move_toward(_rebond, 0.0, delta / 0.25)
	# taille adaptée à l'écran (portrait étroit) puis petit rebond à chaque ajout
	var ecran := get_viewport().get_visible_rect().size
	var k := clampf(ecran.x / 1400.0, 0.55, 1.0)
	_texte.pivot_offset = _texte.size * 0.5
	_texte.scale = Vector2.ONE * k * (1.0 + 0.35 * sin(_rebond * PI) * _rebond)
	_texte.offset_left = -_texte.size.x * 0.5
	_texte.modulate.a = clampf(_vie / 0.5, 0.0, 1.0) if skate.combo_etat != "en_cours" else 1.0
	_texte.visible = _texte.text != "" and _texte.modulate.a > 0.0
	_jauge.visible = skate.manual
	if _jauge.visible:
		_jauge.queue_redraw()
	# les messages utiles (planche perdue, ramassée) : en bas, quelques secondes
	if skate.last_event != _dernier_event:
		_dernier_event = skate.last_event
		var montre := false
		for m in MESSAGES:
			if m in _dernier_event:
				montre = true
		if montre:
			_message.text = _dernier_event
			_message_vie = 3.0
	_message_vie -= delta
	_message.modulate.a = clampf(_message_vie / 0.5, 0.0, 1.0)
	_message.offset_left = -_message.size.x * 0.5
	_message.visible = _message_vie > 0.0


## La jauge du manual : un trait, et un point qui doit rester au milieu.
func _dessiner_jauge() -> void:
	var l := 160.0
	_jauge.draw_line(Vector2(-l, 0), Vector2(l, 0), Color(0.07, 0.04, 0.10, 0.8), 12.0)
	_jauge.draw_line(Vector2(-l, 0), Vector2(l, 0), Color(1, 1, 1, 0.85), 6.0)
	_jauge.draw_rect(Rect2(-l * 0.3, -6, l * 0.6, 12), Color(0.45, 1.0, 0.45, 0.6))
	var b := clampf(skate.manual_bal, -1.0, 1.0)
	var c := VERT if absf(b) < 0.3 else (ORANGE if absf(b) < 0.7 else ROUGE)
	_jauge.draw_circle(Vector2(b * l, 0), 13.0, Color(0.07, 0.04, 0.10))
	_jauge.draw_circle(Vector2(b * l, 0), 10.0, c)
