class_name Player
extends CharacterBody3D
## LOUMS dans l'îlot gris : marche, monte sur sa planche, descend.
## Le corps physique ne tourne jamais ; seul `Visual` tourne (plus stable).
## L'origine du nœud est aux pieds.

enum Mode { WALK, SKATE }

@export var walk_speed := 3.9      ## petite foulée de course (Sleeping Dogs) ; moins si le stick est à peine poussé
@export var run_speed := 6.8        ## en maintenant Maj : la course franche
@export var walk_accel := 32.0
@export var mantle_reach := 2.6     ## hauteur max qu'on attrape depuis les pieds (m)
@export var jump_velocity := 4.2
@export var mouse_sensitivity := 0.003
@export var stick_camera_speed := 2.5
## Caméra qui se replace d'elle-même derrière Loums quand il avance (à pied ou en skate).
## Elle reste libre à l'arrêt, et pendant `camera_pause` secondes après qu'on l'a tournée à la main.
@export var camera_suivi := 1.8      ## vitesse de recalage (plus grand = plus collé au dos)
@export var camera_vitesse_max := 1.3  ## rad/s : le recalage ne tourne jamais plus vite (jamais de coup brusque)
@export var camera_pause := 1.2      ## délai (s) avant que le suivi reprenne après un mouvement manuel
@export var camera_vitesse_min := 1.0  ## en dessous (m/s), pas de suivi : on peut tourner autour de lui

var _camera_libre := 0.0
## Caméra au doigt (Louma 21.11) : le doigt donne une cible, la caméra la rejoint en douceur.
const DOIGT_VERTICAL := 0.35        ## le haut/bas au doigt est 3 fois moins sensible que la rotation
const DOIGT_LISSAGE := 18.0         ## vitesse à laquelle la caméra rattrape le doigt
const TANGAGE_DOIGT := Vector2(-0.95, 0.12)  ## au doigt, on ne bascule ni sous le sol ni à la verticale
const TANGAGE_REPOS := -0.2   ## Louma 21.11 : plus à hauteur d'épaule, moins vue d'ensemble        ## l'angle où elle revient d'elle-même quand on bouge
const ZOOM_MIN := 2.4
const ZOOM_MAX := 8.0
var _doigt_reste := Vector2.ZERO    ## rotation demandée au doigt, pas encore appliquée
var _zoom_cible := -1.0

var mode: Mode = Mode.WALK
var spawn_position := Vector3.ZERO
var climbs := 0                     ## nombre de rétablissements (pour le carnet de session)
var _mantling := false
## Suspendu à un rebord trop haut pour se hisser d'un coup (balcon, muret de toit, prise) :
## on s'y accroche en sautant (Espace maintenu), on se décale (Q/D), on monte (Espace), on lâche (S).
var suspendu := false
var accroches := 0                  ## nombre de fois où il s'est accroché (tests, carnet)
var _rebord := Vector3.ZERO         ## point du bord sous les mains
var _rebord_n := Vector3.ZERO       ## normale du mur, vers Loums
var gouttiere: Node3D = null       ## la descente d'eau à laquelle il grimpe (Getting Up)
var _accroche_relachee := false
const GOUTTIERE_VITESSE := 2.2
var _bond_t := -1.0                 ## bond vers le rebord du dessus en cours (0 → 1), -1 sinon
var _bond_de := Vector3.ZERO
var _bond_vers := Vector3.ZERO
var _bond_sortie := 0.15             ## de combien il se décolle du mur pendant le bond (passer devant le balcon tenu)
var decale := 0.0                   ## suspendu : vitesse de côté le long du bord (m/s, + = droite), lue par l'animation
var decale_dist := 0.0              ## distance parcourue de côté (cadence des mains)
const BOND_MAX := 3.1               ## un étage de balcon en balcon (2,8 m) et un peu de marge
const ACCROCHE_MAX := 3.3           ## hauteur max du bord au-dessus des pieds (au moment où on l'attrape)
const SOUS_LES_MAINS := 2.05        ## des pieds aux mains, bras tendus
var _m_t := 0.0
var _m_dur := 0.4
var _m_from := Vector3.ZERO
var _m_to := Vector3.ZERO
var _m_par := 0.0                   ## de combien il passe au-dessus du point d'arrivée (muret de toit)
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
const Skateboard = preload("res://scripts/skateboard.gd")
@onready var board: Skateboard = $Visual/Board
@onready var skate: SkateController = $SkateController
@onready var debug_label: Label = $HUD/DebugLabel
var _f3_tenu := false


