extends Node
## TRACE — conduire le scooter (et la voiture, sortie de la démo mais gardée).
## Script indépendant : il ne modifie pas les fichiers du joueur. Pendant la conduite, Loums suit le véhicule,
## assis dessus (la pose assise est dans personnage.gd) ; sa caméra suit donc le véhicule, de dos.
##
##   V                monter / descendre ; près d'un scooter couché : le relever et repartir
##   Z / S            gaz / frein, puis marche arrière
##   Q / D            tourner
##   Maj              scooter : dérapage (aussi : freiner fort en tournant à pleine vitesse)
##   Espace           scooter : roue arrière (maintenir ; Z la fait monter, S la fait redescendre)
##                    voiture : frein à main
##
## Refonte du 21.11 (demande de Louma) : plus de vitesse (90 km/h), glisse latérale réelle (dérapage),
## pente et gravité, sauts et réceptions, inclinaison calculée sur le virage, roues qui tournent,
## guidon qui braque, bavette qui racle le bitume en roue arrière (étincelles), et de vraies chutes :
## le scooter part en corps rigide, glisse sur le flanc, se couche ; Loums est éjecté.

const REGLAGES := {
	"scooter": {"vmax": 25.0, "accel": 9.5, "frein": 15.0, "rayon": 2.3, "rayon_v": 0.055, "adherence": 9.0,
		"taille": Vector3(0.6, 1.0, 1.6), "bras": 4.0, "bras_vite": 5.4},
	"voiture": {"vmax": 30.0, "accel": 7.0, "frein": 13.0, "rayon": 5.0, "rayon_v": 0.06, "adherence": 7.0,
		"taille": Vector3(1.7, 1.2, 4.0), "bras": 6.5, "bras_vite": 7.5},
}
const ROUE_AR := Vector3(0, 0.22, -0.55)   # axe de la roue arrière du scooter (repère du modèle)
const ROUE_AV := Vector3(0, 0.22, 0.62)    # axe de la roue avant
const RAYON_ROUE := 0.22
const COLONNE := Vector3(0, 0.93, 0.45)    # haut de la fourche : l'axe de direction passe par ici et l'axe avant
const CHARNIERE := Vector3(0, 0.36, -0.80) # attache de la bavette, derrière la roue arrière
const BAVETTE := 0.28                      # longueur de la bavette
const CHAUSSEE := 0.07                     # la chaussée est dessinée 7 cm au-dessus du sol réel
const KMH_LIGNES := 50.0                   # traits de vitesse au-delà
const CABRE_MAX := 1.25                    # au-delà, le scooter passe sur le dos

var joueur: CharacterBody3D
var quartier: Node
var vehicules: Array = []      # [Vehicule]
var actuel: Vehicule
var roue_arriere := 0.0        # durée de la roue arrière en cours (s)
var record := 0.0
var vient_de_chuter := false   # lu par le son au moment où Loums quitte le véhicule
var racle_sol := 0.0           # 0..1 : un scooter couché qui glisse sur le bitume (lu par le son)
var _texte: Label
var _lignes: Control
var _etincelles: Gerbe
var _gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _fov0 := 70.0
var _secousse := 0.0
var _t := 0.0
var _message_t := 0.0


class Vehicule extends CharacterBody3D:
	var type := "voiture"
	var vmax := 25.0
	var modele: Node3D
	var base_modele := Transform3D()
	var vitesse := 0.0          # le long du cap (négative = marche arrière)
	var cap := 0.0              # rotation Y ; l'avant du véhicule est +Z local
	var lateral := 0.0          # glisse de côté (m/s), + = vers la gauche du conducteur
	var lacet := 0.0            # vitesse de rotation du cap (rad/s)
	var cabre := 0.0            # angle de roue arrière (rad)
	var cabre_v := 0.0
	var penche := 0.0           # roulis (rad), + = penché à gauche
	var tangage := 0.0          # suit la pente au sol, se pilote en l'air
	var plongee := 0.0          # suspension : le nez plonge au freinage, se relève à l'accélération
	var bond := 0.0             # écrasement de la suspension (m) à la réception
	var bond_v := 0.0
	var braquage := 0.0         # angle du guidon
	var roue := 0.0             # rotation des roues (rad)
	var derive := 0.0           # 0..1 : dérapage en cours
	var racle := 0.0            # 0..1 : la bavette frotte le bitume
	var en_l_air := 0.0         # durée du vol en cours
	var chute_y := 0.0          # vitesse verticale au moment de toucher le sol
	var arret := 0.0            # temps passé à l'arrêt en freinant (la marche arrière attend 0,4 s)
	var gaz_tenu := 0.0         # gaz lissé (le moteur 2-temps monte dans les tours)
	var au_sol: RigidBody3D     # le scooter couché après une chute (null sinon)
	var direction: Node3D       # pivot du guidon (scooter)
	var axe_av: Node3D
	var axe_ar: Node3D
	var bavette: Node3D

	func avant() -> Vector3:
		return Vector3(sin(cap), 0.0, cos(cap))

	func gauche() -> Vector3:
		return Vector3(cos(cap), 0.0, -sin(cap))


func _ready() -> void:
	_action("monter", KEY_V, JOY_BUTTON_DPAD_RIGHT)
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	joueur = scene.get_node_or_null("Player") as CharacterBody3D
	quartier = scene.get_node_or_null("Quartier")
	_interface()
	_etincelles = _faire_etincelles()
	add_child(_etincelles)
	_preparer.call_deferred()


