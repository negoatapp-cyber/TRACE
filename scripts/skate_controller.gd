class_name SkateController
extends Node
## Physique du skate, séparée de la marche pour pouvoir la régler seule.
## Choix « arcade assistée » : on contrôle une vitesse et un cap, pas des
## roues. C'est le plus simple à rendre agréable ; on ajoutera de la physique
## seulement si les tests le demandent (cf. GDD, phase 1, « couper si »).

signal trick_done(trick_name: String, clean: bool)
signal atterri(temps_en_l_air: float, qualite: String)  ## pour les secousses, la poussière (player)

@export_group("Roulage")
@export var push_kick := 3.2         ## m/s gagnés par poussée (un coup de pied) — Louma 21.11 : beaucoup plus de puissance
@export var push_cycle := 0.55       ## durée d'une poussée (s) : lever, frapper, revenir
@export var max_push_speed := 11.5   ## on ne dépasse pas ça en poussant seul
@export var max_speed := 18.0       ## plafond (pentes, kickers)
@export var rolling_friction := 0.3  ## perte de vitesse en roue libre
@export var brake_decel := 7.0       ## frein (reculer)
@export var turn_rate := 2.4         ## rad/s à basse vitesse
@export var slope_factor := 1.0      ## 1 = gravité réelle sur les pentes

@export_group("Air")
@export var ollie_velocity := 5.2   ## pop en sortie de grind
@export var ollie_min := 4.0         ## ollie à peine appuyé (≤ 0,2 s)
@export var ollie_max := 6.0         ## ollie chargé à fond (≥ 0,6 s)
@export var charge_min := 0.2
@export var charge_max := 0.6
@export var air_turn := 0.12         ## en l'air, la direction ne change presque plus : le joystick fait tourner le corps
@export var spin_max := 9.0          ## rad/s : rotation en l'air (un 360 en 0,7 s) — Louma 21.11 : « ça va vite en l'air »
@export var spin_accel := 80.0       ## rad/s² : la rotation démarre et s'arrête vite
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
var placement_pop := 0.0 ## placement atteint pendant la préparation, repris au décollage
var saute := false       ## en l'air après un vrai saut (ollie, sortie de rail), pas une bosse
var vitesse_chute := 0.0 ## vitesse au moment d'une chute (la planche part avec)
var tail_devant := false ## orientation du plateau après un shove-it réussi
## Figures (Louma 21.11) : rotations, grabs, grinds, manual, et leur nom à l'écran.
const GOOFY := true      ## Loums est goofy : tourner vers la droite = frontside
var spin := 0.0          ## rotation du corps et de la planche en l'air (rad, + = vers la gauche), lue par le joueur
var spin_vit := 0.0
var grab := 0.0          ## 0 → 1 : la main va chercher la planche (lu par l'animation)
var grab_nom := ""
var _grab_t := 0.0
var manual := false      ## sur les roues arrière
var manual_bal := 0.0    ## -1 → 1 : l'équilibre du manual (lu par l'écran et l'animation)
var _manual_t := 0.0
var grind_nom := ""      ## 50-50, Boardslide, Nosegrind, 5-0
var slide := false       ## planche en travers du rail (boardslide)
var _fakie_depart := false
## Le combo en cours, lu par l'écran (figures_hud.gd).
var combo: Array[String] = []
var combo_etat := ""     ## "en_cours", "propre", "juste", "chute", "fini"
var combo_maj := 0       ## change à chaque mise à jour
var _sol_t := 0.0
const PUSH_CONTACT := Vector2(0.25, 0.6)  ## part du cycle où le pied touche le sol
const FENETRE_FLICK := 0.12  ## accepte la figure juste avant le relâchement de l'ollie
var _figure_preparee := ""
var _delai_flick := 0.0

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
	air_t = 0.0
	saute = false
	_figure_preparee = ""
	tail_devant = false
	pop_t = -1.0
	placement_pop = 0.0
	reception = 0.0
	freine = false
	spin = 0.0
	spin_vit = 0.0
	grab = 0.0
	manual = false
	slide = false
	combo.clear()


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


