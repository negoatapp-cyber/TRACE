extends Node
## TRACE — autoload « Musique »
##
## Bande son lancée dès l'ouverture du jeu (la carte de Marseille comprise),
## avec un petit lecteur MP3 façon années 2000 en haut à gauche.
##
## - Les pistes sont lues dans res://bande_son/ et chargées UNE PAR UNE
##   (jamais toutes en mémoire en même temps) pour ne pas alourdir le jeu.
## - Ordre voulu : Fonky Family (Mystère et suspense) → Kalif Hardcore →
##   Q.U. (Hectic) → Puissance Nord → Anna ft Jul (Bando) → Loums (Bonsoir),
##   puis on reboucle. Les fichiers sont numérotés 01 à 06.
##   Chaque piste est reconnue par un mot de son nom de fichier ; une piste
##   qui ne correspond à rien passe à la fin.
## - Toucher l'écran vert = couper / remettre le son.
## - Clavier : F6 piste précédente, F7 pause, F8 piste suivante.
##
## À déclarer dans project.godot, section [autoload] :
##   Musique="*res://bande son/musique.gd"

const DOSSIERS := ["res://bande_son/", "res://bande son/", "res://Bande son/", "res://bandeson/", "res://musique/"]
const EXTENSIONS := ["ogg", "mp3", "wav"]
const ORDRE := [
	["myst", "suspense"],
	["kalif", "calif", "hardcore"],
	["q.u", "hectic"],
	["puissance"],
	["anna", "bando"],
	["loum", "loom"],
]
const BUS := "Musique"
const VOLUME_DB := -8.0

# Couleurs du lecteur (plastique argenté, boutons bleus, écran LCD vert)
const C_COQUE := Color(0.80, 0.83, 0.88)
const C_BORD := Color(0.16, 0.22, 0.38)
const C_LCD := Color(0.64, 0.76, 0.45)
const C_LCD_BORD := Color(0.20, 0.27, 0.18)
const C_LCD_ENCRE := Color(0.10, 0.17, 0.07)
const C_BOUTON := Color(0.25, 0.42, 0.78)
const C_BOUTON_ENFONCE := Color(0.14, 0.26, 0.55)
const SEPARATEUR := "   --   "

var pistes: Array[String] = []
var index := -1
var lecteur: AudioStreamPlayer

var _muet := false
var _calque: CanvasLayer
var _fenetre_titre: Control
var _titre: Label
var _infos: Label
var _glyphe_lecture: Control
var _largeur_cycle := 0.0
var _defile := 0.0
var _derniere_seconde := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preparer_bus()
	lecteur = AudioStreamPlayer.new()
	lecteur.bus = BUS
	lecteur.volume_db = VOLUME_DB
	add_child(lecteur)
	lecteur.finished.connect(suivante)
	pistes = _construire_playlist()
	_construire_lecteur()
	if pistes.is_empty():
		push_warning("Musique : aucune piste trouvée dans res://bande_son/")
		_afficher_titre("PAS DE MUSIQUE")
		return
	jouer(0)


# ---------------------------------------------------------------- lecture

func jouer(i: int) -> void:
	if pistes.is_empty():
		return
	index = posmod(i, pistes.size())
	var flux := load(pistes[index]) as AudioStream
	if flux == null:
		push_warning("Musique : impossible de lire " + pistes[index])
		_afficher_titre("ERREUR")
		return
	if "loop" in flux:
		flux.set("loop", false)
	lecteur.stream = flux
	lecteur.stream_paused = false
	lecteur.play()
	_afficher_titre(_titre_de(pistes[index]))
	_derniere_seconde = -1
	_glyphe_lecture.queue_redraw()


func suivante() -> void:
	jouer(index + 1)


func precedente() -> void:
	# Comme sur un vrai baladeur : au-delà de 3 s, on revient au début du morceau.
	if lecteur.playing and lecteur.get_playback_position() > 3.0:
		lecteur.seek(0.0)
	else:
		jouer(index - 1)


func basculer_pause() -> void:
	if lecteur.stream == null:
		return
	if not lecteur.playing and not lecteur.stream_paused:
		lecteur.play()
	else:
		lecteur.stream_paused = not lecteur.stream_paused
	_derniere_seconde = -1
	_glyphe_lecture.queue_redraw()


