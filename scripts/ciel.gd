extends Node
## TRACE — le ciel et la lumière, heure par heure (conversation n°2).
## Direction artistique demandée par Louma (19.11) : poétique, « comme dans les films de Miyazaki » :
## un ciel peint avec de beaux nuages, une lumière douce et chaude — on est à Marseille.
##  - remplace le ciel procédural par un ciel peint (shaders/ciel.gdshader) ;
##  - donne à chaque heure sa palette : couleur du soleil, couleur des ombres (bd_ombre), brume, ciel, nuages.
## La course du soleil et la variable « nuit » restent à temps.gd (n°1) : ce nœud passe après lui
## (process_priority) et ne fait que repeindre les couleurs.

const CIEL := preload("res://shaders/ciel.gdshader")

## [heure, haut, milieu, horizon, nuage clair, nuage corps, nuage ombre, halo, soleil, énergie, ombre BD, brume, étoiles]
const CLES := [
	[0.0, Color(0.03, 0.04, 0.12), Color(0.06, 0.08, 0.20), Color(0.12, 0.13, 0.26), Color(0.20, 0.22, 0.36), Color(0.14, 0.16, 0.30), Color(0.08, 0.09, 0.20), Color(0.30, 0.32, 0.50), Color(0.55, 0.62, 0.88), 0.14, Color(0.07, 0.07, 0.17), Color(0.10, 0.12, 0.22), 1.0],
	[5.8, Color(0.05, 0.06, 0.16), Color(0.10, 0.12, 0.28), Color(0.22, 0.20, 0.34), Color(0.30, 0.28, 0.44), Color(0.20, 0.20, 0.36), Color(0.12, 0.12, 0.26), Color(0.40, 0.36, 0.52), Color(0.55, 0.60, 0.85), 0.16, Color(0.09, 0.09, 0.20), Color(0.16, 0.16, 0.28), 0.8],
	# aube : rose et lavande
	[7.0, Color(0.30, 0.34, 0.66), Color(0.66, 0.58, 0.80), Color(1.00, 0.76, 0.62), Color(1.00, 0.80, 0.72), Color(0.88, 0.70, 0.76), Color(0.56, 0.50, 0.72), Color(1.00, 0.78, 0.60), Color(1.00, 0.74, 0.58), 0.75, Color(0.42, 0.38, 0.62), Color(0.92, 0.78, 0.76), 0.0],
	# matin clair
	[9.5, Color(0.22, 0.47, 0.88), Color(0.50, 0.72, 0.96), Color(0.94, 0.92, 0.86), Color(1.00, 0.99, 0.95), Color(0.92, 0.91, 0.94), Color(0.68, 0.70, 0.88), Color(1.00, 0.92, 0.74), Color(1.00, 0.96, 0.88), 1.0, Color(0.58, 0.57, 0.76), Color(0.88, 0.90, 0.92), 0.0],
	# plein jour de Marseille : bleu profond, horizon blanc chaud
	[14.0, Color(0.18, 0.44, 0.88), Color(0.46, 0.70, 0.96), Color(0.95, 0.92, 0.84), Color(1.00, 0.99, 0.94), Color(0.93, 0.91, 0.92), Color(0.68, 0.70, 0.88), Color(1.00, 0.92, 0.72), Color(1.00, 0.95, 0.84), 1.0, Color(0.57, 0.55, 0.76), Color(0.90, 0.89, 0.88), 0.0],
	# sortie du lycée (16 h 30) : la lumière commence à dorer
	[16.5, Color(0.24, 0.42, 0.84), Color(0.58, 0.68, 0.92), Color(1.00, 0.88, 0.74), Color(1.00, 0.93, 0.80), Color(0.95, 0.86, 0.84), Color(0.66, 0.60, 0.82), Color(1.00, 0.84, 0.60), Color(1.00, 0.86, 0.66), 1.0, Color(0.54, 0.48, 0.74), Color(0.98, 0.86, 0.76), 0.0],
	# heure dorée : ciel violet, nuages pêche et rose
	[18.3, Color(0.30, 0.28, 0.70), Color(0.72, 0.52, 0.82), Color(1.00, 0.70, 0.52), Color(1.00, 0.76, 0.56), Color(0.98, 0.58, 0.62), Color(0.58, 0.42, 0.72), Color(1.00, 0.72, 0.46), Color(1.00, 0.72, 0.48), 0.92, Color(0.48, 0.38, 0.68), Color(1.00, 0.76, 0.64), 0.0],
	# coucher : rose vif sous un ciel indigo
	[19.6, Color(0.20, 0.16, 0.46), Color(0.58, 0.32, 0.62), Color(1.00, 0.54, 0.42), Color(1.00, 0.56, 0.52), Color(0.80, 0.38, 0.56), Color(0.38, 0.26, 0.52), Color(1.00, 0.58, 0.40), Color(0.98, 0.56, 0.44), 0.6, Color(0.34, 0.26, 0.52), Color(0.80, 0.52, 0.58), 0.1],
	[21.0, Color(0.05, 0.06, 0.16), Color(0.12, 0.12, 0.30), Color(0.26, 0.20, 0.36), Color(0.30, 0.26, 0.44), Color(0.20, 0.18, 0.36), Color(0.11, 0.11, 0.24), Color(0.42, 0.32, 0.48), Color(0.55, 0.60, 0.86), 0.16, Color(0.09, 0.09, 0.20), Color(0.14, 0.14, 0.26), 0.8],
	[24.0, Color(0.03, 0.04, 0.12), Color(0.06, 0.08, 0.20), Color(0.12, 0.13, 0.26), Color(0.20, 0.22, 0.36), Color(0.14, 0.16, 0.30), Color(0.08, 0.09, 0.20), Color(0.30, 0.32, 0.50), Color(0.55, 0.62, 0.88), 0.14, Color(0.07, 0.07, 0.17), Color(0.10, 0.12, 0.22), 1.0],
]
const PARAMS := ["haut", "milieu", "horizon", "nuage_clair", "nuage_corps", "nuage_ombre", "halo"]