## Pour vérifier qu'un geste ne fait pas entrer Loums dans le décor (grimper, s'accrocher, bondir) :
## un corps de la taille du sien, un peu aminci pour tolérer le contact avec le mur qu'il touche.
const CORPS_RAYON := 0.32
const CORPS_HAUT := 1.75
const CORPS_MARGE := 0.05
var _forme_test := CapsuleShape3D.new()


func _requete_corps(pieds: Vector3) -> PhysicsShapeQueryParameters3D:
	_forme_test.radius = CORPS_RAYON - CORPS_MARGE
	_forme_test.height = CORPS_HAUT - CORPS_MARGE * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _forme_test
	q.transform = Transform3D(Basis(), pieds + Vector3.UP * (CORPS_HAUT * 0.5 + 0.03))
	q.exclude = [get_rid()]
	return q


## Loums tiendrait-il là (pieds à `pieds`) sans rien traverser ?
func place_libre(pieds: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_shape(_requete_corps(pieds), 1).is_empty()


## Comme place_libre, mais les prises de grimpe (balcons, corniches) ne comptent pas : sur une gouttière,
## Loums les longe, il ne doit pas rester coincé dessous.
func _libre_sauf_prises(pieds: Vector3) -> bool:
	for r in get_world_3d().direct_space_state.intersect_shape(_requete_corps(pieds), 8):
		var c := r.collider as Node
		if c == null or not c.is_in_group("prise"):
			return false
	return true


## Le corps peut-il aller en ligne droite de `a` à `b` (positions des pieds) sans rien heurter ?
func trajet_libre(a: Vector3, b: Vector3) -> bool:
	var q := _requete_corps(a)
	q.motion = b - a
	var r := get_world_3d().direct_space_state.cast_motion(q)
	return r[0] >= 0.999


## Se hisser de `de` à `vers` : monter à la verticale, passer par-dessus, se poser (comme _mantle_step).
## Rend la hauteur à laquelle il passe au-dessus du point d'arrivée (un muret de toit, un garde-corps
## qui dépasse), ou -1 s'il ne peut y aller qu'en traversant quelque chose.
func hisse_libre(de: Vector3, vers: Vector3) -> float:
	if not place_libre(vers + Vector3.UP * 0.02):
		return -1.0
	for par: float in [0.0, 0.4, 0.8, 1.2]:
		var coude := Vector3(de.x, vers.y + 0.02 + par, de.z)
		var dessus := vers + Vector3.UP * (0.02 + par)
		if trajet_libre(de + Vector3.UP * 0.02, coude) and trajet_libre(coude, dessus) \
				and (par == 0.0 or trajet_libre(dessus, vers + Vector3.UP * 0.02)):
			return par
	return -1.0


func _ready() -> void:
	debug_label.visible = false
	spawn_position = global_position
	spring_arm.add_excluded_object(get_rid())
	# la caméra a un volume : elle s'arrête avant les murs au lieu de passer à travers
	var boule := SphereShape3D.new()
	boule.radius = 0.25
	spring_arm.shape = boule
	spring_arm.rotation.x = TANGAGE_REPOS
	camera_pivot.top_level = true  # la caméra suit sans hériter des à-coups
	add_to_group("player")
	if not TouchControls.actif:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_mode(Mode.WALK)
	skate.trick_done.connect(_on_trick_done)
	_sensations_pretes()


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


## Caméra au doigt (contrôles tactiles) : `rel` est un déplacement déjà mis à l'échelle (radians).
func touch_look(rel: Vector2) -> void:
	_camera_libre = camera_pause
	_doigt_reste += Vector2(rel.x, rel.y * DOIGT_VERTICAL)


## Deux doigts : pincer / écarter = zoom (facteur > 1 : on s'éloigne), tourner = pivoter autour de Loums.
func touch_zoom(facteur: float) -> void:
	if _zoom_cible < 0.0:
		_zoom_cible = spring_arm.spring_length
	_zoom_cible = clampf(_zoom_cible * facteur, ZOOM_MIN, ZOOM_MAX)


func touch_twist(angle: float) -> void:
	_camera_libre = camera_pause
	_doigt_reste.x += angle


## Applique en douceur ce que le doigt a demandé (les gestes arrivent par à-coups, la caméra glisse).
func _camera_doigt(delta: float) -> void:
	if _doigt_reste.length_squared() > 0.0000001:
		var part := _doigt_reste * minf(1.0, DOIGT_LISSAGE * delta)
		_doigt_reste -= part
		camera_pivot.rotate_y(-part.x)
		spring_arm.rotation.x = clampf(spring_arm.rotation.x - part.y, TANGAGE_DOIGT.x, TANGAGE_DOIGT.y)
	if _zoom_cible > 0.0:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, _zoom_cible, minf(1.0, 10.0 * delta))


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
	if suspendu:
		_suspendu_step(delta)
		return
	if gouttiere:
		_gouttiere_step(delta)
		return

	match mode:
		Mode.WALK:
			_walk(delta)
		Mode.SKATE:
			skate.step(self, delta)
			# le corps et la planche tournent en l'air (spin) ; en boardslide ils restent en travers du rail
			visual.rotation.y = skate.heading + skate.spin + (PI * 0.5 if skate.slide else 0.0)

	if not (mode == Mode.SKATE and skate.grinding):
		move_and_slide()
		if is_on_floor():
			_accroche_relachee = false

	if global_position.y < -20.0:
		_respawn()


