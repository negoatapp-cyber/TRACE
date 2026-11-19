extends Node3D
## TRACE — les habitants du quartier (J2). Le lieu est réel, les habitants sont fictifs.
## Chacun a un rôle, un trajet et une façon de réagir quand il voit Loums graffer :
##   passant  : marche sur les trottoirs, s'arrête, regarde, repart ;
##   voisine  : fait ses courses autour de la barre, n'aime pas ça et le dit ;
##   gardien  : tourne autour de la barre et du parking ; s'il voit Loums peindre, il vient le faire partir ;
##   jeune    : traîne en bande au pied des immeubles ; ça l'impressionne.
## Être vu laisse une trace : chaque témoin est noté dans le graffiti (pour J3, le simulateur).

const VUE_DISTANCE := 22.0
const VUE_ANGLE := deg_to_rad(75)       ## demi-angle du regard
const GARDIEN_PORTEE := 1.8              ## à cette distance, il interrompt le graffiti
const REPLIQUES := {
	"passant": ["Hé…", "Tranquille, toi.", "Encore un…"],
	"voisine": ["Oh ! C'est pas chez toi ici !", "Je vais le dire au gardien !", "Ça va, les murs sont propres peut-être ?"],
	"gardien": ["Hé toi ! Arrête ça !", "Bouge de là !"],
	"jeune": ["Vas-y Loums !", "Ah ouais, propre !", "Fais-le en grand !"],
	"patron": ["Pas devant ma baraque, j'ai dit !", "Oh, le môme…"],
}
## Les vrais personnages (planches de Louma, 19.11), modélisés dans Meshy : assets/personnages/pnj/<nom>.glb.
## Tant qu'un .glb manque, la silhouette provisoire reste. Le crew (12 à 15) et le policier (02) sont gardés
## pour l'histoire (n°4) et la police : creer_personnage(nom) les fabrique à la demande.
const DOSSIER_PNJ := "res://assets/personnages/pnj/"
const CASTING := {
	"gardien": ["01_gardien"],
	"voisine": ["03_voisine"],
	"patron": ["04_patron_snack"],
	"jeune": ["06_jeune_couronne", "07_jeune_chaine", "08_jeune_doudoune"],
	"passant": ["05_jeune_casquette", "09_jeune_capuche", "10_jeune_kaki"],
}
const TAILLES := {"jeune": 1.68, "patron": 1.66, "voisine": 1.64}
const TENUES := {
	"passant": [Color(0.30, 0.36, 0.50), Color(0.55, 0.45, 0.35), Color(0.25, 0.25, 0.28), Color(0.62, 0.30, 0.28)],
	"voisine": [Color(0.55, 0.35, 0.55), Color(0.70, 0.55, 0.40)],
	"gardien": [Color(0.18, 0.28, 0.45)],
	"patron": [Color(0.45, 0.30, 0.20)],
	"jeune": [Color(0.15, 0.15, 0.16), Color(0.85, 0.85, 0.82), Color(0.20, 0.45, 0.30)],
}
const PEAUX := [Color(0.94, 0.78, 0.62), Color(0.78, 0.56, 0.38), Color(0.55, 0.36, 0.22), Color(0.36, 0.24, 0.16)]

var quartier: Node
var graffiti: Node
var joueur: Node3D
var habitants: Array = []
var reputation := {"jeunes": 0, "voisins": 0, "gardien": 0}   ## ce que le quartier pense de Loums (J3)
var _rng := RandomNumberGenerator.new()
var _t_vue := 0.0
var _distribue := {}            ## rôle -> combien de personnages de ce rôle déjà habillés