func basculer_muet() -> void:
	_muet = not _muet
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), _muet)
	_derniere_seconde = -1


## Pour les autres systèmes (ex. masquer le lecteur pendant un tracé de graffiti).
func afficher_lecteur(visible_: bool) -> void:
	if _calque:
		_calque.visible = visible_


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_F6:
				precedente()
			KEY_F7:
				basculer_pause()
			KEY_F8:
				suivante()


func _process(delta: float) -> void:
	if _titre == null:
		return
	# Titre qui défile sur l'écran LCD
	if _largeur_cycle > 0.0:
		_defile = fmod(_defile + delta * 24.0, _largeur_cycle)
		_titre.position.x = -_defile
	# Numéro de piste + temps
	var s := int(lecteur.get_playback_position()) if lecteur.playing else 0
	if s != _derniere_seconde:
		_derniere_seconde = s
		var etat := "%d:%02d" % [s / 60, s % 60]
		if _muet:
			etat = "MUET"
		elif lecteur.stream_paused:
			etat = "PAUSE"
		var n := pistes.size()
		_infos.text = "%02d/%02d   %s" % [index + 1, n, etat] if n > 0 else "--/--"


# ---------------------------------------------------------------- playlist

func _construire_playlist() -> Array[String]:
	var fichiers: Array[String] = []
	for d in DOSSIERS:
		fichiers = _lister(d)
		if not fichiers.is_empty():
			break
	fichiers.sort()
	var ordonnees: Array[String] = []
	for mots in ORDRE:
		for f in fichiers:
			if ordonnees.has(f):
				continue
			var nom := _normaliser(f.get_file())
			var trouve := false
			for m in mots:
				if nom.contains(m):
					trouve = true
					break
			if trouve:
				ordonnees.append(f)
				break
	for f in fichiers:
		if not ordonnees.has(f):
			ordonnees.append(f)
	return ordonnees


func _lister(dossier: String) -> Array[String]:
	var res: Array[String] = []
	var noms := PackedStringArray()
	if ResourceLoader.has_method("list_directory"):
		noms = ResourceLoader.call("list_directory", dossier)
	elif DirAccess.dir_exists_absolute(dossier):
		noms = DirAccess.get_files_at(dossier)
	for brut in noms:
		# Dans le jeu exporté, les fichiers apparaissent en .import / .remap
		var n: String = String(brut).trim_suffix(".remap").trim_suffix(".import")
		if EXTENSIONS.has(n.get_extension().to_lower()):
			var chemin := dossier + n
			if not res.has(chemin):
				res.append(chemin)
	return res


func _normaliser(s: String) -> String:
	s = s.to_lower()
	for paire in [["é", "e"], ["è", "e"], ["ê", "e"], ["à", "a"], ["â", "a"], ["ç", "c"], ["ô", "o"], ["î", "i"], ["ï", "i"], ["ù", "u"]]:
		s = s.replace(paire[0], paire[1])
	return s


func _titre_de(chemin: String) -> String:
	var t := chemin.get_file().get_basename().replace("_", " ").strip_edges()
	# retire un éventuel numéro en tête (« 01 », « 2. »…)
	var i := 0
	while i < t.length() and (t[i].is_valid_int() or t[i] == "." or t[i] == " "):
		i += 1
	if i < t.length():
		t = t.substr(i)
	return t.to_upper()


# ---------------------------------------------------------------- lecteur MP3