func _action(nom: String, touche: Key, bouton: JoyButton) -> void:
	if InputMap.has_action(nom):
		return
	InputMap.add_action(nom, 0.2)
	var k := InputEventKey.new()
	k.physical_keycode = touche
	InputMap.action_add_event(nom, k)
	var b := InputEventJoypadButton.new()
	b.button_index = bouton
	InputMap.action_add_event(nom, b)


## Chaque véhicule garé (corps fixe) devient un véhicule mobile, au même endroit, avec le même modèle.
func _preparer() -> void:
	for n in get_tree().get_nodes_in_group("vehicule"):
		var fixe := n as Node3D
		var type: String = fixe.get_meta("type", "voiture")
		var r: Dictionary = REGLAGES.get(type, REGLAGES["voiture"])
		var v := Vehicule.new()
		v.type = type
		v.vmax = r.vmax
		v.name = "Vehicule_" + type
		v.floor_snap_length = 0.6
		v.floor_max_angle = deg_to_rad(40)
		v.safe_margin = 0.02
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		var t: Vector3 = r.taille
		sh.size = Vector3(t.x, t.y - 0.25, t.z)  # moins haute que le véhicule : elle ne frotte pas le sol
		cs.shape = sh
		cs.position = Vector3(0, (t.y - 0.25) * 0.5, 0)  # le bas de la collision est à l'origine
		v.add_child(cs)
		var sol := fixe.global_position
		if quartier:
			sol.y = quartier.h(sol.x, sol.z)
		v.cap = fixe.global_rotation.y
		fixe.get_parent().add_child(v)
		v.global_position = sol + Vector3.UP * 0.02
		v.rotation.y = v.cap
		var m: Node3D = fixe.get_meta("modele") if fixe.has_meta("modele") else null
		if m:
			m.reparent(v, true)
			# Roues posées sur la chaussée : la collision touche le sol réel, le modèle est 7 cm plus haut.
			m.position = Vector3(0, CHAUSSEE - 0.02, 0)
			m.rotation = Vector3.ZERO
			v.modele = m
			v.base_modele = m.transform
			if type == "scooter":
				_articuler(v)
		v.add_to_group("vehicule")
		v.add_to_group("voiture" if type == "voiture" else "mobilier")
		v.set_meta("type", type)
		vehicules.append(v)
		fixe.queue_free()


## Le modèle du scooter est d'un seul tenant (sommets déjà placés) : on glisse des pivots sous les pièces
## qui bougent. Guidon + fourche + phare + roue avant tournent autour de l'axe de direction ; chaque roue
## tourne sur son axe ; une bavette en caoutchouc est ajoutée derrière la roue arrière.
func _articuler(v: Vehicule) -> void:
	var m := v.modele
	var nom := func(n: String) -> Node3D: return m.find_child(n, true, false) as Node3D
	var parent: Node3D = (nom.call("Coque") as Node3D).get_parent() if nom.call("Coque") else m
	# Axe de direction : de l'axe avant vers le haut de la fourche (incliné vers l'arrière).
	var haut := (COLONNE - ROUE_AV).normalized()
	var x := Vector3.RIGHT
	var z := x.cross(haut).normalized()
	v.direction = Node3D.new()
	v.direction.name = "Direction"
	parent.add_child(v.direction)
	v.direction.transform = Transform3D(Basis(x, haut, z), ROUE_AV)
	v.direction.set_meta("base", v.direction.basis)
	for p in ["Guidon", "Fourche", "Phare"]:
		var n: Node3D = nom.call(p)
		if n:
			n.reparent(v.direction, true)
	v.axe_av = Node3D.new()
	v.axe_av.name = "AxeAv"
	v.direction.add_child(v.axe_av)
	for p in ["RoueAv", "RoueAv_jante"]:
		var n: Node3D = nom.call(p)
		if n:
			n.reparent(v.axe_av, true)
	v.axe_ar = Node3D.new()
	v.axe_ar.name = "AxeAr"
	parent.add_child(v.axe_ar)
	v.axe_ar.position = ROUE_AR
	for p in ["RoueAr", "RoueAr_jante"]:
		var n: Node3D = nom.call(p)
		if n:
			n.reparent(v.axe_ar, true)
	# La bavette : caoutchouc noir, liseré alu en bas (c'est lui qui crache les étincelles).
	v.bavette = Node3D.new()
	v.bavette.name = "Bavette"
	parent.add_child(v.bavette)
	v.bavette.position = CHARNIERE
	var plaque := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, BAVETTE, 0.012)
	plaque.mesh = bm
	plaque.position = Vector3(0, -BAVETTE * 0.5, 0)
	var caoutchouc := StandardMaterial3D.new()
	caoutchouc.albedo_color = Color(0.07, 0.07, 0.08)
	caoutchouc.roughness = 0.9
	plaque.material_override = caoutchouc
	v.bavette.add_child(plaque)
	var lisere := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.2, 0.025, 0.016)
	lisere.mesh = lm
	lisere.position = Vector3(0, -BAVETTE + 0.012, 0)
	var alu := StandardMaterial3D.new()
	alu.albedo_color = Color(0.75, 0.75, 0.78)
	alu.metallic = 0.8
	lisere.material_override = alu
	v.bavette.add_child(lisere)


