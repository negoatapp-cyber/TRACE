extends Node3D
## TRACE — les bâtiments de la grande carte refaits comme la rue pilote (conversation décor, 20.11.2026).
## Chaque bâtiment du relevé est remplacé, À L'ŒIL SEULEMENT, par son modèle peint
## (assets/decor/carte/bat_<n>.glb, fabriqué par assets/decor/source/quartier/generer_quartier.py) :
## même emprise, même hauteur, donc la collision du relevé, les prises de grimpe, les toits accessibles et
## les tags restent exactement là où le jeu les attend. Lumière « décor peint » de la rue pilote.

const Q := preload("res://scripts/quartier_reel.gd")
const PEINT := preload("res://shaders/decor_peint.gdshader")
const AJOURE := preload("res://shaders/decor_peint_ajoure.gdshader")
const DONNEES := "res://data/batiments_peints.json"
const MODELE := "res://assets/decor/carte/bat_%s.glb"

var habillage: Node3D
var _mats := {}


## Noms des bâtiments qui ont un modèle peint pour l'époque en cours (pour habillage_facades.gd).
static func noms_peints() -> Dictionary:
	var noms := {}
	if not FileAccess.file_exists(DONNEES):
		return noms
	var d = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if typeof(d) != TYPE_DICTIONARY:
		return noms
	for id in d:
		var e: Dictionary = d[id]
		if e["epoque"] != "" and e["epoque"] != Q.epoque:
			continue
		if ResourceLoader.exists(MODELE % id):
			noms[e["nom"]] = e.get("collision", true)
	return noms


func construire(quartier: Node) -> void:
	if not FileAccess.file_exists(DONNEES):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	var n := 0
	for id in d:
		var e: Dictionary = d[id]
		if e["epoque"] != "" and e["epoque"] != Q.epoque:
			continue
		var chemin: String = MODELE % id
		if not ResourceLoader.exists(chemin):
			continue
		var centre := Vector2(e["centre"][0], e["centre"][1])
		var releve := _trouver(quartier, String(e["nom"]), centre)
		if releve == null:
			push_warning("Carte peinte : pas trouvé « %s » dans le relevé" % e["nom"])
			continue
		# le volume du relevé reste pour la collision ; on n'en cache que l'image
		for mi in releve.find_children("*", "GeometryInstance3D", true, false):
			(mi as GeometryInstance3D).visible = false
		if releve is GeometryInstance3D:
			(releve as GeometryInstance3D).visible = false
		var m: Node3D = (load(chemin) as PackedScene).instantiate()
		m.name = "Peint_" + String(e["nom"]).validate_node_name()
		add_child(m)
		_peindre(m)
		if e.get("collision", "") == "modele":
			_collision_modele(releve, m, String(e["nom"]), centre, e.get("gouttieres", []))
		else:
			_collision_details(m)
		n += 1
	print("Carte peinte : %d bâtiments" % n)
	_recaler_gouttieres.call_deferred()


func _trouver(quartier: Node, nom: String, centre: Vector2) -> Node3D:
	var meilleur: Node3D = null
	var dmin := 40.0   # (le centre de la boîte englobante d'une barre courbe s'écarte de celui du contour)
	for b in quartier.get_tree().get_nodes_in_group("batiment"):
		if not String(b.name).begins_with(nom.validate_node_name().left(6)):
			continue
		var c := Vector2.ZERO
		var mis: Array = (b as Node).find_children("*", "MeshInstance3D", true, false)
		if mis.is_empty():
			continue
		var bb: AABB = (mis[0] as MeshInstance3D).global_transform * (mis[0] as MeshInstance3D).get_aabb()
		c = Vector2(bb.get_center().x, bb.get_center().z)
		var dist := c.distance_to(centre)
		if dist < dmin:
			dmin = dist
			meilleur = b
	return meilleur


