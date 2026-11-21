extends Node3D
## TRACE — l'intro du jeu : Marseille entière en 3D, dessinée comme le jeu (aplats, lumière BD, encre).
## Données de l'atlas (branche feature/marseille-explorable) : relief IGN, bâti OSM, 111 quartiers.
## On tourne, on zoome, on incline, on se promène ; on touche un quartier pour le voir.
## Le quartier jouable (les Lauriers) brille en vert : « JOUER » plonge dessus et lance la partie.
## Navigation harmonisée (Louma 21.11), comme Google Maps :
##   doigts : un doigt = se déplacer · pincer / écarter = zoom · deux doigts qui tournent = pivoter
##            deux doigts qui montent / descendent ensemble = incliner (relief 3D) · double toucher = zoomer là · toucher = choisir
##            boutons au téléphone : jour/nuit et vue d'ensemble seulement
##   souris : clic gauche glissé = tourner (gauche / droite) et incliner (haut / bas) · clic droit ou milieu glissé = se déplacer
##            molette ou pincement du pavé tactile = zoom · boutons + / − · clic = choisir
##   jour/nuit : de jour à l'ouverture, le choix est gardé (Louma : « à chaque fois qu'on ouvre, c'est direct la nuit »)
##   clavier : flèches/ZQSD = se déplacer · A/E = tourner · R/F = incliner · +/- = zoom · Entrée = jouer

const VILLE := preload("res://scripts/ville_terrain.gd")
const POLICE := preload("res://assets/decor/polices/Anton-Regular.ttf")
const JEU := "res://scenes/marseille_2013.tscn"
const ZONE := Rect2(-125, -325, 400, 600)        ## le quartier jouable (bords de quartier_reel.gd)
const VERT := Color(0.30, 1.0, 0.48)
const ENCRE := Color(0.13, 0.08, 0.18)
const JAUNE := Color(1.0, 0.84, 0.18)
const PAPIER := Color(1.0, 0.95, 0.84)
const MER := Color(0.20, 0.58, 0.80)
const DIST_MIN := 180.0
const DIST_MAX := 26000.0
const PLONGEE := 2.6
## Murs et toits de la ville : crème, ocre, rose béton, terre cuite (palette du jeu).
## Les grandes cités (Louma 21.11 : « c'est pas qu'une histoire de quartier, c'est une histoire de cité aussi »).
## [nom, latitude, longitude, arrondissement] ; projetées comme l'atlas (aeqd centré 43,3268 N 5,412 E).
## Sources : Wikipédia (La Castellane), arrêts OpenStreetMap (Busserine, Plan d'Aou, Savine, Kalliste, Félix Pyat) ;
## Font-Vert, Frais-Vallon et Air-Bel sont placés à quelques centaines de mètres près, à vérifier à l'œil.
const CITES := [
	["La Castellane", 43.3670, 5.3420, 16], ["Plan d'Aou", 43.3689, 5.3522, 15], ["La Savine", 43.3667, 5.3720, 15],
	["Parc Kalliste", 43.3848, 5.3648, 15], ["La Busserine", 43.3321, 5.3987, 14], ["Font-Vert", 43.3375, 5.3940, 14],
	["Frais-Vallon", 43.3170, 5.4165, 13], ["Air-Bel", 43.2895, 5.4310, 11], ["Félix Pyat", 43.3160, 5.3740, 3],
]
const ROSE := Color(1.0, 0.36, 0.62)
const FICHIER_NUIT := "user://accueil_nuit.txt"
const MURS := [Color("#f3e2be"), Color("#eecf98"), Color("#e9b9a1"), Color("#f6eadb"), Color("#e7a96f"), Color("#f0d5c6"), Color("#d9c7e8")]
const TOITS := [Color("#d27b52"), Color("#c76a4a"), Color("#e09464"), Color("#b9a9c9"), Color("#d8c4a6")]

