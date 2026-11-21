extends Node
## TRACE — conduire la voiture et le scooter (conversation n°2, à la demande de Louma).
## Script indépendant : il ne modifie pas les fichiers du joueur. Pendant la conduite, Loums suit le véhicule,
## assis dessus (la pose assise est dans personnage.gd, n°1) ; sa caméra suit donc le véhicule, de dos.
##
##   V                monter / descendre (à côté d'un véhicule, à l'arrêt ou presque)
##   Z / S            accélérer / freiner, puis marche arrière
##   Q / D            tourner
##   Espace + Z       scooter : roue arrière (maintenir, garder l'équilibre avec Z / S)
##   Espace + S       scooter : frein avant, l'arrière se lève (stoppie) ; trop vite, on passe par-dessus
##                    voiture : Espace = frein à main (dérapage)
##
## 21.11 (Louma) : démarrage « boosté » (forte poussée en bas, 90 km/h difficile à atteindre),
## étincelles quand la bavette du modèle touche le bitume (roue arrière entre l'équilibre et la chute),
## freinage avant avec bascule vers l'avant et chute possible dans ce sens.
##
## Les véhicules sont ceux du groupe « vehicule » (posés par habillage.gd), avec la métadonnée
## « type » = "voiture" ou "scooter". Réglages arcade, comme le skate : on règle au ressenti.

const REGLAGES := {
	"scooter": {"vmax": 27.0, "accel": 17.0, "frein": 10.0, "virage": 2.6, "adherence": 7.0, "taille": Vector3(0.6, 1.0, 1.6), "bras": 4.2},
	"voiture": {"vmax": 17.0, "accel": 4.5, "frein": 10.0, "virage": 1.6, "adherence": 6.0, "taille": Vector3(1.7, 1.2, 4.0), "bras": 6.5},
}
const ROUE_AR := Vector3(0, 0.22, -0.55)  # pivot de la roue arrière du scooter (repère du modèle)
const ROUE_AV := Vector3(0, 0.22, 0.60)   # pivot de la roue avant (bascule au freinage avant)
const BOUT_BAVETTE := Vector3(0, 0.07, -0.81)  # bas de la bavette du modèle Meshy
const CABRE_RACLE := 0.95  # au-delà (entre l'équilibre et la chute à 1,25), la bavette touche : étincelles
const PIQUE_CHUTE := 1.05  # bascule avant au-delà : on passe par-dessus le guidon
const CHAUSSEE := 0.07 # la chaussée est dessinée 7 cm au-dessus du sol réel

var joueur: Player
var quartier: Node
var vehicules: Array = []      # [Vehicule]
var actuel: Vehicule
var roue_arriere := 0.0        # durée de la roue arrière en cours (s)
var record := 0.0
var vient_de_chuter := false   # lu par le son au moment où Loums quitte le scooter
var _avis_sortie := 0.0
var _texte: Label
var _etincelles: Gerbe
var _fov0 := -1.0
var _poussee := 0.0            # 0..1 : coup de boost du démarrage (caméra)
var _gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity")


class Vehicule extends CharacterBody3D:
	var type := "voiture"
	var modele: Node3D
	var base_modele := Transform3D()
	var vitesse := 0.0          # le long du cap (négative = marche arrière)
	var cap := 0.0              # rotation Y ; l'avant du véhicule est +Z local
	var cabre := 0.0            # angle de roue arrière (rad)
	var cabre_v := 0.0
	var penche := 0.0
	var arret := 0.0           # temps passé à l'arrêt en freinant (la marche arrière attend 0,4 s)
	var vmax := 13.0
	var pique := 0.0            # bascule vers l'avant au freinage avant (rad)
	var pique_v := 0.0
	var racle := 0.0            # 0..1 : la bavette frotte le bitume (lu par le son)

	func avant() -> Vector3:
		return Vector3(sin(cap), 0.0, cos(cap))