## Appelé à chaque frame physique par Player (avant move_and_slide).
func step(p: CharacterBody3D, delta: float) -> void:
	if grinding:
		_grind_step(p, delta)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var steer := -input.x
	_delai_flick = maxf(0.0, _delai_flick - delta)
	if _delai_flick == 0.0:
		_figure_preparee = ""
	var figure := ""
	if Input.is_action_just_pressed("kickflip"):
		figure = "Kickflip"
	elif Input.is_action_just_pressed("shove_it"):
		figure = "Shove-it"
	reception = move_toward(reception, 0.0, delta / 0.3)
	if pop_t >= 0.0:
		pop_t = pop_t + delta if pop_t < 1.0 else -1.0

	if p.is_on_floor():
		if in_air:
			_land()
		# roulé sur le dessus d'un rail ou d'un ledge : c'est un grind
		if absf(speed) > 2.0 and p.get_floor_normal().y > 0.75:
			_try_catch_rail(p, true)
			if grinding:
				return
		spin = move_toward(spin, 0.0, 7.0 * delta)   # le reste d'une rotation se redresse au sol
		spin_vit = 0.0
		grab = move_toward(grab, 0.0, delta / 0.1)
		_manual_step(input, delta)
		if manual:
			input.y = 0.0   # en manual, avant/arrière sert à l'équilibre, pas à pousser ni freiner
		if not manual and combo_etat == "en_cours":
			_sol_t += delta
			if _sol_t > 0.8:
				_finir_combo("fini")
		var speed_ratio := absf(speed) / max_speed
		heading += steer * turn_rate * delta * clampf(1.2 - speed_ratio, 0.45, 1.2)

		# Pousser : des coups de pied, pas une accélération continue.
		var frein_demande := input.y > 0.5
		if frein_demande:
			push_phase = -1.0
		# il pousse tout seul tant que la direction va vers l'avant (Louma 21.11)
		var veut_pousser := (Input.is_action_pressed("push") or input.y < -0.2) and charge < 0.0 and not frein_demande
		if veut_pousser and push_phase < 0.0 and speed < max_push_speed:
			push_phase = 0.0
		if push_phase >= 0.0:
			var avant := push_phase
			push_phase += delta / push_cycle
			# Intégrale d'une impulsion qui monte puis retombe pendant l'appui au sol.
			var dans := smoothstep(PUSH_CONTACT.x, PUSH_CONTACT.y, push_phase) - smoothstep(PUSH_CONTACT.x, PUSH_CONTACT.y, avant)
			if dans > 0.0 and speed < max_push_speed:
				speed = minf(speed + push_kick * dans, max_push_speed)
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
			if figure != "":
				_figure_preparee = figure
				_delai_flick = FENETRE_FLICK
			charge += delta
			placement_pop = smoothstep(0.0, 0.16, charge)
			if not Input.is_action_pressed("jump"):
				var k := clampf((charge - charge_min) / (charge_max - charge_min), 0.0, 1.0)
				ollie_v = lerpf(ollie_min, ollie_max, k)
				p.velocity += Vector3.UP * ollie_v
				in_air = true
				air_t = 0.0
				pop_t = 0.0
				saute = true
				charge = -1.0
				_fakie_depart = speed < 0.0
				if manual:
					_fin_manual()
				trick = "Ollie"
				trick_t = 1.0
				if _figure_preparee != "":
					trick = _figure_preparee
					trick_t = 0.0
					_figure_preparee = ""
	else:
		air_t += delta
		charge = -1.0
		if air_t > 0.15:
			freine = false  # une vraie phase en l'air, pas une bosse
		if p.velocity.y > 1.0:
			push_phase = -1.0   # un vrai saut interrompt la poussée ; une bosse non
		if not in_air:
			in_air = true  # on a roulé hors d'un rebord
		var vrai_saut := saute or air_t > 0.2   # une bosse ou un trottoir : on continue de tourner normalement
		heading += steer * turn_rate * (air_turn if vrai_saut else 1.0) * delta
		if not vrai_saut:
			steer = 0.0
		# Rotation en l'air : le joystick fait tourner le corps et la planche, vite, sans changer la trajectoire.
		spin_vit = move_toward(spin_vit, steer * spin_max, spin_accel * delta)
		spin += spin_vit * delta
		if absf(steer) < 0.2 and absf(spin_vit) < 2.0:
			# joystick lâché : le corps se cale sur le demi-tour le plus proche (aide, comme dans les jeux de skate)
			spin = move_toward(spin, roundf(spin / PI) * PI, 3.5 * delta)
		# Grab : Maj (ou GRAB au téléphone) tenu en l'air ; haut = nose, bas = tail, sinon indy.
		var tient := Input.is_action_pressed("push") and (saute or air_t > 0.25)
		if tient and grab < 0.05:
			grab_nom = "Nosegrab" if input.y < -0.5 else ("Tailgrab" if input.y > 0.5 else "Indy")
		grab = move_toward(grab, 1.0 if tient else 0.0, delta / 0.12)
		if grab > 0.8:
			_grab_t += delta
		p.velocity.y -= _gravity * delta
		var fwd := forward()
		p.velocity.x = fwd.x * speed
		p.velocity.z = fwd.z * speed

		if figure != "" and (trick == "" or trick == "Ollie"):
			trick = figure
			trick_t = 0.0
		if trick_t < 1.0:
			trick_t = minf(trick_t + delta / flip_duration, 1.0)

		# le rail s'accroche tout seul en tombant dessus (clavier comme téléphone)
		_try_catch_rail(p)