var ville: Node3D
var _cam: Camera3D
# ce qu'on vise (les valeurs affichées les rejoignent en douceur)
var _cible_v := Vector3.ZERO
var _lacet_v := 0.5
var _tangage_v := 0.95
var _dist_v := 17000.0
var _cible := Vector3.ZERO
var _lacet := 0.5
var _tangage := 0.95
var _dist := 17000.0
var _elan := Vector2.ZERO               ## inertie du glisser (rotation)
var _inactif := 0.0
var _doigts := {}
var _ecart := 0.0
var _angle_doigts := 0.0
var _appui := Vector2(-1, -1)          ## où le doigt / la souris s'est posé (un toucher sans glisser = choisir)
var _bouge := 0.0
var _plonge_t := -1.0
var _de := {}
var _ui: CanvasLayer
var _noms: Array = []                   ## [Label, position, niveau] : 0 = arrondissement, 1 = quartier
var _nous: Control
var _carte: PanelContainer
var _carte_titre: Label
var _carte_sous: Label
var _carte_texte: Label
var _jouer: Button
var _lueur: Array[MeshInstance3D] = []
var _t := 0.0
var _rayon_tuiles := -2
var _glisse := Vector2.ZERO             ## inertie du déplacement (m/s au sol)
var _dernier_toucher := -10.0
var _milieu := Vector2.ZERO
var _geste := ""                        ## à deux doigts : "zoom" (pincer, tourner) ou "incliner"
var _geste_cumul := Vector3.ZERO
var _nuit := 0.0
var _nuit_v := 0.0
var _env: Environment
var _ciel: ProceduralSkyMaterial
var _soleil: DirectionalLight3D
var _mat_mer: ShaderMaterial
var _bouton_nuit: Button
var _titre: Label
var _sous: Label
var _aide: Label
var _portrait := false
var _mobile := false
var _sol_y := 0.0                       ## hauteur du sol sous la cible, lissée (pas de sauts sur les collines)
var _pivot := Vector2(-1, -1)           ## clic droit : on tourne autour du point visé
var _icones: Array[Control] = []
var _liste: PanelContainer
var _arrs := {}
var _centre_ville := Vector2.INF


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("bd_actif", 1.0)
	_mobile = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	# les boutons de l'interface ne réagissent qu'aux clics : au doigt, Godot doit simuler la souris
	Input.emulate_mouse_from_touch = true
	if _mobile:
		get_viewport().scaling_3d_scale = 0.6   # téléphone : la 3D en plus petit, l'interface nette
	_environnement()
	ville = Node3D.new()
	ville.set_script(VILLE)
	ville.set("shader_bati", preload("res://shaders/accueil_bati.gdshader"))
	ville.set("shader_sol", preload("res://shaders/accueil_sol.gdshader"))
	ville.set("carte_sol", "carte_bd.png")
	ville.set("teintes_murs", MURS)
	ville.set("teintes_toits", TOITS)
	ville.name = "Ville"
	add_child(ville)
	_mer()
	_cam = Camera3D.new()
	_cam.far = 90000.0
	_cam.near = 2.0
	_cam.fov = 42.0
	add_child(_cam)
	_cam.make_current()
	if not _mobile:
		_encrage()
	var d: Rect2 = ville.get("domaine")
	_cible_v = Vector3(d.get_center().x, 0.0, d.get_center().y + d.size.y * 0.04)
	_dist_v = d.size.y * 0.7
	_tangage_v = 0.82
	_cible = _cible_v
	_dist = _dist_v * 1.8     # on arrive de plus haut : la ville se rapproche à l'ouverture
	_tangage = 1.35
	_nuit_v = 0.0   # de jour à l'ouverture, sauf si on a choisi la nuit la dernière fois
	if FileAccess.file_exists(FICHIER_NUIT):
		_nuit_v = 1.0 if FileAccess.get_file_as_string(FICHIER_NUIT).strip_edges() == "1" else 0.0
	_nuit = _nuit_v
	_lacet = _lacet_v - 0.6
	_poser_lueur()
	_interface()
	_portrait = DisplayServer.window_get_size().y > DisplayServer.window_get_size().x
	_vue_generale()
	_cible = _cible_v
	_dist = _dist_v * 1.8
	_sol_y = float(ville.call("altitude", _cible.x, _cible.z))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if has_node("/root/TouchControls"):
		get_node("/root/TouchControls").visible = false
	get_viewport().size_changed.connect(_mise_en_page)
	_mise_en_page()
	_appliquer_nuit()
	_placer()


func _exit_tree() -> void:
	get_tree().root.content_scale_size = Vector2i(1600, 900)
	Input.emulate_mouse_from_touch = bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", false))
	get_viewport().scaling_3d_scale = 1.0
	if has_node("/root/TouchControls"):
		get_node("/root/TouchControls").visible = true


## Téléphone tenu droit : l'interface est dessinée pour ~620 px de large (sinon tout est minuscule).
func _mise_en_page() -> void:
	var fen := DisplayServer.window_get_size()
	var portrait := fen.y > fen.x
	var voulu := Vector2i(620, 1100) if portrait else Vector2i(1600, 900)
	if get_tree().root.content_scale_size != voulu:
		get_tree().root.content_scale_size = voulu
	_portrait = portrait
	if _carte == null:
		return
	if portrait:
		_carte.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_carte.offset_left = 14
		_carte.offset_right = -14
		_carte.offset_top = -290
		_carte.offset_bottom = -78   # au-dessus de la barre de navigation du téléphone
		_titre.add_theme_font_size_override("font_size", 64)
		_sous.position = Vector2(30, 88)
		_sous.add_theme_font_size_override("font_size", 17)
		_aide.visible = false
	else:
		_carte.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_carte.offset_left = -330
		_carte.offset_right = 330
		_carte.offset_top = -210
		_carte.offset_bottom = -24
		_titre.add_theme_font_size_override("font_size", 92)
		_sous.position = Vector2(34, 122)
		_sous.add_theme_font_size_override("font_size", 22)
		_aide.visible = true


func _environnement() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	_env = env
	var ciel := ProceduralSkyMaterial.new()
	_ciel = ciel
	ciel.sky_top_color = Color(0.13, 0.42, 0.90)
	ciel.sky_horizon_color = Color(1.0, 0.80, 0.55)
	ciel.ground_horizon_color = Color(1.0, 0.80, 0.55)
	ciel.ground_bottom_color = MER
	ciel.sky_curve = 0.12
	env.sky = Sky.new()
	env.sky.sky_material = ciel
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.9, 1.0)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.82, 0.62)
	env.fog_density = 0.000007
	env.fog_sky_affect = 0.0
	env.glow_enabled = not _mobile
	env.glow_intensity = 0.7
	env.glow_bloom = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	_soleil = soleil
	soleil.rotation_degrees = Vector3(-34, -40, 0)
	soleil.light_color = Color(1.0, 0.93, 0.80)
	soleil.light_energy = 1.0
	add_child(soleil)


## L'encrage BD (traits sur les silhouettes) posé sur la caméra, comme en jeu.
func _encrage() -> void:
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var chemin := "res://shaders/bd_encrage_web.gdshader" if compat else "res://shaders/bd_encrage.gdshader"
	if not ResourceLoader.exists(chemin):
		return
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = load(chemin)
	mat.set_shader_parameter("loin", 6000.0)
	mat.set_shader_parameter("pres", 5.0)
	mat.set_shader_parameter("epaisseur", 1.1)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.extra_cull_margin = 16384.0
	m.position = Vector3(0, 0, -1)
	_cam.add_child(m)