func _ready() -> void:
	_action("monter", KEY_V, JOY_BUTTON_DPAD_RIGHT)
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	joueur = scene.get_node_or_null("Player") as Player
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
		v.add_to_group("vehicule")
		v.add_to_group("voiture" if type == "voiture" else "mobilier")
		v.set_meta("type", type)
		vehicules.append(v)
		fixe.queue_free()


func _physics_process(delta: float) -> void:
	if joueur == null:
		return
	if actuel == null:
		var proche := _vehicule_proche()
		_texte.text = ("V : monter sur le scooter" if proche.type == "scooter" else "V : monter dans la voiture") if proche else ""
		_compteur(false)
		if proche and Input.is_action_just_pressed("monter") and joueur.is_on_floor():
			_monter(proche)
		return
	_conduire(actuel, delta)
	if actuel and Input.is_action_just_pressed("monter") and absf(actuel.vitesse) < 3.0 and actuel.cabre < 0.1:
		_descendre()


func _vehicule_proche() -> Vehicule:
	if not joueur or not joueur.is_physics_processing() or not joueur.is_on_floor():
		return null
	if joueur.transition != "" or joueur.chute_t >= 0.0 or joueur._mantling or joueur.suspendu or joueur.gouttiere:
		return null
	var meilleur: Vehicule = null
	var d := 2.8
	for v in vehicules:
		var e: float = (v as Node3D).global_position.distance_to(joueur.global_position)
		if e < d:
			d = e
			meilleur = v
	return meilleur


func _monter(v: Vehicule) -> void:
	actuel = v
	vient_de_chuter = false
	_avis_sortie = 0.0
	if joueur.mode == Player.Mode.SKATE:
		joueur._set_mode(Player.Mode.WALK)
	# Les véhicules sont solides ; seul celui qu'on conduit laisse passer Loums (il est assis dedans).
	v.add_collision_exception_with(joueur)
	joueur.add_collision_exception_with(v)
	joueur.set_physics_process(false)
	joueur.velocity = Vector3.ZERO
	_hud_joueur(false)
	var bras := joueur.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	if bras:
		bras.add_excluded_object(v.get_rid())
		bras.spring_length = float((REGLAGES[v.type] as Dictionary).bras)
		bras.set_meta("vehicule", true)  # le joueur ne remet pas sa distance à pied
	var cam := _camera()
	if cam:
		_fov0 = cam.fov
	_suivre(v)


func _camera() -> Camera3D:
	return joueur.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D


## Cherche du sol portant et la place pour le corps entier, même à côté d'un trottoir ou d'un mur.
func _point_de_sortie(v: Vehicule) -> Dictionary:
	var espace := joueur.get_world_3d().direct_space_state
	var forme := joueur.get_node("CollisionShape3D") as CollisionShape3D
	var taille: Vector3 = REGLAGES[v.type].taille
	var gauche := Vector3.UP.cross(v.avant())
	var pas := gauche * (taille.x * 0.5 + 0.65)
	var bout := v.avant() * (taille.z * 0.5 + 0.65)
	for decalage: Vector3 in [pas, -pas, -bout, bout]:
		var centre := v.global_position + Vector3.UP * 0.75
		var cote := centre + decalage
		var rayon := PhysicsRayQueryParameters3D.create(centre, cote, joueur.collision_mask)
		rayon.exclude = [v.get_rid(), joueur.get_rid()]
		if not espace.intersect_ray(rayon).is_empty():
			continue
		rayon.from = cote
		rayon.to = cote - Vector3.UP * 2.0
		var sol := espace.intersect_ray(rayon)
		if sol.is_empty() or Vector3(sol.normal).angle_to(Vector3.UP) > joueur.floor_max_angle:
			continue
		var pied: Vector3 = sol.position + Vector3.UP * 0.08
		var volume := PhysicsShapeQueryParameters3D.new()
		volume.shape = forme.shape
		volume.transform = Transform3D(joueur.global_basis, pied) * forme.transform
		volume.collision_mask = joueur.collision_mask
		volume.exclude = [joueur.get_rid()]
		if espace.intersect_shape(volume, 1).is_empty():
			return {"pied": pied}
	return {}


