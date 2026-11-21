extends Node
## TRACE — le temps qui passe (J3).
## Une horloge de jeu : 1 minute de jeu par seconde réelle (une heure en une minute), qui commence
## le lundi 15 septembre 2014 à 16 h 30, à la sortie du lycée. Le soleil tourne, la lumière change,
## la nuit tombe ; les jours et les semaines passent (N : au lendemain matin, Maj+N : une semaine).
## Les graffitis vieillissent ; la tour Cyprès B est démolie le 21 juillet 2016.
##
## Pour n°2 (lumière, ciel, fenêtres allumées…) : la variable globale de shader « nuit » (0 le jour,
## 1 en pleine nuit) et le signal heure_changee.

signal heure_changee(minutes: float)
signal jour_change(jour: int)

const SAUVEGARDE := "user://temps.json"
const MINUTES_PAR_SECONDE := 1.0
const DEBUT := {"year": 2014, "month": 9, "day": 15, "hour": 16, "minute": 30}
const DEMOLITION_CYPRES := {"year": 2016, "month": 7, "day": 21}
const JOURS := ["Lun.", "Mar.", "Mer.", "Jeu.", "Ven.", "Sam.", "Dim."]
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

## Une scène d'étude peut choisir sa date sans déplacer les sauvegardes de la partie normale.
@export var calendrier_debut: Dictionary = DEBUT.duplicate()
@export var fichier_sauvegarde: String = SAUVEGARDE

var minutes := 0.0            ## minutes de jeu écoulées depuis DEBUT
var pause := false
var _jour := -1
var _soleil: DirectionalLight3D
var _env: Environment
var _ciel: ProceduralSkyMaterial
var _base := {}
var _texte: Label
var _heure_texte: Label
var _carton: Control          ## la date en grand, au début puis à chaque nouveau jour (Louma 21.11)
var _carton_t := 0.0
const CARTON_DUREE := 4.0
const JOURS_LONGS := ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
const MOIS_LONGS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
var _debut_unix := 0


func _ready() -> void:
	_debut_unix = Time.get_unix_time_from_datetime_dict(calendrier_debut)
	_charger()
	_jour = jour()
	_interface()
	_actions()
	call_deferred("_prendre_les_reperes")


func _actions() -> void:
	for a in [["temps_demain", KEY_N, false], ["temps_semaine", KEY_N, true]]:
		if InputMap.has_action(a[0]):
			continue
		InputMap.add_action(a[0])
		var ev := InputEventKey.new()
		ev.physical_keycode = a[1]
		ev.shift_pressed = a[2]
		InputMap.action_add_event(a[0], ev)


## Les valeurs de la scène (après le rendu BD de n°2) : le jour, c'est elles ; la nuit les assombrit.
func _prendre_les_reperes() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	for n in scene.find_children("*", "DirectionalLight3D", true, false):
		_soleil = n
		break
	for n in scene.find_children("*", "WorldEnvironment", true, false):
		_env = (n as WorldEnvironment).environment
		break
	if _env and _env.sky:
		_ciel = _env.sky.sky_material as ProceduralSkyMaterial
	_base = {
		"energie": _soleil.light_energy if _soleil else 1.0,
		"couleur": _soleil.light_color if _soleil else Color.WHITE,
		"ambiant": _env.ambient_light_energy if _env else 0.5,
		"brume": _env.fog_light_color if _env else Color.WHITE,
		"haut": _ciel.sky_top_color if _ciel else Color(),
		"horizon": _ciel.sky_horizon_color if _ciel else Color(),
		"sol": _ciel.ground_horizon_color if _ciel else Color(),
		"ombre": ProjectSettings.get_setting("shader_globals/bd_ombre", {}).get("value", Color(0.46, 0.4, 0.66)),
	}
	_eclairer()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("temps_semaine"):
		avancer_jusqu_a(jour() + 7, 8.0)
	elif Input.is_action_just_pressed("temps_demain") and not Input.is_key_pressed(KEY_SHIFT):
		avancer_jusqu_a(jour() + 1, 8.0)
	if not pause:
		minutes += delta * MINUTES_PAR_SECONDE
	var j := jour()
	if j != _jour:
		_jour = j
		jour_change.emit(j)
		_carton_t = 0.0
		_sauver()
		_verifier_demolition()
	heure_changee.emit(minutes)
	_eclairer()
	_carton_t += delta
	_animer_carton()