func _land() -> void:
	in_air = false
	saute = false
	var t_air := air_t
	if air_t > 0.15:
		reception = 1.0  # amorti après un vrai saut, pas après une bosse
	air_t = 0.0
	# Rotation : on retombe sur le demi-tour le plus proche ; trop de travers, c'est la chute.
	var n := roundi(spin / PI)
	var reste := absf(spin - n * PI)
	var qualite := "propre"
	if reste > deg_to_rad(55.0):
		qualite = "chute"
	elif reste > deg_to_rad(28.0):
		qualite = "juste"
	if trick != "" and trick_t < 1.0:
		qualite = "chute"   # flip pas fini
	if grab > 0.5 and qualite == "propre":
		qualite = "juste"   # grab lâché trop tard
	var nom := _nom_figure(n)
	var est_figure := nom != "" and (t_air > 0.3 or trick != "")
	if n % 2 != 0:
		heading += PI       # retombé à l'envers : il repart en fakie (ou revient en normal)
		speed = -speed
	spin -= n * PI
	spin_vit = 0.0
	grab = 0.0
	_grab_t = 0.0
	if qualite != "chute" and trick == "Shove-it":
		tail_devant = not tail_devant
	atterri.emit(t_air, qualite if est_figure or qualite == "chute" else "")
	if qualite == "chute":
		last_event = "Chute"
		vitesse_chute = speed
		speed *= 0.2
		if combo_etat != "en_cours":
			combo.clear()
		if nom != "":
			combo.append(nom)
		_finir_combo("chute")
		trick_done.emit(trick if trick != "" else nom, false)
		trick = ""
		trick_t = 0.0
		return
	if qualite == "juste":
		speed *= 0.7
	if est_figure:
		_ajouter(nom, qualite)
	if trick != "":
		trick_done.emit(trick, true)
	trick = ""
	trick_t = 0.0


## Le nom d'une figure aérienne : flip, rotation, grab (« Kickflip FS 180 », « BS 360 Indy »).
func _nom_figure(demi_tours: int) -> String:
	var parts: Array[String] = []
	var base := trick
	if _fakie_depart:
		parts.append("Fakie")
	if base != "" and not (base == "Ollie" and (demi_tours != 0 or _grab_t > 0.15)):
		parts.append(base)
	if demi_tours != 0:
		var fs := (spin < 0.0) == GOOFY
		parts.append("%s %d" % ["FS" if fs else "BS", absi(demi_tours) * 180])
	if _grab_t > 0.15:
		parts.append(grab_nom)
	if parts.size() == 1 and parts[0] == "Fakie":
		return ""
	return " ".join(parts)


func _ajouter(nom: String, qualite: String) -> void:
	if combo_etat != "en_cours":
		combo.clear()
	combo.append(nom)
	combo_etat = "en_cours"
	_sol_t = 0.0
	last_event = nom
	combo_maj += 1
	_derniere_qualite = qualite


var _derniere_qualite := "propre"


func _finir_combo(etat: String) -> void:
	if combo.is_empty():
		combo_etat = ""
		return
	if etat == "fini" and _derniere_qualite == "juste":
		etat = "juste"
	combo_etat = etat if etat != "fini" else "propre"
	combo_maj += 1
	_sol_t = 0.0
	# le combo reste affiché un moment, puis l'écran l'efface (figures_hud.gd)


## Manual : B (ou MANUAL au téléphone) tenu en roulant ; avant/arrière garde l'équilibre.
func _manual_step(input: Vector2, delta: float) -> void:
	var veut := Input.is_action_pressed("grind") and absf(speed) > 1.5 and charge < 0.0
	if veut and not manual:
		manual = true
		manual_bal = 0.15
		_manual_t = 0.0
		push_phase = -1.0
		if combo_etat != "en_cours":
			combo.clear()
		combo_etat = "en_cours"
		combo.append("Manual")
		combo_maj += 1
	if not manual:
		return
	_manual_t += delta
	_sol_t = 0.0
	# instable : plus on penche, plus ça penche ; un peu de vibration ; le joueur rattrape
	manual_bal += (manual_bal * 1.1 + sin(_manual_t * 4.1) * 0.3 + 0.08) * delta + input.y * 2.0 * delta
	speed = move_toward(speed, 0.0, rolling_friction * 0.5 * delta)
	if absf(manual_bal) > 1.0:
		manual = false
		last_event = "Chute"
		vitesse_chute = speed
		speed *= 0.3
		_finir_combo("chute")
		trick_done.emit("Manual", false)
		return
	if not veut:
		_fin_manual()


