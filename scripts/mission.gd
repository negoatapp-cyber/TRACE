extends CanvasLayer
## TRACE — le moteur des missions (conversation n°4, histoire). Autoload « Mission ».
##
## Mission 1, « Premier mur » : snack (peinture) -> un mur au choix -> retour au snack.
## Ce fichier ne modifie AUCUN fichier des autres conversations : il observe le jeu (le graffiti,
## le temps, les zones du décor) et dessine sa propre interface (objectif + dialogues, en haut à droite).
##
## Ce qu'il lit :
##   - groupe « ravitaillement » (Area3D, meta type = "peinture") posé par n°2 au snack ;
##   - groupe « conteneur » (terrain vague, derrière la barre) pour reconnaître un tag « discret » ;
##   - graffiti.poses (les murs peints), graffiti._trace (un tracé est en cours), le champ « temoins » de chaque pose ;
##   - quartier.h(x, z) pour savoir si Loums peignait en hauteur (un toit) ;
##   - temps.jour() / temps.heure() pour dater la trace.
## Ce qu'il émet : signal etape_changee(etape) (pour le son, n°3) et mission_terminee(trace) (pour le simulateur, J3).
## Au snack, le ravitaillement est automatique (pas de bouton : marche aussi au toucher).
## F9 remet la mission à zéro (test).

signal etape_changee(etape: String)
signal mission_terminee(trace: Dictionary)

const HISTOIRE := preload("res://histoire/mission_01.gd")
const SAUVEGARDE := "user://mission.json"
const DELAI_DEPART := 3.0          ## secondes avant l'intro, une fois le jeu lancé
const RAYON_SNACK := 5.0           ## distance (m) à laquelle on est « au snack »
const ATTENTE_SNACK := 0.5         ## secondes à rester près du snack
const ATTENTE_TAG := 1.5           ## secondes après la fin du tag avant de conclure l'étape
const HAUTEUR_TOIT := 3.0          ## Loums est « en hauteur » s'il peint à plus de 3 m au-dessus du sol (à régler)
const RAYON_TERRAIN_VAGUE := 30.0  ## près d'un conteneur : le terrain vague, discret (à régler)
const RAYON_BOULEVARD := 45.0      ## près du snack : le boulevard, visible (à régler)
const ENCRE := Color(0.10, 0.07, 0.12)
const PAPIER := Color(0.97, 0.94, 0.86)
const JAUNE := Color(0.98, 0.82, 0.10)

var etat := "attente"              ## attente, peinture, mur, retour, fini
var trace := {}                    ## ce que la mission a laissé : lieu, type, témoins, jour (pour J3)

var _base := 0                     ## nombre de murs peints quand la peinture a été prise
var _joueur: Node3D
var _graffiti: Node
var _quartier: Node
var _temps: Node
var _t := 0.0
var _t_snack := 0.0
var _t_tag := 0.0
var _t_fini := 0.0
var _file: Array = []
var _t_ligne := 0.0
var _boite_objectif: PanelContainer
var _boite_dialogue: PanelContainer
var _objectif: Label
var _nom: Label
var _texte: Label
var _f9 := false

## La carte (en bas à droite) : plan des rues et des bâtiments, Loums au centre, l'objectif en magenta.
const CARTE_TAILLE := 150.0        ## côté de la carte (px)
const CARTE_PORTEE := 90.0         ## rayon visible autour de Loums (m)
const CARTE_PX_PAR_M := 0.8        ## finesse du fond de plan
const COULEUR_ROUTE := Color(0.78, 0.76, 0.84)
const COULEUR_BATI := Color(0.32, 0.27, 0.42)
const MAGENTA := Color(0.92, 0.15, 0.45)
var _carte: Control
var _fond: ImageTexture
var _fond_x0 := 0.0
var _fond_z0 := 0.0
var _fond_ppm := CARTE_PX_PAR_M
var _fond_essaye := false


func _ready() -> void:
	layer = 6
	_interface()
	_charger()