# ==================================================================================================
#  Boucle
# ==================================================================================================
func _physics_process(delta: float) -> void:
	_t += delta
	_message_t = maxf(0.0, _message_t - delta)
	_scooters_couches(delta)
	if joueur == null:
		return
	if actuel == null:
		_effets(null, delta)
		var proche := _vehicule_proche()
		if _message_t <= 0.0:
			if proche == null:
				_texte.text = ""
			elif proche.au_sol:
				_texte.text = "V : relever le scooter"
			else:
				_texte.text = "V : monter sur le scooter" if proche.type == "scooter" else "V : monter dans la voiture"
		if proche and Input.is_action_just_pressed("monter") and joueur.is_on_floor() and joueur.get("chute_t") < 0.0:
			if proche.au_sol:
				_relever(proche)
			else:
				_monter(proche)
		return
	_conduire(actuel, delta)
	if actuel and Input.is_action_just_pressed("monter") and absf(actuel.vitesse) < 3.0 and actuel.cabre < 0.1 and actuel.en_l_air <= 0.0:
		_descendre()


func _vehicule_proche() -> Vehicule:
	var meilleur: Vehicule = null
	var d := 2.8
	for v in vehicules:
		var ici: Vector3 = (v as Vehicule).au_sol.global_position if (v as Vehicule).au_sol else (v as Node3D).global_position
		var e: float = ici.distance_to(joueur.global_position)
		if e < d:
			d = e
			meilleur = v
	return meilleur


func _monter(v: Vehicule) -> void:
	actuel = v
	vient_de_chuter = false
	# Les véhicules sont solides ; seul celui qu'on conduit laisse passer Loums (il est assis dedans).
	v.add_collision_exception_with(joueur)
	joueur.add_collision_exception_with(v)
	joueur.set_physics_process(false)
	joueur.velocity = Vector3.ZERO
	_hud_joueur(false)
	var cam := _camera()
	if cam:
		_fov0 = cam.fov
	var bras := _bras()
	if bras:
		bras.spring_length = float((REGLAGES[v.type] as Dictionary).bras)
	_suivre(v)


func _descendre() -> void:
	var v := actuel
	actuel = null
	v.vitesse = 0.0
	v.lateral = 0.0
	v.velocity = Vector3.ZERO
	# Loums réapparaît à gauche du véhicule.
	var taille: Vector3 = (REGLAGES[v.type] as Dictionary).taille
	var p := v.global_position + v.gauche() * (taille.x * 0.5 + 0.7)
	if quartier:
		p.y = quartier.h(p.x, p.z) + 0.1
	_rendre_joueur(v, p, Vector3.ZERO)
	_texte.text = ""


func _rendre_joueur(v: Vehicule, p: Vector3, vel: Vector3) -> void:
	joueur.global_position = p
	joueur.velocity = vel
	v.remove_collision_exception_with(joueur)
	joueur.remove_collision_exception_with(v)
	(joueur.get("visual") as Node3D).visible = true
	_hud_joueur(true)
	joueur.set_physics_process(true)
	var bras := _bras()
	if bras:
		bras.spring_length = 4.5
	var cam := _camera()
	if cam:
		cam.fov = _fov0
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	_lignes.set("force", 0.0)


## Le texte d'aide du joueur (« À PIED… ») est masqué pendant la conduite.
func _hud_joueur(visible: bool) -> void:
	var hud := joueur.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = visible


func _bras() -> SpringArm3D:
	return joueur.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D


func _camera() -> Camera3D:
	return joueur.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D


## Loums « suit » le véhicule : sa caméra et son suivi de dos s'appliquent au véhicule.
func _suivre(v: Vehicule) -> void:
	joueur.global_position = v.global_position
	joueur.velocity = v.velocity
	(joueur.get("visual") as Node3D).rotation.y = v.cap + PI  # le joueur regarde vers -Z


