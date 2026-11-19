class_name Player
extends CharacterBody3D
## LOUMS dans l'îlot gris : marche, monte sur sa planche, descend.
## Le corps physique ne tourne jamais ; seul `Visual` tourne (plus stable).
## L'origine du nœud est aux pieds.

enum Mode { WALK, SKATE }

@export var walk_speed := 3.2
@export var walk_accel := 25.0
@export var jump_velocity := 4.2
@export var mouse_sensitivity := 0.003
@export var stick_camera_speed := 2.5

var mode: Mode = Mode.WALK
var spawn_position := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var visual: Node3D = $Visual
@onready var board: Node3D = $Visual/Board
@onready var skate: SkateController = $SkateController
@onready var debug_label: Label = $HUD/DebugLabel


func _ready() -> void:
	spawn_position = global_position
	spring_arm.add_excluded_object(get_rid())
	spring_arm.rotation.x = -0.35
	camera_pivot.top_level = true  # la caméra suit sans hériter des à-coups
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_mode(Mode.WALK)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x - event.relative.y * mouse_sensitivity, -1.2, 0.25)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		_respawn()
	if Input.is_action_just_pressed("toggle_board") and is_on_floor() and not skate.grinding:
		_set_mode(Mode.SKATE if mode == Mode.WALK else Mode.WALK)

	match mode:
		Mode.WALK:
			_walk(delta)
		Mode.SKATE:
			skate.step(self, delta)
			visual.rotation.y = skate.heading

	if not (mode == Mode.SKATE and skate.grinding):
		move_and_slide()

	if global_position.y < -20.0:
		_respawn()


func _process(delta: float) -> void:
	# Caméra : suit le joueur en douceur, stick droit pour tourner.
	var target := global_position + Vector3.UP * 1.5
	camera_pivot.global_position = camera_pivot.global_position.lerp(target, minf(1.0, 12.0 * delta))
	var cam := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	camera_pivot.rotate_y(-cam.x * stick_camera_speed * delta)
	spring_arm.rotation.x = clampf(spring_arm.rotation.x - cam.y * stick_camera_speed * delta, -1.2, 0.25)
	_animate_board()
	_update_hud()


## Direction voulue, relative à la caméra, à plat.
func move_input_world() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var b := camera_pivot.global_basis
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	return right * input.x - fwd * input.y


func _walk(delta: float) -> void:
	var dir := move_input_world()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	var target := dir * walk_speed
	velocity.x = move_toward(velocity.x, target.x, walk_accel * delta)
	velocity.z = move_toward(velocity.z, target.z, walk_accel * delta)
	if dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	board.visible = mode == Mode.SKATE
	if mode == Mode.SKATE:
		floor_snap_length = 0.35
		skate.enter(self, visual.rotation.y)
		skate.last_event = "Sur la planche"
	else:
		floor_snap_length = 0.1
		var keep := velocity * 0.3
		velocity = Vector3(keep.x, velocity.y, keep.z)
		skate.last_event = "À pied"


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	skate.grinding = false
	skate.speed = 0.0
	_set_mode(Mode.WALK)


## Rotation de la planche pendant les flips (purement visuel).
func _animate_board() -> void:
	board.rotation = Vector3.ZERO
	if mode != Mode.SKATE or skate.trick_t >= 1.0:
		return
	match skate.trick:
		"Kickflip":
			board.rotation.z = TAU * skate.trick_t
		"Shove-it":
			board.rotation.y = PI * skate.trick_t


func _update_hud() -> void:
	var kmh := absf(skate.speed) * 3.6 if mode == Mode.SKATE else Vector2(velocity.x, velocity.z).length() * 3.6
	var state := "À PIED"
	if mode == Mode.SKATE:
		state = "GRIND" if skate.grinding else ("AIR" if skate.in_air else "SKATE")
	debug_label.text = "%s   %d km/h\n%s\n\nZQSD bouger · Maj pousser · Espace ollie · E planche\nJ kickflip · K shove-it · L grind (maintenir) · R départ · Échap souris\nÀ pied, face à un mur : G graffiti (maintenir) · C couleur" % [
		state, roundi(kmh), skate.last_event]
