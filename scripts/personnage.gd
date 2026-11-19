extends Node3D
## Le corps de Loums. Au lancement, charge le modèle 3D s'il est présent
## (assets/personnages/loums.glb, exporté de Meshy avec squelette et animations)
## et remplace la capsule orange. Sans fichier, la capsule reste : le jeu marche toujours.
##
## Le fichier est lu directement au lancement (pas besoin de l'ouvrir dans l'éditeur).
## Les animations sont reconnues à leur nom : idle / walk / run / jump.

const FICHIER := "res://assets/personnages/loums.glb"
const TAILLE := 1.75   ## hauteur voulue du personnage (m)

var modele: Node3D
var anim: AnimationPlayer
var _clips := {}       ## "attente" / "marche" / "course" / "saut" -> nom réel de l'animation
var _joueur: Player


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


func _process(_delta: float) -> void:
	if anim == null or _joueur == null:
		return
	var etat := "attente"
	var v := Vector2(_joueur.velocity.x, _joueur.velocity.z).length()
	if _joueur.mode == Player.Mode.SKATE:
		etat = "attente"            # debout sur la planche, en attendant une vraie pose de skate
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