func _fin_manual() -> void:
	manual = false
	manual_bal = 0.0
	if _manual_t < 0.35 and not combo.is_empty() and combo[-1] == "Manual":
		combo.pop_back()   # trop court pour compter
	_derniere_qualite = "propre"
	combo_maj += 1


func _try_catch_rail(p: CharacterBody3D, au_sol := false) -> void:
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
		var accroche := flat_dist <= grind_catch_radius and above > -0.25 and above <= grind_catch_above
		if au_sol:
			accroche = flat_dist <= 0.3 and above > -0.06 and above < 0.15   # les roues sont vraiment sur le dessus
		if accroche:
			_rail = rail
			_rail_t = t
			var dir := ab.normalized()
			_rail_dir = 1.0 if forward().dot(dir) >= 0.0 else -1.0
			# arrivé dans l'axe : 50-50 ; de travers : boardslide (le corps reste en travers du rail)
			var axe := absf(forward().dot(dir))
			slide = axe < cos(deg_to_rad(35.0))
			grind_nom = "Boardslide" if slide else "50-50"
			var nom_air := _nom_figure(roundi(spin / PI))
			spin = 0.0
			spin_vit = 0.0
			grab = 0.0
			_grab_t = 0.0
			if nom_air != "" and nom_air != "Ollie":
				_ajouter(nom_air, "propre")
			_ajouter(grind_nom, "propre")
			last_event = grind_nom
			speed = maxf(absf(speed), grind_min_speed)
			var d := dir * _rail_dir
			heading = atan2(-d.x, -d.z)
			grinding = true
			in_air = false
			if manual:
				_fin_manual()
			if trick == "Shove-it":
				tail_devant = not tail_devant
			trick_t = 1.0  # le flip se termine sur le rail
			trick = ""
			_fakie_depart = false
			p.global_position = point
			p.velocity = Vector3.ZERO
			return


func _grind_step(p: CharacterBody3D, delta: float) -> void:
	var a := _rail.top_start()
	var b := _rail.top_end()
	var ab := b - a
	var dir := ab.normalized() * _rail_dir
	speed = move_toward(speed, grind_min_speed * 0.6, grind_friction * delta)
	# rail en pente (main courante d'escalier) : on prend de la vitesse en descendant
	speed = clampf(speed - _gravity * dir.y * 0.7 * delta, 1.0, max_speed)
	_rail_t += _rail_dir * speed * delta / ab.length()

	_sol_t = 0.0
	if not slide:
		# sur le rail : avant = nosegrind, arrière = 5-0
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var n := "Nosegrind" if input.y < -0.5 else ("5-0" if input.y > 0.5 else "50-50")
		if n != grind_nom:
			grind_nom = n
			if not combo.is_empty() and combo[-1] in ["50-50", "Nosegrind", "5-0"]:
				combo[-1] = n
				combo_maj += 1
	if Input.is_action_just_pressed("jump"):
		_leave_rail(p, dir, ollie_velocity, grind_nom)
		return
	if _rail_t <= 0.0 or _rail_t >= 1.0:
		_leave_rail(p, dir, 1.0, grind_nom)
		return

	p.global_position = a + ab * _rail_t
	p.velocity = dir * speed


func _leave_rail(p: CharacterBody3D, dir: Vector3, up: float, done: String) -> void:
	grinding = false
	slide = false
	_rail = null
	_fakie_depart = speed < 0.0
	p.global_position += Vector3.UP * 0.05
	p.velocity = dir * speed + Vector3.UP * up
	in_air = true
	saute = up > 2.0
	air_t = 0.0
	trick = ""
	trick_t = 1.0
	trick_done.emit(done, true)


## Contrôles tactiles actifs ? (lu par le nœud, pas par le nom global : les scripts de test compilent
## SkateController avant que les autoloads n'existent)
func _tactile(p: Node) -> bool:
	var t := p.get_tree().root.get_node_or_null("TouchControls")
	return t != null and bool(t.get("actif"))
