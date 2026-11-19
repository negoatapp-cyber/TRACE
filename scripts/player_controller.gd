class_name Player
extends CharacterBody3D
## LOUMS dans l'îlot gris : marche, monte sur sa planche, descend.
## Le corps physique ne tourne jamais ; seul `Visual` tourne (plus stable).
## L'origine du nœud est aux pieds.

enum Mode { WALK, SKATE }

@export var walk_speed := 3.2
@export var run_speed := 6.2        ## en maintenant Maj
@export var walk_accel := 25.0
@export var mantle_reach := 2.3     ## hauteur max qu'on attrape depuis les pieds (m)
@export var jump_velocity := 4.2
@export var mouse_sensitivity := 0.003
@export var stick_camera_speed := 2.5

var mode: Mode = Mode.WALK
var spawn_position := Vector3.ZERO
var climbs := 0                     ## nombre de rétablissements (pour le carnet de session)
var _mantling := false
var _m_t := 0.0
var _m_dur := 0.4
var _m_from := Vector3.ZERO
var _m_to := Vector3.ZERO
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

	if _mantling:
		_mantle_step(delta)
		return

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
		# En l'air, saut maintenu face à un rebord : on s'y accroche.
		if Input.is_action_pressed("jump") and velocity.y < 2.0 and _try_mantle():
			return
	elif Input.is_action_just_pressed("jump"):
		if _try_mantle():
			return
		velocity.y = jump_velocity
	var target := dir * (run_speed if Input.is_action_pressed("push") else walk_speed)
	velocity.x = move_toward(velocity.x, target.x, walk_accel * delta)
	velocity.z = move_toward(velocity.z, target.z, walk_accel * delta)
	if dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)


## Grimper : s'il y a devant soi un obstacle dont le dessus est à portée, on se hisse dessus.
func _try_mantle() -> bool:
	var ry := visual.rotation.y
	var fwd := Vector3(-sin(ry), 0.0, -cos(ry))
	var space := get_world_3d().direct_space_state
	var feet := global_position
	var hit := {}
	for hgt in [0.3, 0.9, 1.5]:
		var q := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * hgt, feet + Vector3.UP * hgt + fwd * 0.9)
		q.exclude = [get_rid()]
		hit = space.intersect_ray(q)
		if not hit.is_empty() and absf(hit.normal.y) < 0.4:
			break
		hit = {}
	if hit.is_empty():
		return false
	var over: Vector3 = hit.position + fwd * 0.15
	var q2 := PhysicsRayQueryParameters3D.create(
		Vector3(over.x, feet.y + mantle_reach + 0.3, over.z), Vector3(over.x, feet.y + 0.3, over.z))
	q2.exclude = [get_rid()]
	var down := space.intersect_ray(q2)
	if down.is_empty() or down.normal.y < 0.7:
		return false
	var rise: float = down.position.y - feet.y
	if rise < 0.35 or rise > mantle_reach:
		return false
	var q3 := PhysicsRayQueryParameters3D.create(down.position + Vector3.UP * 0.15, down.position + Vector3.UP * 1.8)
	q3.exclude = [get_rid()]
	if not space.intersect_ray(q3).is_empty():
		return false  # pas la place de tenir debout là-haut
	_mantling = true
	_m_t = 0.0
	_m_dur = 0.25 + rise * 0.22
	_m_from = feet
	_m_to = down.position + Vector3.UP * 0.05
	velocity = Vector3.ZERO
	climbs += 1
	skate.last_event = "Grimpe"
	return true


func _mantle_step(delta: float) -> void:
	_m_t = minf(_m_t + delta / _m_dur, 1.0)
	# On monte d'abord, on avance ensuite.
	var up := clampf(_m_t / 0.65, 0.0, 1.0)
	var fwd := clampf((_m_t - 0.45) / 0.55, 0.0, 1.0)
	global_position = Vector3(
		lerpf(_m_from.x, _m_to.x, fwd), lerpf(_m_from.y, _m_to.y, up), lerpf(_m_from.z, _m_to.z, fwd))
	if _m_t >= 1.0:
		_mantling = false


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
	_mantling = false
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
	debug_label.text = "%s   %d km/h\n%s\n\nZQSD bouger · Maj courir / pousser · Espace sauter, grimper / ollie · E planche\nJ kickflip · K shove-it · L grind (maintenir) · R départ · Échap souris\nÀ pied, face à un mur : G graffiti (maintenir) · C couleur" % [
		state, roundi(kmh), skate.last_event]
