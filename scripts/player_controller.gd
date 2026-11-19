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
## Caméra qui se replace d'elle-même derrière Loums quand il avance (à pied ou en skate).
## Elle reste libre à l'arrêt, et pendant `camera_pause` secondes après qu'on l'a tournée à la main.
@export var camera_suivi := 3.0      ## vitesse de recalage (plus grand = plus collé au dos)
@export var camera_pause := 1.2      ## délai (s) avant que le suivi reprenne après un mouvement manuel
@export var camera_vitesse_min := 1.0  ## en dessous (m/s), pas de suivi : on peut tourner autour de lui

var _camera_libre := 0.0

var mode: Mode = Mode.WALK
var spawn_position := Vector3.ZERO
var climbs := 0                     ## nombre de rétablissements (pour le carnet de session)
var _mantling := false
var _m_t := 0.0
var _m_dur := 0.4
var _m_from := Vector3.ZERO
var _m_to := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
const CHUTE_DUREE := 1.6            ## tomber, rester au sol, se relever (s)
var chute_t := -1.0                 ## secondes depuis la chute, -1 sinon (lu par l'animation)
var planche_libre := false          ## après une chute, la planche roule seule : il faut aller la chercher
var _planche_vel := Vector3.ZERO
## Monter / descendre de la planche prend un instant (lu par l'animation) :
## « decroche » = il prend la planche dans son dos, la pose devant lui et monte ;
## « accroche » = il ramasse la planche par le tail et la remet dans son dos.
const TRANSITION_DUREE := 0.5
var transition := ""
var transition_t := 0.0
var planche_depart := Transform3D()  ## où était la planche au début de « accroche »

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
	skate.trick_done.connect(_on_trick_done)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_libre = camera_pause
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
	if planche_libre:
		_planche_roule(delta)
	if chute_t >= 0.0:
		_chute_step(delta)
		return
	if transition != "":
		_transition_step(delta)
		return
	# (sur la planche, une bosse décolle les roues une image : ça compte comme au sol)
	var au_sol := is_on_floor() or (mode == Mode.SKATE and not skate.saute and skate.air_t < 0.15)
	if Input.is_action_just_pressed("toggle_board") and au_sol and not skate.grinding:
		if planche_libre:
			_ramasser()
		elif mode == Mode.WALK:
			_commencer("decroche")
		else:
			planche_depart = board.global_transform
			_set_mode(Mode.WALK)
			_commencer("accroche")

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
	if absf(cam.x) > 0.1 or absf(cam.y) > 0.1:
		_camera_libre = camera_pause
	_suivre_de_dos(delta)
	spring_arm.rotation.x = clampf(spring_arm.rotation.x - cam.y * stick_camera_speed * delta, -1.2, 0.25)
	_animate_board()
	_update_hud()


## Replace doucement la caméra dans le dos de Loums quand il se déplace : plus il va vite, plus elle suit.
func _suivre_de_dos(delta: float) -> void:
	_camera_libre = maxf(0.0, _camera_libre - delta)
	if _camera_libre > 0.0 or _mantling:
		return
	var v := absf(skate.speed) if mode == Mode.SKATE else Vector2(velocity.x, velocity.z).length()
	if v < camera_vitesse_min:
		return
	var cap := visual.rotation.y
	if mode == Mode.SKATE and skate.speed < 0.0:
		cap += PI  # en fakie, on regarde dans le sens de la marche
	# Moins de suivi quand on se déplace de côté par rapport à la caméra (sinon on tourne en rond).
	var b := camera_pivot.global_basis
	var avant := Vector2(-b.z.x, -b.z.z).normalized()
	var dir := Vector2(-sin(cap), -cos(cap))
	var face := 0.35 + 0.65 * maxf(0.0, avant.dot(dir))
	var force := clampf(v / 4.0, 0.3, 1.6) * camera_suivi * face
	camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, cap, clampf(force * delta, 0.0, 1.0))


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


## Figure pas finie à l'atterrissage : Loums tombe, la planche continue sans lui.
func _on_trick_done(_nom: String, propre: bool) -> void:
	if not propre and mode == Mode.SKATE:
		_tomber()


func _tomber() -> void:
	var dir := skate.forward()
	var v := maxf(absf(skate.vitesse_chute), 2.5)
	var quoi := skate.last_event
	_set_mode(Mode.WALK)
	chute_t = 0.0
	velocity = dir * v * 0.25
	planche_libre = true
	board.visible = true
	board.top_level = true
	board.global_transform = Transform3D(Basis(Vector3.UP, skate.heading), global_position + Vector3.UP * 0.085 + dir * 0.4)
	_planche_vel = dir * v * 0.9
	skate.last_event = quoi + " · va chercher ta planche (E)"


func _chute_step(delta: float) -> void:
	chute_t += delta
	velocity.y -= _gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	move_and_slide()
	if chute_t >= CHUTE_DUREE:
		chute_t = -1.0