func _process(delta: float) -> void:
	# Caméra collée à Loums (contre un mur, dans un échafaudage) : on le cache, lui et sa planche,
	# plutôt que de remplir l'écran avec son dos (comme les jeux à la 3e personne).
	var cam3d := spring_arm.get_child(0) as Node3D if spring_arm.get_child_count() > 0 else null
	if cam3d:
		var pres := cam3d.global_position.distance_to(global_position + Vector3.UP * 1.3) < 0.85
		visual.visible = not pres
	# Caméra : suit le joueur en douceur, stick droit pour tourner.
	var target := global_position + Vector3.UP * 1.4
	camera_pivot.global_position = camera_pivot.global_position.lerp(target, minf(1.0, 12.0 * delta))
	var cam := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	camera_pivot.rotate_y(-cam.x * stick_camera_speed * delta)
	if absf(cam.x) > 0.1 or absf(cam.y) > 0.1:
		_camera_libre = camera_pause
	_camera_doigt(delta)
	# Distance de base : 3 m en paysage ; en portrait l'image est étroite, on recule un peu (tant qu'on n'a pas zoomé).
	if _zoom_cible < 0.0 and not spring_arm.has_meta("vehicule"):
		var ecran := get_viewport().get_visible_rect().size
		spring_arm.spring_length = 4.2 if ecran.y > ecran.x else 3.0
	_suivre_de_dos(delta)
	spring_arm.rotation.x = clampf(spring_arm.rotation.x - cam.y * stick_camera_speed * delta, -1.2, 0.25)
	_animate_board()
	_sensations(delta)
	_update_hud()
	# collé à un mur, la caméra arrive sur Loums : on le cache plutôt que de filmer l'intérieur de son corps
	var perso := visual.get_node_or_null("Personnage") as Node3D
	if perso:
		perso.visible = spring_arm.get_hit_length() > 0.7


## Replace doucement la caméra dans le dos de Loums quand il se déplace : plus il va vite, plus elle suit.
func _suivre_de_dos(delta: float) -> void:
	_camera_libre = maxf(0.0, _camera_libre - delta)
	if _camera_libre > 0.0 or _mantling:
		return
	var v := absf(skate.speed) if mode == Mode.SKATE else Vector2(velocity.x, velocity.z).length()
	if v < camera_vitesse_min:
		return
	var cap := skate.heading if mode == Mode.SKATE else visual.rotation.y  # la rotation en l'air ne fait pas tourner la caméra
	if mode == Mode.SKATE and skate.speed < 0.0:
		cap += PI  # en fakie, on regarde dans le sens de la marche
	# Louma 21.11 (5 h) : dès qu'on se met en mouvement, la caméra passe dans le dos, même si on part de face
	# ou vers elle. Elle ne tourne plus en rond car la direction du joystick est figée au départ du mouvement
	# (voir move_input_world). À l'arrêt, elle reste libre : on peut voir Loums sous toutes ses faces.
	var b := camera_pivot.global_basis
	var avant := Vector2(-b.z.x, -b.z.z).normalized()
	var dir := Vector2(-sin(cap), -cos(cap))
	var face := 1.0
	var demi_tour := avant.dot(dir) < 0.0   # Loums vient vers la caméra : elle fait le tour plus franchement
	var force := clampf(v / 4.0, 0.3, 1.4) * camera_suivi * face
	var ecart := angle_difference(camera_pivot.rotation.y, cap)
	var vmax := camera_vitesse_max * (1.8 if demi_tour else 1.0)
	var pas := clampf(ecart * clampf(force * delta, 0.0, 1.0), -vmax * delta, vmax * delta)
	if demi_tour and absf(pas) < 0.6 * vmax * delta:
		pas = signf(ecart) * 0.6 * vmax * delta   # face à la caméra, l'écart est maximal : on garde un vrai élan
	camera_pivot.rotation.y += pas
	# au téléphone, elle reprend aussi sa hauteur normale : on n'a jamais à la recaler à la main
	if TouchControls.actif:
		spring_arm.rotation.x = lerpf(spring_arm.rotation.x, TANGAGE_REPOS, clampf(0.25 * force * delta, 0.0, 1.0))


