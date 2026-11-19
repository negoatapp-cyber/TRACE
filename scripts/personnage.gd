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
	_posture(delta)
	if anim == null:
		return
	var etat := "attente"
	var v := Vector2(_joueur.velocity.x, _joueur.velocity.z).length()
	if _joueur.mode == Player.Mode.SKATE:
		etat = "attente"            # le haut du corps respire ; les jambes sont tenues par l'IK
	elif not _joueur.is_on_floor() and _clips.has("saut"):
		etat = "saut"
	elif v > 4.5:
		etat = "course"
	elif v > 0.3:
		etat = "marche"
	var clip: StringName = _clips.get(etat, &"")
	if clip == &"":
		return
	if anim.current_animation != clip:
		anim.play(clip, 0.2)
	if etat == "marche" or etat == "course":
		anim.speed_scale = clampf(v / (6.2 if etat == "course" else 3.2), 0.6, 1.4)
	else:
		anim.speed_scale = 1.0


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
		cible_arriere.position = _pied_qui_pousse(skate.push_phase) if pousse else PIED_ARRIERE
	_porter_planche(not sur_planche)


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
