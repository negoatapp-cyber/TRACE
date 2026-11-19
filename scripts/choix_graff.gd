extends CanvasLayer
## Le choix du graffiti (G au clavier, GRAFF au téléphone), face à un mur.
## On voit ce qu'on va peindre avant de le peindre : un onglet par taille (tag, flop, pièce, perche, rouleau),
## puis les styles disponibles en vignettes (les tags de Loums, les palettes des flops et des pièces).
## Un clic (ou un doigt, ou Entrée) sur une vignette : Loums commence. Le jeu est en pause pendant le choix.
## Clavier : ← → ↑ ↓ pour se déplacer, Entrée pour peindre, Tab pour changer de bombe, Échap ou G pour fermer.

const PAPIER := Color(0.97, 0.94, 0.86)
const ENCRE := Color(0.10, 0.07, 0.12)
const JAUNE := Color(0.98, 0.82, 0.10)
const TYPES := ["tag", "flop", "piece", "perche", "rouleau"]
const NOMS := {"tag": "TAG", "flop": "FLOP", "piece": "PIÈCE", "perche": "PERCHE", "rouleau": "ROULEAU"}
const AIDE_TYPE := {
	"tag": "Une signature, un trait. Rapide et discret.",
	"flop": "Lettres rondes : fond, contour, surcontour.",
	"piece": "La grande pièce : fond, contour, lights, surcontour, signature. Longue, on se fait voir.",
	"perche": "Un tag tout en haut, au bout de la perche.",
	"rouleau": "Grosses lettres pleines au rouleau (le pot de peinture).",
}

var graffiti: Node
var onglet := "tag"
var _racine: Control
var _onglets: HBoxContainer
var _cartes: HBoxContainer
var _bombes: HBoxContainer
var _bas: HBoxContainer
var _info: Label
var _souris_avant := Input.MOUSE_MODE_VISIBLE
var _pause_avant := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_construire()


func ouvrir(o := "") -> void:
	if o != "":
		onglet = o
	_souris_avant = Input.mouse_mode
	_pause_avant = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_touches_tactiles(false)
	visible = true
	_remplir()


func fermer() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _pause_avant
	_touches_tactiles(true)
	if _souris_avant == Input.MOUSE_MODE_CAPTURED and graffiti.get("_trace") == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _touches_tactiles(montrer: bool) -> void:
	var tc := get_node_or_null("/root/TouchControls") as CanvasLayer
	if tc:
		tc.visible = montrer


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("graff"):
		fermer()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("graff_color"):
		_changer_bombe((int(graffiti.get("bombe")) + 1) % 4)
		get_viewport().set_input_as_handled()
	else:
		for i in TYPES.size():
			if InputMap.has_action("graff_%d" % (i + 1)) and e.is_action_pressed("graff_%d" % (i + 1)):
				_choisir_onglet(TYPES[i])
				get_viewport().set_input_as_handled()


# ───────────────────────── construction ─────────────────────────

func _construire() -> void:
	_racine = PanelContainer.new()
	_racine.anchor_left = 0.5
	_racine.anchor_right = 0.5
	_racine.anchor_top = 1.0
	_racine.anchor_bottom = 1.0
	_racine.offset_left = -640
	_racine.offset_right = 640
	_racine.offset_top = -490
	_racine.offset_bottom = -24
	var st := StyleBoxFlat.new()
	st.bg_color = Color(PAPIER, 0.97)
	st.border_color = ENCRE
	st.set_border_width_all(5)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(18)
	_racine.add_theme_stylebox_override("panel", st)
	add_child(_racine)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_racine.add_child(v)
	var titre := HBoxContainer.new()
	var t := Label.new()
	t.text = "GRAFFITI"
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", ENCRE)
	titre.add_child(t)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_color", ENCRE)
	titre.add_child(_info)
	v.add_child(titre)
	_onglets = HBoxContainer.new()
	_onglets.add_theme_constant_override("separation", 10)
	v.add_child(_onglets)
	_cartes = HBoxContainer.new()
	_cartes.add_theme_constant_override("separation", 14)
	_cartes.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_cartes)
	_bas = HBoxContainer.new()
	_bas.add_theme_constant_override("separation", 12)
	v.add_child(_bas)
	_bombes = HBoxContainer.new()
	_bombes.add_theme_constant_override("separation", 10)


func _style_bouton(b: BaseButton, fond: Color, bord: Color, epais := 3) -> void:
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = fond
		s.border_color = bord
		s.set_border_width_all(epais)
		s.set_corner_radius_all(10)
		s.set_content_margin_all(8)
		if etat == "hover" or etat == "focus":
			s.border_color = JAUNE
			s.set_border_width_all(epais + 3)
		elif etat == "pressed":
			s.bg_color = fond.lightened(0.15)
		elif etat == "disabled":
			s.bg_color = Color(fond, 0.35)
		b.add_theme_stylebox_override(etat, s)