func _process(delta: float) -> void:
	_test_reset()
	_eviter_boutons_tactiles()
	_vivre_dialogue(delta)
	if not _scene_prete():
		_boite_objectif.visible = false
		_carte.visible = false
		return
	_vivre_carte()
	match etat:
		"attente":
			_t += delta
			if _t >= DELAI_DEPART:
				_dire(HISTOIRE.INTRO)
				_changer("peinture")
		"peinture":
			var d := _distance_snack()
			_afficher_objectif(HISTOIRE.OBJECTIF["peinture"] + "  ·  %d m" % int(d))
			_t_snack = _t_snack + delta if d < RAYON_SNACK else 0.0
			if _t_snack >= ATTENTE_SNACK:
				_au_snack()
		"mur":
			_afficher_objectif(HISTOIRE.OBJECTIF["mur"])
			var poses: Array = _graffiti.get("poses")
			if poses.size() > _base and _graffiti.get("_trace") == null:
				_t_tag += delta
				if _t_tag >= ATTENTE_TAG:
					_evaluer()
			else:
				_t_tag = 0.0
		"retour":
			var d2 := _distance_snack()
			_afficher_objectif(HISTOIRE.OBJECTIF["retour"] + "  ·  %d m" % int(d2))
			_t_snack = _t_snack + delta if d2 < RAYON_SNACK else 0.0
			if _t_snack >= ATTENTE_SNACK:
				_conclure()
		"fini":
			_t_fini += delta
			_afficher_objectif("✓  " + HISTOIRE.OBJECTIF["fini"])
			if _t_fini > 8.0:
				_boite_objectif.visible = false


# ───────────────────────── les étapes ─────────────────────────

func _au_snack() -> void:
	if _graffiti.has_method("_fouiller"):
		_graffiti.call("_fouiller")      # quatre bombes pleines (la fonction existe déjà côté graffiti)
	_base = (_graffiti.get("poses") as Array).size()
	_t_snack = 0.0
	_dire(HISTOIRE.ARRIVEE)
	_changer("mur")


## Le tag est posé : on regarde où, et qui a vu.
func _evaluer() -> void:
	var poses: Array = _graffiti.get("poses")
	var g: Dictionary = poses[poses.size() - 1]
	var temoins: Array = g.get("temoins", [])
	var qui := _qui(temoins)
	trace = {
		"mission": "01",
		"type": str(g.get("t", "tag")),
		"spot": _spot(g),
		"temoins": temoins.duplicate(),
		"vu_par": qui,
		"jour": int(g.get("jour", 0)),
		"heure": float(_temps.call("heure")) if _temps and _temps.has_method("heure") else 0.0,
	}
	_t_snack = 0.0
	_dire(HISTOIRE.apres_tag(qui))
	_changer("retour")


func _conclure() -> void:
	_dire(HISTOIRE.retour(str(trace.get("spot", "ailleurs")), str(trace.get("vu_par", "personne"))))
	_t_fini = 0.0
	_changer("fini")
	mission_terminee.emit(trace)


# ───────────────────────── lire le monde ─────────────────────────

func _scene_prete() -> bool:
	var s := get_tree().current_scene
	if s == null or s.name != "Lauriers":
		return false
	if _joueur == null or not is_instance_valid(_joueur):
		_joueur = get_tree().get_first_node_in_group("player") as Node3D
	if _graffiti == null or not is_instance_valid(_graffiti):
		_graffiti = s.get_node_or_null("Graffiti")
	if _quartier == null or not is_instance_valid(_quartier):
		_quartier = s.get_node_or_null("Quartier")
	if _temps == null or not is_instance_valid(_temps):
		_temps = s.get_node_or_null("Temps")
	return _joueur != null and _graffiti != null and _snack() != null


func _snack() -> Node3D:
	for n in get_tree().get_nodes_in_group("ravitaillement"):
		if str(n.get_meta("type", "")) == "peinture" and n is Node3D:
			return n as Node3D
	return null


func _distance_snack() -> float:
	var s := _snack()
	return _joueur.global_position.distance_to(s.global_position) if s else 9999.0