## Direction voulue, relative à la caméra, à plat.
## Le repère de la caméra est figé au moment où l'on se met en marche (comme dans les jeux à la 3e personne) :
## la caméra peut alors pivoter dans le dos de Loums sans changer la direction qu'on a donnée au joystick.
## Il se recale sur la caméra quand on lâche le joystick, quand on change franchement de direction,
## ou quand on tourne la caméra à la main.
var _repere_fige := false
var _repere_yaw := 0.0
var _repere_entree := Vector2.ZERO

func move_input_world() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := camera_pivot.global_rotation.y
	if input.length() < 0.2 or _camera_libre > 0.0:
		_repere_fige = false
	elif not _repere_fige or absf(angle_difference(input.angle(), _repere_entree.angle())) > deg_to_rad(60.0):
		_repere_fige = true
		_repere_yaw = yaw
		_repere_entree = input
	else:
		# petits ajustements du joystick : on accompagne, sans recaler le repère
		_repere_entree = _repere_entree.slerp(input.normalized() * _repere_entree.length(), 0.05) if _repere_entree.length() > 0.0 else input
	if _repere_fige:
		yaw = _repere_yaw
	var b := Basis(Vector3.UP, yaw)
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	return right * input.x - fwd * input.y


func _walk(delta: float) -> void:
	var dir := move_input_world()
	if Input.is_action_just_pressed("jump"):
		_accroche_relachee = false
	if not is_on_floor():
		velocity.y -= _gravity * delta
		# En l'air, saut maintenu face à un rebord : on s'y accroche.
		var vers_le_mur := move_input_world().length() > 0.3 or Input.is_action_pressed("jump")
		if not _accroche_relachee and vers_le_mur and velocity.y < 2.0 and (_try_mantle() or _try_accrocher() or _try_gouttiere()):
			return
	elif Input.is_action_just_pressed("jump"):
		if _try_gouttiere() or _try_mantle():
			return
		velocity.y = jump_velocity
		# Course murale (Sleeping Dogs) : en courant droit sur un mur, on prend appui dessus et on monte plus haut.
		if Vector2(velocity.x, velocity.z).length() > 2.0 and _mur_proche(2.4):
			velocity.y = jump_velocity * 1.55
			skate.last_event = "Course murale"
	# au téléphone, pas de bouton COURIR : le joystick poussé à fond fait courir
	var court := Input.is_action_pressed("push") or (TouchControls.actif and dir.length() > 0.85)
	var target := dir * (run_speed if court else walk_speed)
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
		var q := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * hgt, feet + Vector3.UP * hgt + fwd * 1.2)
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
	var par := hisse_libre(feet, down.position + Vector3.UP * 0.05)
	if par < 0.0:
		return false  # une corniche, un poteau, un rebord trop étroit : il ne passerait qu'en traversant
	_m_par = par
	_mantling = true
	_m_t = 0.0
	_m_dur = 0.25 + rise * 0.22
	_m_from = feet
	_m_to = down.position + Vector3.UP * 0.05
	velocity = Vector3.ZERO
	climbs += 1
	skate.last_event = "Grimpe"
	return true


## Le dessus d'un bord devant soi, cherché de haut en bas : {} s'il n'y en a pas.
func _bord_devant(depuis: Vector3, fwd: Vector3, bas: float, haut: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var mur := {}
	var hauteurs: Array = []
	var hh := bas
	while hh <= haut - 0.15:
		hauteurs.append(hh)
		hh += 0.35
	for hgt in hauteurs:
		var q := PhysicsRayQueryParameters3D.create(depuis + Vector3.UP * hgt, depuis + Vector3.UP * hgt + fwd * 0.9)
		q.exclude = [get_rid()]
		mur = space.intersect_ray(q)
		if not mur.is_empty() and absf(mur.normal.y) < 0.4:
			break
		mur = {}
	if mur.is_empty():
		return {}
	var n: Vector3 = mur.normal
	n.y = 0.0
	n = n.normalized()
	var dessus: Vector3 = mur.position - n * 0.12
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(dessus.x, depuis.y + haut + 0.3, dessus.z), Vector3(dessus.x, depuis.y + bas - 0.2, dessus.z))
	q2.exclude = [get_rid()]
	var d := space.intersect_ray(q2)
	if d.is_empty() or d.normal.y < 0.7:
		return {}
	return {"haut": d.position.y, "point": Vector3(mur.position.x, d.position.y, mur.position.z), "n": n}