func _bouton_texte(texte: String, taille: int, actif: bool) -> Button:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", taille)
	var clair := PAPIER if actif else ENCRE
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, clair)
	b.add_theme_color_override("font_disabled_color", Color(ENCRE, 0.4))
	_style_bouton(b, ENCRE if actif else Color(1, 1, 1, 0.6), ENCRE)
	return b


func _remplir() -> void:
	for boite in [_onglets, _cartes, _bas, _bombes]:
		for n in boite.get_children():
			boite.remove_child(n)
			n.queue_free()
	var reserve: Array = graffiti.get("reserve")
	var bombe: int = graffiti.get("bombe")

	# les onglets : un par taille
	for ty in TYPES:
		var b := _bouton_texte(NOMS[ty], 26, ty == onglet)
		b.custom_minimum_size = Vector2(0, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choisir_onglet.bind(ty))
		_onglets.add_child(b)
	var possible: bool = float(reserve[bombe]) >= float(graffiti.call("cout_de", onglet)) if onglet != "rouleau" else float(graffiti.get("pot")) >= 0.1
	_info.text = AIDE_TYPE[onglet] if possible else ("Bombe vide : change de bombe, ou va au snack." if onglet != "rouleau" else "Pot vide : va au conteneur derrière la grande barre.")
	# les vignettes : les styles
	var styles: Array = graffiti.call("styles_de", onglet)
	var premiere: Button = null
	for i in styles.size():
		var carte := _carte(styles[i], i)
		carte.disabled = not possible
		_cartes.add_child(carte)
		if premiere == null:
			premiere = carte
	# en bas : les bombes (la couleur du tag), reprendre, le mode, fermer
	var l := Label.new()
	l.text = "Bombe :"
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", ENCRE)
	_bas.add_child(l)
	var ceinture: Array = graffiti.get("ceinture")
	var couleurs: Array = graffiti.call("couleurs")
	for i in 4:
		var bb := Button.new()
		bb.custom_minimum_size = Vector2(64, 64)
		bb.focus_mode = Control.FOCUS_ALL
		_style_bouton(bb, couleurs[ceinture[i]], JAUNE if i == bombe else ENCRE, 6 if i == bombe else 3)
		bb.tooltip_text = "%d %%" % int(float(reserve[i]) * 100.0)
		bb.pressed.connect(_changer_bombe.bind(i))
		_bas.add_child(bb)
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bas.add_child(vide)
	if graffiti.call("a_reprendre_ici"):
		var r := _bouton_texte("REPRENDRE", 22, true)
		r.custom_minimum_size = Vector2(170, 64)
		r.pressed.connect(func(): fermer(); graffiti.call("commande_tactile", "reprendre"))
		_bas.add_child(r)
	var m := _bouton_texte("Mode : " + ("EXPERT" if graffiti.get("expert") else "SIMPLE"), 20, false)
	m.custom_minimum_size = Vector2(190, 64)
	m.pressed.connect(func(): graffiti.call("basculer_mode"); _remplir())
	_bas.add_child(m)
	var f := _bouton_texte("✕  Fermer", 22, false)
	f.custom_minimum_size = Vector2(150, 64)
	f.pressed.connect(fermer)
	_bas.add_child(f)
	if premiere and not premiere.disabled:
		premiere.grab_focus()
	else:
		f.grab_focus()


## Une vignette : l'aperçu du graffiti dans ce style, et son nom.
func _carte(style: Dictionary, i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(285, 210)
	b.focus_mode = Control.FOCUS_ALL
	_style_bouton(b, Color(0.42, 0.40, 0.44), ENCRE, 4)   # un bout de mur gris
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 8
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var cadre := Control.new()
	cadre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cadre)
	var couches: Array = graffiti.call("couches_apercu", onglet, style)
	if couches.is_empty():
		var l := Label.new()
		l.text = "LOUMS"
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 44)
		cadre.add_child(l)
	for c in couches:
		var tr := TextureRect.new()
		tr.texture = c[0]
		tr.modulate = c[1]
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadre.add_child(tr)
	var nom := Label.new()
	nom.text = style.nom
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.add_theme_font_size_override("font_size", 20)
	nom.add_theme_color_override("font_color", PAPIER)
	nom.add_theme_color_override("font_outline_color", ENCRE)
	nom.add_theme_constant_override("outline_size", 6)
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nom)
	b.pressed.connect(_peindre.bind(i))
	return b


func _choisir_onglet(ty: String) -> void:
	onglet = ty
	_remplir()


func _changer_bombe(i: int) -> void:
	graffiti.set("bombe", i)
	graffiti.set("couleur", (graffiti.get("ceinture") as Array)[i])
	_remplir()


func _peindre(i: int) -> void:
	fermer()
	graffiti.call("choisir", onglet, i)