func _plat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Où Loums a peint : en hauteur, sur le terrain vague (discret), sur le boulevard (visible), ailleurs.
func _spot(g: Dictionary) -> String:
	var p := Vector3(float(g.get("x", 0.0)), float(g.get("y", 0.0)), float(g.get("z", 0.0)))
	var sol := float(_quartier.call("h", p.x, p.z)) if _quartier and _quartier.has_method("h") else p.y
	if p.y - sol > HAUTEUR_TOIT:
		return "haut"
	for c in get_tree().get_nodes_in_group("conteneur"):
		if c is Node3D and _plat(p, (c as Node3D).global_position) < RAYON_TERRAIN_VAGUE:
			return "terrain_vague"
	var s := _snack()
	if s and _plat(p, s.global_position) < RAYON_BOULEVARD:
		return "boulevard"
	return "ailleurs"


## Le témoin qui compte le plus : le gardien, puis la voisine, les jeunes, un passant, personne.
func _qui(temoins: Array) -> String:
	for r in ["gardien", "voisine", "jeune", "passant"]:
		if temoins.has(r):
			return r
	return "personne"


# ───────────────────────── sauvegarde ─────────────────────────

func _changer(e: String) -> void:
	etat = e
	_sauver()
	etape_changee.emit(e)


func _sauver() -> void:
	var f := FileAccess.open(SAUVEGARDE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"etat": etat, "base": _base, "trace": trace}))


func _charger() -> void:
	if not FileAccess.file_exists(SAUVEGARDE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAUVEGARDE))
	if data is Dictionary:
		var e := str(data.get("etat", "attente"))
		if ["attente", "peinture", "mur", "retour", "fini"].has(e):
			etat = e
		_base = int(data.get("base", 0))
		if data.get("trace") is Dictionary:
			trace = data.trace


## F9 : recommencer la mission (pour les tests).
func _test_reset() -> void:
	var appui := Input.is_key_pressed(KEY_F9)
	if appui and not _f9:
		etat = "attente"
		trace = {}
		_base = 0
		_t = 0.0
		_t_snack = 0.0
		_t_tag = 0.0
		_file.clear()
		_sauver()
	_f9 = appui


# ───────────────────────── l'interface ─────────────────────────

func _dire(lignes: Array) -> void:
	for l in lignes:
		_file.append(l)


func _vivre_dialogue(delta: float) -> void:
	if _t_ligne > 0.0:
		_t_ligne -= delta
	if _t_ligne <= 0.0:
		if _file.is_empty():
			_boite_dialogue.visible = false
		else:
			var e: Array = _file.pop_front()
			_nom.text = str(e[0]).to_upper()
			_nom.visible = str(e[0]) != ""
			_texte.text = str(e[1])
			_boite_dialogue.visible = true
			_t_ligne = 2.4 + 0.05 * _texte.text.length()


func _afficher_objectif(t: String) -> void:
	_boite_objectif.visible = true
	if _objectif.text != t:
		_objectif.text = t


func _interface() -> void:
	_boite_objectif = _panneau(8.0)
	_objectif = Label.new()
	_objectif.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objectif.custom_minimum_size.x = 340.0
	_objectif.add_theme_font_size_override("font_size", 15)
	_objectif.add_theme_color_override("font_color", ENCRE)
	_boite_objectif.add_child(_objectif)
	_boite_objectif.visible = false
	add_child(_boite_objectif)

	_boite_dialogue = _panneau(96.0)
	var v := VBoxContainer.new()
	_nom = Label.new()
	_nom.add_theme_font_size_override("font_size", 13)
	_nom.add_theme_color_override("font_color", Color(0.55, 0.20, 0.45))
	v.add_child(_nom)
	_texte = Label.new()
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.custom_minimum_size.x = 340.0
	_texte.add_theme_font_size_override("font_size", 16)
	_texte.add_theme_color_override("font_color", ENCRE)
	v.add_child(_texte)
	_boite_dialogue.add_child(v)
	_boite_dialogue.visible = false
	add_child(_boite_dialogue)

	# La carte : en bas à droite, au-dessus des jauges de bombes.
	_carte = Control.new()
	_carte.anchor_left = 1.0
	_carte.anchor_right = 1.0
	_carte.anchor_top = 1.0
	_carte.anchor_bottom = 1.0
	_carte.offset_left = -(CARTE_TAILLE + 12.0)
	_carte.offset_right = -12.0
	_carte.offset_top = -(CARTE_TAILLE + 112.0)
	_carte.offset_bottom = -112.0
	_carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carte.clip_contents = true
	_carte.visible = false
	_carte.draw.connect(_dessiner_carte)
	add_child(_carte)