## Une descente d'eau à portée de main (au pied, ou en sautant) : il s'y agrippe.
func gouttiere_proche() -> Node3D:
	var meilleure: Node3D = null
	var d := 0.9
	for g in get_tree().get_nodes_in_group("gouttiere"):
		var m := g as Node3D
		var e := Vector2(m.global_position.x - global_position.x, m.global_position.z - global_position.z).length()
		var haut: float = m.get_meta("haut", 0.0)
		if e < d and global_position.y > m.global_position.y - 0.5 and global_position.y < haut - 1.0:
			d = e
			meilleure = m
	return meilleure


func _try_gouttiere() -> bool:
	var g := gouttiere_proche()
	if g == null:
		return false
	var accroche: Vector3 = g.global_position + (g.get_meta("dehors", Vector3.FORWARD) as Vector3) * 0.32
	if not place_libre(Vector3(accroche.x, global_position.y + 0.05, accroche.z)):
		return false  # un coffret, une grille au pied de la descente d'eau : pas la place de s'y coller
	gouttiere = g
	velocity = Vector3.ZERO
	var dehors: Vector3 = g.get_meta("dehors", Vector3.FORWARD)
	visual.rotation.y = atan2(dehors.x, dehors.z)
	skate.last_event = "Gouttière"
	climbs += 1
	return true


## Sur la gouttière : haut / bas pour monter et descendre, Espace pour lâcher ;
## en haut, il passe par-dessus le muret et se retrouve sur le toit.
func _gouttiere_step(delta: float) -> void:
	var g := gouttiere
	var dehors: Vector3 = g.get_meta("dehors", Vector3.FORWARD)
	var haut: float = g.get_meta("haut", 0.0)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var y := global_position.y - input.y * GOUTTIERE_VITESSE * delta
	var y_max := haut - SOUS_LES_MAINS + 0.6
	var ancrage := g.global_position + dehors * 0.32
	var rapproche := 1.0 - exp(-16.0 * delta)
	var suivant := Vector3(lerpf(global_position.x, ancrage.x, rapproche),
		clampf(y, g.global_position.y, y_max), lerpf(global_position.z, ancrage.z, rapproche))
	if _libre_sauf_prises(suivant) or not _libre_sauf_prises(global_position):
		global_position = suivant   # sinon il reste où il est : quelque chose bloque le long de la descente
	velocity = Vector3.ZERO
	_rebord = Vector3(g.global_position.x, global_position.y + SOUS_LES_MAINS - 0.1, g.global_position.z)
	_rebord_n = dehors
	# Saut lâche la gouttière, sauf s'il tient « haut » : là, le joueur veut monter, pas tomber.
	if Input.is_action_just_pressed("jump") and input.y > -0.3:
		gouttiere = null
		_accroche_relachee = true
		global_position += dehors * 0.2
		skate.last_event = "Lâche"
		return
	var sommet := Vector3(g.global_position.x, haut + 0.05, g.global_position.z) - dehors * 0.9
	var par_toit := hisse_libre(global_position, sommet) if y >= y_max and input.y < -0.3 else -1.0
	if par_toit >= 0.0:
		# en haut : par-dessus le muret, sur le toit (on passe dans le coin, côté intérieur)
		_m_par = par_toit
		gouttiere = null
		_mantling = true
		_m_t = 0.0
		_m_dur = 0.8
		_m_from = global_position
		_m_to = sommet
		skate.last_event = "Grimpe"
		return
	if y <= g.global_position.y + 0.01 and input.y > 0.3:
		gouttiere = null   # en bas : il repose le pied au sol


## Un rebord à attraper devant lui (muret, balcon, plateau, palier, toit) : pour l'aide à l'écran.
func peut_grimper() -> bool:
	if mode != Mode.WALK or not is_on_floor():
		return false
	if gouttiere_proche() != null:
		return true
	var ry := visual.rotation.y
	var fwd := Vector3(-sin(ry), 0.0, -cos(ry))
	for recul in [0.0, 0.6]:
		var b := _bord_devant(global_position - fwd * recul, fwd, 0.35, 4.6)
		if not b.is_empty() and b.haut - global_position.y > 0.35:
			return true
	return false


func _mur_proche(dist: float) -> bool:
	var ry := visual.rotation.y
	var fwd := Vector3(-sin(ry), 0.0, -cos(ry))
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.0 + fwd * dist)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and absf(hit.normal.y) < 0.4


## En l'air, Espace maintenu, face à un bord trop haut pour se hisser : on s'y accroche.
func _try_accrocher() -> bool:
	var ry := visual.rotation.y
	var fwd := Vector3(-sin(ry), 0.0, -cos(ry))
	# aussi un peu en arrière : sous un balcon en surplomb, on attrape son bord avant
	var b := {}
	for recul in [0.0, 0.6, 1.2]:
		b = _bord_devant(global_position - fwd * recul, fwd, mantle_reach * 0.6, ACCROCHE_MAX)
		if not b.is_empty():
			break
	if b.is_empty():
		return false
	var rise: float = b.haut - global_position.y
	if rise <= mantle_reach - 0.1 or rise > ACCROCHE_MAX:
		return false
	if not place_libre(b.point + b.n * 0.32 - Vector3.UP * SOUS_LES_MAINS):
		return false  # suspendu là, il serait dans le mur (sous un balcon, contre un appui de fenêtre)
	_accrocher(b.point, b.n)
	return true


