extends Node3D
## TRACE — les lumières de la nuit (avec temps.gd).
## En 2014, l'éclairage public des quartiers nord, ce sont des lampes au sodium : une lumière orangée,
## des flaques de lumière sous chaque lampadaire, du noir entre deux. Les globes de la place sont plus blancs.
## Tout est « faux » (aplats additifs, sans vraies lampes) pour rester léger sur téléphone ;
## l'intensité suit la variable globale « nuit » (0 le jour, 1 la nuit).
## Les fenêtres allumées sont dans le shader des façades (facade.gdshader, n°2).

const SODIUM := Color(1.0, 0.62, 0.25)
const GLOBE := Color(1.0, 0.88, 0.70)

var quartier: Node
var _mat_flaque: ShaderMaterial
var _mat_halo: ShaderMaterial
var lampes := 0


func _ready() -> void:
	quartier = get_node_or_null("../Quartier")
	_mat_flaque = _materiau(true)
	_mat_halo = _materiau(false)
	# le décor est posé par l'habillage (n°2) juste après le chargement : on attend qu'il soit là
	for i in 6:
		await get_tree().process_frame
	_allumer()


func _materiau(flaque: bool) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
global uniform float nuit;
uniform vec4 couleur : source_color = vec4(1.0, 0.62, 0.25, 1.0);
uniform float force = 0.55;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = %s;
	ALBEDO = couleur.rgb * a * force * nuit;
}
""" % ("pow(clamp(1.0 - d, 0.0, 1.0), 1.6)" if flaque else "pow(clamp(1.0 - d, 0.0, 1.0), 3.0) * 2.0")
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _allumer() -> void:
	var scene := get_tree().current_scene
	for n in scene.find_children("Lampadaire*", "StaticBody3D", true, false):
		var b := n as Node3D
		var boule := str(b.name).begins_with("Lampadaire_boule")
		var p := b.global_position
		var sol := _h(p.x, p.z)
		var haut := 2.6 if boule else 7.2
		var rayon := 4.5 if boule else 7.5
		var c := GLOBE if boule else SODIUM
		add_child(_flaque(Vector2(p.x, p.z), rayon, c, 0.35 if boule else 0.55))
		add_child(_halo(Vector3(p.x, sol + haut, p.z), 1.1 if boule else 1.6, c))
		lampes += 1


func _h(x: float, z: float) -> float:
	return quartier.call("h", x, z) if quartier else 0.0


## Une flaque de lumière posée sur le sol, qui épouse la pente (grille de 10 × 10).
func _flaque(c: Vector2, r: float, couleur: Color, force: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	for j in n:
		for i in n:
			var coins := [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			for k in coins:
				var uv: Vector2 = k / float(n)
				var x := c.x + (uv.x - 0.5) * 2.0 * r
				var z := c.y + (uv.y - 0.5) * 2.0 * r
				st.set_uv(uv)
				st.add_vertex(Vector3(x, _h(x, z) + 0.12, z))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat := _mat_flaque.duplicate() as ShaderMaterial
	mat.set_shader_parameter("couleur", couleur)
	mat.set_shader_parameter("force", force)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## Le halo de la lanterne, toujours tourné vers la caméra.
func _halo(p: Vector3, taille: float, couleur: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(taille, taille)
	var m := MeshInstance3D.new()
	m.mesh = q
	var mat := _mat_halo.duplicate() as ShaderMaterial
	mat.set_shader_parameter("couleur", couleur)
	mat.set_shader_parameter("force", 1.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = p
	m.set_meta("halo", true)
	return m


func _process(_delta: float) -> void:
	# les halos regardent la caméra
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for m in get_children():
		if (m as Node).has_meta("halo"):
			(m as Node3D).look_at(cam.global_position, Vector3.UP, true)