class Habitant extends CharacterBody3D:
	var role := "passant"
	var route: PackedVector3Array = PackedVector3Array()
	var i := 0
	var sens := 1
	var vitesse := 1.2
	var pause := 0.0
	var etat := "marche"         ## marche, regarde, va_vers, reste
	var bulle: Label3D
	var bulle_t := 0.0
	var corps: Node3D
	var anim: AnimationPlayer    ## celle du modèle Meshy, si le vrai personnage est là
	var clips := {}              ## "attente" / "marche" -> nom du clip
	var a_vu := false            ## a déjà vu le graffiti en cours
	var bloque_t := 0.0
	var _pas := 0.0

	func avant() -> Vector3:
		return -global_transform.basis.z


func _ready() -> void:
	_rng.seed = 13013
	quartier = get_node_or_null("../Quartier")
	graffiti = get_node_or_null("../Graffiti")
	joueur = get_node_or_null("../Player")
	call_deferred("_peupler")


func _routes() -> Array:
	var routes: Array = []
	var f := FileAccess.open("res://data/quartier_reel.txt", FileAccess.READ)
	if f == null:
		return routes
	var epoque: String = str(quartier.get("epoque")) if quartier else "avant"
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if not l.begins_with("R|"):
			continue
		var champs := l.split("|")
		if champs.size() < 4:
			continue
		if champs.size() > 4 and champs[4].begins_with("@") and champs[4] != "@" + epoque:
			continue
		var pts: Array = []
		for c in champs[3].split(" ", false):
			var xy := c.split(",")
			if xy.size() == 2:
				pts.append(Vector2(float(xy[0]), float(xy[1])))
		if pts.size() >= 2:
			routes.append(pts)
	return routes


## Un trottoir : la rue décalée sur un côté, avec l'altitude du terrain.
func _trottoir(pts: Array, cote: float, debut: int, nb: int) -> PackedVector3Array:
	var r := PackedVector3Array()
	for k in range(debut, mini(pts.size(), debut + nb)):
		var a: Vector2 = pts[maxi(k - 1, 0)]
		var b: Vector2 = pts[mini(k + 1, pts.size() - 1)]
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x) * cote
		var p: Vector2 = pts[k] + n * 5.0
		r.append(Vector3(p.x, _h(p.x, p.y), p.y))
	return r


func _h(x: float, z: float) -> float:
	return quartier.call("h", x, z) if quartier else 0.0


func _peupler() -> void:
	var routes := _routes()
	var centre := Vector2(20, -60)
	var proches: Array = []
	for pts in routes:
		for p in pts:
			if (p as Vector2).distance_to(centre) < 170.0:
				proches.append(pts)
				break
	# passants : sur les trottoirs des rues proches
	for k in 7:
		if proches.is_empty():
			break
		var pts: Array = proches[_rng.randi() % proches.size()]
		var debut := _rng.randi() % maxi(1, pts.size() - 1)
		var r := _trottoir(pts, 1.0 if _rng.randf() < 0.5 else -1.0, maxi(0, debut - 1), 4)
		if r.size() >= 2:
			_ajouter("passant", r, _rng.randf_range(1.0, 1.4))
	# voisines et gardien : autour de la grande barre (parking devant, terrain vague derrière)
	var tour_barre := [Vector2(-5, -150), Vector2(-40, -118), Vector2(-70, -132), Vector2(-60, -160), Vector2(-25, -175), Vector2(-5, -150)]
	var r_gardien := PackedVector3Array()
	for p in tour_barre:
		r_gardien.append(Vector3(p.x, _h(p.x, p.y), p.y))
	_ajouter("gardien", r_gardien, 1.1)
	for k in 2:
		var p0: Vector2 = tour_barre[k * 2] + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		var p1: Vector2 = tour_barre[k * 2 + 1] + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		_ajouter("voisine", PackedVector3Array([Vector3(p0.x, _h(p0.x, p0.y), p0.y), Vector3(p1.x, _h(p1.x, p1.y), p1.y)]), 0.8)
	# le patron du snack, devant sa baraque (zone « ravitaillement » de n°2)
	for z in get_tree().get_nodes_in_group("ravitaillement"):
		if str(z.get_meta("type", "")) == "peinture":
			var zp: Vector3 = (z as Node3D).global_position
			var hp := _ajouter("patron", PackedVector3Array([Vector3(zp.x + 1.2, _h(zp.x + 1.2, zp.z), zp.z)]), 0.0)
			hp.etat = "reste"
			break
	# jeunes : en bande, au pied des immeubles, près du départ
	var bande := Vector2(48, -58)
	for k in 3:
		var p := bande + Vector2(k * 1.1 - 1.1, _rng.randf_range(-0.6, 0.6))
		var h := _ajouter("jeune", PackedVector3Array([Vector3(p.x, _h(p.x, p.y), p.y)]), 0.0)
		h.etat = "reste"
		h.rotation.y = PI * 0.5 + (k - 1) * 0.6