## Sur téléphone, les boutons DEMAIN / DÉPART occupent le coin haut droit : on décale les cartes à leur gauche.
## (ajout n°1, intégration)
func _eviter_boutons_tactiles() -> void:
	var tc := get_node_or_null("/root/TouchControls")
	var d := -200.0 if tc != null and bool(tc.get("actif")) else 0.0
	for b in [_boite_objectif, _boite_dialogue]:
		if b:
			b.offset_left = -372.0 + d
			b.offset_right = -12.0 + d


## Une petite carte de papier cernée d'encre, comme le reste du jeu, en haut à droite.
func _panneau(haut: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -372.0
	p.offset_right = -12.0
	p.offset_top = haut
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPIER
	sb.border_color = ENCRE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	return p


# ───────────────────────── la carte ─────────────────────────

func _vivre_carte() -> void:
	if not _fond_essaye:
		_fond_essaye = true
		_baker_fond()
	_carte.visible = _fond != null and _graffiti.get("_trace") == null   # masquée pendant qu'on trace
	if _carte.visible:
		_carte.queue_redraw()


## Le fond de plan est dessiné une seule fois, à partir des toits (bâtiments) et des sols de voie du décor.
func _baker_fond() -> void:
	var bat := _triangles("batiment")
	if bat.is_empty():
		return
	var routes := _triangles("sol_voie")
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in bat:
		mn = mn.min(p)
		mx = mx.max(p)
	mn -= Vector2(40.0, 40.0)
	mx += Vector2(40.0, 40.0)
	var etendue := mx - mn
	var ppm := minf(CARTE_PX_PAR_M, 1024.0 / maxf(etendue.x, etendue.y))
	var img := Image.create(maxi(8, int(etendue.x * ppm)), maxi(8, int(etendue.y * ppm)), false, Image.FORMAT_RGBA8)
	for lot in [[routes, COULEUR_ROUTE], [bat, COULEUR_BATI]]:
		var pts: PackedVector2Array = lot[0]
		var i := 0
		while i + 2 < pts.size():
			_remplir_triangle(img, (pts[i] - mn) * ppm, (pts[i + 1] - mn) * ppm, (pts[i + 2] - mn) * ppm, lot[1])
			i += 3
	_fond = ImageTexture.create_from_image(img)
	_fond_x0 = mn.x
	_fond_z0 = mn.y
	_fond_ppm = ppm


## Les triangles (vus d'en haut, x/z du monde) des éléments d'un groupe du décor.
## Si le maillage n'est pas lisible (certains exports), on retombe sur sa boîte englobante.
func _triangles(groupe: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for n in get_tree().get_nodes_in_group(groupe):
		var meshs: Array = []
		if n is MeshInstance3D:
			meshs = [n]
		else:
			meshs = n.find_children("*", "MeshInstance3D", true, false)
		for mi in meshs:
			var m: MeshInstance3D = mi
			if m.mesh == null:
				continue
			var xf := m.global_transform
			var faces := m.mesh.get_faces()
			var ajoute := 0
			var i := 0
			while i + 2 < faces.size():
				var a := xf * faces[i]
				var b := xf * faces[i + 1]
				var c := xf * faces[i + 2]
				var nrm := (b - a).cross(c - a)
				if nrm.length() > 0.0001 and absf(nrm.y) > 0.8 * nrm.length():
					out.append(Vector2(a.x, a.z))
					out.append(Vector2(b.x, b.z))
					out.append(Vector2(c.x, c.z))
					ajoute += 1
				i += 3
			if ajoute == 0:
				var bb: AABB = xf * m.get_aabb()
				var p0 := Vector2(bb.position.x, bb.position.z)
				var p1 := Vector2(bb.end.x, bb.position.z)
				var p2 := Vector2(bb.end.x, bb.end.z)
				var p3 := Vector2(bb.position.x, bb.end.z)
				out.append_array(PackedVector2Array([p0, p1, p2, p0, p2, p3]))
	return out


## Remplit un triangle ligne par ligne (rapide : un fill_rect par ligne).
func _remplir_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var w := img.get_width()
	var y0 := maxi(0, int(ceil(minf(a.y, minf(b.y, c.y)))))
	var y1 := mini(img.get_height() - 1, int(floor(maxf(a.y, maxf(b.y, c.y)))))
	var pts := [a, b, c]
	for y in range(y0, y1 + 1):
		var xs: Array = []
		for k in 3:
			var p: Vector2 = pts[k]
			var q: Vector2 = pts[(k + 1) % 3]
			if (p.y <= y and q.y > y) or (q.y <= y and p.y > y):
				xs.append(p.x + (y - p.y) / (q.y - p.y) * (q.x - p.x))
		if xs.size() >= 2:
			var x0 := clampi(int(floor(minf(xs[0], xs[1]))), 0, w - 1)
			var x1 := clampi(int(ceil(maxf(xs[0], xs[1]))), 0, w - 1)
			if x1 >= x0:
				img.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), col)


