class_name SkateController
extends Node
## Physique du skate, séparée de la marche pour pouvoir la régler seule.
## Choix « arcade assistée » : on contrôle une vitesse et un cap, pas des
## roues. C'est le plus simple à rendre agréable ; on ajoutera de la physique
## seulement si les tests le demandent (cf. GDD, phase 1, « couper si »).

signal trick_done(trick_name: String, clean: bool)

@export_group("Roulage")
@export var push_kick := 2.2         ## m/s gagnés par poussée (un coup de pied)
@export var push_cycle := 0.7        ## durée d'une poussée (s) : lever, frapper, revenir
@export var max_push_speed := 8.5    ## on ne dépasse pas ça en poussant seul
@export var max_speed := 14.0        ## plafond (pentes, kickers)
@export var rolling_friction := 0.5  ## perte de vitesse en roue libre
@export var brake_decel := 7.0       ## frein (reculer)
@export var turn_rate := 2.4         ## rad/s à basse vitesse
@export var slope_factor := 1.0      ## 1 = gravité réelle sur les pentes

@export_group("Air")
@export var ollie_velocity := 5.2   ## pop en sortie de grind
@export var ollie_min := 4.0         ## ollie à peine appuyé (≤ 0,2 s)
@export var ollie_max := 6.0         ## ollie chargé à fond (≥ 0,6 s)
@export var charge_min := 0.2
@export var charge_max := 0.6
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
var push_phase := -1.0   ## 0 → 1 pendant une poussée, -1 sinon (lu par l'animation)
var lean := 0.0          ## inclinaison dans les virages, -1 → 1 (lu par l'animation)
## Lus par l'animation :
var charge := -1.0       ## secondes d'appui sur Espace (accroupi), -1 sinon
var air_t := 0.0         ## secondes depuis le décollage
var pop_t := -1.0        ## secondes depuis le pop (le tail claque), -1 sinon
var reception := 0.0     ## 1 → 0 juste après l'atterrissage (amorti)
var freine := false      ## le pied arrière frotte le sol
var ollie_v := 0.0       ## impulsion du dernier ollie (m/s)
var saute := false       ## en l'air après un vrai saut (ollie, sortie de rail), pas une bosse
var vitesse_chute := 0.0 ## vitesse au moment d'une chute (la planche part avec)
const PUSH_CONTACT := Vector2(0.25, 0.6)  ## part du cycle où le pied touche le sol

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
	push_phase = -1.0
	lean = 0.0
	charge = -1.0
	pop_t = -1.0
	reception = 0.0
	freine = false


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


## Appelé à chaque frame physique par Player (avant move_and_slide).
func step(p: CharacterBody3D, delta: float) -> void:
	if grinding:
		_grind_step(p, delta)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var steer := -input.x
	reception = move_toward(reception, 0.0, delta / 0.3)
	if pop_t >= 0.0:
		pop_t = pop_t + delta if pop_t < 1.0 else -1.0

	if p.is_on_floor():
		if in_air:
			_land()
		var speed_ratio := absf(speed) / max_speed
		heading += steer * turn_rate * delta * clampf(1.2 - speed_ratio, 0.45, 1.2)

		# Pousser : des coups de pied, pas une accélération continue.
		var veut_pousser := (Input.is_action_pressed("push") or input.y < -0.5) and charge < 0.0
		if veut_pousser and push_phase < 0.0 and speed < max_push_speed:
			push_phase = 0.0
		if push_phase >= 0.0:
			var avant := push_phase
			push_phase += delta / push_cycle
			var dans := clampf(push_phase, PUSH_CONTACT.x, PUSH_CONTACT.y) - clampf(avant, PUSH_CONTACT.x, PUSH_CONTACT.y)
			if dans > 0.0 and speed < max_push_speed:
				speed = minf(speed + push_kick * dans / (PUSH_CONTACT.y - PUSH_CONTACT.x), max_push_speed)
			if push_phase >= 1.0:
				push_phase = 0.0 if veut_pousser and speed < max_push_speed else -1.0
		elif input.y > 0.5:
			speed = move_toward(speed, 0.0, brake_decel * delta)
		else:
			speed = move_toward(speed, 0.0, rolling_friction * delta)
		freine = push_phase < 0.0 and input.y > 0.5 and absf(speed) > 0.3
		lean = lerpf(lean, steer * clampf(absf(speed) / 6.0, 0.0, 1.0), minf(1.0, 8.0 * delta))

		# Pente : la gravité accélère ou freine le long du cap.
		var n := p.get_floor_normal()
		var fwd := forward()
		var along := (fwd - n * fwd.dot(n)).normalized()
		speed += -_gravity * along.y * slope_factor * delta
		speed = clampf(speed, -max_speed, max_speed)

		p.velocity = along * speed

		# Ollie chargé : appuyer = s'accroupir, relâcher = sauter (plus on a tenu, plus c'est haut).
		if Input.is_action_just_pressed("jump") and charge < 0.0:
			charge = 0.0
			push_phase = -1.0
		if charge >= 0.0:
			charge += delta
			if not Input.is_action_pressed("jump"):
				var k := clampf((charge - charge_min) / (charge_max - charge_min), 0.0, 1.0)
				ollie_v = lerpf(ollie_min, ollie_max, k)
				p.velocity += Vector3.UP * ollie_v
				in_air = true
				air_t = 0.0
				pop_t = 0.0
				saute = true
				charge = -1.0
				trick = "Ollie"
				trick_t = 1.0
	else:
		air_t += delta
		charge = -1.0
		if air_t > 0.15:
			freine = false  # une vraie phase en l'air, pas une bosse
		if p.velocity.y > 1.0:
			push_phase = -1.0   # un vrai saut interrompt la poussée ; une bosse non
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
	saute = false
	if air_t > 0.15:
		reception = 1.0  # amorti après un vrai saut, pas après une bosse
	air_t = 0.0
	if trick == "":
		return
	var clean := trick_t >= 1.0
	last_event = trick if clean else "Chute (" + trick + " pas fini)"
	if not clean:
		vitesse_chute = speed
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
	saute = up > 2.0
	air_t = 0.0
	trick = ""
	trick_t = 1.0
	trick_done.emit(done, true)