# ==================================================================================================
#  La conduite
# ==================================================================================================
func _conduire(v: Vehicule, delta: float) -> void:
	var r: Dictionary = REGLAGES[v.type]
	var scooter := v.type == "scooter"
	var entree := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var gaz := -entree.y
	var volant := -entree.x
	var espace := Input.is_action_pressed("jump")
	var au_sol := v.is_on_floor()
	v.gaz_tenu = move_toward(v.gaz_tenu, maxf(gaz, 0.0), 3.0 * delta)

	# --- Vitesse le long du cap : moteur, frein, frein moteur, air, pente.
	var f := v.vitesse
	if au_sol:
		if gaz > 0.1:
			if f >= 0.0:
				# Un 2-temps : ça arrache en bas, ça s'essouffle près de la vitesse max.
				var reste := clampf(1.0 - pow(f / v.vmax, 1.7), 0.0, 1.0)
				f += r.accel * v.gaz_tenu * reste * delta
			else:
				f = minf(f + r.frein * delta, 0.0)
			v.arret = 0.0
		elif gaz < -0.1:
			if f > 0.0:
				f = maxf(f - r.frein * -gaz * delta, 0.0)
				v.arret = 0.0
			elif v.arret < 0.4:
				v.arret += delta  # on marque l'arrêt avant de reculer
			else:
				f = maxf(f - r.accel * 0.4 * delta, -4.0)
		else:
			f = move_toward(f, 0.0, 1.6 * delta)  # frein moteur
			v.arret = 0.0
		# La pente : on prend de la vitesse en descente, on en perd en montée.
		var n := v.get_floor_normal()
		var avant3 := (v.avant() - n * v.avant().dot(n)).normalized()
		f -= _gravite * avant3.y * delta
	f -= 0.0008 * f * absf(f) * delta  # résistance de l'air (plafonne naturellement)
	f = clampf(f, -6.0, v.vmax * 1.25)  # une descente raide peut dépasser la vitesse moteur

	# --- Dérapage : Maj, ou freiner fort en braquant à bonne allure. Le cap tourne plus vite que la
	# trajectoire : l'arrière glisse, on contre-braque pour tenir l'angle.
	var veut_deriver := false
	if v.type == "voiture":
		veut_deriver = espace and absf(f) > 4.0
	elif au_sol and f > 7.0 and absf(volant) > 0.25:
		veut_deriver = Input.is_action_pressed("push") or gaz < -0.5
	v.derive = move_toward(v.derive, 1.0 if veut_deriver else 0.0, (5.0 if veut_deriver else 2.5) * delta)

	# --- Virage : rayon court à basse vitesse, large à pleine vitesse ; à l'arrêt, rien.
	var rayon: float = r.rayon + r.rayon_v * f * f
	var lacet_voulu := volant * f / rayon
	lacet_voulu *= 1.0 + 0.9 * v.derive
	if v.cabre > 0.15:
		lacet_voulu *= 0.35  # en roue arrière, on dirige au déhanché, pas au guidon
	if not au_sol:
		lacet_voulu *= 0.15
	v.lacet = lerpf(v.lacet, lacet_voulu, clampf(9.0 * delta, 0.0, 1.0))
	v.cap += v.lacet * delta
	v.braquage = lerpf(v.braquage, volant * clampf(0.55 - absf(f) * 0.015, 0.2, 0.55) * (1.0 - v.derive * 1.6), 10.0 * delta)

	# --- Adhérence : la vitesse de côté s'éteint plus ou moins vite. Quand le cap tourne, l'ancienne
	# vitesse devient de la glisse latérale : c'est elle qui fait déraper.
	var plat := Vector3(v.velocity.x, 0.0, v.velocity.z)
	if au_sol:
		var lat := plat.dot(v.gauche())
		var adherence: float = r.adherence
		var g_lat := absf(f * v.lacet)
		if g_lat > 7.5:
			adherence *= 7.5 / g_lat  # trop vite dans le virage : ça décroche tout seul
		adherence = lerpf(adherence, 1.3, v.derive)
		lat *= exp(-adherence * delta)
		if absf(lat) > 2.0:
			f = move_toward(f, 0.0, absf(lat) * 0.5 * delta)  # glisser freine
		v.lateral = lat
	if v.racle > 0.0:
		f = move_toward(f, 0.0, 1.2 * v.racle * delta)
	v.vitesse = f
	var voulu := v.avant() * f + v.gauche() * v.lateral

	# --- Vertical : collé à la pente au sol (pour décoller en haut d'une bosse), gravité en l'air.
	if au_sol:
		var n := v.get_floor_normal()
		var vy := -(n.x * voulu.x + n.z * voulu.z) / maxf(n.y, 0.3)
		v.velocity = Vector3(voulu.x, minf(vy, 9.0), voulu.z)
	else:
		v.velocity.x = voulu.x
		v.velocity.z = voulu.z
		v.velocity.y -= _gravite * delta
	v.floor_snap_length = 0.12 if absf(f) > 9.0 else 0.6
	var avant_choc := Vector3(v.velocity.x, 0.0, v.velocity.z)
	var vy_avant := v.velocity.y
	v.move_and_slide()
	v.rotation.y = v.cap

	# --- Chocs : un mur pris de face fait perdre la vitesse ; trop fort, c'est la chute.
	if v.get_slide_collision_count() > 0:
		var apres := Vector3(v.velocity.x, 0.0, v.velocity.z)
		var perte := avant_choc.length() - apres.length()
		var de_face := 0.0
		for i in v.get_slide_collision_count():
			var c := v.get_slide_collision(i)
			if absf(c.get_normal().y) < 0.6:
				de_face = maxf(de_face, -c.get_normal().dot(avant_choc.normalized()))
		if de_face > 0.3 and perte > 1.0:
			_secousse = maxf(_secousse, clampf(perte / 8.0, 0.2, 1.0))
			if scooter and perte > 8.0 and de_face > 0.55:
				_chute(v, "mur", avant_choc)
				return
			v.vitesse = apres.dot(v.avant())
			v.lateral = apres.dot(v.gauche())

	# --- Vol et réception.
	var maintenant_au_sol := v.is_on_floor()
	if not maintenant_au_sol:
		v.en_l_air += delta
		v.chute_y = vy_avant
		# En l'air : Z penche l'avant, S le relève (comme sur une moto de cross).
		v.tangage = lerpf(v.tangage, clampf(-gaz * 0.45 + v.velocity.y * 0.03, -0.6, 0.5), 2.5 * delta)
	elif v.en_l_air > 0.0:
		var vol := v.en_l_air
		v.en_l_air = 0.0
		var impact := -v.chute_y
		if vol > 0.12:
			v.bond_v -= clampf(impact * 0.12, 0.0, 1.2)
			_secousse = maxf(_secousse, clampf(impact / 10.0, 0.1, 0.8))
			_message_court("RÉCEPTION %.1f s" % vol if vol > 0.6 else "", 1.2)
		var pente := _pente_sol(v)
		var ecart := absf(v.tangage - pente) + (v.cabre if v.cabre > 0.95 else 0.0)
		if scooter and (impact > 12.0 or (impact > 5.0 and ecart > 0.7)):
			_chute(v, "reception", Vector3(v.velocity.x, -impact, v.velocity.z))
			return
	if maintenant_au_sol:
		v.tangage = lerpf(v.tangage, _pente_sol(v), 10.0 * delta)

	# --- Suspension : plongée au freinage, cabrage léger à l'accélération, rebond à la réception.
	var plongee_voulue := 0.0
	if maintenant_au_sol:
		var freine := gaz * 0.07 if gaz < -0.1 and v.vitesse > 1.0 else 0.0
		plongee_voulue = clampf(freine + 0.03 * v.gaz_tenu * clampf(1.0 - v.vitesse / v.vmax, 0.0, 1.0), -0.08, 0.04)
	v.plongee = lerpf(v.plongee, plongee_voulue, 6.0 * delta)
	v.bond_v += (-v.bond * 180.0 - v.bond_v * 14.0) * delta
	v.bond = clampf(v.bond + v.bond_v * delta, -0.12, 0.06)

	# --- Le scooter : roue arrière, inclinaison, bavette.
	if scooter:
		_roue_arriere(v, gaz, espace, maintenant_au_sol, delta)
		if v.au_sol:
			return  # il vient de passer sur le dos
		# Inclinaison : celle qui équilibre la force du virage (on penche dans le virage), un peu plus en
		# dérapage ; presque rien à l'arrêt.
		var lean := atan2(v.vitesse * v.lacet, _gravite) * 0.85
		lean = clampf(lean, -0.75, 0.75) if maintenant_au_sol else v.penche
		v.penche = lerpf(v.penche, lean, 7.0 * delta)
	v.roue += v.vitesse / RAYON_ROUE * delta
	_poser_modele(v)
	_suivre(v)
	_effets(v, delta)
	_hud(v)


