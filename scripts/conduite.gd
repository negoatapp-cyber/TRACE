extends Node
## TRACE — conduire la voiture et le scooter (conversation n°2, à la demande de Louma).
## Script indépendant : il ne modifie pas les fichiers du joueur. Pendant la conduite, Loums suit le véhicule,
## assis dessus (la pose assise est dans personnage.gd, n°1) ; sa caméra suit donc le véhicule, de dos.
##
##   V                monter / descendre (à côté d'un véhicule, à l'arrêt ou presque)
##   Z / S            accélérer / freiner, puis marche arrière
##   Q / D            tourner
##   Espace           scooter : roue arrière (maintenir, garder l'équilibre avec Z / S)
##                    voiture : frein à main (dérapage)
##
## Les véhicules sont ceux du groupe « vehicule » (posés par habillage.gd), avec la métadonnée
## « type » = "voiture" ou "scooter". Réglages arcade, comme le skate : on règle au ressenti.

const REGLAGES := {
	"scooter": {"vmax": 13.0, "accel": 5.5, "frein": 9.0, "virage": 2.6, "adherence": 7.0, "taille": Vector3(0.6, 1.0, 1.6), "bras": 4.2},
	"voiture": {"vmax": 17.0, "accel": 4.5, "frein": 10.0, "virage": 1.6, "adherence": 6.0, "taille": Vector3(1.7, 1.2, 4.0), "bras": 6.5},
}
const ROUE_AR := Vector3(0, 0.22, -0.55)  # pivot de la roue arrière du scooter (repère du modèle)
const CHAUSSEE := 0.07 # la chaussée est dessinée 7 cm au-dessus du sol réel

var joueur: CharacterBody3D
var quartier: Node
var vehicules: Array = []      # [Vehicule]
var actuel: Vehicule
var roue_arriere := 0.0        # durée de la roue arrière en cours (s)
var record := 0.0
var _texte: Label
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

	func avant() -> Vector3:
		return Vector3(sin(cap), 0.0, cos(cap))


func _ready() -> void:
	_action("monter", KEY_V, JOY_BUTTON_DPAD_RIGHT)
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	joueur = scene.get_node_or_null("Player") as CharacterBody3D
	quartier = scene.get_node_or_null("Quartier")
	_interface()
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
		if proche and Input.is_action_just_pressed("monter") and joueur.is_on_floor():
			_monter(proche)
		return
	_conduire(actuel, delta)
	if Input.is_action_just_pressed("monter") and absf(actuel.vitesse) < 3.0 and actuel.cabre < 0.1:
		_descendre()


func _vehicule_proche() -> Vehicule:
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
	# Les véhicules sont solides ; seul celui qu'on conduit laisse passer Loums (il est assis dedans).
	v.add_collision_exception_with(joueur)
	joueur.add_collision_exception_with(v)
	joueur.set_physics_process(false)
	joueur.velocity = Vector3.ZERO
	_hud_joueur(false)
	var bras := joueur.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	if bras:
		bras.spring_length = float((REGLAGES[v.type] as Dictionary).bras)
	_suivre(v)


func _descendre() -> void:
	var v := actuel
	actuel = null
	v.vitesse = 0.0
	v.velocity = Vector3.ZERO
	# Loums réapparaît à gauche du véhicule.
	var gauche := v.avant().cross(Vector3.UP).normalized()
	var taille: Vector3 = (REGLAGES[v.type] as Dictionary).taille
	var demi: float = taille.x * 0.5 + 0.7
	var p := v.global_position + gauche * demi
	if quartier:
		p.y = quartier.h(p.x, p.z) + 0.1
	joueur.global_position = p
	joueur.velocity = Vector3.ZERO
	v.remove_collision_exception_with(joueur)
	joueur.remove_collision_exception_with(v)
	(joueur.get("visual") as Node3D).visible = true
	_hud_joueur(true)
	joueur.set_physics_process(true)
	var bras := joueur.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	if bras:
		bras.spring_length = 4.5
	_texte.text = ""


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
	if gaz > 0.1:
		v.vitesse = minf(v.vitesse + r.accel * gaz * delta, r.vmax) if v.vitesse >= 0.0 else v.vitesse + r.frein * delta
	elif gaz < -0.1:
		if v.vitesse > 0.0:
			v.vitesse = maxf(v.vitesse - r.frein * delta, 0.0)
			v.arret = 0.0
		elif v.arret < 0.4:
			v.arret += delta  # on marque l'arrêt avant de reculer
		else:
			v.vitesse = maxf(v.vitesse - r.accel * 0.6 * delta, -r.vmax * 0.3)
	else:
		v.vitesse = move_toward(v.vitesse, 0.0, 1.5 * delta)
		v.arret = 0.0
	# Virage : plus serré à faible vitesse, nul à l'arrêt, inversé en marche arrière.
	var effet := clampf(absf(v.vitesse) / 4.0, 0.0, 1.0) * clampf(1.3 - absf(v.vitesse) / r.vmax * 0.6, 0.6, 1.3)
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
		v.penche = lerpf(v.penche, -volant * 0.32 * clampf(absf(v.vitesse) / 8.0, 0.0, 1.0), 6.0 * delta)
	_poser_modele(v)
	_suivre(v)
	_hud(v)


## Roue arrière : Espace cabre le scooter ; Z le fait monter, S le fait redescendre ; trop haut, c'est la chute.
func _roue_arriere(v: Vehicule, gaz: float, espace: bool, delta: float) -> void:
	var tire := 0.0
	if espace and v.vitesse > 2.5:
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
		_chute(v)


func _chute(v: Vehicule) -> void:
	record = maxf(record, roue_arriere)
	roue_arriere = 0.0
	v.cabre = 0.0
	v.cabre_v = 0.0
	v.vitesse = 0.0
	_descendre()
	joueur.global_position -= v.avant() * 1.2
	_texte.text = "Chute !"


func _poser_modele(v: Vehicule) -> void:
	if v.modele == null:
		return
	var t := v.base_modele
	if v.cabre > 0.0:
		# On cabre autour de la roue arrière.
		var pivot := t.origin + ROUE_AR
		t = Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.RIGHT, -v.cabre), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot) * t
	t = Transform3D(Basis(Vector3.FORWARD, v.penche), Vector3.ZERO) * t
	v.modele.transform = t


func _hud(v: Vehicule) -> void:
	var kmh := absf(v.vitesse) * 3.6
	var lignes := "%s   %d km/h" % ["SCOOTER" if v.type == "scooter" else "VOITURE", roundi(kmh)]
	if v.type == "scooter":
		if roue_arriere > 0.0:
			lignes += "\nROUE ARRIÈRE  %.1f s" % roue_arriere
		elif record > 0.0:
			lignes += "\nrecord roue arrière : %.1f s" % record
		if not TouchControls.actif:
			lignes += "\nZ / S gaz · Q / D tourner · Espace roue arrière · V descendre"
	elif not TouchControls.actif:
		lignes += "\nZ / S gaz · Q / D tourner · Espace frein à main · V descendre"
	_texte.text = lignes


func _interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	_texte = Label.new()
	_texte.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_texte.position = Vector2(-260, 230)
	_texte.custom_minimum_size = Vector2(520, 0)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.add_theme_font_size_override("font_size", 20)
	_texte.add_theme_color_override("font_outline_color", Color.BLACK)
	_texte.add_theme_constant_override("outline_size", 5)
	couche.add_child(_texte)
