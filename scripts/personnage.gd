extends Node3D
## Le corps de Loums. Au lancement, charge le modèle 3D s'il est présent
## (assets/personnages/loums.glb, exporté de Meshy avec squelette et animations)
## et remplace la capsule orange. Sans fichier, la capsule reste : le jeu marche toujours.
##
## Le fichier est lu directement au lancement (pas besoin de l'ouvrir dans l'éditeur).
## Les animations sont reconnues à leur nom : idle / walk / run / jump.

const FICHIER := "res://assets/personnages/loums.glb"
const TAILLE := 1.75   ## hauteur voulue du personnage (m)

## Loums est goofy : pied droit devant. Sur la planche, il regarde vers sa gauche
## (le côté gauche de la direction de roulage) ; son épaule droite ouvre la route.
@export var goofy := true
## Où vont les pieds sur la planche (repère de la planche : -Z = nose). Hauteur = cheville.
const PIED_AVANT := Vector3(0.0, 0.11, -0.16)
const PIED_ARRIERE := Vector3(0.0, 0.11, 0.20)
const CHEVILLE := 0.10     ## hauteur de la cheville au-dessus de la semelle (m)

var modele: Node3D
var anim: AnimationPlayer
var _clips := {}       ## "attente" / "marche" / "course" / "saut" -> nom réel de l'animation
var _joueur: Player
var squelette: Skeleton3D
var ik: TwoBoneIK3D
var cible_avant: Marker3D      ## pied avant (droit si goofy)
var cible_arriere: Marker3D    ## pied arrière : c'est lui qui pousse
var _poids := 0.0              ## 0 = à pied, 1 = sur la planche
var _main_droite := -1
var pose: PoseProcedurale      ## postures calculées (attente debout, planche, ollie, chute…)
var etat := ""                 ## ce que fait le corps : debout, marche, planche, chute, grimpe, bombe…
var _t := 0.0


func _ready() -> void:
	_joueur = owner as Player
	if _joueur == null:
		_joueur = get_parent().get_parent() as Player
	var chemin := ProjectSettings.globalize_path(FICHIER)
	if not FileAccess.file_exists(chemin):
		return
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	if doc.append_from_file(chemin, etat) != OK:
		push_warning("TRACE : impossible de lire " + FICHIER)
		return
	modele = doc.generate_scene(etat) as Node3D
	if modele == null:
		return
	add_child(modele)
	_mettre_a_l_echelle()
	anim = _trouver_animations(modele)
	if anim:
		_ranger_clips()
	var sk := modele.find_children("*", "Skeleton3D", true, false)
	if sk.size() > 0:
		squelette = sk[0]
		_preparer_ik()
	for nom in ["Body", "Cap"]:
		var n := get_parent().get_node_or_null(nom)
		if n:
			n.visible = false