func _accrocher(point: Vector3, n: Vector3) -> void:
	suspendu = true
	_rebord = point
	_rebord_n = n
	velocity = Vector3.ZERO
	visual.rotation.y = atan2(n.x, n.z)
	global_position = point + n * 0.32 - Vector3.UP * SOUS_LES_MAINS
	accroches += 1
	skate.last_event = "Accroché"


## Suspendu : Q/D se décalent le long du bord (s'il continue), Espace hisse, S lâche.
func _suspendu_step(delta: float) -> void:
	velocity = Vector3.ZERO
	if _bond_t >= 0.0:
		_bond_t = minf(_bond_t + delta / 0.38, 1.0)
		var k := _bond_t * _bond_t * (3.0 - 2.0 * _bond_t)
		global_position = _bond_de.lerp(_bond_vers, k) + _rebord_n * sin(_bond_t * PI) * _bond_sortie
		if _bond_t >= 1.0:
			_bond_t = -1.0
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	decale = 0.0
	# monter : Espace, ou haut maintenu (il enchaîne de rebord en rebord tant qu'on pousse)
	# Monter. Haut maintenu : on enchaîne de balcon en balcon jusqu'en haut de l'immeuble (le bond passe
	# avant le hissage, sinon on finit coincé sur le premier balcon, sous la dalle du suivant).
	# Espace : on se hisse sur ce qu'on tient (le balcon, le toit).
	var espace := Input.is_action_just_pressed("jump")
	var tient_haut := input.y < -0.6
	if espace or tient_haut:
		if tient_haut and not espace and _bondir_plus_haut():
			return
		if _se_hisser():
			return
		if _bondir_plus_haut():
			return
	if input.y > 0.6:
		suspendu = false   # on lâche
		_accroche_relachee = true
		global_position += _rebord_n * 0.15
		skate.last_event = "Lâche"
		return
	if absf(input.x) > 0.2:
		var long := Vector3.UP.cross(_rebord_n).normalized()   # vers la droite de Loums, face au mur
		var pas := long * input.x * 1.7 * delta
		var b := _bord_devant(global_position + pas, -_rebord_n, SOUS_LES_MAINS - 0.5, SOUS_LES_MAINS + 0.35)
		var vers_cote: Vector3 = (b.point + _rebord_n * 0.32 - Vector3.UP * SOUS_LES_MAINS) if not b.is_empty() else Vector3.ZERO
		if not b.is_empty() and absf(b.haut - _rebord.y) < 0.2 and place_libre(vers_cote):
			_rebord = b.point
			decale = input.x * 1.7
			decale_dist += absf(pas.length())
			global_position = vers_cote


## Se hisser sur le rebord tenu, s'il y a la place d'y tenir debout. Vrai si c'est parti.
func _se_hisser() -> bool:
	var space := get_world_3d().direct_space_state
	var haut := _rebord - _rebord_n * 0.35
	var q := PhysicsRayQueryParameters3D.create(haut + Vector3.UP * 0.15, haut + Vector3.UP * 1.8)
	q.exclude = [get_rid()]
	var par := hisse_libre(global_position, haut + Vector3.UP * 0.05) if space.intersect_ray(q).is_empty() else -1.0
	if par < 0.0:
		return false
	_m_par = par
	suspendu = false
	_mantling = true
	_m_t = 0.0
	_m_dur = 0.6
	_m_from = global_position
	_m_to = haut + Vector3.UP * 0.05
	climbs += 1
	skate.last_event = "Grimpe"
	return true


