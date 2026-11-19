extends Node3D
## Le graffiti. À pied, face à un mur, on maintient G :
##   0,8 s = un tag · 3 s = un flop · 7 s = une pièce. Plus c'est long, plus c'est gros — et plus on s'expose.
## C change de bombe (quatre à la ceinture, une couleur chacune). Chaque bombe se vide :
## un tag prend peu, une pièce beaucoup. Pour en avoir d'autres, il faut aller au
## conteneur derrière la grande barre et fouiller (F). Les murs et les bombes sont sauvegardés.
## (Le temps passé immobile face au mur servira plus tard au risque d'être vu.)

const SAUVEGARDE := "user://graffitis.json"
## Le vrai lettrage de Loums, tiré des photos de Louma (gardé en local, hors du dépôt public).
## S'il manque, on retombe sur une police simple.
const LETTRAGE := "res://assets/graffitis/"
const LARGEUR := {"tag": 0.9, "flop": 2.2, "piece": 3.8}   ## largeur sur le mur (m)
const NB_TAGS := 4
const PORTEE := 2.2
## Le tag se trace à la main (appui bref sur G). Maintenir G : flop, puis pièce.
const PALIERS := [["flop", 1.0], ["piece", 3.8]]
const APPUI_BREF := 0.35
const COULEURS := [Color(0.92, 0.15, 0.45), Color(0.12, 0.12, 0.14), Color(0.95, 0.95, 0.92), Color(0.15, 0.55, 0.95), Color(0.98, 0.82, 0.10), Color(0.25, 0.75, 0.35), Color(0.80, 0.15, 0.15), Color(0.55, 0.30, 0.80)]

@export var blaze := "LOUMS"

## Ce que coûte chaque taille, en part d'une bombe pleine.
const COUT := {"tag": 0.06, "flop": 0.25, "piece": 0.6}
const PORTEE_CONTENEUR := 3.5

var ceinture := [0, 4, 3, 1]        ## couleurs des quatre bombes (indices dans COULEURS)
var reserve := [1.0, 1.0, 1.0, 1.0]  ## peinture restante dans chaque bombe (0 → 1)
var bombe := 0                       ## bombe en main
var couleur := 0
var tenue := 0.0
var poses: Array = []       # tout ce qui est sur les murs (sauvegardé)
var compte := {"tag": 0, "flop": 0, "piece": 0}

var _joueur: Player
var _texte: Label
var _barre: ProgressBar
var _pastille: ColorRect
var _cible := {}
var _jauges: HBoxContainer
var _textures := {}
var _noeuds := {}              ## indice dans poses -> nœud dessiné
var _apercu: Node3D            ## ce que le joueur est en train de peindre
var _apercu_cle := ""
var _reprise := -1             ## indice d'une pièce inachevée qu'on reprend
const PIECE_DEBUT := 3.8       ## au-delà, on commence une pièce
const PIECE_PAS := 0.8         ## durée de chaque étape de la pièce
var _trace: TraceTag           ## tag en cours de tracé à la main
var _trace_g := {}
var _camera_trace: Camera3D
var _attendre_relache := false
var _message := ""
var _message_t := 0.0


func _ready() -> void:
	_joueur = get_node_or_null("../Player") as Player
	_interface()
	_charger()
	var aide := Aide.new()
	aide.name = "Aide"
	aide.graffiti = self
	aide.joueur = _joueur
	add_child(aide)