## L'angle de la pente sous le véhicule, dans le sens de la marche (+ = ça monte).
func _pente_sol(v: Vehicule) -> float:
	if not v.is_on_floor():
		return v.tangage
	var n := v.get_floor_normal()
	return -atan2(n.dot(v.avant()), n.y)


## Roue arrière. Espace « tire sur le guidon » : le scooter se cabre jusqu'à un angle que règle le gaz
## (Z plus haut, S redescend). L'équilibre n'est jamais parfait : les bosses et la durée le font dériver,
## il faut doser. Au-delà de 72°, c'est la chute en arrière.
func _roue_arriere(v: Vehicule, gaz: float, espace: bool, au_sol: bool, delta: float) -> void:
	var vise := 0.0
	if espace and v.vitesse > 2.5:
		vise = 0.42 + 0.5 * maxf(gaz, 0.0) - 0.3 * maxf(-gaz, 0.0) + 0.06 * roue_arriere
		vise += sin(_t * 2.3) * 0.05 + sin(_t * 5.7 + 1.0) * 0.03 * clampf(v.vitesse / 10.0, 0.0, 1.0)
	elif not au_sol:
		vise = v.cabre  # en l'air, la roue arrière se garde
	var raideur := 14.0 if vise > v.cabre else 9.0
	v.cabre_v += ((vise - v.cabre) * raideur - v.cabre_v * 4.5) * delta
	# Passé 55°, le centre de gravité passe derrière la roue : ça tire tout seul vers l'arrière.
	if v.cabre > 0.95:
		v.cabre_v += (v.cabre - 0.95) * 9.0 * delta
	v.cabre = clampf(v.cabre + v.cabre_v * delta, 0.0, 1.5)
	if v.cabre == 0.0:
		if v.cabre_v < -1.2 and au_sol:
			v.bond_v -= 0.4  # la roue avant retombe : la fourche encaisse
			_secousse = maxf(_secousse, 0.25)
		v.cabre_v = maxf(v.cabre_v, 0.0)
	if v.cabre > 0.08:
		roue_arriere += delta
	elif roue_arriere > 0.0:
		record = maxf(record, roue_arriere)
		if roue_arriere > 1.5:
			_message_court("ROUE ARRIÈRE  %.1f s" % roue_arriere, 1.5)
		roue_arriere = 0.0
	if v.cabre >= CABRE_MAX and au_sol:
		_chute(v, "dos", Vector3(v.velocity.x, 0.0, v.velocity.z))


func _poser_modele(v: Vehicule) -> void:
	if v.modele == null:
		return
	var t := v.base_modele
	# Tangage (pente, vol) et suspension autour du milieu ; roue arrière autour de l'axe arrière.
	var bascule := v.tangage + v.plongee
	t = Transform3D(Basis(Vector3.RIGHT, -bascule), Vector3.ZERO) * t
	if v.cabre > 0.0:
		var pivot := t.origin + ROUE_AR
		t = Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.RIGHT, -v.cabre), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot) * t
	# Roulis autour de la ligne de contact au sol.
	t = Transform3D(Basis(Vector3.FORWARD, v.penche), Vector3.ZERO) * t
	t.origin.y += v.bond
	v.modele.transform = t
	if v.direction:
		v.direction.basis = (v.direction.get_meta("base") as Basis) * Basis(Vector3.UP, v.braquage)
	if v.axe_av:
		v.axe_av.rotation.x = v.roue
	if v.axe_ar:
		v.axe_ar.rotation.x = v.roue
	_bavette(v)