## La planche seule : elle roule dans la direction du ride, freine, rebondit sur les murs.
func _planche_roule(delta: float) -> void:
	var v := _planche_vel.length()
	if v < 0.01:
		return
	var space := get_world_3d().direct_space_state
	var pos := board.global_position
	var pas := _planche_vel * delta
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.1, pos + Vector3.UP * 0.1 + pas.normalized() * (pas.length() + 0.4))
	q.exclude = [get_rid()]
	var mur := space.intersect_ray(q)
	if not mur.is_empty() and absf(mur.normal.y) < 0.5:
		var n: Vector3 = mur.normal
		n.y = 0.0
		_planche_vel = _planche_vel.bounce(n.normalized()) * 0.4
		pas = _planche_vel * delta
	pos += pas
	var q2 := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.8, pos + Vector3.DOWN * 2.0)
	q2.exclude = [get_rid()]
	var sol := space.intersect_ray(q2)
	if not sol.is_empty():
		pos.y = sol.position.y + 0.085
	var dir := _planche_vel.normalized()
	board.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), pos)
	_planche_vel = _planche_vel.move_toward(Vector3.ZERO, 1.6 * delta)


func _ramasser() -> void:
	var d := Vector2(board.global_position.x - global_position.x, board.global_position.z - global_position.z).length()
	if d > 1.6:
		skate.last_event = "Ta planche est là-bas (%d m)" % roundi(d)
		return
	planche_depart = board.global_transform
	planche_libre = false
	_planche_vel = Vector3.ZERO
	board.top_level = false
	board.visible = true
	board.global_transform = planche_depart
	_commencer("accroche")
	skate.last_event = "Planche ramassée"


func _commencer(quoi: String) -> void:
	transition = quoi
	transition_t = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _transition_step(delta: float) -> void:
	transition_t += delta
	velocity.y -= _gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, walk_accel * delta)
	velocity.z = move_toward(velocity.z, 0.0, walk_accel * delta)
	move_and_slide()
	if transition_t >= TRANSITION_DUREE:
		var fini := transition
		transition = ""
		if fini == "decroche":
			_set_mode(Mode.SKATE)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	board.visible = mode == Mode.SKATE or planche_libre
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
	chute_t = -1.0
	transition = ""
	if planche_libre:
		planche_libre = false
		board.top_level = false
	global_position = spawn_position
	velocity = Vector3.ZERO
	skate.grinding = false
	_mantling = false
	skate.speed = 0.0
	_set_mode(Mode.WALK)


const POP_DUREE := 0.2

## Rotation de la planche : pop, genoux remontés, flips (purement visuel).
func _animate_board() -> void:
	if planche_libre or mode == Mode.WALK:
		return  # à pied, c'est Personnage qui la porte (dans le dos) ou la manie
	board.rotation = Vector3.ZERO
	board.position = Vector3(0, 0.085, 0)
	if mode == Mode.SKATE and not skate.in_air:
		board.rotation.z = -skate.lean * 0.12   # la planche bascule dans le virage
	if mode != Mode.SKATE:
		return
	if skate.in_air and not skate.grinding:
		# Genoux remontés : la planche monte vers lui, puis redescend avant la réception.
		var monte := smoothstep(0.0, 0.12, skate.air_t) if skate.saute else smoothstep(0.25, 0.45, skate.air_t)
		var descend := clampf((-velocity.y - 1.0) / 3.0, 0.0, 1.0)
		board.position.y += 0.22 * monte * (1.0 - 0.6 * descend)
	if skate.pop_t >= 0.0 and skate.pop_t < POP_DUREE:
		# Pop : le tail claque au sol, le nose se lève, puis la planche se remet à plat.
		var a := 0.5 * sin(PI * skate.pop_t / POP_DUREE)
		var tail := Vector3(0, 0, 0.38)
		var r := Basis(Vector3.RIGHT, a)
		board.rotation.x = a
		board.position += tail - r * tail
	if skate.trick_t >= 1.0:
		return
	match skate.trick:
		"Kickflip":
			board.rotation.z = TAU * skate.trick_t
		"Shove-it":
			board.rotation.y = PI * skate.trick_t


func _update_hud() -> void:
	var kmh := absf(skate.speed) * 3.6 if mode == Mode.SKATE else Vector2(velocity.x, velocity.z).length() * 3.6
	var state := "CHUTE" if chute_t >= 0.0 else "À PIED"
	if mode == Mode.SKATE:
		state = "GRIND" if skate.grinding else ("AIR" if skate.in_air else "SKATE")
	debug_label.text = "%s   %d km/h\n%s\n\nZQSD bouger · Maj courir / pousser · Espace sauter, grimper / ollie · E planche\nJ kickflip · K shove-it · L grind (maintenir) · R départ · Échap souris\nÀ pied, face à un mur : G bref : tag à la main · G maintenu : flop, pièce · C couleur · B rendu BD / d'origine" % [
		state, roundi(kmh), skate.last_event]