func _physics_process(delta: float) -> void:
	if _joueur == null:
		return
	_message_t = maxf(0.0, _message_t - delta)
	if _trace:
		_suivre_le_geste(delta)
		_texte.text = "TRACE TON TAG"
		_barre.visible = false
		return
	if _attendre_relache:
		if Input.is_action_pressed("graff"):
			_afficher(false)
			return
		_attendre_relache = false
	if Input.is_action_just_pressed("graff_color"):
		bombe = (bombe + 1) % ceinture.size()
	couleur = ceinture[bombe]
	_pastille.color = COULEURS[couleur]
	if Input.is_action_just_pressed("fouiller") and _conteneur_proche():
		_fouiller()
	_cible = _mur_devant()
	var peut := not _cible.is_empty() and _joueur.mode == Player.Mode.WALK and _joueur.is_on_floor()
	if peut and Input.is_action_just_pressed("graff"):
		_reprise = _piece_a_reprendre()
		if _reprise >= 0:
			tenue = PIECE_DEBUT + int(poses[_reprise].get("e", 0)) * PIECE_PAS + 0.01
	if peut and Input.is_action_pressed("graff") and reserve[bombe] >= COUT["tag"]:
		tenue += delta
		# On ne peut pas dépasser ce que la bombe contient encore.
		for e in PALIERS:
			if reserve[bombe] < COUT[e[0]]:
				tenue = minf(tenue, e[1] - 0.01)
				break
		if _etape() >= 5 and tenue >= PIECE_DEBUT + 5 * PIECE_PAS + 0.3:
			_poser()
	elif tenue > 0.0:
		if tenue < APPUI_BREF and peut and _reprise < 0:
			_commencer_trace()
		elif peut or not _cible.is_empty():
			_poser()
		tenue = 0.0
		_reprise = -1
	_maj_apercu()
	_afficher(peut)


## Étape de la pièce : 0 esquisse, 1 fond, 2 contour, 3 lights, 4 surcontour, 5 signature.
func _etape() -> int:
	return clampi(int((tenue - PIECE_DEBUT) / PIECE_PAS), 0, 5)


## Une pièce inachevée, à soi, sur le mur qu'on regarde : on peut la reprendre.
func _piece_a_reprendre() -> int:
	if _cible.is_empty():
		return -1
	var p: Vector3 = _cible.position
	for i in range(poses.size() - 1, -1, -1):
		var g: Dictionary = poses[i]
		if g.t == "piece" and int(g.get("e", 5)) < 5 and Vector2(g.x - p.x, g.z - p.z).length() < 2.5:
			return i
	return -1


## Montre en direct ce qu'on est en train de peindre.
func _maj_apercu() -> void:
	var type := _palier()
	var cle := ""
	if tenue > 0.0 and type != "" and not _cible.is_empty():
		cle = "%s_%d_%d" % [type, _etape() if type == "piece" else 0, couleur]
	if cle == _apercu_cle:
		return
	_apercu_cle = cle
	if _apercu:
		_apercu.queue_free()
		_apercu = null
	if cle == "":
		return
	var g := _nouveau(type)
	g["e"] = _etape()
	_apercu = _dessiner_lettrage(g)
	if _apercu:
		_placer(_apercu, g)
		add_child(_apercu)


func _palier() -> String:
	var p := ""
	for e in PALIERS:
		if tenue >= e[1]:
			p = e[0]
	return p