## Le nombre de jours depuis le 15 septembre 2014.
func jour() -> int:
	return int(floor((minutes + calendrier_debut.hour * 60.0 + calendrier_debut.minute) / 1440.0))


## L'heure de la journée, en heures (0 → 24).
func heure() -> float:
	return fmod(minutes + calendrier_debut.hour * 60.0 + calendrier_debut.minute, 1440.0) / 60.0


func date() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(_debut_unix + int(minutes * 60.0))


func date_texte() -> String:
	var d := date()
	var js: int = (int(d.weekday) + 6) % 7   # Godot : 0 = dimanche
	return "%s %d %s %d   ·   %02d:%02d" % [JOURS[js], d.day, MOIS[int(d.month) - 1], d.year, d.hour, d.minute]


## Saute au jour donné, à l'heure donnée (dormir, ou laisser passer une semaine).
func avancer_jusqu_a(j: int, h: float) -> void:
	var cible: float = j * 1440.0 + h * 60.0 - (calendrier_debut.hour * 60.0 + calendrier_debut.minute)
	if cible > minutes:
		minutes = cible


## 0 en plein jour, 1 en pleine nuit, avec l'aube et le crépuscule entre les deux.
func nuit() -> float:
	var h := heure()
	if h >= 7.5 and h <= 19.0:
		return 0.0
	if h > 19.0 and h < 21.0:
		return smoothstep(19.0, 21.0, h)
	if h > 6.0 and h < 7.5:
		return 1.0 - smoothstep(6.0, 7.5, h)
	return 1.0


func _eclairer() -> void:
	if _base.is_empty():
		return
	var n := nuit()
	var h := heure()
	# soleil : vraie course à Marseille (latitude 43,3°), mi-septembre (déclinaison +2,7°), midi solaire 13 h 45
	# (heure d'été). À 16 h 30 il est à ~35°, à 18 h 30 à ~12° : la lumière dorée de fin d'après-midi.
	var course := clampf((h - 7.3) / 12.6, 0.0, 1.0)
	var lat := deg_to_rad(43.3)
	var dec := deg_to_rad(2.7)
	var ha := deg_to_rad((h - 13.75) * 15.0)
	var elev := rad_to_deg(asin(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(ha)))
	var azim := rad_to_deg(atan2(sin(ha), cos(ha) * sin(lat) - tan(dec) * cos(lat)))   # depuis le sud, + vers l'ouest
	var hauteur := maxf(elev, 4.0)
	if _soleil:
		_soleil.rotation_degrees = Vector3(-hauteur, -10.0 + azim, 0.0)
		var orange := 1.0 - smoothstep(0.0, 0.25, sin(course * PI))   # lumière dorée en début et fin de journée
		var c: Color = (_base.couleur as Color).lerp(Color(1.0, 0.72, 0.45), orange * 0.6)
		_soleil.light_color = c.lerp(Color(0.55, 0.62, 0.85), n)   # la nuit : la lune, bleutée
		_soleil.light_energy = float(_base.energie) * lerpf(1.0, 0.12, n)
	if _env:
		_env.ambient_light_energy = float(_base.ambiant) * lerpf(1.0, 0.35, n)
		_env.fog_light_color = (_base.brume as Color).lerp(Color(0.10, 0.12, 0.22), n)
	if _ciel:
		_ciel.sky_top_color = (_base.haut as Color).lerp(Color(0.02, 0.03, 0.09), n)
		_ciel.sky_horizon_color = (_base.horizon as Color).lerp(Color(0.10, 0.10, 0.20), n)
		_ciel.ground_horizon_color = (_base.sol as Color).lerp(Color(0.06, 0.06, 0.12), n)
	RenderingServer.global_shader_parameter_set("bd_ombre", (_base.ombre as Color).lerp(Color(0.06, 0.06, 0.14), n * 0.9))
	if ProjectSettings.has_setting("shader_globals/nuit"):
		RenderingServer.global_shader_parameter_set("nuit", n)