## Pose les pieds au sol et ramène le personnage à TAILLE mètres.
func _mettre_a_l_echelle() -> void:
	var boite := AABB()
	var premier := true
	for mi in modele.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := (modele.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		boite = b if premier else boite.merge(b)
		premier = false
	if premier or boite.size.y <= 0.0:
		return
	var s := TAILLE / boite.size.y
	modele.scale = Vector3.ONE * s
	modele.position = Vector3(-(boite.position.x + boite.size.x * 0.5) * s, -boite.position.y * s, -(boite.position.z + boite.size.z * 0.5) * s)
	# Le modèle de Meshy regarde vers +Z ; le joueur regarde vers -Z.
	modele.rotation.y = PI
	modele.position = modele.position.rotated(Vector3.UP, PI)


func _trouver_animations(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a := _trouver_animations(c)
		if a:
			return a
	return null


func _ranger_clips() -> void:
	var mots := {
		"attente": ["idle", "stand", "breath"],
		"marche": ["walk"],
		"course": ["running", "run", "jog", "sprint"],
		"saut": ["jump"],
	}
	for nom in anim.get_animation_list():
		var bas := String(nom).to_lower()
		for etat in mots:
			if not _clips.has(etat):
				for mot in mots[etat]:
					if mot in bas:
						_clips[etat] = nom
						break
		var a := anim.get_animation(nom)
		if a and not bas.contains("jump"):
			a.loop_mode = Animation.LOOP_LINEAR
	# Ce qui manque prend la place la plus proche.
	if not _clips.has("course") and _clips.has("marche"):
		_clips["course"] = _clips["marche"]
	if not _clips.has("marche") and _clips.has("course"):
		_clips["marche"] = _clips["course"]
	var liste := anim.get_animation_list()
	if not _clips.has("attente") and liste.size() > 0:
		_clips["attente"] = _clips.get("marche", liste[0])


## Deux jambes en cinématique inverse : les pieds vont se poser sur la planche.
func _preparer_ik() -> void:
	var planche := get_parent().get_node_or_null("Board") as Node3D
	if planche == null:
		return
	cible_avant = Marker3D.new()
	cible_arriere = Marker3D.new()
	planche.add_child(cible_avant)
	planche.add_child(cible_arriere)
	# Les genoux pointent du côté où il regarde (sa gauche = -X de la planche si goofy).
	var face := -1.0 if goofy else 1.0
	var poles: Array[Marker3D] = []
	for z in [PIED_AVANT.z, PIED_ARRIERE.z]:
		var pole := Marker3D.new()
		pole.position = Vector3(face * 0.9, 0.55, z * 1.6)
		planche.add_child(pole)
		poles.append(pole)
	ik = TwoBoneIK3D.new()
	ik.setting_count = 2
	var avant := "Right" if goofy else "Left"
	var arriere := "Left" if goofy else "Right"
	var jambes := [[avant, cible_avant, poles[0]], [arriere, cible_arriere, poles[1]]]
	squelette.add_child(ik)
	for i in 2:
		var cote: String = jambes[i][0]
		ik.set_root_bone_name(i, "mixamorig_%sUpLeg" % cote)
		ik.set_middle_bone_name(i, "mixamorig_%sLeg" % cote)
		ik.set_end_bone_name(i, "mixamorig_%sFoot" % cote)
		ik.set_target_node(i, ik.get_path_to(jambes[i][1]))
		ik.set_pole_node(i, ik.get_path_to(jambes[i][2]))
	ik.influence = 0.0
	_main_droite = squelette.find_bone("mixamorig_RightHand")
	# Les postures calculées passent avant l'IK : les pieds restent posés sur la planche.
	pose = PoseProcedurale.new()
	squelette.add_child(pose)
	squelette.move_child(pose, ik.get_index())
	squelette.skeleton_updated.connect(_apres_squelette)


## Où est le pied arrière pendant une poussée (repère de la planche).
## 0 → 0,25 : il quitte la planche et descend au sol, devant ;
## 0,25 → 0,6 : il frappe le sol et glisse vers l'arrière ;
## 0,6 → 1 : il remonte se poser sur le tail.
func _pied_qui_pousse(t: float) -> Vector3:
	var face := -1.0 if goofy else 1.0
	var sol := Vector3(face * 0.16, -0.085 + CHEVILLE, 0.0)
	var debut := sol + Vector3(0, 0, -0.05)
	var fin := sol + Vector3(0, 0, 0.55)
	if t < 0.25:
		var k := t / 0.25
		return PIED_ARRIERE.lerp(debut, k) + Vector3(0, sin(k * PI) * 0.08, 0)
	if t < 0.6:
		return debut.lerp(fin, (t - 0.25) / 0.35)
	var k2 := (t - 0.6) / 0.4
	return fin.lerp(PIED_ARRIERE, k2) + Vector3(0, sin(k2 * PI) * 0.12, 0)


func _process(delta: float) -> void:
	if modele == null or _joueur == null:
		return
	_t += delta
	_posture(delta)
	etat = _etat()
	if pose:
		_composer(delta)
	if anim == null:
		return
	var clip_etat := "attente"
	var v := Vector2(_joueur.velocity.x, _joueur.velocity.z).length()
	if etat == "marche" or etat == "course" or etat == "saut":
		clip_etat = etat
	var clip: StringName = _clips.get(clip_etat, _clips.get("attente", &""))
	if clip == &"":
		return
	if anim.current_animation != clip:
		anim.play(clip, 0.2)
	if clip_etat == "marche" or clip_etat == "course":
		anim.speed_scale = clampf(v / (6.2 if clip_etat == "course" else 3.2), 0.6, 1.4)
	else:
		anim.speed_scale = 1.0


## Ce que fait le corps en ce moment.
func _etat() -> String:
	var v := Vector2(_joueur.velocity.x, _joueur.velocity.z).length()
	if _joueur.mode == Player.Mode.SKATE:
		return "planche"
	if not _joueur.is_on_floor() and _clips.has("saut"):
		return "saut"
	if v > 4.5:
		return "course"
	if v > 0.3:
		return "marche"
	return "debout"


## Mètres → unités du squelette.
func _u(m: float) -> float:
	return m / maxf(modele.scale.x, 0.001)


## Fabrique la posture voulue selon l'état, puis y glisse en douceur.
func _composer(delta: float) -> void:
	var c := {
		"haut": 0.0, "bas": 0.0,
		"bassin": Vector3.ZERO, "bassin_rot": Vector3.ZERO,
		"buste": Vector3.ZERO, "tete": Vector3.ZERO, "souffle": 0.0,
		"bg": [Vector3(0.12, -1, 0.0), Vector3(0.08, -1, 0.32)],
		"bd": [Vector3(-0.12, -1, 0.0), Vector3(-0.08, -1, 0.32)],
		"jg": [Vector3(0.02, -1, 0.0), Vector3(0.02, -1, -0.02)],
		"jd": [Vector3(-0.02, -1, 0.0), Vector3(-0.02, -1, -0.02)],
	}
	match etat:
		"debout":
			_debout(c)
		"planche":
			_sur_planche(c)
	# Les poids passent de 0 à 1 en 0,2 s (fondu avec la marche).
	pose.poids_haut = move_toward(pose.poids_haut, c.haut, delta / 0.2)
	pose.poids_bas = move_toward(pose.poids_bas, c.bas, delta / 0.2)
	var k := 1.0 - exp(-14.0 * delta)
	pose.bassin = pose.bassin.lerp(c.bassin, k)
	pose.bassin_rot = pose.bassin_rot.lerp(c.bassin_rot, k)
	pose.buste = pose.buste.lerp(c.buste, k)
	pose.tete = pose.tete.lerp(c.tete, k)
	pose.respiration = lerpf(pose.respiration, c.souffle, k)
	for i in 2:
		pose.bras_g[i] = pose.bras_g[i].lerp(c.bg[i], k)
		pose.bras_d[i] = pose.bras_d[i].lerp(c.bd[i], k)
		pose.jambe_g[i] = pose.jambe_g[i].lerp(c.jg[i], k)
		pose.jambe_d[i] = pose.jambe_d[i].lerp(c.jd[i], k)


## Attente : debout, bras le long du corps, coudes à peine pliés, poids sur les deux pieds,
## le buste qui respire, le regard qui se promène un peu.
func _debout(c: Dictionary) -> void:
	c.haut = 1.0
	c.bas = 1.0
	c.souffle = 0.025
	c.tete = Vector3(0.04, sin(_t * 0.37) * 0.25 + sin(_t * 0.11) * 0.1, 0.0)
	c.bassin_rot = Vector3(0, 0, sin(_t * 0.5) * 0.015)
	var balance := sin(_t * 0.9) * 0.02
	c.bg = [Vector3(0.12, -1, balance), Vector3(0.08, -1, 0.32 + balance)]
	c.bd = [Vector3(-0.12, -1, -balance), Vector3(-0.08, -1, 0.32 - balance)]


## Sur la planche : le haut du corps tient l'équilibre, bras un peu écartés,
## buste tourné vers le nose, genoux pliés (le bassin descend, l'IK garde les pieds sur les vis).
func _sur_planche(c: Dictionary) -> void:
	var skate: SkateController = _joueur.skate
	var nez := -1.0 if goofy else 1.0   # côté du nose dans le repère du squelette (sa droite = -X)
	c.haut = 1.0
	c.souffle = 0.012
	var torsion := 0.42 * nez
	var penche := 0.16
	var accroupi := 0.11
	var ecart := 0.55
	var pousse := skate.push_phase >= 0.0 and not skate.in_air
	var haut_bras := -0.8     # bras plus ou moins levés
	var avant_bras := 0.05    # bras vers l'avant (+) ou l'arrière (-)
	if pousse:
		var ph := skate.push_phase
		torsion = 0.25 * nez
		penche = 0.32
		accroupi = 0.15 + sin(ph * PI) * 0.04
		ecart = 0.35
	if skate.charge >= 0.0:
		# Ollie qui se charge : on descend, le buste au-dessus des pieds, bras vers l'avant.
		var k := clampf(skate.charge / skate.charge_max, 0.0, 1.0)
		accroupi += 0.25 * k
		penche += 0.3 * k
		ecart = lerpf(ecart, 0.3, k)
		avant_bras += 0.4 * k
	if skate.grinding:
		# 50-50 : bras grands ouverts, genoux pliés, buste moins tourné.
		torsion = 0.3 * nez
		accroupi = 0.17
		penche = 0.2
		ecart = 0.95
		haut_bras = -0.35 + sin(_t * 2.1) * 0.08
	elif skate.in_air and (skate.saute or skate.air_t > 0.15):
		# En l'air : les bras montent pour l'équilibre ; les genoux sont remontés par la planche.
		accroupi = 0.05
		ecart = 0.75
		haut_bras = -0.45
	if skate.reception > 0.0 and not skate.in_air:
		# Réception : on plie pour amortir, puis on se relève.
		accroupi += 0.17 * sin(PI * (1.0 - skate.reception))
		penche += 0.1 * sin(PI * (1.0 - skate.reception))
	if skate.freine:
		# Frein : le pied arrière frotte derrière le tail, le buste recule un peu.
		penche = 0.05
		accroupi = 0.22
		torsion = 0.3 * nez
	c.buste = Vector3(penche, torsion, -skate.lean * 0.12)
	c.bassin = Vector3(0, -_u(accroupi), 0)
	c.tete = Vector3(-0.1, nez * 1.05 - torsion, 0)
	var balance := sin(_t * 1.3) * 0.05 + skate.lean * 0.25
	var yaw := Basis(Vector3.UP, torsion)
	var bas2 := haut_bras * 0.7
	c.bg = [yaw * Vector3(ecart, haut_bras, avant_bras + balance), yaw * Vector3(ecart * 0.9, bas2, avant_bras + 0.3)]
	c.bd = [yaw * Vector3(-ecart, haut_bras, avant_bras - balance), yaw * Vector3(-ecart * 0.9, bas2, avant_bras + 0.3)]


## Le squelette vient d'être posé (animations + postures + IK) : la planche suit la main.
func _apres_squelette() -> void:
	_porter_planche(_joueur != null and _joueur.mode == Player.Mode.WALK)


## Sur la planche : de profil, pieds sur les vis, genoux fléchis, penché dans les virages.
## À pied : la planche est portée à la main droite.
func _posture(delta: float) -> void:
	var skate: SkateController = _joueur.skate
	var sur_planche: bool = _joueur.mode == Player.Mode.SKATE
	_poids = move_toward(_poids, 1.0 if sur_planche else 0.0, delta / 0.25)
	if ik:
		ik.influence = _poids
	var pousse := sur_planche and skate.push_phase >= 0.0 and not skate.in_air
	# De profil sur la planche ; un peu plus de face quand il pousse.
	var profil := (PI * 0.5 if goofy else -PI * 0.5) * (0.55 if pousse else 1.0)
	rotation.y = lerp_angle(rotation.y, profil * _poids, minf(1.0, 10.0 * delta))
	rotation.z = lerpf(rotation.z, -skate.lean * 0.18 * _poids, minf(1.0, 8.0 * delta))
	# Monté sur la planche, un peu accroupi.
	position.y = lerpf(0.0, 0.03, _poids)
	if cible_avant:
		cible_avant.position = PIED_AVANT
		if pousse:
			cible_arriere.position = _pied_qui_pousse(skate.push_phase)
		elif sur_planche and skate.freine:
			cible_arriere.position = _pied_qui_freine()
		else:
			cible_arriere.position = PIED_ARRIERE
		if sur_planche and skate.in_air and skate.trick_t < 1.0 and skate.trick in ["Kickflip", "Shove-it"]:
			_pieds_en_flip(skate)


## Kickflip / shove-it : les pieds quittent la planche qui tourne sous eux, puis la rattrapent.
## Les cibles suivent la planche « à plat » (sans sa rotation), soulevées au milieu du flip.
func _pieds_en_flip(skate: SkateController) -> void:
	var planche := cible_avant.get_parent() as Node3D
	var vis := get_parent() as Node3D
	var cadre := vis.global_transform * Transform3D(Basis(), planche.position)
	var t := skate.trick_t
	var leve := sin(PI * t) * 0.24
	var face := -1.0 if goofy else 1.0
	var avant := PIED_AVANT + Vector3(0, leve, 0)
	if skate.trick == "Kickflip":
		# le pied avant glisse vers le bord et chasse la planche
		avant.x += face * 0.1 * sin(PI * minf(t * 1.6, 1.0))
	else:
		# shove-it : le pied arrière racle le tail vers l'arrière
		avant.y += 0.03
	cible_avant.global_position = cadre * avant
	cible_arriere.global_position = cadre * (PIED_ARRIERE + Vector3(0, leve * 0.9, 0))


## Frein : le pied arrière descend derrière le tail et frotte le sol.
func _pied_qui_freine() -> Vector3:
	var face := -1.0 if goofy else 1.0
	return Vector3(face * 0.06, -0.085 + CHEVILLE - 0.01, 0.46)


func _porter_planche(a_pied: bool) -> void:
	var planche := get_parent().get_node_or_null("Board") as Node3D
	if planche == null or squelette == null or _main_droite < 0:
		return
	if not a_pied:
		return
	planche.visible = true
	var main: Vector3 = (squelette.global_transform * squelette.get_bone_global_pose(_main_droite)).origin
	# Planche verticale le long de la jambe, grip contre la cuisse, tenue par le nose.
	var vis := get_parent() as Node3D
	var b := vis.global_basis
	var droite := b.x.normalized()
	var haut := b.y.normalized()
	var avant := -b.z.normalized()
	var base := Basis(avant, -droite, haut).orthonormalized()   # X planche, Y = normale du plateau, Z = long
	planche.global_transform = Transform3D(base, main - haut * 0.30 + droite * 0.05)