## La mer : un aplat bleu au niveau 0 (le relief de l'atlas est décalé de −90 m), rides dessinées.
func _mer() -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160000, 160000)
	m.mesh = pm
	var mat := ShaderMaterial.new()
	var s := Shader.new()
	s.code = """
shader_type spatial;
#include "res://shaders/bd_lumiere.gdshaderinc"
uniform vec4 mer : source_color;
varying vec3 monde;
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// des vaguelettes en petits traits clairs, comme au feutre
	vec2 p = monde.xz / vec2(260.0, 90.0);
	vec2 c = fract(p) - 0.5;
	float h = fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
	float trait = step(abs(c.y + sin(c.x * 6.0 + TIME + h * 6.0) * 0.06), 0.035) * step(abs(c.x), 0.22) * step(0.55, h);
	ALBEDO = mix(mer.rgb, vec3(0.75, 0.9, 1.0), trait * 0.7);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	mat.shader = s
	mat.set_shader_parameter("mer", MER)
	_mat_mer = mat
	m.material_override = mat
	m.position.y = -91.5   # sous la côte : au large seulement (la mer près des côtes est peinte par le sol)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


## Le rideau de lumière verte autour du quartier jouable (fort au sol, qui s'efface en montant).
func _poser_lueur() -> void:
	var coins := [ZONE.position, Vector2(ZONE.end.x, ZONE.position.y), ZONE.end, Vector2(ZONE.position.x, ZONE.end.y)]
	var mat := ShaderMaterial.new()
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec4 couleur : source_color;
uniform float pouls = 1.0;
void fragment() {
	float bas = smoothstep(0.0, 1.0, UV.y);
	float stries = 0.65 + 0.35 * sin(UV.x * 140.0 - TIME * 2.0);
	ALBEDO = couleur.rgb * bas * bas * stries * pouls;
}
"""
	mat.shader = s
	mat.set_shader_parameter("couleur", VERT)
	var y0: float = float(ville.call("altitude", ZONE.get_center().x, ZONE.get_center().y)) - 20.0
	var haut := 220.0
	for i in 4:
		var a: Vector2 = coins[i]
		var b: Vector2 = coins[(i + 1) % 4]
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(a.distance_to(b), haut)
		m.mesh = q
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mil := (a + b) * 0.5
		m.position = Vector3(mil.x, y0 + haut * 0.5, mil.y)
		m.rotation.y = atan2(-(b.y - a.y), b.x - a.x)
		add_child(m)
		_lueur.append(m)


# ───────────────────────── interface ─────────────────────────