var _mat: ShaderMaterial
var _env: Environment
var _soleil: DirectionalLight3D
var _temps: Node
var _style: Node
var _derive := 0.0
## Heure imposée (captures, tests) : -1 = suivre l'horloge du jeu.
var heure_fixe := -1.0


func _ready() -> void:
	process_priority = 100   # après temps.gd
	call_deferred("_installer")


func _installer() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_temps = scene.get_node_or_null("Temps")
	_style = scene.get_node_or_null("StyleBD")
	for n in scene.find_children("*", "WorldEnvironment", true, false):
		_env = (n as WorldEnvironment).environment
		break
	for n in scene.find_children("*", "DirectionalLight3D", true, false):
		_soleil = n
		break
	if _env == null:
		return
	if _env.sky == null:
		_env.sky = Sky.new()
	_mat = ShaderMaterial.new()
	_mat.shader = CIEL
	_env.sky.sky_material = _mat
	_env.sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.background_mode = Environment.BG_SKY
	_env.fog_sky_affect = 0.12
	_env.fog_aerial_perspective = 0.35
	_env.fog_sun_scatter = 0.4
	_peindre()


func _process(delta: float) -> void:
	_derive += delta
	_peindre()


func heure() -> float:
	if heure_fixe >= 0.0:
		return heure_fixe
	if _temps and _temps.has_method("heure"):
		return _temps.heure()
	return 16.5


## La palette de l'heure h : interpolation douce entre les deux clés qui l'encadrent.
func palette(h: float) -> Array:
	h = fposmod(h, 24.0)
	for i in CLES.size() - 1:
		var a: Array = CLES[i]
		var b: Array = CLES[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var t := smoothstep(0.0, 1.0, (h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001))
			var res := []
			for k in range(1, a.size()):
				if a[k] is Color:
					res.append((a[k] as Color).lerp(b[k], t))
				else:
					res.append(lerpf(float(a[k]), float(b[k]), t))
			return res
	return CLES[0].slice(1)


func _peindre() -> void:
	if _mat == null:
		return
	var p := palette(heure())
	for i in PARAMS.size():
		_mat.set_shader_parameter(PARAMS[i], p[i])
	_mat.set_shader_parameter("sol", (p[2] as Color).darkened(0.25))
	_mat.set_shader_parameter("derive", _derive)
	_mat.set_shader_parameter("etoiles", p[11])
	var bd: bool = _style == null or bool(_style.get("actif"))
	if _soleil and bd:
		_soleil.light_color = p[7]
		_soleil.light_energy = p[8]
	if bd:
		RenderingServer.global_shader_parameter_set("bd_ombre", p[9])
		_env.fog_light_color = p[10]