func _descendre() -> bool:
	var v := actuel
	var sortie := _point_de_sortie(v)
	if sortie.is_empty():
		_avis_sortie = 2.0
		return false
	actuel = null
	v.vitesse = 0.0
	v.velocity = Vector3.ZERO
	v.penche = 0.0
	v.cabre = 0.0
	v.cabre_v = 0.0
	v.pique = 0.0
	v.pique_v = 0.0
	v.racle = 0.0
	v.arret = 0.0
	record = maxf(record, roue_arriere)
	roue_arriere = 0.0
	_poser_modele(v)
	joueur.global_position = sortie.pied
	joueur.velocity = Vector3.ZERO
	v.remove_collision_exception_with(joueur)
	joueur.remove_collision_exception_with(v)
	(joueur.get("visual") as Node3D).visible = true
	_hud_joueur(true)
	joueur.set_physics_process(true)
	var bras := joueur.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	if bras:
		bras.remove_excluded_object(v.get_rid())
		bras.spring_length = 3.0  # distance à pied (player.tscn)
		bras.remove_meta("vehicule")
	var cam := _camera()
	if cam and _fov0 > 0.0:
		cam.fov = _fov0
	_texte.text = ""
	_compteur(false)
	return true


## Le texte d'aide du joueur (« À PIED… ») est masqué pendant la conduite.
func _hud_joueur(visible: bool) -> void:
	var hud := joueur.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = visible


## Loums « suit » le véhicule : sa caméra et son suivi de dos s'appliquent au véhicule.
func _suivre(v: Vehicule) -> void:
	joueur.global_position = v.global_position
	joueur.velocity = v.velocity
	(joueur.get("visual") as Node3D).rotation.y = v.cap + PI  # le joueur regarde vers -Z


func _conduire(v: Vehicule, delta: float) -> void:
	var r: Dictionary = REGLAGES[v.type]
	var entree := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var gaz := -entree.y
	var volant := -entree.x
	var espace := Input.is_action_pressed("jump")
	# Vitesse le long du cap.
	var frein_avant := v.type == "scooter" and espace and gaz < -0.1 and v.vitesse > 0.5 and v.cabre < 0.05
	if gaz > 0.1:
		if v.vitesse >= 0.0:
			if v.type == "scooter":
				# Démarrage boosté : un coup de pied au départ, une poussée très forte en bas qui
				# s'essouffle ; les derniers km/h sont durs à aller chercher.
				if v.vitesse < 1.0 and v.cabre < 0.05:
					v.vitesse += 1.8 * gaz
					_poussee = 1.0
					v.cabre_v += 0.8  # l'avant se soulève un instant
				var k := clampf(1.0 - v.vitesse / r.vmax, 0.0, 1.0)
				var a: float = r.accel * pow(k, 2.6) + 1.2 * k
				v.vitesse = minf(v.vitesse + a * gaz * delta, r.vmax)
				_poussee = maxf(_poussee, clampf(a / r.accel, 0.0, 1.0) * gaz)
			else:
				v.vitesse = minf(v.vitesse + r.accel * gaz * delta, r.vmax)
		else:
			v.vitesse += r.frein * delta
	elif frein_avant:
		v.vitesse = maxf(v.vitesse - 9.0 * -gaz * delta, 0.0)  # le frein avant mord fort
		v.arret = 0.0
	elif gaz < -0.1:
		if v.vitesse > 0.0:
			v.vitesse = maxf(v.vitesse - r.frein * delta, 0.0)
			v.arret = 0.0
		elif v.arret < 0.4:
			v.arret += delta  # on marque l'arrêt avant de reculer
		else:
			v.vitesse = maxf(v.vitesse - 3.0 * delta, -4.0)  # marche arrière au pas
	else:
		v.vitesse = move_toward(v.vitesse, 0.0, 1.5 * delta)
		v.arret = 0.0
	# Virage : plus serré à faible vitesse, nul à l'arrêt, inversé en marche arrière.
	var effet := clampf(absf(v.vitesse) / 4.0, 0.0, 1.0) * clampf(1.3 - absf(v.vitesse) / r.vmax, 0.35, 1.3)
	var frein_main := v.type == "voiture" and espace
	v.cap += volant * r.virage * effet * signf(v.vitesse) * delta * (1.4 if frein_main else 1.0)
	if frein_main:
		v.vitesse = move_toward(v.vitesse, 0.0, 4.0 * delta)
	# Adhérence : la vitesse réelle rejoint le cap plus ou moins vite (dérapage au frein à main).
	var voulu := v.avant() * v.vitesse
	var plat := Vector3(v.velocity.x, 0, v.velocity.z)
	plat = plat.lerp(voulu, clampf((1.2 if frein_main else r.adherence) * delta, 0.0, 1.0))
	v.velocity.x = plat.x
	v.velocity.z = plat.z
	v.velocity.y = 0.0 if v.is_on_floor() else v.velocity.y - _gravite * delta
	var avant_choc := plat.length()
	v.move_and_slide()
	# Un choc franc fait perdre la vitesse.
	if v.get_slide_collision_count() > 0 and Vector3(v.velocity.x, 0, v.velocity.z).length() < avant_choc * 0.6:
		v.vitesse *= 0.4
	v.rotation.y = v.cap
	if v.type == "scooter":
		_roue_arriere(v, gaz, espace, delta)
		if actuel == null:
			return
		_frein_avant(v, frein_avant, -gaz, delta)
		if actuel == null:
			return
		_effets(v, delta)
		v.penche = lerpf(v.penche, -volant * 0.32 * clampf(absf(v.vitesse) / 8.0, 0.0, 1.0), 6.0 * delta)
	_poser_modele(v)
	_suivre(v)
	_hud(v)
	_avis_sortie = maxf(0.0, _avis_sortie - delta)