## La tour Cyprès B tombe le 21 juillet 2016 : si on a passé cette date, le quartier est reconstruit sans elle.
func _verifier_demolition() -> void:
	var Q = load("res://scripts/quartier_reel.gd")
	var dem := Time.get_unix_time_from_datetime_dict(DEMOLITION_CYPRES)
	var tombee: bool = _debut_unix + int(minutes * 60.0) >= dem
	if tombee and not Q.demolies.has("Tour Cyprès B"):
		Q.demolies.append("Tour Cyprès B")
		_sauver()
		get_tree().reload_current_scene.call_deferred()


func _interface() -> void:
	var couche := CanvasLayer.new()
	couche.layer = 4
	add_child(couche)
	# Plus de date permanente en haut de l'écran : un carton au début, puis elle s'efface.
	_carton = VBoxContainer.new()
	_carton.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_carton.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_carton.offset_top = 70
	_carton.alignment = BoxContainer.ALIGNMENT_CENTER
	_carton.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carton.pivot_offset = Vector2(0, 0)
	couche.add_child(_carton)
	_texte = _ligne(50, Color(1.0, 0.82, 0.12), 14)
	_heure_texte = _ligne(30, Color(0.96, 0.28, 0.62), 10)
	_carton.add_child(_texte)
	_carton.add_child(_heure_texte)
	_carton.modulate.a = 0.0


func _ligne(taille: int, couleur: Color, contour: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.10))
	l.add_theme_constant_override("outline_size", contour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## La date en grand : elle entre en glissant, reste, puis s'efface.
func _animer_carton() -> void:
	if _carton == null:
		return
	var t := _carton_t
	if t > CARTON_DUREE + 1.0:
		if _carton.visible:
			_carton.visible = false
		return
	_carton.visible = true
	var d := date()
	var js: int = (int(d.weekday) + 6) % 7
	_texte.text = "%s %d %s %d" % [JOURS_LONGS[js], d.day, MOIS_LONGS[int(d.month) - 1], d.year]
	_heure_texte.text = "%02dh%02d" % [d.hour, d.minute]
	var entree := smoothstep(0.0, 0.45, t)
	var sortie := 1.0 - smoothstep(CARTON_DUREE, CARTON_DUREE + 1.0, t)
	_carton.modulate.a = entree * sortie
	_carton.offset_top = 70.0 - 30.0 * (1.0 - entree)
	_carton.size.x = 0.0


func _sauver() -> void:
	var f := FileAccess.open(fichier_sauvegarde, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"minutes": minutes}))


func _charger() -> void:
	if FileAccess.file_exists(fichier_sauvegarde):
		var d = JSON.parse_string(FileAccess.get_file_as_string(fichier_sauvegarde))
		if d is Dictionary:
			minutes = float(d.get("minutes", 0.0))
	var Q = load("res://scripts/quartier_reel.gd")
	if _debut_unix + int(minutes * 60.0) >= Time.get_unix_time_from_datetime_dict(DEMOLITION_CYPRES):
		if not Q.demolies.has("Tour Cyprès B"):
			Q.demolies.append("Tour Cyprès B")
	else:
		# Cette liste est statique : une autre scène a pu avancer jusqu'en 2016.
		# Revenir en 2013 restaure la tour, même sans fichier de sauvegarde.
		Q.demolies.erase("Tour Cyprès B")