func _interface() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	# noms : les 16 arrondissements de loin, les 111 quartiers de près
	var info: Dictionary = ville.get("info")
	var arr := {}
	for l in info.labels:
		var n := int(l[1])
		if not arr.has(n):
			arr[n] = [Vector2.ZERO, 0]
		arr[n][0] += Vector2(l[2], l[3])
		arr[n][1] += 1
		var q := _label(String(l[0]).to_upper(), 17, PAPIER, 6)
		q.add_theme_constant_override("shadow_offset_x", 2)
		q.add_theme_constant_override("shadow_offset_y", 2)
		q.add_theme_color_override("font_shadow_color", ENCRE)
		_ui.add_child(q)
		_noms.append([q, Vector2(l[2], l[3]), 1, String(l[0]), n])
	var cites: Array = []
	for c in CITES:
		var lat: float = c[1]
		var lon: float = c[2]
		var pos := Vector2((lon - 5.412) * cos(deg_to_rad(43.3268)) * 111320.0, -(lat - 43.3268) * 110574.0)
		var lc := _label(String(c[0]).to_upper(), 20, ROSE, 7)
		lc.add_theme_constant_override("shadow_offset_x", 2)
		lc.add_theme_constant_override("shadow_offset_y", 2)
		lc.add_theme_color_override("font_shadow_color", ENCRE)
		_ui.add_child(lc)
		cites.append([lc, pos, 2, String(c[0]), int(c[3])])
	_noms = cites + _noms   # les cités passent avant les quartiers quand la place manque
	if arr.has(1):
		_centre_ville = arr[1][0] / arr[1][1]
	for n in arr:
		_arrs[n] = arr[n][0] / arr[n][1]
		var e := _label("%d%s" % [n, "er" if n == 1 else "e"], 44, JAUNE, 12)
		_ui.add_child(e)
		_noms.append([e, arr[n][0] / arr[n][1], 0, "", n])
	# le quartier jouable : une étiquette-tag verte, qu'on peut toucher
	_nous = _tag("★ LES LAURIERS — JOUABLE", VERT.darkened(0.25))
	_ui.add_child(_nous)
	(_nous as Button).pressed.connect(_choisir_lauriers)
	# titre
	var titre := _label("TRACE", 92, Color.WHITE, 18)
	_titre = titre
	titre.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	titre.position = Vector2(28, 8)
	_ui.add_child(titre)
	var sous := _label("MARSEILLE · SEPTEMBRE 2013", 22, JAUNE, 8)
	_sous = sous
	sous.position = Vector2(34, 122)
	_ui.add_child(sous)
	# commandes à l'écran : des pictos dessinés (les symboles Unicode n'existent pas dans la police du jeu)
	var boutons := VBoxContainer.new()
	boutons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	boutons.offset_left = -84
	boutons.offset_right = -14
	boutons.offset_top = -300
	boutons.offset_bottom = 230
	boutons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boutons.add_theme_constant_override("separation", 10)
	_ui.add_child(boutons)
	# Louma 21.11 : au doigt et à la souris on tourne, incline et zoome déjà ; restent les boutons utiles.
	# Au téléphone : vue d'ensemble et jour/nuit seulement. Sur ordinateur : + et − en plus, et la liste.
	var tactile: bool = TouchControls.actif or _mobile
	var liste_b: Array = [["maison", _vue_generale], ["nuit", _basculer_nuit]]
	if not tactile:
		liste_b = [["plus", func(): _dist_v = clampf(_dist_v * 0.5, DIST_MIN, DIST_MAX)],
				["moins", func(): _dist_v = clampf(_dist_v * 2.0, DIST_MIN, DIST_MAX)],
				["maison", _vue_generale],
				["liste", func(): _liste.visible = not _liste.visible],
				["nuit", _basculer_nuit]]
	for b in liste_b:
		var bt := _icone(b[0])
		bt.pressed.connect(func(): _inactif = 0.0; b[1].call(); _redessiner())
		boutons.add_child(bt)
		if b[0] == "nuit":
			_bouton_nuit = bt
	if tactile:
		# deux petits ronds en haut à droite, loin des pouces
		boutons.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		boutons.offset_left = -84
		boutons.offset_right = -14
		boutons.offset_top = 150
		boutons.offset_bottom = 310
	# la liste des arrondissements : on choisit, la caméra y vole
	_liste = PanelContainer.new()
	_liste.add_theme_stylebox_override("panel", _boite(PAPIER, ENCRE, 5, 16))
	_liste.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_liste.offset_left = -330
	_liste.offset_right = -96
	_liste.offset_top = -300
	_liste.offset_bottom = 230
	_liste.visible = false
	_ui.add_child(_liste)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_liste.add_child(defile)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	defile.add_child(col)
	var lau := _tag("★ LES LAURIERS", VERT.darkened(0.25))
	lau.pressed.connect(func(): _liste.visible = false; _choisir_lauriers(true))
	col.add_child(lau)
	var ns := _arrs.keys()
	ns.sort()
	for n in ns:
		var t := _tag("%d%s ARRONDISSEMENT" % [n, "ER" if n == 1 else "E"], Color(0.42, 0.24, 0.55))
		t.add_theme_font_size_override("font_size", 19)
		var c: Vector2 = _arrs[n]
		t.pressed.connect(func(): _liste.visible = false; _voler_vers(Vector3(c.x, 0, c.y), 3800.0))
		col.add_child(t)
	# la fiche du quartier choisi
	_carte = PanelContainer.new()
	_carte.add_theme_stylebox_override("panel", _boite(PAPIER, ENCRE, 6, 18))
	_carte.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_carte.offset_top = -210
	_carte.offset_bottom = -24
	_carte.offset_left = -330
	_carte.offset_right = 330
	_ui.add_child(_carte)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_carte.add_child(v)
	_carte_titre = _label("", 40, ENCRE, 0)
	v.add_child(_carte_titre)
	_carte_sous = _label("", 18, Color(0.45, 0.25, 0.5), 0)
	v.add_child(_carte_sous)
	_carte_texte = Label.new()
	_carte_texte.autowrap_mode = TextServer.AUTOWRAP_WORD
	_carte_texte.add_theme_font_size_override("font_size", 17)
	_carte_texte.add_theme_color_override("font_color", ENCRE)
	v.add_child(_carte_texte)
	_jouer = Button.new()
	_jouer.text = "JOUER"
	_jouer.add_theme_font_override("font", POLICE)
	_jouer.add_theme_font_size_override("font_size", 34)
	_jouer.add_theme_color_override("font_color", Color.WHITE)
	_jouer.add_theme_color_override("font_hover_color", Color.WHITE)
	_jouer.add_theme_stylebox_override("normal", _boite(Color(0.10, 0.6, 0.28), ENCRE, 5, 30))
	_jouer.add_theme_stylebox_override("hover", _boite(Color(0.16, 0.76, 0.36), ENCRE, 5, 30))
	_jouer.add_theme_stylebox_override("pressed", _boite(Color(0.16, 0.76, 0.36), ENCRE, 5, 30))
	_jouer.add_theme_stylebox_override("focus", _boite(Color(0.16, 0.76, 0.36), ENCRE, 5, 30))
	_jouer.pressed.connect(entrer)
	v.add_child(_jouer)
	_choisir_lauriers(false)
	var aide := _label("un doigt : se déplacer · pince : zoom · deux doigts : tourner, incliner · touche un quartier" if TouchControls.actif else "glisser : tourner, incliner · clic droit glissé ou flèches : se déplacer · molette, pavé ou + / − : zoom · clic : choisir", 15, Color.WHITE, 5)
	_aide = aide
	aide.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	aide.offset_left = -760
	aide.offset_right = -20
	aide.offset_top = 16
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(aide)


func _label(s: String, taille: int, c: Color, contour: int) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", POLICE)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", ENCRE)
	l.add_theme_constant_override("outline_size", contour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _tag(s: String, fond: Color) -> Button:
	var b := Button.new()
	b.text = s
	b.add_theme_font_override("font", POLICE)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _boite(fond, ENCRE, 4, 8))
	b.add_theme_stylebox_override("hover", _boite(fond.lightened(0.15), ENCRE, 4, 8))
	b.add_theme_stylebox_override("pressed", _boite(fond.lightened(0.15), ENCRE, 4, 8))
	b.add_theme_stylebox_override("focus", _boite(fond.lightened(0.15), ENCRE, 4, 8))
	return b


func _icone(nom: String) -> Button:
	var b := _rond("")
	var d := Control.new()
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.draw.connect(func(): _dessiner(d, nom))
	b.add_child(d)
	_icones.append(d)
	return b


func _sur_interface(p: Vector2) -> bool:
	var zones: Array = [_carte, _liste, _nous]
	for d in _icones:
		zones.append(d.get_parent())
	for z in zones:
		if z and (z as Control).is_visible_in_tree() and (z as Control).get_global_rect().has_point(p):
			return true
	return false


func _redessiner() -> void:
	for d in _icones:
		d.queue_redraw()