## Bondir au rebord du dessus (le balcon de l'étage suivant, Getting Up). Vrai si c'est parti.
func _bondir_plus_haut() -> bool:
	var b := _bord_devant(global_position, -_rebord_n, SOUS_LES_MAINS + 0.5, SOUS_LES_MAINS + BOND_MAX)
	if b.is_empty() or b.haut - _rebord.y <= 0.4:
		return false
	# Le balcon qu'il tient (dalle, garde-corps) est juste devant lui : tout droit vers le haut, il le
	# heurte. Il se décolle donc un peu du mur le temps du bond (comme on se repousse des pieds), et
	# s'il ne peut pas se suspendre pile sous le balcon du dessus, un peu plus en avant.
	for ecart: float in [0.32, 0.45, 0.6]:
		var vers_bond: Vector3 = b.point + _rebord_n * ecart - Vector3.UP * SOUS_LES_MAINS
		if not place_libre(vers_bond):
			continue
		for sortie: float in [0.0, 0.3, 0.55]:
			var d := _rebord_n * sortie
			if trajet_libre(global_position, global_position + d) and trajet_libre(global_position + d, vers_bond + d) \
					and trajet_libre(vers_bond + d, vers_bond):
				_rebord = b.point
				_bond_de = global_position
				_bond_vers = vers_bond
				_bond_sortie = maxf(0.15, sortie * 1.15)
				_bond_t = 0.0
				climbs += 1
				skate.last_event = "Bond"
				return true
	return false


func _mantle_step(delta: float) -> void:
	_m_t = minf(_m_t + delta / _m_dur, 1.0)
	# On monte d'abord, on avance ensuite.
	# on monte, on passe par-dessus (au besoin plus haut que l'arrivée), on se pose
	var up := smoothstep(0.0, 0.6, _m_t)
	var fwd := smoothstep(0.55, 0.95 if _m_par > 0.0 else 1.0, _m_t)
	var pose := smoothstep(0.9, 1.0, _m_t) if _m_par > 0.0 else 0.0
	global_position = Vector3(
		lerpf(_m_from.x, _m_to.x, fwd), lerpf(_m_from.y, _m_to.y + _m_par, up) - _m_par * pose, lerpf(_m_from.z, _m_to.z, fwd))
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
	suspendu = false
	gouttiere = null
	_bond_t = -1.0
	skate.speed = 0.0
	_set_mode(Mode.WALK)


const POP_DUREE := 0.2

## Rotation de la planche : pop, genoux remontés, flips (purement visuel).
func _animate_board() -> void:
	var demi_tour := PI if skate.tail_devant else 0.0
	var roulis := 0.0
	if mode == Mode.SKATE and skate.trick in ["Kickflip", "Shove-it"]:
		# Le pied relâche la planche, puis la rattrape à plat avant la réception.
		var rotation_finie := smoothstep(0.04, 0.86, skate.trick_t)
		if skate.trick == "Kickflip":
			roulis = TAU * rotation_finie
		else:
			demi_tour += PI * rotation_finie
	board.plateau_mobile.basis = Basis(Vector3.BACK, roulis) * Basis(Vector3.UP, demi_tour)
	if planche_libre or mode == Mode.WALK:
		return  # à pied, c'est Personnage qui la porte (dans le dos) ou la manie
	board.rotation = Vector3.ZERO
	board.position = Vector3(0, 0.085, 0)
	if mode == Mode.SKATE and not skate.in_air:
		board.rotation.z = -skate.lean * 0.12   # la planche bascule dans le virage
		if skate.manual:
			# sur les roues arrière : le nose se lève (pivot sur l'essieu arrière)
			var m := 0.2 + 0.08 * clampf(skate.manual_bal, -1.0, 1.0)
			var essieu := Vector3(0, 0, 0.27)
			board.rotation.x = -m
			board.position += essieu - Basis(Vector3.RIGHT, -m) * essieu
	if mode != Mode.SKATE:
		return
	if skate.in_air and not skate.grinding:
		# Genoux remontés : la planche monte vers lui, puis redescend avant la réception.
		var monte := smoothstep(0.0, 0.12, skate.air_t) if skate.saute else smoothstep(0.25, 0.45, skate.air_t)
		var descend := clampf((-velocity.y - 1.0) / 3.0, 0.0, 1.0)
		board.position.y += 0.22 * monte * (1.0 - descend)
		if skate.grab > 0.0:
			# grab : la planche monte à la main, un peu penchée
			board.position.y += 0.2 * skate.grab
			board.rotation.z += 0.35 * skate.grab
	if skate.pop_t >= 0.0 and skate.pop_t < POP_DUREE:
		# Pop : le tail claque au sol, le nose se lève, puis la planche se remet à plat.
		var a := 0.53 * smoothstep(0.0, 0.045, skate.pop_t) * (1.0 - smoothstep(0.045, POP_DUREE, skate.pop_t))
		var tail := Vector3(0, 0, 0.38)
		var r := Basis(Vector3.RIGHT, a)
		board.rotation.x = a
		board.position += tail - r * tail