## Cherche un mur vertical juste devant le personnage.
func _mur_devant() -> Dictionary:
	var ry := _joueur.visual.rotation.y
	var avant := Vector3(-sin(ry), 0, -cos(ry))
	var depart := _joueur.global_position + Vector3.UP * 1.3
	var q := PhysicsRayQueryParameters3D.create(depart, depart + avant * PORTEE)
	q.exclude = [_joueur.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or absf(hit.normal.y) > 0.35:
		return {}
	if hit.normal.dot(avant) > 0.0:
		hit.normal = -hit.normal  # mur vu de dos : on peint du côté où l'on est
	return hit


## Appui bref sur G : la caméra se met face au mur, le tag de Loums apparaît en fantôme,
## et le joueur le repasse à la souris.
func _commencer_trace(variante := -1) -> void:
	tenue = 0.0
	var v := randi() % NB_TAGS if variante < 0 else variante
	var img := Image.load_from_file(ProjectSettings.globalize_path(LETTRAGE + "tag_%d.png" % (v + 1)))
	if img == null:
		return
	var g := _nouveau("tag")
	g["v"] = v
	g["a"] = 0.0
	_trace_g = g
	_trace = TraceTag.new()
	_trace.name = "TraceTag"
	add_child(_trace)
	_trace.preparer(img, COULEURS[couleur], LARGEUR.tag)
	_placer(_trace, g)
	var n := Vector3(g.nx, 0, g.nz)
	var droite := (-n).cross(Vector3.UP).normalized()
	var centre := _trace.global_position
	# Loums se met un peu à gauche du tag, face au mur, le bras vers la peinture.
	var sol := Vector3(g.x, float(g.y), g.z)
	_joueur.global_position = sol + n * 0.55 - droite * 0.38
	_joueur.velocity = Vector3.ZERO
	_joueur.visual.rotation.y = atan2(n.x, n.z)
	_joueur.set_physics_process(false)
	_joueur.set_process_unhandled_input(false)
	_camera_trace = Camera3D.new()
	_camera_trace.fov = 55.0
	add_child(_camera_trace)
	_camera_trace.global_position = centre + n * 1.45 + droite * 0.55 + Vector3.UP * 0.2
	_camera_trace.look_at(centre, Vector3.UP)
	_camera_trace.make_current()
	_trace.camera = _camera_trace
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_trace.fini.connect(_finir_trace)
	_trace.annule.connect(_sortir_trace)


## Pendant le tracé, Loums se déplace le long du mur pour garder la bombe à portée de main :
## il se tient un peu à gauche du jet, à 55 cm du mur.
func _suivre_le_geste(delta: float) -> void:
	var g := _trace_g
	var n := Vector3(g.nx, 0, g.nz)
	var droite := (-n).cross(Vector3.UP).normalized()
	var jet := point_du_jet()
	var cote := (jet - Vector3(g.x, 0, g.z)).dot(droite)
	var but := Vector3(g.x, float(g.y), g.z) + n * 0.55 + droite * (cote - 0.38)
	var pos := _joueur.global_position
	pos.x = lerpf(pos.x, but.x, minf(1.0, 4.0 * delta))
	pos.z = lerpf(pos.z, but.z, minf(1.0, 4.0 * delta))
	_joueur.global_position = pos


## Où la bombe vise en ce moment (dans le monde) : le curseur, ou le centre du tag.
func point_du_jet() -> Vector3:
	if _trace == null:
		return Vector3.ZERO
	var c := _trace.curseur
	if c.x < 0.0 or c.y < 0.0:
		return _trace.global_position
	return _trace.vers_monde(c)


func _finir_trace(img: Image, q: Dictionary) -> void:
	if q.couverture < 0.05:
		_sortir_trace()
		return
	reserve[bombe] = maxf(0.0, reserve[bombe] - COUT.tag * clampf(_trace.depose / 900.0, 0.3, 3.0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://traces"))
	var chemin := "user://traces/tag_%d_%d.png" % [Time.get_unix_time_from_system(), randi() % 100000]
	img.save_png(ProjectSettings.globalize_path(chemin))
	var g := _trace_g.duplicate()
	g["img"] = chemin
	g["q"] = snappedf(q.note, 0.01)
	poses.append(g)
	_dessiner(g, poses.size() - 1)
	_sauver()
	_message = "Tag %s   ·   %d %% du trait couvert%s" % [q.mot, int(q.couverture * 100), ("   ·   %d coulure%s" % [q.coulures, "s" if q.coulures > 1 else ""]) if q.coulures > 0 else ""]
	_message_t = 3.5
	_sortir_trace()


func _sortir_trace() -> void:
	if _trace:
		_trace.queue_free()
		_trace = null
	if _camera_trace:
		_camera_trace.clear_current(true)
		_camera_trace.queue_free()
		_camera_trace = null
	var cam := _joueur.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if cam:
		cam.make_current()
	_joueur.set_physics_process(true)
	_joueur.set_process_unhandled_input(true)
	if not TouchControls.actif:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_attendre_relache = true
	tenue = 0.0


func _nouveau(type: String) -> Dictionary:
	var n: Vector3 = _cible.normal
	n.y = 0.0
	n = n.normalized()
	var p: Vector3 = _cible.position
	if _reprise >= 0:
		return poses[_reprise].duplicate()
	return {
		"t": type, "c": couleur, "b": blaze,
		"x": p.x, "y": _joueur.global_position.y, "z": p.z,
		"nx": n.x, "nz": n.z, "a": randf_range(-0.06, 0.06) if type == "piece" else randf_range(-0.10, 0.10),
		"v": randi() % NB_TAGS,
	}


func _poser() -> void:
	var type := _palier()
	var etape := _etape()
	tenue = 0.0
	if type == "" or _cible.is_empty():
		_reprise = -1
		return
	var cout: float = COUT[type]
	if type == "piece":
		var avant := int(poses[_reprise].get("e", -1)) if _reprise >= 0 else -1
		cout = COUT.piece * float(etape - avant) / 6.0
	reserve[bombe] = maxf(0.0, reserve[bombe] - cout)
	var g := _nouveau(type)
	if type == "piece":
		g["e"] = etape
	if _reprise >= 0:
		# On reprend la pièce : on remplace l'ancienne version.
		var vieux: Node = _noeuds.get(_reprise)
		if vieux:
			vieux.queue_free()
		poses[_reprise] = g
		_dessiner(g, _reprise)
	else:
		poses.append(g)
		_dessiner(g, poses.size() - 1)
	_reprise = -1
	_sauver()


func _texture(nom: String) -> Texture2D:
	if not _textures.has(nom):
		var chemin := ProjectSettings.globalize_path(nom if nom.begins_with("user://") else LETTRAGE + nom + ".png")
		var tex: Texture2D = null
		if FileAccess.file_exists(chemin):
			var img := Image.load_from_file(chemin)
			if img:
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
		_textures[nom] = tex
	return _textures[nom]


func _calque(tex: Texture2D, largeur: float, teinte: Color, ordre: int) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.pixel_size = largeur / tex.get_width()
	sp.modulate = teinte
	sp.shaded = false
	sp.double_sided = false
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.render_priority = ordre
	sp.position = Vector3(0, 0, ordre * 0.0015)
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sp


## Le graffiti dans le style du jeu : les formes des lettres de Loums (tirées de ses photos),
## rendues en aplats avec un trait d'encre. Les couleurs viennent des bombes.
const ENCRE := Color(0.10, 0.07, 0.12)
func _dessiner_lettrage(g: Dictionary) -> Node3D:
	var c: Color = COULEURS[int(g.c) % COULEURS.size()]
	var autre: Color = COULEURS[(int(g.c) + 3) % COULEURS.size()]
	var couches := []
	# Règle du graffiti (Louma) : tag = un trait ; flop = fond, contour, surcontour ;
	# pièce = fond, contour (sombre ou clair selon le fond), lights, surcontour, puis une signature.
	var contour := ENCRE if c.get_luminance() > 0.35 else Color(0.97, 0.96, 0.92)
	var troisieme: Color = COULEURS[(int(g.c) + 5) % COULEURS.size()]
	var lumiere := Color(1, 0.99, 0.95)
	var etape: int = int(g.get("e", 99))   # étapes visibles (aperçu pendant qu'on peint)
	match g.t:
		"tag":
			couches = [[g.img if g.has("img") else "tag_%d" % (int(g.get("v", 0)) % NB_TAGS + 1), c]]
		"flop":
			couches = [["flop_surcontour", autre], ["flop_contour", contour], ["flop_fond", c], ["flop_lights", lumiere]]
		"piece":
			couches = [["piece_esquisse", Color(0.2, 0.2, 0.22, 0.8)], ["piece_surcontour2", troisieme], ["piece_surcontour", autre],
				["piece_contour", contour], ["piece_fond", c], ["piece_lights", lumiere]]
			# Ordre de peinture : esquisse, fond, contour, lights, surcontour. L'esquisse disparaît sous la peinture finie.
			var ordre := {"piece_esquisse": 0, "piece_fond": 1, "piece_contour": 2, "piece_lights": 3, "piece_surcontour": 4, "piece_surcontour2": 4}
			couches = couches.filter(func(cc): return ordre[cc[0]] <= etape and not (cc[0] == "piece_esquisse" and etape >= 2))
	var racine := Node3D.new()
	var k := 0
	for couche in couches:
		var t := _texture(couche[0])
		if t == null:
			racine.free()
			return null
		racine.add_child(_calque(t, LARGEUR[g.t], couche[1], k))
		k += 1
	if g.t == "piece" and int(g.get("e", 99)) >= 5:
		var sig := _texture("tag_4")
		if sig:
			var sp := _calque(sig, LARGEUR.piece * 0.22, ENCRE, k + 1)
			sp.position += Vector3(LARGEUR.piece * 0.42, -0.62, 0)
			racine.add_child(sp)
	return racine


func _placer(n: Node3D, g: Dictionary) -> void:
	var nn := Vector3(g.nx, 0, g.nz)
	var h: float = {"tag": 1.45, "flop": 1.55, "piece": 1.9}[g.t]
	n.transform = Transform3D(Basis.looking_at(-nn, Vector3.UP).rotated(nn, float(g.a)), Vector3(g.x, float(g.y) + h, g.z) + nn * 0.035)


func _dessiner(g: Dictionary, indice := -1) -> void:
	var n := Vector3(g.nx, 0, g.nz)
	var c: Color = COULEURS[int(g.c) % COULEURS.size()]
	var vrai := _dessiner_lettrage(g)
	if vrai:
		_placer(vrai, g)
		if indice >= 0:
			_noeuds[indice] = vrai
		vrai.name = "Graff_" + str(g.t)
		add_child(vrai, true)
		compte[g.t] = int(compte.get(g.t, 0)) + 1
		return
	var haut := 1.25
	var l := Label3D.new()
	l.text = str(g.b)
	l.modulate = c
	l.shaded = false
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	match g.t:
		"tag":
			l.font_size = 64
			l.pixel_size = 0.008
			l.outline_size = 8
			l.outline_modulate = c
		"flop":
			l.font_size = 96
			l.pixel_size = 0.011
			l.outline_size = 28
			l.outline_modulate = Color(0.08, 0.08, 0.09) if c.get_luminance() > 0.25 else Color(0.95, 0.95, 0.92)
			haut = 1.4
		"piece":
			l.font_size = 128
			l.pixel_size = 0.019
			l.outline_size = 36
			l.outline_modulate = Color(0.06, 0.06, 0.08) if c.get_luminance() > 0.25 else Color(0.95, 0.95, 0.92)
			haut = 1.9
			# Fond de couleur derrière les lettres.
			var fond := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(1.9 * str(g.b).length() + 1.2, 3.2)
			fond.mesh = qm
			var m := StandardMaterial3D.new()
			m.albedo_color = COULEURS[(int(g.c) + 3) % COULEURS.size()].lerp(Color.WHITE, 0.15)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fond.material_override = m
			fond.position = Vector3(0, 0, -0.012)
			l.add_child(fond)
	var pos := Vector3(g.x, float(g.y) + haut, g.z) + n * 0.035
	l.transform = Transform3D(Basis.looking_at(-n, Vector3.UP).rotated(n, float(g.a)), pos)
	l.name = "Graff_" + str(g.t)
	add_child(l, true)
	compte[g.t] = int(compte.get(g.t, 0)) + 1


func _conteneur_proche() -> Node3D:
	for c in get_tree().get_nodes_in_group("conteneur"):
		var n := c as Node3D
		var local := n.to_local(_joueur.global_position)
		if absf(local.x) < 1.22 + PORTEE_CONTENEUR * 0.5 and absf(local.z) < 3.03 + PORTEE_CONTENEUR * 0.5:
			return n
	return null


## Au conteneur : quatre bombes pleines, de nouvelles couleurs.
func _fouiller() -> void:
	var depart: int = (int(ceinture[0]) + 1) % COULEURS.size()
	for i in ceinture.size():
		ceinture[i] = (depart + i * 2) % COULEURS.size()
		reserve[i] = 1.0
	_joueur.skate.last_event = "Quatre bombes pleines"
	_sauver()


func _sauver() -> void:
	var f := FileAccess.open(SAUVEGARDE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"murs": poses, "ceinture": ceinture, "reserve": reserve}))


func _charger() -> void:
	if not FileAccess.file_exists(SAUVEGARDE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAUVEGARDE))
	if data is Dictionary:
		if data.get("ceinture") is Array and data.ceinture.size() == 4:
			ceinture = data.ceinture.map(func(v): return int(v))
		if data.get("reserve") is Array and data.reserve.size() == 4:
			reserve = data.reserve.map(func(v): return float(v))
		data = data.get("murs", [])
	if data is Array:
		for g in data:
			if g is Dictionary and g.has("t") and g.has("nx"):
				poses.append(g)
				_dessiner(g, poses.size() - 1)