## La bavette pend, chassée vers l'arrière par le vent ; en roue arrière elle touche le bitume, se plie
## et racle (étincelles). Calcul dans le repère du véhicule, sol à y = 0.
func _bavette(v: Vehicule) -> void:
	v.racle = 0.0
	if v.bavette == null:
		return
	var c := v.cabre
	var d := CHARNIERE - ROUE_AR
	var y_charniere := ROUE_AR.y + d.y * cos(c) + d.z * sin(c) - v.plongee * 0.6 + v.bond
	var repos := clampf(absf(v.vitesse) * 0.025, 0.0, 0.6)  # le vent la soulève
	var beta := repos
	var contact := y_charniere - BAVETTE * cos(beta) < 0.012
	if contact:
		beta = acos(clampf((y_charniere - 0.012) / BAVETTE, -1.0, 1.0))
		if absf(v.vitesse) > 1.0 and v.is_on_floor():
			v.racle = clampf(absf(v.vitesse) / 12.0, 0.25, 1.0)
	# Dans le repère du modèle, cabré de c : il faut tourner de beta + c (et du tangage) vers l'arrière.
	v.bavette.rotation = Vector3(beta + c + v.tangage + v.plongee, 0.0, 0.0)


# ==================================================================================================
#  La chute : le scooter devient un corps rigide (vraie pesanteur), Loums est éjecté.
# ==================================================================================================
func _chute(v: Vehicule, pourquoi: String, vitesse: Vector3) -> void:
	record = maxf(record, roue_arriere)
	roue_arriere = 0.0
	vient_de_chuter = true
	var gt := v.modele.global_transform if v.modele else v.global_transform
	# Le corps rigide prend la place du modèle, avec sa vitesse ; une rotation qui dépend du choc.
	var rb := RigidBody3D.new()
	rb.name = "ScooterAuSol"
	rb.mass = 95.0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.55
	mat.bounce = 0.12
	rb.physics_material_override = mat
	rb.contact_monitor = true
	rb.max_contacts_reported = 4
	rb.angular_damp = 0.6
	rb.linear_damp = 0.05
	# Forme instable comme un vrai deux-roues : les roues sont un cylindre arrondi (on ne tient pas debout
	# dessus), la coque est étroite, le guidon large : il finit couché, appuyé sur le guidon et le flanc.
	var roues := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.2
	capsule.height = 1.55
	roues.shape = capsule
	roues.position = Vector3(0, 0.22, 0.03)
	roues.rotation = Vector3(PI * 0.5, 0, 0)
	rb.add_child(roues)
	var coque := CollisionShape3D.new()
	var bc := BoxShape3D.new()
	bc.size = Vector3(0.36, 0.5, 1.3)
	coque.shape = bc
	coque.position = Vector3(0, 0.62, -0.1)
	rb.add_child(coque)
	var guidon := CollisionShape3D.new()
	var bg := BoxShape3D.new()
	bg.size = Vector3(0.64, 0.1, 0.12)
	guidon.shape = bg
	guidon.position = Vector3(0, 0.95, 0.47)
	rb.add_child(guidon)
	rb.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	rb.center_of_mass = Vector3(0, 0.45, -0.05)
	v.get_parent().add_child(rb)
	rb.global_transform = gt.orthonormalized()
	rb.add_collision_exception_with(v)
	rb.add_collision_exception_with(joueur)
	if v.modele:
		v.modele.reparent(rb, true)
	var avant := v.avant()
	var lat := v.gauche()
	match pourquoi:
		"dos":
			rb.linear_velocity = vitesse * 0.8 + Vector3.UP * 1.5
			rb.angular_velocity = lat * -3.2  # il passe par-dessus la roue arrière
		"mur":
			rb.linear_velocity = vitesse * -0.15 + Vector3.UP * 1.2
			rb.angular_velocity = lat * 2.0 + avant * randf_range(-2.5, 2.5) + Vector3.UP * randf_range(-2.0, 2.0)
		_:
			rb.linear_velocity = vitesse * 0.9
			rb.angular_velocity = avant * (signf(v.penche + 0.001) * -2.5) + Vector3.UP * v.lacet
	# Couché du côté où il penchait (ou au hasard), il finit sur le flanc.
	rb.angular_velocity += avant * -signf(v.penche if absf(v.penche) > 0.05 else randf_range(-1, 1)) * 1.5
	v.au_sol = rb
	v.cabre = 0.0
	v.cabre_v = 0.0
	v.vitesse = 0.0
	v.lateral = 0.0
	v.velocity = Vector3.ZERO
	v.process_mode = Node.PROCESS_MODE_DISABLED
	v.visible = false
	(v.get_child(0) as CollisionShape3D).disabled = true
	# Loums est éjecté : vers l'avant contre un mur ou à la réception, vers l'arrière s'il est passé sur le dos.
	actuel = null
	var p := v.global_position + Vector3.UP * 0.9
	var ejecte := vitesse * 0.55 + Vector3.UP * 3.0
	if pourquoi == "dos":
		p -= avant * 0.6
		ejecte = vitesse * 0.4 - avant * 1.5 + Vector3.UP * 2.0
	elif pourquoi == "mur":
		ejecte = -avant * minf(vitesse.length() * 0.2, 3.0) + Vector3.UP * 3.5
	_rendre_joueur(v, p, ejecte)
	joueur.set("chute_t", 0.0)
	_secousse = 1.0
	_message_court({"dos": "Passé sur le dos !", "mur": "Dans le mur !"}.get(pourquoi, "Chute !") + "   V : relever le scooter", 2.5)


## Les scooters couchés : étincelles et raclement tant qu'ils glissent sur le bitume.
func _scooters_couches(_delta: float) -> void:
	racle_sol = 0.0
	for v in vehicules:
		var rb: RigidBody3D = (v as Vehicule).au_sol
		if rb == null:
			continue
		var vit := rb.linear_velocity.length()
		if rb.get_contact_count() > 0 and vit > 1.2:
			racle_sol = maxf(racle_sol, clampf(vit / 10.0, 0.2, 1.0))
			_etincelle(rb.global_position + Vector3.UP * 0.1, rb.linear_velocity, racle_sol)


