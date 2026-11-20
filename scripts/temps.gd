extends Node
## TRACE — le temps qui passe (J3).
## Une horloge de jeu : 1 minute de jeu par seconde réelle (une heure en une minute), qui commence
## le lundi 16 septembre 2013 à 16 h 30, à la sortie du lycée. Le soleil tourne, la lumière change,
## la nuit tombe ; les jours et les semaines passent (N : au lendemain matin, Maj+N : une semaine).
## Les graffitis vieillissent en jours de jeu. Le calendrier du décor reste en 2013.
##
## Pour n°2 (lumière, ciel, fenêtres allumées…) : la variable globale de shader « nuit » (0 le jour,
## 1 en pleine nuit) et le signal heure_changee.

signal heure_changee(minutes: float)
signal jour_change(jour: int)

const SAUVEGARDE := "user://temps.json"
const MINUTES_PAR_SECONDE := 1.0
const DEBUT := {"year": 2013, "month": 9, "day": 16, "hour": 16, "minute": 30}
const ANNEE_EN_SECONDES := 365 * 86400
const JOURS := ["Lun.", "Mar.", "Mer.", "Jeu.", "Ven.", "Sam.", "Dim."]
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

var minutes := 0.0            ## minutes de jeu écoulées depuis DEBUT
var pause := false
var visite_archive := false
var _jour := -1
var _soleil: DirectionalLight3D
var _env: Environment
var _ciel: ProceduralSkyMaterial
var _base := {}
var _texte: Label
var _debut_unix := 0
var _janvier := Time.get_unix_time_from_datetime_dict({"year": 2013, "month": 1, "day": 1})


func _ready() -> void:
	_debut_unix = Time.get_unix_time_from_datetime_dict(DEBUT)
	visite_archive = get_parent().has_meta("diderot_archives")
	if visite_archive:
		minutes = -180
		pause = true
	else:
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
	if not visite_archive and Input.is_action_just_pressed("temps_semaine"):
		avancer_jusqu_a(jour() + 7, 8.0)
	elif not visite_archive and Input.is_action_just_pressed("temps_demain") and not Input.is_key_pressed(KEY_SHIFT):
		avancer_jusqu_a(jour() + 1, 8.0)
	if not pause:
		minutes += delta * MINUTES_PAR_SECONDE
	var j := jour()
	if j != _jour:
		_jour = j
		jour_change.emit(j)
		_sauver()
	heure_changee.emit(minutes)
	_eclairer()
	_texte.text = "Diderot   ·   2013" if visite_archive else date_texte()


## Le nombre de jours depuis le 16 septembre 2013.
func jour() -> int:
	return int(floor((minutes + DEBUT.hour * 60.0 + DEBUT.minute) / 1440.0))


## L'heure de la journée, en heures (0 → 24).
func heure() -> float:
	return fmod(minutes + DEBUT.hour * 60.0 + DEBUT.minute, 1440.0) / 60.0


func date() -> Dictionary:
	var depuis_janvier := _debut_unix - _janvier + int(minutes * 60.0)
	return Time.get_datetime_dict_from_unix_time(_janvier + posmod(depuis_janvier, ANNEE_EN_SECONDES))


func date_texte() -> String:
	var d := date()
	var js: int = (int(d.weekday) + 6) % 7   # Godot : 0 = dimanche
	return "%s %d %s %d   ·   %02d:%02d" % [JOURS[js], d.day, MOIS[int(d.month) - 1], d.year, d.hour, d.minute]


## Saute au jour donné, à l'heure donnée (dormir, ou laisser passer une semaine).
func avancer_jusqu_a(j: int, h: float) -> void:
	var cible := j * 1440.0 + h * 60.0 - (DEBUT.hour * 60.0 + DEBUT.minute)
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


func _interface() -> void:
	var couche := CanvasLayer.new()
	couche.layer = 4
	add_child(couche)
	_texte = Label.new()
	_texte.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_texte.position = Vector2(-200, 8)
	_texte.custom_minimum_size = Vector2(400, 0)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.add_theme_font_size_override("font_size", 15)
	_texte.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	_texte.add_theme_color_override("font_outline_color", Color(0.10, 0.07, 0.12))
	_texte.add_theme_constant_override("outline_size", 5)
	couche.add_child(_texte)


func _sauver() -> void:
	var f := FileAccess.open(SAUVEGARDE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"minutes": minutes}))


func _charger() -> void:
	if not FileAccess.file_exists(SAUVEGARDE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAUVEGARDE))
	if d is Dictionary:
		minutes = float(d.get("minutes", 0.0))