func _update_hud() -> void:
	var kmh := absf(skate.speed) * 3.6 if mode == Mode.SKATE else Vector2(velocity.x, velocity.z).length() * 3.6
	var state := "CHUTE" if chute_t >= 0.0 else "À PIED"
	if mode == Mode.SKATE:
		state = "GRIND" if skate.grinding else ("AIR" if skate.in_air else "SKATE")
	var ips := Engine.get_frames_per_second()
	# Louma 21.11 : plus de texte de mise au point à l'écran (F3 pour le revoir sur PC).
	if Input.is_key_pressed(KEY_F3) and not _f3_tenu:
		debug_label.visible = not debug_label.visible
	_f3_tenu = Input.is_key_pressed(KEY_F3)
	if debug_label.visible:
		debug_label.text = "%s   %d km/h   %d img/s\n%s" % [state, roundi(kmh), ips, skate.last_event]


# ---------------------------------------------------------------------------------------------
# Sensations (Louma 21.11) : vitesse, impact, grind. Purement visuel, rien ne change la physique.

const FOV_BASE := 62.0
const FOV_VITE := 76.0
var _cam: Camera3D
var _hud_figures: CanvasLayer
var _traits: ColorRect
var _poussiere: CPUParticles3D
var _etincelles: CPUParticles3D
var _secousse := 0.0
var _traits_t := 0.0


func _sensations_pretes() -> void:
	_cam = spring_arm.get_child(0) as Camera3D if spring_arm.get_child_count() > 0 else null
	_hud_figures = preload("res://scripts/figures_hud.gd").new()
	_hud_figures.set("skate", skate)
	add_child(_hud_figures)
	var couche := CanvasLayer.new()
	couche.layer = 1
	add_child(couche)
	_traits = ColorRect.new()
	_traits.set_anchors_preset(Control.PRESET_FULL_RECT)
	_traits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/vitesse.gdshader")
	_traits.material = mat
	_traits.visible = false
	couche.add_child(_traits)
	_poussiere = _particules(Color(0.85, 0.78, 0.66, 0.8), 26, 0.45, Vector3(0, 1.6, 0), 2.2, 0.09)
	_etincelles = _particules(Color(1.0, 0.75, 0.25), 40, 0.35, Vector3(0, 2.5, 0), 4.0, 0.03)
	_etincelles.one_shot = false
	_etincelles.emitting = false
	skate.atterri.connect(_impact)


func _particules(c: Color, n: int, vie: float, haut: Vector3, v: float, taille: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = vie
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.direction = haut.normalized()
	p.spread = 70.0
	p.initial_velocity_min = v * 0.5
	p.initial_velocity_max = v
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var m := SphereMesh.new()
	m.radius = taille
	m.height = taille * 2.0
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	var fondu := Gradient.new()
	fondu.set_color(0, Color(1, 1, 1, 1))
	fondu.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fondu
	p.top_level = true
	add_child(p)
	return p


## Réception : secousse proportionnée au saut, poussière, et un gel d'une fraction de seconde sur les gros.
func _impact(t_air: float, qualite: String) -> void:
	if t_air < 0.25:
		return
	_secousse = clampf(t_air * 0.5, 0.15, 0.7) * (1.4 if qualite == "chute" else 1.0)
	if _poussiere:
		_poussiere.global_position = global_position + Vector3.UP * 0.05
		_poussiere.amount = int(clampf(t_air * 30.0, 10.0, 40.0))
		_poussiere.restart()
	if t_air > 0.65 and qualite != "chute":
		Engine.time_scale = 0.12
		get_tree().create_timer(0.07, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _sensations(delta: float) -> void:
	if _cam == null:
		return
	if spring_arm.has_meta("vehicule"):
		_traits.visible = false
		return  # en scooter, conduite.gd gère l'angle de vue, les traits de vitesse et les secousses
	var vite := clampf((absf(skate.speed) - 5.0) / 9.0, 0.0, 1.0) if mode == Mode.SKATE and chute_t < 0.0 else 0.0
	# plus on va vite, plus l'image s'ouvre (et la caméra se rapproche du sol)
	_cam.fov = lerpf(_cam.fov, FOV_BASE + (FOV_VITE - FOV_BASE) * vite, minf(1.0, 3.0 * delta))
	_traits_t += delta
	_traits.visible = vite > 0.05
	if _traits.visible:
		var mat := _traits.material as ShaderMaterial
		mat.set_shader_parameter("force", vite)
		mat.set_shader_parameter("temps", _traits_t)
	# secousse : un tremblement court qui s'éteint vite
	_secousse = move_toward(_secousse, 0.0, delta * 2.5)
	var s2 := _secousse * _secousse
	_cam.h_offset = (randf() - 0.5) * 0.35 * s2
	_cam.v_offset = (randf() - 0.5) * 0.35 * s2
	# grind : des étincelles sous la planche
	var grind := mode == Mode.SKATE and skate.grinding
	if _etincelles.emitting != grind:
		_etincelles.emitting = grind
	if grind:
		_etincelles.global_position = global_position + Vector3.UP * 0.03
