extends Node
## TRACE — le style « bande dessinée », appliqué à toute la scène.
##  - remplace chaque matériau standard par sa version BD (même couleur, lumière en trois tons) ;
##  - pose l'encrage (traits sur silhouettes et arêtes) sur tout l'écran ;
##  - règle le ciel et l'ambiance pour des aplats francs.
## Les objets créés plus tard (graffitis, Loums importé…) sont convertis à leur arrivée.
## Crée aussi le nœud Habillage (mobilier urbain, scripts/habillage.gd).
## Touche B : comparer avec le rendu d'origine.

const TOON := preload("res://shaders/bd_toon.gdshader")
const ENCRAGE_PATH := "res://shaders/bd_encrage.gdshader"
const ENCRAGE_WEB_PATH := "res://shaders/bd_encrage_web.gdshader"  # sans normales : mode Compatibilité (web, mobile)
const HABILLAGE := preload("res://scripts/habillage.gd")

## Ciel et ambiance en mode BD.
@export var ciel_haut := Color(0.16, 0.48, 0.93)
@export var ciel_horizon := Color(0.72, 0.87, 0.97)
@export var brume := Color(0.76, 0.86, 0.97)

var actif := true
var _toon := {}         # matériau d'origine → version BD
var _origine := {}      # [MeshInstance3D, surface] → matériau d'origine
var _encrage: MeshInstance3D
var _env_brut := {}


func _ready() -> void:
	get_tree().node_added.connect(_nouveau)
	_convertir_tout.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("style_bd"):
		basculer(not actif)


func basculer(oui: bool) -> void:
	actif = oui
	RenderingServer.global_shader_parameter_set("bd_actif", 1.0 if oui else 0.0)
	for cle in _origine:
		var mi: MeshInstance3D = cle[0]
		if not is_instance_valid(mi):
			continue
		var m: Material = _origine[cle]
		_poser(mi, cle[1], _toon[m] if oui else m)
	if _encrage:
		_encrage.visible = oui
	_ambiance(oui)


func _convertir_tout() -> void:
	_poser_habillage()
	RenderingServer.global_shader_parameter_set("bd_actif", 1.0)
	_ambiance(true)
	_convertir(get_tree().current_scene if get_tree().current_scene else get_parent())
	_poser_encrage()


func _nouveau(n: Node) -> void:
	if n is MeshInstance3D:
		_convertir_mesh.call_deferred(n)


func _convertir(n: Node) -> void:
	if n is MeshInstance3D:
		_convertir_mesh(n)
	for e in n.get_children():
		_convertir(e)


func _convertir_mesh(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi) or mi == _encrage or mi.mesh == null:
		return
	if mi.material_override:
		_remplacer(mi, -1, mi.material_override)
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s)
		if m == null:
			m = mi.mesh.surface_get_material(s)
		if m:
			_remplacer(mi, s, m)


func _remplacer(mi: MeshInstance3D, s: int, m: Material) -> void:
	var std := m as BaseMaterial3D
	if std == null:
		return  # déjà un shader (façades) : il gère lui-même le style
	if std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return  # vitres, fonds de graffiti : on les laisse tels quels
	if not _toon.has(m):
		var t := ShaderMaterial.new()
		t.shader = TOON
		t.set_shader_parameter("couleur", std.albedo_color)
		if std.albedo_texture:
			# Matériau peint (Loums, modèles importés) : on garde sa texture, réduite à quelques
			# teintes, sans le grain du décor (qui « glisserait » sur un corps en mouvement).
			t.set_shader_parameter("texture_couleur", std.albedo_texture)
			t.set_shader_parameter("avec_texture", true)
			t.set_shader_parameter("paliers", 12.0)
			t.set_shader_parameter("grain", 0.0)
			t.set_shader_parameter("personnage", true)
		_toon[m] = t
	_origine[[mi, s]] = m
	if actif:
		_poser(mi, s, _toon[m])


func _poser(mi: MeshInstance3D, s: int, m: Material) -> void:
	if s < 0:
		mi.material_override = m
	else:
		mi.set_surface_override_material(s, m)


## Le mobilier urbain (habillage.gd) se pose après la construction du quartier.
func _poser_habillage() -> void:
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	var q := scene.get_node_or_null("Quartier")
	if q == null or scene.has_node("Habillage"):
		return
	var hab := Node3D.new()
	hab.set_script(HABILLAGE)
	hab.name = "Habillage"
	hab.set("quartier", q)
	scene.add_child(hab)


## Un quad plein écran attaché à la caméra porte l'encrage.
func _poser_encrage() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_encrage = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_encrage.mesh = q
	var m := ShaderMaterial.new()
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	m.shader = load(ENCRAGE_WEB_PATH if compat else ENCRAGE_PATH)
	_encrage.material_override = m
	_encrage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_encrage.extra_cull_margin = 16384.0
	_encrage.position = Vector3(0, 0, -1)
	_encrage.name = "Encrage"
	cam.add_child(_encrage)


func _ambiance(oui: bool) -> void:
	var we := _environnement()
	if we == null:
		return
	var env := we.environment
	var ciel := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
	if _env_brut.is_empty():
		_env_brut = {
			"ssao": env.ssao_enabled, "glow": env.glow_enabled, "tonemap": env.tonemap_mode,
			"ambient": env.ambient_light_energy, "refl": env.reflected_light_source,
			"fog": env.fog_light_color, "densite": env.fog_density,
			"haut": ciel.sky_top_color if ciel else Color(), "horizon": ciel.sky_horizon_color if ciel else Color(),
			"sol": ciel.ground_horizon_color if ciel else Color(),
		}
	var b := _env_brut
	env.ssao_enabled = b.ssao and not oui
	env.glow_enabled = b.glow and not oui
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR if oui else b.tonemap
	env.ambient_light_energy = 0.08 if oui else b.ambient  # l'ombre vient de bd_ombre, pas du ciel
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if oui else b.refl
	env.fog_light_color = brume if oui else b.fog
	env.fog_density = 0.0016 if oui else b.densite
	if ciel:
		ciel.sky_top_color = ciel_haut if oui else b.haut
		ciel.sky_horizon_color = ciel_horizon if oui else b.horizon
		ciel.ground_horizon_color = ciel_horizon if oui else b.sol
	var soleil := _soleil()
	if soleil:
		if not _env_brut.has("soleil"):
			_env_brut["soleil"] = soleil.light_energy
		soleil.light_energy = 1.0 if oui else _env_brut["soleil"]


func _environnement() -> WorldEnvironment:
	for n in get_tree().current_scene.find_children("*", "WorldEnvironment", true, false):
		return n
	return null


func _soleil() -> DirectionalLight3D:
	for n in get_tree().current_scene.find_children("*", "DirectionalLight3D", true, false):
		return n
	return null
