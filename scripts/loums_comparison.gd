extends Node3D
## Standalone visual review. The project's main gameplay scene is unchanged.

var camera: Camera3D
var yaw := 0.0
var pitch := -0.08
var distance := 4.6

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("171823")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9bfd2")
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(10, 10)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("242633")
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	_add_model("res://assets/characters/loums/loums_meshy_6lite.glb", -0.9, "MESHY 6 LITE\n138 180 triangles · sans texture")
	_add_model("res://assets/characters/loums/loums_tripo_h25_retopo.glb", 0.9, "TRIPO H2.5\n18 194 triangles · texture")
	camera = Camera3D.new()
	camera.fov = 43
	add_child(camera)
	camera.make_current()
	_update_camera()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var instructions := Label.new()
	instructions.text = "LOUMS — comparaison des exports gratuits\nGlisser avec clic droit : tourner · Molette : zoom · R : vue de face"
	instructions.position = Vector2(24, 20)
	instructions.add_theme_font_size_override("font_size", 21)
	canvas.add_child(instructions)

func _add_model(path: String, x: float, caption: String) -> void:
	var instance := (load(path) as PackedScene).instantiate() as Node3D
	add_child(instance)
	var bounds := AABB()
	var first := true
	for mesh in instance.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (instance.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var factor := 1.75 / bounds.size.y
	instance.scale = Vector3.ONE * factor
	instance.position = Vector3(x, -bounds.position.y * factor, 0)
	var label := Label3D.new()
	label.text = caption
	label.position = Vector3(x, 2.06, 0)
	label.font_size = 36
	label.pixel_size = 0.0014
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch - event.relative.y * 0.004, -0.6, 0.4)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2.5, distance - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(8.0, distance + 0.3)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		yaw = 0.0
		pitch = -0.08
		distance = 4.6
	_update_camera()

func _update_camera() -> void:
	var target := Vector3(0, 0.95, 0)
	camera.position = target + Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)