func _dessiner(d: Control, nom: String) -> void:
	var c := d.size * 0.5
	var r := minf(d.size.x, d.size.y) * 0.24
	var w := 4.0
	match nom:
		"plus":
			d.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), ENCRE, w)
			d.draw_line(c - Vector2(0, r), c + Vector2(0, r), ENCRE, w)
		"moins":
			d.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), ENCRE, w)
		"gauche", "droite":
			var s := -1.0 if nom == "gauche" else 1.0
			var a0 := -PI * 0.15
			var a1 := PI * 1.2
			d.draw_arc(c, r, a0, a1, 24, ENCRE, w)
			# pointe de flèche au bout de l'arc, côté choisi
			var a := a0 if s > 0 else a1
			var bout := c + Vector2(cos(a), sin(a)) * r
			var tan := Vector2(-sin(a), cos(a)) * (-s)
			var nrm := Vector2(cos(a), sin(a))
			d.draw_colored_polygon(PackedVector2Array([bout + tan * 9.0, bout - nrm * 7.0, bout + nrm * 7.0]), ENCRE)
		"3d":
			var t := "2D" if _tangage_v < 0.95 else "3D"
			d.draw_string(POLICE, c + Vector2(-15, 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ENCRE)
		"maison":
			var pts := PackedVector2Array([c + Vector2(-r, -0.1 * r), c + Vector2(0, -r), c + Vector2(r, -0.1 * r),
				c + Vector2(0.75 * r, -0.1 * r), c + Vector2(0.75 * r, r), c + Vector2(-0.75 * r, r), c + Vector2(-0.75 * r, -0.1 * r)])
			d.draw_colored_polygon(pts, ENCRE)
		"liste":
			for k in 3:
				var y := (k - 1) * r * 0.75
				d.draw_line(c + Vector2(-r, y), c + Vector2(r, y), ENCRE, w)
		"nuit":
			if _nuit_v > 0.5:   # la nuit : le bouton propose le soleil
				d.draw_circle(c, r * 0.55, ENCRE)
				for k in 8:
					var a := k * TAU / 8.0
					d.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.78, c + Vector2(cos(a), sin(a)) * r * 1.1, ENCRE, 3.0)
			else:
				d.draw_circle(c, r * 0.9, ENCRE)
				var fond: Color = (d.get_parent() as Button).get_theme_stylebox("normal").bg_color
				d.draw_circle(c + Vector2(r * 0.45, -r * 0.3), r * 0.75, fond)


func _rond(s: String) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size = Vector2(62, 62)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", ENCRE)
	b.add_theme_color_override("font_hover_color", ENCRE)
	b.add_theme_stylebox_override("normal", _boite(PAPIER, ENCRE, 4, 31))
	b.add_theme_stylebox_override("hover", _boite(JAUNE, ENCRE, 4, 31))
	b.add_theme_stylebox_override("pressed", _boite(JAUNE, ENCRE, 4, 31))
	b.add_theme_stylebox_override("focus", _boite(PAPIER, ENCRE, 4, 31))
	return b


