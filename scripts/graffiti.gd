extends Node3D
## Le graffiti. À pied, face à un mur, on maintient G :
##   0,8 s = un tag · 3 s = un flop · 7 s = une pièce. Plus c'est long, plus c'est gros — et plus on s'expose.
## C change de couleur. Les murs gardent leurs graffitis d'une partie à l'autre.
## (Le temps passé immobile face au mur servira plus tard au risque d'être vu.)

const SAUVEGARDE := "user://graffitis.json"
const PORTEE := 2.2
const PALIERS := [["tag", 0.8], ["flop", 3.0], ["piece", 7.0]]
const COULEURS := [Color(0.92, 0.15, 0.45), Color(0.12, 0.12, 0.14), Color(0.95, 0.95, 0.92), Color(0.15, 0.55, 0.95), Color(0.98, 0.82, 0.10), Color(0.25, 0.75, 0.35), Color(0.80, 0.15, 0.15), Color(0.55, 0.30, 0.80)]

@export var blaze := "LOUMS"

var couleur := 0
var tenue := 0.0
var poses: Array = []       # tout ce qui est sur les murs (sauvegardé)
var compte := {"tag": 0, "flop": 0, "piece": 0}

var _joueur: Player
var _texte: Label
var _barre: ProgressBar
var _pastille: ColorRect
var _cible := {}


func _ready() -> void:
	_joueur = get_node_or_null("../Player") as Player
	_interface()
	_charger()


func _physics_process(delta: float) -> void:
	if _joueur == null:
		return
	if Input.is_action_just_pressed("graff_color"):
		couleur = (couleur + 1) % COULEURS.size()
		_pastille.color = COULEURS[couleur]
	_cible = _mur_devant()
	var peut := not _cible.is_empty() and _joueur.mode == Player.Mode.WALK and _joueur.is_on_floor()
	if peut and Input.is_action_pressed("graff"):
		tenue += delta
		if tenue >= PALIERS[2][1] + 0.4:
			_poser()
	elif tenue > 0.0:
		if peut or not _cible.is_empty():
			_poser()
		tenue = 0.0
	_afficher(peut)


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


func _poser() -> void:
	var type := _palier()
	tenue = 0.0
	if type == "" or _cible.is_empty():
		return
	var n: Vector3 = _cible.normal
	n.y = 0.0
	n = n.normalized()
	var p: Vector3 = _cible.position
	var g := {
		"t": type, "c": couleur, "b": blaze,
		"x": p.x, "y": _joueur.global_position.y, "z": p.z,
		"nx": n.x, "nz": n.z, "a": randf_range(-0.10, 0.10),
	}
	poses.append(g)
	_dessiner(g)
	_sauver()


func _dessiner(g: Dictionary) -> void:
	var n := Vector3(g.nx, 0, g.nz)
	var c: Color = COULEURS[int(g.c) % COULEURS.size()]
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


func _sauver() -> void:
	var f := FileAccess.open(SAUVEGARDE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(poses))


func _charger() -> void:
	if not FileAccess.file_exists(SAUVEGARDE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAUVEGARDE))
	if data is Array:
		for g in data:
			if g is Dictionary and g.has("t") and g.has("nx"):
				poses.append(g)
				_dessiner(g)


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
	_barre.max_value = PALIERS[2][1]
	_barre.show_percentage = false
	_barre.custom_minimum_size = Vector2(340, 10)
	boite.add_child(_barre)
	_pastille = ColorRect.new()
	_pastille.color = COULEURS[couleur]
	_pastille.custom_minimum_size = Vector2(340, 6)
	boite.add_child(_pastille)


func _afficher(peut: bool) -> void:
	_barre.visible = tenue > 0.0
	_pastille.visible = peut
	_barre.value = tenue
	if tenue > 0.0:
		var p := _palier()
		var noms := {"": "…", "tag": "TAG", "flop": "FLOP", "piece": "PIÈCE"}
		_texte.text = "%s   (relâche pour poser)" % noms[p]
	elif peut:
		_texte.text = "G : graffiti   ·   C : couleur   ·   %d tags, %d flops, %d pièces" % [compte.tag, compte.flop, compte.piece]
	else:
		_texte.text = ""