func _ajouter(role: String, route: PackedVector3Array, vitesse: float) -> Habitant:
	var h := Habitant.new()
	h.role = role
	h.route = route
	h.vitesse = vitesse
	h.name = "Habitant_%s_%d" % [role, habitants.size()]
	h.floor_snap_length = 0.5
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	h.add_child(cs)
	var n: int = _distribue.get(role, 0)
	_distribue[role] = n + 1
	var noms: Array = CASTING.get(role, [])
	h.corps = creer_personnage(noms[n % noms.size()], float(TAILLES.get(role, 1.75))) if not noms.is_empty() else null
	if h.corps:
		h.anim = _trouver_anim(h.corps)
		h.clips = _ranger_clips(h.anim)
	else:
		h.corps = _silhouette(role)
	h.add_child(h.corps)
	h.bulle = Label3D.new()
	h.bulle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	h.bulle.position.y = 2.25
	h.bulle.font_size = 44
	h.bulle.pixel_size = 0.006
	h.bulle.outline_size = 10
	h.bulle.modulate = Color(1, 1, 0.95)
	h.bulle.outline_modulate = Color(0.08, 0.06, 0.1)
	h.bulle.no_depth_test = true
	h.bulle.visible = false
	h.add_child(h.bulle)
	h.add_to_group("habitant")
	add_child(h)
	h.global_position = route[0] + Vector3.UP * 0.1
	habitants.append(h)
	return h


