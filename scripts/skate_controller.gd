class_name SkateController
extends Node
## Physique du skate, séparée de la marche pour pouvoir la régler seule.
## Choix « arcade assistée » : on contrôle une vitesse et un cap, pas des
## roues. C'est le plus simple à rendre agréable ; on ajoutera de la physique
## seulement si les tests le demandent (cf. GDD, phase 1, « couper si »).

signal trick_done(trick_name: String, clean: bool)

@export_group("Roulage")
@export var push_accel := 7.0        ## m/s² quand on pousse
@export var max_push_speed := 8.5    ## on ne dépasse pas ça en poussant seul
@export var max_speed := 14.0        ## plafond (pentes, kickers)
@export var rolling_friction := 0.5  ## perte de vitesse en roue libre
@export var brake_decel := 7.0       ## frein (reculer)
@export var turn_rate := 2.4         ## rad/s à basse vitesse
@export var slope_factor := 1.0      ## 1 = gravité réelle sur les pentes

@export_group("Air")
@export var ollie_velocity := 5.2
@export var air_turn := 0.5          ## part du virage conservée en l'air
@export var flip_duration := 0.45    ## durée d'un kickflip / shove-it (s)

@export_group("Grind")
@export var grind_catch_radius := 0.7  ## distance horizontale max au rail
@export var grind_catch_above := 0.9   ## pieds au plus à 0,9 m au-dessus
@export var grind_min_speed := 3.5
@export var grind_friction := 0.4

var heading := 0.0       ## cap (rotation Y), 0 = regarde vers -Z
var speed := 0.0         ## vitesse le long du cap (négative = fakie)
var in_air := false
var trick := ""          ## figure en cours
var trick_t := 0.0       ## 0 → 1 pendant un flip
var grinding := false
var last_event := ""     ## affiché dans le HUD

var _rail: Rail
var _rail_dir := 1.0
var _rail_t := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func enter(p: CharacterBody3D, yaw: float) -> void:
	heading = yaw
	var flat := Vector3(p.velocity.x, 0.0, p.velocity.z)
	speed = flat.length()
	in_air = not p.is_on_floor()
	trick = ""
	trick_t = 0.0
	grinding = false


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


## Appelé à chaque frame physique par Player (avant move_and_slide).
func step(p: CharacterBody3D, delta: float) -> void:
	if grinding:
		_grind_step(p, delta)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var steer := -input.x

	if p.is_on_floor():
		if in_air:
			_land()
		var speed_ratio := absf(speed) / max_speed
		heading += steer * turn_rate * delta * clampf(1.2 - speed_ratio, 0.45, 1.2)

		if Input.is_action_pressed("push") or input.y < -0.5:
			if speed < max_push_speed:
				speed += push_accel * delta
		elif input.y > 0.5:
			speed = move_toward(speed, 0.0, brake_decel * delta)
		else:
			speed = move_toward(speed, 0.0, rolling_friction * delta)

		# Pente : la gravité accélère ou freine le long du cap.
		var n := p.get_floor_normal()
		var fwd := forward()
		var along := (fwd - n * fwd.dot(n)).normalized()
		speed += -_gravity * along.y * slope_factor * delta
		speed = clampf(speed, -max_speed, max_speed)

		p.velocity = along * speed

		if Input.is_action_just_pressed("jump"):
			p.velocity += Vector3.UP * ollie_velocity
			in_air = true
			trick = "Ollie"
			trick_t = 1.0
	else:
		if not in_air:
			in_air = true  # on a roulé hors d'un rebord
		heading += steer * turn_rate * air_turn * delta
		p.velocity.y -= _gravity * delta
		var fwd := forward()
		p.velocity.x = fwd.x * speed
		p.velocity.z = fwd.z * speed

		if trick_t >= 1.0 and (trick == "" or trick == "Ollie"):
			if Input.is_action_just_pressed("kickflip"):
				trick = "Kickflip"
				trick_t = 0.0
			elif Input.is_action_just_pressed("shove_it"):
				trick = "Shove-it"
				trick_t = 0.0
		if trick_t < 1.0:
			trick_t = minf(trick_t + delta / flip_duration, 1.0)

		if Input.is_action_pressed("grind"):
			_try_catch_rail(p)


func _land() -> void:
	in_air = false
	if trick == "":
		return
	var clean := trick_t >= 1.0
	last_event = trick if clean else "Chute (" + trick + " pas fini)"
	if not clean:
		speed *= 0.2
	trick_done.emit(trick, clean)
	trick = ""
	trick_t = 0.0


func _try_catch_rail(p: CharacterBody3D) -> void:
	if p.velocity.y > 2.0:
		return  # on monte encore franchement : trop tôt
	var feet := p.global_position
	for node in p.get_tree().get_nodes_in_group("grindable"):
		var rail := node as Rail
		if rail == null:
			continue
		var a := rail.top_start()
		var b := rail.top_end()
		var ab := b - a
		var t := clampf((feet - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var point := a + ab * t
		var flat_dist := Vector2(feet.x - point.x, feet.z - point.z).length()
		var above := feet.y - point.y
		if flat_dist <= grind_catch_radius and above > -0.25 and above <= grind_catch_above:
			_rail = rail
			_rail_t = t
			var dir := ab.normalized()
			_rail_dir = 1.0 if forward().dot(dir) >= 0.0 else -1.0
			speed = maxf(absf(speed), grind_min_speed)
			var d := dir * _rail_dir
			heading = atan2(-d.x, -d.z)
			grinding = true
			if trick_t < 1.0:
				trick_t = 1.0  # le flip se termine sur le rail
			trick = ""
			last_event = "50-50"
			p.global_position = point
			p.velocity = Vector3.ZERO
			return


func _grind_step(p: CharacterBody3D, delta: float) -> void:
	var a := _rail.top_start()
	var b := _rail.top_end()
	var ab := b - a
	speed = move_toward(speed, grind_min_speed * 0.6, grind_friction * delta)
	_rail_t += _rail_dir * speed * delta / ab.length()
	var dir := ab.normalized() * _rail_dir

	if Input.is_action_just_pressed("jump"):
		_leave_rail(p, dir, ollie_velocity, "50-50")
		return
	if _rail_t <= 0.0 or _rail_t >= 1.0 or not Input.is_action_pressed("grind"):
		_leave_rail(p, dir, 1.0, "50-50")
		return

	p.global_position = a + ab * _rail_t
	p.velocity = dir * speed


func _leave_rail(p: CharacterBody3D, dir: Vector3, up: float, done: String) -> void:
	grinding = false
	_rail = null
	p.global_position += Vector3.UP * 0.05
	p.velocity = dir * speed + Vector3.UP * up
	in_air = true
	trick = ""
	trick_t = 1.0
	trick_done.emit(done, true)