func _boite(c: Color, bord: Color, epais: int, rayon: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(rayon)
	s.set_border_width_all(epais)
	s.border_color = bord
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(ENCRE, 0.9)
	s.shadow_size = 0
	s.shadow_offset = Vector2(5, 5)
	return s


## La fiche d'un quartier : le quartier jouable, ou un autre (« pas encore »).
func _fiche(titre: String, sous: String, texte: String, jouable: bool) -> void:
	_carte_titre.text = titre
	_carte_sous.text = sous
	_carte_texte.text = texte
	_jouer.visible = jouable
	_carte.visible = true


func _choisir_lauriers(voler := true) -> void:
	_fiche("LES LAURIERS", "Malpassé · 13e arrondissement · le quartier de Loums",
		"Les barres, la tour Cyprès B, la rue de Marathon, le lycée Diderot. C'est ici que tout commence.", true)
	if voler:
		_voler_vers(Vector3(ZONE.get_center().x, 0, ZONE.get_center().y), 1100.0)


func _choisir_quartier(nom: String, arr: int, p: Vector2, voler := false) -> void:
	if ZONE.grow(150).has_point(p):
		_choisir_lauriers(voler)
		return
	_fiche(nom.to_upper(), "%d%s arrondissement" % [arr, "er" if arr == 1 else "e"],
		"Pas encore jouable. Pour l'instant, Loums trace sa route aux Lauriers.", false)
	if voler:
		_voler_vers(Vector3(p.x, 0, p.y), 1500.0)


func _vue_generale() -> void:
	var d: Rect2 = ville.get("domaine")
	_cible_v = Vector3(d.get_center().x, 0.0, d.get_center().y + d.size.y * 0.04)
	if _centre_ville != Vector2.INF:
		# entre le Vieux-Port et les Lauriers : la ville habitée remplit l'écran
		var c := _centre_ville.lerp(ZONE.get_center(), 0.4)
		_cible_v = Vector3(c.x, 0.0, c.y)
	_dist_v = d.size.y * (0.55 if _portrait else 0.6)
	_tangage_v = 0.82


func _voler_vers(p: Vector3, dist: float) -> void:
	_inactif = 0.0
	_cible_v = p
	_dist_v = clampf(dist, DIST_MIN, DIST_MAX)
	_tangage_v = clampf(_tangage_v, 0.55, 0.9)


## La partie commence : on plonge sur les Lauriers, puis on charge le quartier.
func entrer() -> void:
	if _plonge_t >= 0.0:
		return
	_plonge_t = 0.0
	_de = {"cible": _cible, "dist": _dist, "tangage": _tangage, "lacet": _lacet}
	_ui.visible = false


# ───────────────────────── caméra ─────────────────────────

func _placer() -> void:
	_cible.y = _sol_y
	_cam.near = clampf(_dist * 0.01, 1.0, 120.0)   # profondeur précise : plus de mer qui « mange » la côte
	_cam.far = _dist * 10.0 + 20000.0
	var dir := Vector3(cos(_tangage) * sin(_lacet), sin(_tangage), cos(_tangage) * cos(_lacet))
	var pos := _cible + dir * _dist
	# jamais sous le relief
	pos.y = maxf(pos.y, float(ville.call("altitude", pos.x, pos.z)) + 25.0)
	_cam.global_position = pos
	_cam.look_at(_cible, Vector3.UP)
	# les bâtiments arrivent quand on s'approche (tuiles de 512 m autour du point regardé)
	var rayon := 2 if _dist < 2200.0 else (1 if _dist < 4500.0 else -1)
	if _mobile:
		rayon = mini(rayon, 1)
	if rayon != _rayon_tuiles or rayon >= 0:
		_rayon_tuiles = rayon
		ville.call("demander", Vector2(_cible.x, _cible.z), rayon)
	_placer_noms()


func _placer_noms() -> void:
	var taille := get_viewport().get_visible_rect().size
	var pris: Array[Rect2] = []
	# le tag du quartier jouable d'abord (prioritaire)
	var wz := Vector3(ZONE.get_center().x, float(ville.call("altitude", ZONE.get_center().x, ZONE.get_center().y)) + 60.0, ZONE.get_center().y)
	var ez := _cam.unproject_position(wz)
	_nous.visible = not _cam.is_position_behind(wz)
	_nous.position = ez - Vector2(_nous.size.x * 0.5, _nous.size.y + 10.0)
	# toujours lisible : jamais sous les boutons ni hors de l'écran
	_nous.position.x = clampf(_nous.position.x, 8.0, taille.x - 100.0 - _nous.size.x)
	_nous.position.y = clampf(_nous.position.y, 130.0, taille.y - 320.0)
	if _nous.visible:
		pris.append(Rect2(_nous.position, _nous.size).grow(6))
	for n in _noms:
		var l: Label = n[0]
		var niveau: int = n[2]
		var montre := (niveau == 0 and _dist > 5000.0) or (niveau == 1 and _dist < 6500.0) or (niveau == 2 and _dist < 16000.0)
		if not montre:
			l.visible = false
			continue
		var p: Vector2 = n[1]
		var w := Vector3(p.x, float(ville.call("altitude", p.x, p.y)) + 20.0, p.y)
		if _cam.is_position_behind(w):
			l.visible = false
			continue
		var e := _cam.unproject_position(w)
		var r := Rect2(e - l.size * 0.5, l.size)
		var libre := r.position.x > 0 and r.end.x < taille.x - 90 and r.position.y > 150 and r.end.y < taille.y - 220
		for q in pris:
			if q.intersects(r):
				libre = false
				break
		l.visible = libre
		if libre:
			l.position = r.position
			pris.append(r.grow(4))


func _process(delta: float) -> void:
	_t += delta
	var pouls := 0.8 + 0.2 * sin(_t * 2.4)
	for m in _lueur:
		(m.material_override as ShaderMaterial).set_shader_parameter("pouls", pouls)
	for mat in [ville.get("materiau"), ville.get("materiau_sol")]:
		if mat:
			(mat as ShaderMaterial).set_shader_parameter("pouls", pouls)
	if _plonge_t >= 0.0:
		_plonger(delta)
		return
	_clavier(delta)
	if absf(_nuit - _nuit_v) > 0.001:
		_nuit = move_toward(_nuit, _nuit_v, delta * 0.8)
		_appliquer_nuit()
	# inertie : la carte glisse encore un peu quand on lâche
	var lache := _doigts.is_empty() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if lache and _glisse.length() > 0.5:
		_cible_v += Vector3(_glisse.x, 0.0, _glisse.y) * delta
		_cible += Vector3(_glisse.x, 0.0, _glisse.y) * delta
		_glisse *= exp(-5.0 * delta)
	if lache and _elan.length() > 0.01:
		_lacet_v -= _elan.x * delta
		_tangage_v = clampf(_tangage_v + _elan.y * delta, 0.22, 1.48)
		_elan *= exp(-4.0 * delta)
	_inactif += delta
	var d: Rect2 = ville.get("domaine")
	# on reste au-dessus de la ville (pas de fuite au large)
	var terre := d.grow_individual(-d.size.x * 0.12, -d.size.y * 0.1, -d.size.x * 0.12, -d.size.y * 0.1)
	_cible_v.x = clampf(_cible_v.x, terre.position.x, terre.end.x)
	_cible_v.z = clampf(_cible_v.z, terre.position.y, terre.end.y)
	_dist_v = minf(_dist_v, d.size.y * 1.2)
	# tout rejoint sa cible en douceur
	var k := 1.0 - exp(-6.0 * delta)
	_cible = _cible.lerp(_cible_v, 1.0 - exp(-14.0 * delta))
	_lacet = lerpf(_lacet, _lacet_v, k)
	_tangage = lerpf(_tangage, _tangage_v, k)
	_dist = exp(lerpf(log(_dist), log(_dist_v), 1.0 - exp(-10.0 * delta)))
	_sol_y = lerpf(_sol_y, maxf(float(ville.call("altitude", _cible.x, _cible.z)), -90.0), 1.0 - exp(-3.0 * delta))
	_placer()


func _plonger(delta: float) -> void:
	_plonge_t = minf(_plonge_t + delta / PLONGEE, 1.0)
	var k := _plonge_t * _plonge_t * (3.0 - 2.0 * _plonge_t)
	var arrivee := Vector3(128.4, 0.0, 66.8)   # le départ de Loums, devant le lycée Diderot (Q.DEPART)
	_cible = (_de.cible as Vector3).lerp(arrivee, k)
	_dist = exp(lerpf(log(float(_de.dist)), log(60.0), k))
	_tangage = lerpf(float(_de.tangage), 0.45, k)
	_lacet = lerp_angle(float(_de.lacet), PI, k)
	_placer()
	for m in _lueur:
		m.visible = k < 0.85
	if _plonge_t >= 1.0:
		set_process(false)
		get_tree().change_scene_to_file(JEU)


func _clavier(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if dir != Vector2.ZERO:
		_deplacer(-dir.limit_length(1.0) * delta * 900.0)
	if Input.is_physical_key_pressed(KEY_Q) and not Input.is_action_pressed("move_left"): _lacet_v += delta * 1.2
	if Input.is_physical_key_pressed(KEY_E): _lacet_v -= delta * 1.2
	if Input.is_physical_key_pressed(KEY_R): _tangage_v = clampf(_tangage_v + delta, 0.22, 1.48)
	if Input.is_physical_key_pressed(KEY_F): _tangage_v = clampf(_tangage_v - delta, 0.22, 1.48)
	if Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_physical_key_pressed(KEY_KP_ADD): _dist_v = clampf(_dist_v * (1.0 - delta * 1.5), DIST_MIN, DIST_MAX)
	if Input.is_physical_key_pressed(KEY_MINUS) or Input.is_physical_key_pressed(KEY_KP_SUBTRACT): _dist_v = clampf(_dist_v * (1.0 + delta * 1.5), DIST_MIN, DIST_MAX)


func _unhandled_input(e: InputEvent) -> void:
	if _plonge_t >= 0.0:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		_inactif = 0.0
		if e.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			entrer()
		elif e.keycode == KEY_N:
			_basculer_nuit()
		return
	# au doigt, Godot simule aussi la souris (pour les boutons) : on ignore ces doublons ici
	if (e is InputEventMouseButton or e is InputEventMouseMotion) and e.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_pivot = e.position
		_elan = Vector2.ZERO
	if e is InputEventMouseButton and e.pressed:
		_inactif = 0.0
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoomer_vers(e.position, 0.82)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoomer_vers(e.position, 1.22)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			_glisse = Vector2.ZERO
			_elan = Vector2.ZERO
			_appui = e.position
			_bouge = 0.0
			if e.double_click:
				_zoomer_vers(e.position, 0.45)
				_appui = Vector2(-1, -1)
	elif e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _bouge < 8.0 and _appui.x >= 0.0:
			_toucher(e.position, false)
		_appui = Vector2(-1, -1)
	elif e is InputEventMouseMotion:
		if e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# Louma 21.11 : clic gauche glissé = tourner autour du centre (gauche / droite) et incliner (haut / bas)
			_bouge += e.relative.length()
			if _bouge >= 8.0:
				_lacet_v -= e.relative.x * 0.005
				_tangage_v = clampf(_tangage_v + e.relative.y * 0.004, 0.22, 1.48)
		elif e.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			_saisir(e.position - e.relative, e.position, e.velocity)
	elif e is InputEventMagnifyGesture:
		_inactif = 0.0
		_zoomer_vers(e.position, 1.0 / maxf(e.factor, 0.01))   # pincer sur le pavé tactile (Mac)
	elif e is InputEventPanGesture:
		_inactif = 0.0
		_zoomer_vers(e.position, 1.0 + clampf(e.delta.y, -3.0, 3.0) * 0.06)
	elif e is InputEventScreenTouch:
		_inactif = 0.0
		if e.pressed and _sur_interface(e.position):
			return   # un doigt sur un bouton ou la fiche : c'est l'interface qui répond
		if e.pressed:
			_doigts[e.index] = e.position
			_elan = Vector2.ZERO
			_glisse = Vector2.ZERO
			if _doigts.size() == 1:
				_appui = e.position
				_bouge = 0.0
				if _t - _dernier_toucher < 0.3:
					_zoomer_vers(e.position, 0.45)     # double toucher : on plonge là
					_bouge = 999.0
				_dernier_toucher = _t
			else:
				_bouge = 999.0
		else:
			if _doigts.size() == 1 and _bouge < 14.0:
				_toucher(e.position, false)
			_doigts.erase(e.index)
		if _doigts.size() == 2:
			_ecart = _ecart_doigts()
			_angle_doigts = _angle()
			_milieu = _milieu_doigts()
			_geste = ""
			_geste_cumul = Vector3.ZERO
	elif e is InputEventScreenDrag:
		_inactif = 0.0
		var avant: Vector2 = _doigts.get(e.index, e.position)
		_doigts[e.index] = e.position
		if _doigts.size() == 1:
			_bouge += e.relative.length()
			_saisir(avant, e.position, e.velocity)
		elif _doigts.size() == 2:
			var ecart := _ecart_doigts()
			var mil := _milieu_doigts()
			var ang := _angle()
			var d_ecart := ecart - _ecart if _ecart > 1.0 else 0.0
			var d_ang := wrapf(ang - _angle_doigts, -PI, PI)
			var dm := mil - _milieu
			# Un seul geste à la fois, comme Google Maps : on reconnaît le geste au début, puis on le garde.
			#   doigts qui s'écartent / se rapprochent ou tournent = zoom + pivot ; qui montent ensemble = incliner
			if _geste == "":
				_geste_cumul += Vector3(absf(d_ecart), absf(d_ang) * ecart * 0.5, absf(dm.y))
				if _geste_cumul.z > 18.0 and _geste_cumul.z > (_geste_cumul.x + _geste_cumul.y) * 1.5:
					_geste = "incliner"
				elif _geste_cumul.x + _geste_cumul.y > 14.0:
					_geste = "zoom"
			if _geste == "zoom":
				if _ecart > 1.0 and ecart > 1.0:
					_zoomer_vers(mil, _ecart / ecart)
				_pivoter(mil, -d_ang)
				_saisir(_milieu, mil)   # le milieu des doigts tire aussi la carte
			elif _geste == "incliner":
				_tangage_v = clampf(_tangage_v + dm.y * 0.006, 0.22, 1.48)
			_ecart = ecart
			_angle_doigts = ang
			_milieu = mil


## Le point du sol (à hauteur de la cible) sous un point de l'écran.
func _sol_sous(ecran: Vector2) -> Vector3:
	var o := _cam.project_ray_origin(ecran)
	var dr := _cam.project_ray_normal(ecran)
	if dr.y > -0.02:
		dr.y = -0.02
	var t := (o.y - _cible.y) / -dr.y
	return o + dr * minf(t, _dist * 6.0)


## Un doigt (ou la souris) attrape la carte : le point touché reste sous le doigt.
func _saisir(de: Vector2, a: Vector2, vitesse := Vector2.ZERO) -> void:
	_inactif = 0.0
	var d := _sol_sous(de) - _sol_sous(a)
	d.y = 0.0
	# près de l'horizon un pixel vaut des kilomètres : on borne
	var haut := get_viewport().get_visible_rect().size.y
	d = d.limit_length(_dist * 2.5 * de.distance_to(a) / haut)
	_cible_v += d
	_cible += d
	_placer()
	# l'élan au lâcher : même sens que le dernier geste, vitesse bornée
	if de.distance_to(a) > 0.5 and vitesse.length() > 1.0:
		var g := d / de.distance_to(a) * vitesse.length() * 0.5   # la vitesse du sol sous le doigt
		g = g.limit_length(_dist * 0.6)
		_glisse = Vector2(g.x, g.z)
	else:
		_glisse = Vector2.ZERO


func _zoomer_vers(ecran: Vector2, facteur: float) -> void:
	_inactif = 0.0
	var avant := _sol_sous(ecran)
	var nouveau := clampf(_dist_v * facteur, DIST_MIN, DIST_MAX)
	var f := nouveau / _dist_v
	_dist_v = nouveau
	# le point visé se rapproche du centre en proportion du zoom
	var vers := avant - _cible_v
	vers.y = 0.0
	_cible_v += vers * (1.0 - f)


## Tourner la vue autour d'un point de l'écran : ce point reste sous le doigt / la souris.
func _pivoter(ecran: Vector2, angle: float) -> void:
	_inactif = 0.0
	var p := _sol_sous(ecran)
	var v := _cible - p
	v.y = 0.0
	var nv := v.rotated(Vector3.UP, angle)
	_cible += nv - v
	_cible_v += nv - v
	_lacet += angle
	_lacet_v += angle
	_placer()


func _milieu_doigts() -> Vector2:
	var p: Array = _doigts.values()
	return ((p[0] as Vector2) + (p[1] as Vector2)) * 0.5


func _basculer_nuit() -> void:
	_nuit_v = 0.0 if _nuit_v > 0.5 else 1.0
	var f := FileAccess.open(FICHIER_NUIT, FileAccess.WRITE)
	if f:
		f.store_string("1" if _nuit_v > 0.5 else "0")
	_redessiner()


## Jour ↔ nuit : ciel, soleil devenu lune, mer, et la ville qui s'allume.
func _appliquer_nuit() -> void:
	var n := _nuit
	_redessiner()
	_ciel.sky_top_color = Color(0.13, 0.42, 0.90).lerp(Color(0.03, 0.04, 0.16), n)
	_ciel.sky_horizon_color = Color(1.0, 0.80, 0.55).lerp(Color(0.42, 0.18, 0.42), n)
	_ciel.ground_horizon_color = _ciel.sky_horizon_color
	_ciel.ground_bottom_color = MER.lerp(Color(0.04, 0.08, 0.2), n)
	_env.ambient_light_color = Color(0.95, 0.9, 1.0).lerp(Color(0.45, 0.5, 1.0), n)
	_env.ambient_light_energy = lerpf(0.3, 0.38, n)
	_env.fog_light_color = Color(1.0, 0.82, 0.62).lerp(Color(0.12, 0.1, 0.3), n)
	_env.glow_intensity = lerpf(0.7, 1.3, n)
	_env.glow_bloom = lerpf(0.12, 0.05, n)
	_soleil.light_color = Color(1.0, 0.93, 0.80).lerp(Color(0.55, 0.65, 1.0), n)
	_soleil.light_energy = lerpf(1.0, 0.32, n)
	_mat_mer.set_shader_parameter("mer", MER.lerp(Color(0.05, 0.12, 0.3), n))
	for mat in [ville.get("materiau"), ville.get("materiau_sol")]:
		if mat:
			(mat as ShaderMaterial).set_shader_parameter("nuit", n)
			(mat as ShaderMaterial).set_shader_parameter("mer", MER)


## Toucher la carte : un quartier (le plus proche du point touché) devient la fiche, et on y vole.
func _toucher(ecran: Vector2, voler: bool) -> void:
	var o := _cam.project_ray_origin(ecran)
	var dr := _cam.project_ray_normal(ecran)
	# on marche le long du rayon jusqu'au relief
	var p := o
	var pas := maxf(_dist / 200.0, 5.0)
	for i in 600:
		p += dr * pas
		if p.y <= float(ville.call("altitude", p.x, p.z)):
			break
	var sol := Vector2(p.x, p.z)
	var meilleur: Array = []
	var dmin := INF
	for n in _noms:
		if n[2] == 0:
			continue
		var dd: float = (n[1] as Vector2).distance_to(sol)
		if n[2] == 2:
			dd -= 250.0   # on touche la cité de préférence au quartier autour
		if dd < dmin:
			dmin = dd
			meilleur = n
	if ZONE.grow(60).has_point(sol):
		_choisir_lauriers(voler)
	elif not meilleur.is_empty():
		_choisir_quartier(meilleur[3], meilleur[4], sol, voler)


func _ecart_doigts() -> float:
	var p: Array = _doigts.values()
	return (p[0] as Vector2).distance_to(p[1])


func _angle() -> float:
	var p: Array = _doigts.values()
	var d: Vector2 = p[1] - p[0]
	return atan2(d.y, d.x)


func _tourner(rel: Vector2, vitesse := Vector2.ZERO) -> void:
	_inactif = 0.0
	_lacet_v -= rel.x * 0.005
	_tangage_v = clampf(_tangage_v + rel.y * 0.004, 0.22, 1.48)
	_elan = Vector2(vitesse.x * 0.005, vitesse.y * 0.004) * 0.25


func _deplacer(rel: Vector2) -> void:
	_inactif = 0.0
	var droite := _cam.global_transform.basis.x
	droite.y = 0.0
	var avant := -_cam.global_transform.basis.z
	avant.y = 0.0
	var k := _dist * 0.0016
	_cible_v += (-droite.normalized() * rel.x + avant.normalized() * rel.y) * k