## Roue arrière : Espace cabre le scooter ; Z le fait monter, S le fait redescendre ; trop haut, c'est la chute.
func _roue_arriere(v: Vehicule, gaz: float, espace: bool, delta: float) -> void:
	var tire := 0.0
	if espace and v.vitesse > 2.5 and (gaz > -0.1 or v.cabre > 0.05):  # Espace + S à plat : c'est le stoppie
		# plein gaz : équilibre vers 55° au début, puis ça tire de plus en plus (il faut doser le gaz),
		# sinon on bascule au bout de 3 à 4 s plein gaz.
		tire = 2.7 + gaz * (1.2 + 0.3 * roue_arriere)
	var retour := 5.0 * sin(v.cabre) + (2.5 if not espace else 0.0)
	v.cabre_v += (tire - retour) * delta * 2.0
	v.cabre_v *= exp(-2.5 * delta)
	v.cabre = clampf(v.cabre + v.cabre_v * delta, 0.0, 1.4)
	if v.cabre == 0.0:
		v.cabre_v = maxf(v.cabre_v, 0.0)
	if v.cabre > 0.08:
		roue_arriere += delta
	elif roue_arriere > 0.0:
		record = maxf(record, roue_arriere)
		roue_arriere = 0.0
	if v.cabre >= 1.25:  # trop cabré : on bascule en arrière
		_chute(v, -1.0)


## Frein avant (Espace + S) : l'arrière se lève d'autant plus qu'on freine fort et vite. À vitesse
## modérée on tient un stoppie ; au-dessus de ~45 km/h ça continue de monter : on passe par-dessus.
func _frein_avant(v: Vehicule, actif: bool, force: float, delta: float) -> void:
	# Réglé au ressenti : ~25 km/h → 30°, ~35 km/h → 55°, au-delà de ~45 km/h → par-dessus.
	var tire := 0.0
	if actif and v.cabre < 0.05:
		tire = 5.0 * clampf(v.vitesse / 10.0, 0.0, 2.0) * clampf(force, 0.0, 1.0)
	var retour := 5.0 * sin(v.pique) + (2.5 if not actif else 0.0)
	v.pique_v += (tire - retour) * delta * 3.0
	v.pique_v *= exp(-2.5 * delta)
	v.pique = clampf(v.pique + v.pique_v * delta, 0.0, 1.3)
	if v.pique == 0.0:
		v.pique_v = maxf(v.pique_v, 0.0)
	if v.pique >= PIQUE_CHUTE:
		_chute(v, 1.0)