## Un vrai personnage : son .glb Meshy (importé, ou lu directement), pieds au sol, tourné vers -Z,
## ramené à « taille » mètres. null si le fichier n'est pas encore là.
func creer_personnage(nom: String, taille := 1.75) -> Node3D:
	var chemin := DOSSIER_PNJ + nom + ".glb"
	var m: Node3D = null
	if ResourceLoader.exists(chemin):
		var ps := load(chemin) as PackedScene
		if ps:
			m = ps.instantiate() as Node3D
	if m == null:
		var brut := ProjectSettings.globalize_path(chemin)
		if not FileAccess.file_exists(brut):
			return null
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(brut, st) != OK:
			return null
		m = doc.generate_scene(st) as Node3D
	if m == null:
		return null
	var racine := Node3D.new()
	racine.name = "Corps_" + nom
	racine.add_child(m)
	var boite := AABB()
	var premier := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var b := (m.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		boite = b if premier else boite.merge(b)
		premier = false
	if not premier and boite.size.y > 0.0:
		var s := taille / boite.size.y
		m.scale = Vector3.ONE * s
		m.position = Vector3(-(boite.position.x + boite.size.x * 0.5) * s, -boite.position.y * s, -(boite.position.z + boite.size.z * 0.5) * s)
	racine.rotation.y = PI       # les modèles Meshy regardent vers +Z, les habitants avancent vers -Z
	return racine


func _trouver_anim(n: Node) -> AnimationPlayer:
	var l := n.find_children("*", "AnimationPlayer", true, false)
	return l[0] as AnimationPlayer if not l.is_empty() else null


func _ranger_clips(ap: AnimationPlayer) -> Dictionary:
	var c := {}
	if ap == null:
		return c
	for nom in ap.get_animation_list():
		var b := String(nom).to_lower()
		if not c.has("marche") and (b.contains("walk") or b.contains("marche")):
			c["marche"] = nom
		elif not c.has("attente") and (b.contains("idle") or b.contains("attente") or b.contains("stand") or b.contains("breath")):
			c["attente"] = nom
	for k in ["marche", "attente"]:
		if c.has(k):
			var a := ap.get_animation(c[k])
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
	return c


## Une silhouette simple, dans les aplats du rendu BD : corps, tête, jambes.
func _silhouette(role: String) -> Node3D:
	var racine := Node3D.new()
	var tenue: Color = TENUES[role][_rng.randi() % TENUES[role].size()]
	var peau: Color = PEAUX[_rng.randi() % PEAUX.size()]
	var taille := _rng.randf_range(0.92, 1.06) * (0.93 if role == "jeune" else 1.0)
	var piece := func(mesh: Mesh, c: Color, pos: Vector3) -> void:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		m.material_override = mat
		m.position = pos
		racine.add_child(m)
	var buste := CapsuleMesh.new()
	buste.radius = 0.24
	buste.height = 0.8
	piece.call(buste, tenue, Vector3(0, 1.15, 0))
	var jambes := BoxMesh.new()
	jambes.size = Vector3(0.36, 0.8, 0.2)
	piece.call(jambes, tenue.darkened(0.35), Vector3(0, 0.42, 0))
	var tete := SphereMesh.new()
	tete.radius = 0.14
	tete.height = 0.3
	piece.call(tete, peau, Vector3(0, 1.66, 0))
	if role == "gardien":
		var casquette := CylinderMesh.new()
		casquette.top_radius = 0.15
		casquette.bottom_radius = 0.16
		casquette.height = 0.07
		piece.call(casquette, Color(0.12, 0.16, 0.28), Vector3(0, 1.79, 0))
	racine.scale = Vector3.ONE * taille
	return racine


func _physics_process(delta: float) -> void:
	if joueur == null:
		return
	var g := 9.8
	for h: Habitant in habitants:
		if not h.is_on_floor():
			h.velocity.y -= g * delta
		else:
			h.velocity.y = 0.0
		var cible := Vector3.ZERO
		var v := 0.0
		match h.etat:
			"marche":
				if h.pause > 0.0:
					h.pause -= delta
				elif h.route.size() >= 2:
					cible = h.route[h.i]
					v = h.vitesse
					if Vector2(cible.x - h.global_position.x, cible.z - h.global_position.z).length() < 0.8:
						h.i += h.sens
						if h.i >= h.route.size() or h.i < 0:
							h.sens = -h.sens
							h.i = clampi(h.i + 2 * h.sens, 0, h.route.size() - 1)
							h.pause = _rng.randf_range(1.0, 4.0)
			"regarde":
				h.pause -= delta
				_tourner_vers(h, joueur.global_position, delta)
				if h.pause <= 0.0:
					h.etat = "marche"
			"va_vers":
				cible = joueur.global_position
				v = 2.3
				h.pause -= delta
				if h.pause <= 0.0 or graffiti == null or graffiti.get("_trace") == null:
					h.etat = "marche"
			"reste":
				_tourner_vers(h, joueur.global_position, delta * 0.3)
		if v > 0.0:
			var d := cible - h.global_position
			d.y = 0.0
			if d.length() > 0.05:
				d = d.normalized()
				h.velocity.x = d.x * v
				h.velocity.z = d.z * v
				_tourner_vers(h, h.global_position + d, delta * 2.0)
		else:
			h.velocity.x = move_toward(h.velocity.x, 0.0, 6.0 * delta)
			h.velocity.z = move_toward(h.velocity.z, 0.0, 6.0 * delta)
		h.move_and_slide()
		# coincé contre un mur : il fait demi-tour
		if v > 0.0 and Vector2(h.get_real_velocity().x, h.get_real_velocity().z).length() < 0.2:
			h.bloque_t += delta
			if h.bloque_t > 1.5 and h.etat == "marche":
				h.sens = -h.sens
				h.i = clampi(h.i + h.sens, 0, maxi(h.route.size() - 1, 0))
				h.bloque_t = 0.0
		else:
			h.bloque_t = 0.0
		# la démarche : un léger balancement
		var vit := Vector2(h.velocity.x, h.velocity.z).length()
		if h.anim:
			var clip: String = h.clips.get("marche" if vit > 0.3 else "attente", "")
			if clip != "" and h.anim.current_animation != clip:
				h.anim.play(clip, 0.25)
			elif clip == "" and h.anim.is_playing():
				h.anim.stop()   # pas de clip d'attente : il reste debout, immobile
			if vit > 0.3:
				h.anim.speed_scale = clampf(vit / 1.2, 0.6, 1.6)
		else:
			h._pas += vit * delta * 4.0
			h.corps.position.y = absf(sin(h._pas)) * 0.04
			h.corps.rotation.z = sin(h._pas) * 0.04
		if h.bulle_t > 0.0:
			h.bulle_t -= delta
			if h.bulle_t <= 0.0:
				h.bulle.visible = false
		# le gardien arrive au contact : il fait partir Loums
		if h.role == "gardien" and h.etat == "va_vers" and graffiti and graffiti.get("_trace") != null \
				and h.global_position.distance_to(joueur.global_position) < GARDIEN_PORTEE:
			_dire(h, "Allez, dégage !")
			graffiti.call("chasse_par", "le gardien")
			reputation.gardien -= 1
			h.etat = "regarde"
			h.pause = 3.0
	_t_vue -= delta
	if _t_vue <= 0.0:
		_t_vue = 0.2
		_regards()


func _tourner_vers(h: Habitant, p: Vector3, k: float) -> void:
	var d := p - h.global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	var vise := atan2(-d.x, -d.z)
	h.rotation.y = lerp_angle(h.rotation.y, vise, clampf(k * 4.0, 0.0, 1.0))


## Qui voit Loums en train de peindre ? (distance, champ de vision, rien entre eux)
func _regards() -> void:
	var peint: bool = graffiti != null and graffiti.get("_trace") != null
	if not peint:
		for h: Habitant in habitants:
			h.a_vu = false
		return
	var sp := get_world_3d().direct_space_state
	var cible := joueur.global_position + Vector3.UP * 1.3
	for h: Habitant in habitants:
		if h.a_vu:
			continue
		var oeil := h.global_position + Vector3.UP * 1.6
		var vers := cible - oeil
		if vers.length() > VUE_DISTANCE:
			continue
		var plat := Vector3(vers.x, 0, vers.z).normalized()
		if h.etat != "reste" and h.avant().angle_to(plat) > VUE_ANGLE:
			continue
		var q := PhysicsRayQueryParameters3D.create(oeil, cible)
		q.exclude = [h.get_rid(), (joueur as CollisionObject3D).get_rid()]
		if not sp.intersect_ray(q).is_empty():
			continue
		h.a_vu = true
		_reagir(h)


func _reagir(h: Habitant) -> void:
	_dire(h, REPLIQUES[h.role][_rng.randi() % REPLIQUES[h.role].size()])
	if graffiti:
		graffiti.call("vu_par", h.role)
	match h.role:
		"gardien":
			h.etat = "va_vers"
			h.pause = 12.0
			reputation.gardien -= 1
		"voisine":
			h.etat = "regarde"
			h.pause = 2.5
			reputation.voisins -= 1
		"jeune":
			reputation.jeunes += 1
		_:
			h.etat = "regarde"
			h.pause = _rng.randf_range(2.0, 4.0)


func _dire(h: Habitant, texte: String) -> void:
	h.bulle.text = texte
	h.bulle.visible = true
	h.bulle_t = 3.0