## Même lumière « décor peint » que la rue pilote (rue_paix.gd).
func _peindre(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var std := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if std == null:
				continue
			if not _mats.has(std):
				var ajoure := std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				var t := ShaderMaterial.new()
				t.shader = AJOURE if ajoure else PEINT
				t.set_shader_parameter("couleur", std.albedo_color)
				if std.albedo_texture:
					t.set_shader_parameter("texture_couleur", std.albedo_texture)
					t.set_shader_parameter("avec_texture", true)
				var nom := String(std.resource_name)
				var sombre := 0.78
				for cle in ["tableau", "corniche", "souche", "orange", "zinc", "metal", "toit"]:
					if nom.begins_with(cle):
						sombre = 0.62
				t.set_shader_parameter("face_detournee", sombre)
				# (n°2) métal peint : reflet du soleil et du ciel
				for cle in ["metal", "main_courante", "persienne", "zinc", "kiosque", "limon", "grille", "porte_metal"]:
					if nom.begins_with(cle):
						t.set_shader_parameter("brillance", 0.6)
						t.set_shader_parameter("metal", 0.45)
				_mats[std] = t
			mi.set_surface_override_material(s, _mats[std])
	for e in n.get_children():
		_peindre(e)


## Bâtiment dont la volumétrie s'écarte de la boîte du relevé (Tour Cyprès B : lames décalées, noyau en
## retrait) : on coupe la collision et les prises du relevé, la collision vient du modèle peint lui-même
## (nez de dalle en relief = prises), et les descentes d'eau grimpables viennent de batiments_peints.json.
func _collision_modele(releve: Node, m: Node3D, nom: String, centre: Vector2, gouttieres: Array) -> void:
	for cs in releve.find_children("*", "CollisionShape3D", true, false):
		(cs as CollisionShape3D).disabled = true
	if releve is CollisionObject3D:
		(releve as CollisionObject3D).collision_layer = 0
	var cle := nom.validate_node_name()
	for nd in get_tree().root.find_children("*", "", true, false):
		var nn := String(nd.name)
		if nn == "Prises_" + cle or nn == "Peau_" + cle:
			nd.queue_free()
	for g in get_tree().get_nodes_in_group("gouttiere"):
		var p: Vector3 = (g as Node3D).global_position
		if Vector2(p.x, p.z).distance_to(centre) < 20.0 and not (g in get_children()):
			g.remove_from_group("gouttiere")
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).ends_with("_metal"):
			continue   # antenne, garde-corps fins : pas de collision (ils barraient l'arrivée sur le toit)
		var corps := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		corps.add_child(cs)
		mi.add_child(corps)
	for g in gouttieres:
		var mk := Marker3D.new()
		mk.position = Vector3(g[0], g[1], g[2])
		mk.set_meta("haut", float(g[3]))
		mk.set_meta("dehors", Vector3(g[4], 0, g[5]))
		mk.add_to_group("gouttiere")
		add_child(mk)


## Les détails en relief qui sortent de la boîte du relevé (escaliers des porches, limons, bandeau du
## soubassement de la Grande barre) reçoivent leur propre collision : on y marche, on s'y accroche, on y ride.
func _collision_details(m: Node3D) -> void:
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if not (nm.ends_with("_marche") or nm.ends_with("_limon") or nm.ends_with("_rebord")):
			continue
		var corps := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		corps.add_child(cs)
		mi.add_child(corps)


## Louma : « il faut qu'on puisse monter sur tous les toits ». En haut d'une gouttière, Loums passe
## sur le toit 0,9 m à l'intérieur, à la cote « haut » de la gouttière. Quand cette cote ne tombe pas
## juste (acrotère, toit du modèle peint, relevé décalé), il reste bloqué en haut. On mesure donc le
## vrai dessus du toit à cet endroit, une fois la physique prête, et on recale « haut ».
func _recaler_gouttieres() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var espace := get_world_3d().direct_space_state
	var joueur := get_tree().get_first_node_in_group("player")
	var n := 0
	var retirees := 0
	for g in get_tree().get_nodes_in_group("gouttiere"):
		var m := g as Node3D
		var haut: float = m.get_meta("haut", 0.0)
		if haut - m.global_position.y < 2.5:
			continue
		var dehors: Vector3 = m.get_meta("dehors", Vector3.FORWARD)
		# 1. le vrai dessus, 0,9 m à l'intérieur (toutes les couches de collision : prises comprises)
		var s := m.global_position - dehors * 0.9
		var q := PhysicsRayQueryParameters3D.create(Vector3(s.x, haut + 4.0, s.z), Vector3(s.x, haut - 4.0, s.z), 0xFFFFFFFF)
		var hit := espace.intersect_ray(q)
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.6:
			var y: float = (hit.position as Vector3).y
			if absf(y - haut) > 0.04:
				m.set_meta("haut", y)
				haut = y
				n += 1
		if joueur == null or not joueur.has_method("hisse_libre"):
			continue
		# 2. une corniche ou un balcon en surplomb au sommet : on écarte la descente d'eau du mur
		for k in 16:
			var depart := m.global_position + dehors * 0.32 + Vector3.UP * (haut - m.global_position.y - 1.45 + 0.02)
			if joueur.place_libre(depart) and joueur.place_libre(depart + Vector3.UP * 0.4):
				break
			m.global_position += dehors * 0.1
		# 3. dernier contrôle, avec le geste du jeu : sinon la gouttière n'est plus proposée (jamais bloqué en haut)
		var haut_pieds := m.global_position + dehors * 0.32
		haut_pieds.y = haut - 1.45
		var sommet := Vector3(m.global_position.x, haut + 0.05, m.global_position.z) - dehors * 0.9
		if joueur.hisse_libre(haut_pieds, sommet) < 0.0:
			m.remove_from_group("gouttiere")
			retirees += 1
			print("  gouttière retirée %s (%.0f, %.0f) toit %.1f" % [m.get_parent().name, m.global_position.x, m.global_position.z, haut])
	print("Gouttières : %d recalées sur le vrai toit, %d sans arrivée possible retirées" % [n, retirees])