func _interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	var boite := VBoxContainer.new()
	boite.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	boite.position = Vector2(-170, -120)
	boite.custom_minimum_size = Vector2(340, 0)
	couche.add_child(boite)
	_texte = Label.new()
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.add_theme_font_size_override("font_size", 18)
	_texte.add_theme_color_override("font_outline_color", Color.BLACK)
	_texte.add_theme_constant_override("outline_size", 4)
	boite.add_child(_texte)
	_barre = ProgressBar.new()
	_barre.max_value = PIECE_DEBUT + 5 * PIECE_PAS
	_barre.show_percentage = false
	_barre.custom_minimum_size = Vector2(340, 10)
	boite.add_child(_barre)
	_pastille = ColorRect.new()
	_pastille.color = COULEURS[couleur]
	_pastille.custom_minimum_size = Vector2(340, 6)
	boite.add_child(_pastille)
	# Les quatre bombes de la ceinture, en bas à droite.
	_jauges = HBoxContainer.new()
	_jauges.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_jauges.position = Vector2(-170, -96)
	_jauges.add_theme_constant_override("separation", 8)
	couche.add_child(_jauges)
	for i in 4:
		var fond := ColorRect.new()
		fond.color = Color(0, 0, 0, 0.5)
		fond.custom_minimum_size = Vector2(30, 70)
		var plein := ColorRect.new()
		plein.anchor_left = 0.0
		plein.anchor_right = 1.0
		plein.anchor_top = 1.0
		plein.anchor_bottom = 1.0
		fond.add_child(plein)
		_jauges.add_child(fond)