## Relever le scooter : on le remet debout, dans l'axe où il a fini, puis on repart.
var _releve_en_cours := false
func _relever(v: Vehicule) -> void:
	if _releve_en_cours:
		return
	_releve_en_cours = true
	var rb := v.au_sol
	var ici := rb.global_position
	var axe := rb.global_basis.z
	axe.y = 0.0
	if axe.length() < 0.1:
		axe = rb.global_basis.y
		axe.y = 0.0
	var cap := atan2(axe.x, axe.z)
	if quartier:
		ici.y = quartier.h(ici.x, ici.z)
	var espace := v.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(ici + Vector3.UP * 1.5, ici + Vector3.DOWN * 2.0)
	q.exclude = [rb.get_rid(), joueur.get_rid(), v.get_rid()]
	var sol := espace.intersect_ray(q)
	if not sol.is_empty():
		ici.y = (sol.position as Vector3).y
	var m := v.modele
	# Le modèle revient debout en 0,6 s (Loums le redresse), puis le scooter redevient conduisible.
	var depart := m.global_transform
	var arrivee := Transform3D(Basis(Vector3.UP, cap), ici + Vector3.UP * (CHAUSSEE - 0.02))
	rb.freeze = true
	_texte.text = ""
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		var e := k * k * (3.0 - 2.0 * k)
		m.global_transform = Transform3D(depart.basis.orthonormalized().slerp(arrivee.basis, e), depart.origin.lerp(arrivee.origin, e))
	, 0.0, 1.0, 0.6)
	await tw.finished
	m.reparent(v, true)
	v.au_sol = null
	rb.queue_free()
	v.global_position = ici + Vector3.UP * 0.02
	v.cap = cap
	v.rotation = Vector3(0, cap, 0)
	v.tangage = 0.0
	v.penche = 0.0
	v.bond = 0.0
	v.bond_v = 0.0
	(v.get_child(0) as CollisionShape3D).disabled = false
	v.visible = true
	v.process_mode = Node.PROCESS_MODE_INHERIT
	_poser_modele(v)
	_releve_en_cours = false
	if joueur.global_position.distance_to(ici) < 4.0:
		_monter(v)


# ==================================================================================================
#  Sensations : caméra, traits de vitesse BD, étincelles, secousses
# ==================================================================================================
func _effets(v: Vehicule, delta: float) -> void:
	_secousse = maxf(0.0, _secousse - delta * 2.2)
	var cam := _camera()
	if v == null or cam == null:
		if cam and _secousse > 0.0:
			cam.h_offset = (randf() - 0.5) * 0.12 * _secousse
			cam.v_offset = (randf() - 0.5) * 0.12 * _secousse
		elif cam and absf(cam.h_offset) > 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
		return
	var r: Dictionary = REGLAGES[v.type]
	var k := clampf(absf(v.vitesse) / v.vmax, 0.0, 1.3)
	# L'angle de vue s'ouvre avec la vitesse, la caméra recule et se rapproche du sol.
	cam.fov = lerpf(cam.fov, _fov0 + 20.0 * k * k, 3.0 * delta)
	var bras := _bras()
	if bras:
		bras.spring_length = lerpf(bras.spring_length, lerpf(r.bras, r.bras_vite, k), 2.0 * delta)
	# Vibration : moteur au ralenti, bitume à pleine vitesse, chocs.
	var vib := 0.004 + 0.012 * k * k + 0.03 * v.racle + 0.08 * _secousse
	cam.h_offset = (randf() - 0.5) * vib
	cam.v_offset = (randf() - 0.5) * vib
	_lignes.set("force", clampf((absf(v.vitesse) * 3.6 - KMH_LIGNES) / 40.0, 0.0, 1.0))
	# Étincelles de la bavette.
	if v.racle > 0.0 and v.modele:
		var bout: Vector3 = v.bavette.global_transform * Vector3(0, -BAVETTE, 0)
		_etincelle(bout, v.velocity, v.racle)
	# Fumée de pneu en dérapage : des étincelles grises plus lentes (le style BD les encre comme des traits).
	if v.derive > 0.4 and absf(v.lateral) > 1.5 and v.is_on_floor() and v.type == "scooter":
		var arr: Vector3 = v.global_transform * Vector3(0, 0.05, -0.55)
		_fumee(arr)


## Des étincelles (et de la fumée de pneu) simulées à la main : un MultiMesh, aucun shader de particules,
## donc identique sur PC et sur téléphone.
class Gerbe extends MultiMeshInstance3D:
	var vies := PackedFloat32Array()
	var durees := PackedFloat32Array()
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var gravite := -12.0
	var frottement := 0.0
	var couleur_debut := Color(1.0, 0.95, 0.6)
	var couleur_fin := Color(1.0, 0.35, 0.05)
	var grossit := 1.0
	var etire := true
	var _i := 0

	func _init(nb: int, maille: Mesh) -> void:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = maille
		multimesh.instance_count = nb
		vies.resize(nb)
		durees.resize(nb)
		pos.resize(nb)
		vel.resize(nb)
		for i in nb:
			vies[i] = 0.0
			durees[i] = 1.0
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func lancer(ou: Vector3, v: Vector3, duree: float) -> void:
		vies[_i] = duree
		durees[_i] = duree
		pos[_i] = ou
		vel[_i] = v
		_i = (_i + 1) % vies.size()

	func _physics_process(delta: float) -> void:
		global_transform = Transform3D.IDENTITY
		for i in vies.size():
			if vies[i] <= 0.0:
				continue
			vies[i] -= delta
			if vies[i] <= 0.0:
				multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				continue
			var v := vel[i]
			v.y += gravite * delta
			v *= exp(-frottement * delta)
			var p := pos[i] + v * delta
			if p.y < 0.0 and gravite < 0.0:
				p.y = 0.0
				v.y = absf(v.y) * 0.3  # rebondit sur le bitume
			pos[i] = p
			vel[i] = v
			var k := 1.0 - vies[i] / durees[i]
			var b := Basis.from_scale(Vector3.ONE * lerpf(1.0, grossit, k))
			if etire and v.length() > 0.5:
				var z := v.normalized()
				var x := z.cross(Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).normalized()
				b = Basis(x, z.cross(x), z) * Basis.from_scale(Vector3(1, 1, clampf(v.length() * 0.25, 1.0, 3.0)))
			multimesh.set_instance_transform(i, Transform3D(b, p))
			multimesh.set_instance_color(i, couleur_debut.lerp(couleur_fin, k))