## sens : -1 = en arrière (roue arrière ratée), +1 = par-dessus le guidon (freinage avant).
func _chute(v: Vehicule, sens := -1.0) -> void:
	record = maxf(record, roue_arriere)
	roue_arriere = 0.0
	var elan := v.avant() * v.vitesse
	vient_de_chuter = true
	v.cabre = 0.0
	v.cabre_v = 0.0
	v.pique = 0.0
	v.pique_v = 0.0
	v.vitesse = 0.0
	if _descendre():
		_texte.text = "Chute !"
		# Loums est projeté : vers l'avant par-dessus le guidon, ou glisse en arrière du scooter.
		joueur.velocity = (elan * 0.7 if sens > 0.0 else -v.avant() * 1.5) + Vector3.UP * (3.5 if sens > 0.0 else 1.5)
		joueur.chute_t = 0.0


func _poser_modele(v: Vehicule) -> void:
	if v.modele == null:
		return
	var t := v.base_modele
	if v.cabre > 0.0:
		# On cabre autour de la roue arrière.
		var pivot := t.origin + ROUE_AR
		t = Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.RIGHT, -v.cabre), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot) * t
	if v.pique > 0.0:
		# On bascule vers l'avant autour de la roue avant.
		var pivot_av := t.origin + ROUE_AV
		t = Transform3D(Basis.IDENTITY, pivot_av) * Transform3D(Basis(Vector3.RIGHT, v.pique), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot_av) * t
	t = Transform3D(Basis(Vector3.FORWARD, v.penche), Vector3.ZERO) * t
	v.modele.transform = t


## Compteur en haut à droite, sous le bouton « Départ » : grosse vitesse en lettrage d'affiche (Anton),
## le nom du véhicule au-dessus, la roue arrière en jaune ; l'aide clavier, discrète, en bas au centre.
const POLICE := preload("res://assets/decor/polices/Anton-Regular.ttf")
const JAUNE := Color(1.0, 0.82, 0.12)
const ROSE := Color(0.93, 0.18, 0.47)
var _vitesse: Label
var _unite: Label
var _roue: Label
var _aide: Label
var _cadre: Control


func _compteur(oui: bool) -> void:
	if _vitesse:
		_vitesse.get_parent().visible = oui
		_roue.visible = oui
		_aide.visible = oui


func _hud(v: Vehicule) -> void:
	_compteur(true)
	var kmh := absf(v.vitesse) * 3.6
	_texte.text = "SCOOTER" if v.type == "scooter" else "VOITURE"
	if _avis_sortie > 0.0:
		_texte.text = "Sortie bloquée · déplace le véhicule"
	_vitesse.text = "%d" % roundi(kmh)
	_roue.text = ""
	_roue.add_theme_color_override("font_color", JAUNE)
	if v.type == "scooter":
		if roue_arriere > 0.0:
			_roue.text = "ROUE ARRIÈRE  %.1f s" % roue_arriere
			_roue.add_theme_color_override("font_color", ROSE)
		elif v.pique > 0.1:
			_roue.text = "STOPPIE"
			_roue.add_theme_color_override("font_color", ROSE)
		elif record > 0.0:
			_roue.text = "RECORD  %.1f s" % record
	if TouchControls.actif:
		_aide.text = ""
	elif v.type == "scooter":
		_aide.text = "Z / S gaz · Q / D tourner · Espace + Z roue arrière · Espace + S stoppie · V descendre"
	else:
		_aide.text = "Z / S gaz · Q / D tourner · Espace frein à main · V descendre"