func _afficher_titre(t: String) -> void:
	var police := _titre.get_theme_font("font")
	var taille := _titre.get_theme_font_size("font_size")
	var largeur := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	_defile = 0.0
	_titre.position.x = 0.0
	if largeur > _fenetre_titre.size.x - 2.0:
		_titre.text = t + SEPARATEUR + t
		_largeur_cycle = police.get_string_size(t + SEPARATEUR, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	else:
		_titre.text = t
		_largeur_cycle = 0.0


func _construire_lecteur() -> void:
	_calque = CanvasLayer.new()
	_calque.layer = 60
	add_child(_calque)

	var coque := Panel.new()
	coque.position = Vector2(12, 12)
	coque.size = Vector2(244, 66)
	coque.mouse_filter = Control.MOUSE_FILTER_STOP
	coque.add_theme_stylebox_override("panel", _boite(C_COQUE, C_BORD, 2, 12, true))
	_calque.add_child(coque)

	# Reflet du plastique brillant
	var reflet := Panel.new()
	reflet.position = Vector2(5, 3)
	reflet.size = Vector2(234, 16)
	reflet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reflet.add_theme_stylebox_override("panel", _boite(Color(1, 1, 1, 0.5), Color(0, 0, 0, 0), 0, 9, false))
	coque.add_child(reflet)

	# Écran LCD
	var lcd := Panel.new()
	lcd.position = Vector2(8, 8)
	lcd.size = Vector2(132, 50)
	lcd.add_theme_stylebox_override("panel", _boite(C_LCD, C_LCD_BORD, 2, 4, false))
	lcd.gui_input.connect(_lcd_touche)
	coque.add_child(lcd)

	_fenetre_titre = Control.new()
	_fenetre_titre.position = Vector2(6, 4)
	_fenetre_titre.size = Vector2(120, 20)
	_fenetre_titre.clip_contents = true
	_fenetre_titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lcd.add_child(_fenetre_titre)

	_titre = _etiquette(14, C_LCD_ENCRE)
	_fenetre_titre.add_child(_titre)

	_infos = _etiquette(12, C_LCD_ENCRE)
	_infos.position = Vector2(6, 26)
	_infos.text = "--/--"
	lcd.add_child(_infos)

	# Boutons
	_bouton(coque, Vector2(146, 8), "prec", precedente)
	_glyphe_lecture = _bouton(coque, Vector2(176, 8), "lecture", basculer_pause)
	_bouton(coque, Vector2(206, 8), "suiv", suivante)

	var marque := _etiquette(11, C_BORD)
	marque.text = "TRACE  MP3"
	marque.position = Vector2(150, 40)
	coque.add_child(marque)


func _etiquette(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bouton(parent: Control, pos: Vector2, type: String, action: Callable) -> Control:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(26, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _boite(C_BOUTON, C_BORD, 2, 13, true))
	b.add_theme_stylebox_override("hover", _boite(C_BOUTON.lightened(0.15), C_BORD, 2, 13, true))
	b.add_theme_stylebox_override("pressed", _boite(C_BOUTON_ENFONCE, C_BORD, 2, 13, false))
	b.pressed.connect(action)
	parent.add_child(b)
	# Les symboles sont dessinés (la police du jeu n'a pas les flèches)
	var g := Control.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.draw.connect(_dessiner_glyphe.bind(g, type))
	b.add_child(g)
	return g


func _dessiner_glyphe(g: Control, type: String) -> void:
	var c := g.size * 0.5
	var blanc := Color(1, 1, 1)
	match type:
		"prec":
			g.draw_rect(Rect2(c.x - 7, c.y - 5, 2, 10), blanc)
			g.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 5, c.y), Vector2(c.x + 5, c.y - 5), Vector2(c.x + 5, c.y + 5)]), blanc)
		"suiv":
			g.draw_rect(Rect2(c.x + 5, c.y - 5, 2, 10), blanc)
			g.draw_colored_polygon(PackedVector2Array([Vector2(c.x + 5, c.y), Vector2(c.x - 5, c.y - 5), Vector2(c.x - 5, c.y + 5)]), blanc)
		"lecture":
			if lecteur.playing and not lecteur.stream_paused:
				g.draw_rect(Rect2(c.x - 5, c.y - 6, 3, 12), blanc)
				g.draw_rect(Rect2(c.x + 2, c.y - 6, 3, 12), blanc)
			else:
				g.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 4, c.y - 6), Vector2(c.x + 6, c.y), Vector2(c.x - 4, c.y + 6)]), blanc)


func _lcd_touche(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		basculer_muet()


func _boite(fond: Color, bord: Color, epaisseur: int, rayon: int, ombre: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(epaisseur)
	s.set_corner_radius_all(rayon)
	s.anti_aliasing = true
	if ombre:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 3
		s.shadow_offset = Vector2(0, 2)
	return s


func _preparer_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "Master")