func _dessiner_carte() -> void:
	var taille := _carte.size
	var c := taille * 0.5
	_carte.draw_rect(Rect2(Vector2.ZERO, taille), Color(PAPIER, 0.92))
	var cam := get_viewport().get_camera_3d()
	if cam == null or _joueur == null or _fond == null:
		return
	# La carte tourne avec la caméra : le haut de la carte, c'est devant soi.
	var bas := cam.global_transform.basis
	var r := Vector2(bas.x.x, bas.x.z).normalized()
	var f := Vector2(-bas.z.x, -bas.z.z).normalized()
	var pj := Vector2(_joueur.global_position.x, _joueur.global_position.z)
	var s := (CARTE_TAILLE * 0.5) / CARTE_PORTEE
	var o := Vector2(_fond_x0, _fond_z0) - pj
	var origine := c + Vector2(o.dot(r), -o.dot(f)) * s
	var k := s / _fond_ppm
	_carte.draw_set_transform_matrix(Transform2D(Vector2(r.x, -f.x) * k, Vector2(r.y, -f.y) * k, origine))
	_carte.draw_texture_rect(_fond, Rect2(Vector2.ZERO, Vector2(_fond.get_width(), _fond.get_height())), false)
	_carte.draw_set_transform_matrix(Transform2D.IDENTITY)
	# L'objectif : le snack, à l'aller comme au retour.
	var snack := _snack()
	if snack != null and (etat == "peinture" or etat == "retour"):
		var d := Vector2(snack.global_position.x, snack.global_position.z) - pj
		var p := Vector2(d.dot(r), -d.dot(f)) * s
		var lim := CARTE_TAILLE * 0.5 - 12.0
		var dehors := absf(p.x) > lim or absf(p.y) > lim
		if dehors:
			p *= lim / maxf(absf(p.x), absf(p.y))
		var q := c + p
		if dehors:
			var dir := p.normalized()
			var perp := Vector2(-dir.y, dir.x)
			var fleche := PackedVector2Array([q + dir * 9.0, q - dir * 5.0 + perp * 7.0, q - dir * 5.0 - perp * 7.0])
			_carte.draw_colored_polygon(fleche, MAGENTA)
			_carte.draw_polyline(PackedVector2Array([fleche[0], fleche[1], fleche[2], fleche[0]]), ENCRE, 2.0)
		else:
			var pouls := 7.0 + 2.0 * sin(Time.get_ticks_msec() * 0.006)
			_carte.draw_circle(q, pouls, MAGENTA)
			_carte.draw_arc(q, pouls, 0.0, TAU, 20, ENCRE, 2.5)
		var police := ThemeDB.fallback_font
		var texte := "SNACK  %d m" % int(d.length())
		_carte.draw_string_outline(police, Vector2(6.0, taille.y - 7.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 5, PAPIER)
		_carte.draw_string(police, Vector2(6.0, taille.y - 7.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ENCRE)
	# Loums, au centre, tourné vers le haut.
	var tri := PackedVector2Array([c + Vector2(0.0, -9.0), c + Vector2(-6.0, 6.0), c + Vector2(6.0, 6.0)])
	_carte.draw_colored_polygon(tri, JAUNE)
	_carte.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), ENCRE, 2.0)
	_carte.draw_rect(Rect2(Vector2(1.5, 1.5), taille - Vector2(3.0, 3.0)), ENCRE, false, 3.0)