func _etiquette(taille: int, couleur: Color, contour := 6) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", POLICE)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.14))
	l.add_theme_constant_override("outline_size", contour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	_cadre = Control.new()
	_cadre.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_cadre.offset_left = -260
	_cadre.offset_right = -24
	_cadre.offset_top = 96          # sous le bouton « Départ »
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(_cadre)
	var pile := VBoxContainer.new()
	pile.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pile.add_theme_constant_override("separation", -10)
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre.add_child(pile)
	_texte = _etiquette(22, Color(0.96, 0.95, 0.90), 5)       # SCOOTER / VOITURE
	pile.add_child(_texte)
	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_END
	ligne.add_theme_constant_override("separation", 6)
	pile.add_child(ligne)
	_vitesse = _etiquette(64, JAUNE, 10)
	ligne.add_child(_vitesse)
	_unite = _etiquette(22, Color(0.96, 0.95, 0.90), 5)
	_unite.text = "KM/H"
	_unite.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_unite.size_flags_vertical = Control.SIZE_SHRINK_END
	ligne.add_child(_unite)
	_roue = _etiquette(22, JAUNE, 5)
	pile.add_child(_roue)
	_aide = Label.new()
	_aide.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_aide.offset_left = -360
	_aide.offset_right = 360
	_aide.offset_top = -40
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aide.add_theme_font_size_override("font_size", 15)
	_aide.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_aide.add_theme_color_override("font_outline_color", Color.BLACK)
	_aide.add_theme_constant_override("outline_size", 4)
	couche.add_child(_aide)


# ==================================================================================================
#  Effets : étincelles de la bavette, coup de boost à la caméra
# ==================================================================================================
func _effets(v: Vehicule, delta: float) -> void:
	# La bavette du modèle touche le bitume entre le point d'équilibre et la chute.
	v.racle = 0.0
	if v.cabre > CABRE_RACLE and v.vitesse > 1.0 and v.modele:
		v.racle = clampf((v.cabre - CABRE_RACLE) / (1.25 - CABRE_RACLE) * 0.6 + 0.4, 0.0, 1.0)
		var bout: Vector3 = v.modele.global_transform * BOUT_BAVETTE
		bout.y = v.global_position.y + CHAUSSEE  # au niveau du bitume
		var plat := Vector3(v.velocity.x, 0.0, v.velocity.z)
		var arriere := -plat.normalized() if plat.length() > 0.5 else -v.avant()
		for i in int(3 + 6 * v.racle):
			var vit := plat * 0.5 + arriere * randf_range(1.5, 5.0) + Vector3(randf_range(-1.3, 1.3), randf_range(0.8, 3.0), randf_range(-1.3, 1.3))
			_etincelles.lancer(bout, vit, randf_range(0.2, 0.45))
	# Le coup de boost : l'angle de vue s'ouvre d'un coup au démarrage, puis suit la vitesse.
	_poussee = maxf(0.0, _poussee - delta * 1.6)
	var cam := _camera()
	if cam and _fov0 > 0.0:
		var k := clampf(absf(v.vitesse) / v.vmax, 0.0, 1.0)
		cam.fov = lerpf(cam.fov, _fov0 + 9.0 * _poussee + 12.0 * k * k, 8.0 * delta)


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


## Étincelles simulées à la main (MultiMesh) : identiques sur PC et sur téléphone.
class Gerbe extends MultiMeshInstance3D:
	var vies := PackedFloat32Array()
	var durees := PackedFloat32Array()
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
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
			v.y -= 12.0 * delta
			var p := pos[i] + v * delta
			pos[i] = p
			vel[i] = v
			var k := 1.0 - vies[i] / durees[i]
			var b := Basis.IDENTITY
			if v.length() > 0.5:
				var z := v.normalized()
				var x := z.cross(Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).normalized()
				b = Basis(x, z.cross(x), z) * Basis.from_scale(Vector3(1, 1, clampf(v.length() * 0.25, 1.0, 3.0)))
			multimesh.set_instance_transform(i, Transform3D(b, p))
			multimesh.set_instance_color(i, Color(1.0, 0.95, 0.6).lerp(Color(1.0, 0.35, 0.05), k))