func _faire_etincelles() -> Gerbe:
	var q := BoxMesh.new()
	q.size = Vector3(0.018, 0.018, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	q.material = m
	var g := Gerbe.new(220, q)
	g.name = "Etincelles"
	return g


## Une poignée d'étincelles au point de contact, projetées vers l'arrière de la glisse.
func _etincelle(ou: Vector3, vitesse: Vector3, force: float) -> void:
	var plat := Vector3(vitesse.x, 0.0, vitesse.z)
	var arriere := -plat.normalized() if plat.length() > 0.5 else Vector3.BACK
	for i in int(2 + 5 * force):
		var v := plat * 0.6 + arriere * randf_range(1.0, 4.0) * force + Vector3(randf_range(-1.2, 1.2), randf_range(0.6, 2.6), randf_range(-1.2, 1.2))
		_etincelles.lancer(ou, v, randf_range(0.18, 0.4))


var _fumees: Gerbe
func _fumee(ou: Vector3) -> void:
	if _fumees == null:
		var s := SphereMesh.new()
		s.radius = 0.14
		s.height = 0.28
		s.radial_segments = 8
		s.rings = 4
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		s.material = m
		_fumees = Gerbe.new(90, s)
		_fumees.name = "Fumee"
		_fumees.gravite = 0.5
		_fumees.frottement = 2.5
		_fumees.grossit = 4.0
		_fumees.etire = false
		_fumees.couleur_debut = Color(0.95, 0.93, 0.9, 0.55)
		_fumees.couleur_fin = Color(0.95, 0.93, 0.9, 0.0)
		add_child(_fumees)
	if randf() < 0.6:
		_fumees.lancer(ou, Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.7), randf_range(-0.5, 0.5)), randf_range(0.6, 1.0))


func _message_court(txt: String, duree: float) -> void:
	if txt == "":
		return
	_texte.text = txt
	_message_t = duree


func _hud(v: Vehicule) -> void:
	if _message_t > 0.0:
		return
	var kmh := absf(v.vitesse) * 3.6
	var lignes := "%s   %d km/h" % ["SCOOTER" if v.type == "scooter" else "VOITURE", roundi(kmh)]
	if v.type == "scooter":
		if roue_arriere > 0.0:
			lignes += "\nROUE ARRIÈRE  %.1f s%s" % [roue_arriere, "  · ça racle !" if v.racle > 0.0 else ""]
		elif v.derive > 0.5:
			lignes += "\nDÉRAPAGE"
		elif record > 0.0:
			lignes += "\nrecord roue arrière : %.1f s" % record
		if not TouchControls.actif:
			lignes += "\nZ / S gaz · Q / D tourner · Maj dérapage · Espace roue arrière · V descendre"
	elif not TouchControls.actif:
		lignes += "\nZ / S gaz · Q / D tourner · Espace frein à main · V descendre"
	_texte.text = lignes


func _interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	_lignes = TraitsVitesse.new()
	_lignes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(_lignes)
	_texte = Label.new()
	_texte.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_texte.position = Vector2(-300, 230)
	_texte.custom_minimum_size = Vector2(600, 0)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.add_theme_font_size_override("font_size", 20)
	_texte.add_theme_color_override("font_outline_color", Color.BLACK)
	_texte.add_theme_constant_override("outline_size", 5)
	couche.add_child(_texte)


## Traits de vitesse façon BD : des lignes qui filent du centre vers les bords, seulement sur le pourtour.
class TraitsVitesse extends Control:
	var force := 0.0
	var _traits: Array = []
	var _attente := 0.0

	func _process(delta: float) -> void:
		_attente -= delta
		if force <= 0.01:
			if not _traits.is_empty():
				_traits.clear()
				queue_redraw()
			return
		if _attente <= 0.0:
			_attente = 0.06
			_traits.clear()
			for i in int(10 + 34 * force):
				_traits.append([randf() * TAU, randf_range(0.62, 0.8), randf_range(0.12, 0.35) * (0.5 + force), randf_range(1.0, 3.2)])
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := c.length()
		for t in _traits:
			var d := Vector2(cos(t[0]), sin(t[0]))
			var a: Vector2 = c + d * r * float(t[1])
			var b: Vector2 = c + d * r * (float(t[1]) + float(t[2]))
			draw_line(a, b, Color(0.12, 0.1, 0.18, 0.55 * force), float(t[3]) + 1.2, true)
			draw_line(a, b, Color(1, 1, 1, 0.6 * force), float(t[3]), true)