func _afficher(peut: bool) -> void:
	for i in _jauges.get_child_count():
		var fond := _jauges.get_child(i) as ColorRect
		var plein := fond.get_child(0) as ColorRect
		plein.color = COULEURS[ceinture[i]]
		plein.offset_top = -70.0 * reserve[i]
		plein.offset_bottom = 0.0
		fond.color = Color(1, 1, 1, 0.55) if i == bombe else Color(0, 0, 0, 0.5)
	_barre.visible = tenue > 0.0
	_pastille.visible = peut
	_barre.value = tenue
	if _message_t > 0.0 and tenue <= 0.0:
		_texte.text = _message
	elif tenue > 0.0:
		var p := _palier()
		var noms := {"": "…", "tag": "TAG", "flop": "FLOP", "piece": "PIÈCE"}
		var etapes := ["esquisse", "fond", "contour", "lights", "surcontour", "signature"]
		if p == "piece":
			_texte.text = "PIÈCE : %s   (relâche pour t'arrêter, reviens la finir)" % etapes[_etape()]
		else:
			_texte.text = "%s   (relâche pour poser)" % noms[p] if p != "" else "maintiens pour un flop · relâche vite pour tracer un tag"
	elif _conteneur_proche():
		_texte.text = ""
	elif peut and reserve[bombe] < COUT["tag"]:
		_texte.text = "Bombe vide   ·   C : changer   ·   conteneur derrière la grande barre"
	elif peut:
		_texte.text = ""
	else:
		_texte.text = ""
