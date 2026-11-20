extends Node3D
const JOUEUR := preload("res://scenes/player.tscn")
const VILLE := preload("res://scripts/ville_terrain.gd")
const ENCRE := Color("#222b34")
const PAPIER := Color("#fff0d3")
const SOLEIL := Color("#ffd177")
@onready var ville: VILLE = $Ville
@onready var cam: Camera3D = $Camera
var point := Vector2.ZERO
var echelle := 28000.
var cap := 0.
var acteur: Player
var menu: PanelContainer
var lieux: OptionButton
var info: Label
var reperes := {}
var titre: Label
var aide: Label
var glisse := false
var doigt := -1
var terre: Image
var dernier_sol := Vector3.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	TouchControls.visible = false
	terre = preload("res://data/marseille/terre.png").get_image()
	_interface()
	_ensemble()
	_cadrer()

func _exit_tree() -> void:
	TouchControls.visible = true

func _ensemble() -> void:
	point = ville.domaine.get_center()
	point.y += ville.domaine.size.y*.07
	echelle = ville.domaine.size.y*1.26
	cap = 0
	titre.text = "Marseille"
	if lieux: lieux.select(0)

func _cadrer() -> void:
	point = point.clamp(ville.domaine.position,ville.domaine.end)
	var altitude := ville.altitude(point.x,point.y)
	var cible := Vector3(point.x,altitude,point.y)
	var oblique := lerpf(0.90,0.19,clampf(echelle/12000,0,1))
	var axe := Vector3(sin(cap)*oblique,1,cos(cap)*oblique).normalized()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = echelle
	cam.position = cible+axe*(echelle+2500)
	cam.look_at(cible)
	ville.demander(point,1 if echelle<3700 else -1)
	for lbl: Label in reperes:
		var p: Vector2 = reperes[lbl]
		var screen := cam.unproject_position(Vector3(p.x,ville.altitude(p.x,p.y)+6,p.y))
		lbl.position = screen - Vector2(lbl.size.x*.5,0)
		lbl.visible = echelle>5500 and screen.y>60 and screen.y<get_viewport().get_visible_rect().size.y-148

func _process(dt: float) -> void:
	if is_instance_valid(acteur):
		var p := Vector2(acteur.position.x,acteur.position.z)
		if not _dans_la_commune(p):
			acteur.global_position=dernier_sol
			acteur.velocity=Vector3.ZERO
			acteur.skate.speed=0
			return
		if acteur.is_on_floor(): dernier_sol=acteur.position
		ville.demander(p,1)
		var cle := Vector2i(floori(p.x/512),floori(p.y/512))
		acteur.set_physics_process(ville.secteurs.has(cle))
		return
	var dir := Input.get_vector("move_left","move_right","move_forward","move_back")
	if dir.length_squared()>0: _pan(dir*dt*echelle*.63)
	_cadrer()

func _dans_la_commune(p: Vector2) -> bool:
	if not ville.domaine.has_point(p): return false
	var uv := (p-ville.domaine.position)/ville.domaine.size
	var px := Vector2i(uv*Vector2(terre.get_size()-Vector2i.ONE))
	return terre.get_pixelv(px).r>.5

func _pan(d: Vector2) -> void:
	point += Vector2(cos(cap),-sin(cap))*d.x + Vector2(sin(cap),cos(cap))*d.y

func _zoom(facteur: float) -> void:
	echelle = clampf(echelle*facteur,230,35000)

func _unhandled_input(e: InputEvent) -> void:
	if is_instance_valid(acteur): return
	if e is InputEventMouseButton:
		if e.button_index==MOUSE_BUTTON_LEFT: glisse=e.pressed
		if e.pressed and e.button_index==MOUSE_BUTTON_WHEEL_UP: _zoom(.76)
		if e.pressed and e.button_index==MOUSE_BUTTON_WHEEL_DOWN: _zoom(1.32)
	if e is InputEventMouseMotion and glisse:
		_pan(-e.relative*echelle/get_viewport().get_visible_rect().size.y)
	if e is InputEventScreenTouch:
		if e.pressed and doigt==-1: doigt=e.index
		elif not e.pressed and e.index==doigt: doigt=-1
	if e is InputEventScreenDrag and e.index==doigt:
		_pan(-e.relative*echelle/get_viewport().get_visible_rect().size.y)
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_Q: cap-=PI/12
			KEY_E: cap+=PI/12
			KEY_EQUAL,KEY_KP_ADD: _zoom(.72)
			KEY_MINUS,KEY_KP_SUBTRACT: _zoom(1.38)

func _label(s: String, taille: int, color: Color) -> Label:
	var l := Label.new()
	l.text=s
	l.add_theme_font_size_override("font_size",taille)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func _boite(color: Color, bord: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(bord)
	s.content_margin_left=18
	s.content_margin_right=18
	s.content_margin_top=9
	s.content_margin_bottom=9
	return s

func _bouton(row: Container, nom: String, action: Callable, actif:=false) -> Button:
	var b := Button.new()
	b.text=nom
	b.add_theme_font_size_override("font_size",21)
	b.add_theme_stylebox_override("normal",_boite(SOLEIL if actif else Color("#36444c"),5))
	b.add_theme_stylebox_override("hover",_boite(Color("#b9986c") if actif else Color("#495862"),5))
	b.add_theme_color_override("font_color",ENCRE if actif else PAPIER)
	b.add_theme_color_override("font_hover_color",ENCRE if actif else PAPIER)
	b.pressed.connect(action)
	row.add_child(b)
	return b

func _interface() -> void:
	var top := PanelContainer.new()
	top.position=Vector2(28,22)
	top.add_theme_stylebox_override("panel",_boite(ENCRE,5))
	$Interface.add_child(top)
	var heading := VBoxContainer.new()
	top.add_child(heading)
	heading.add_child(_label("T R A C E     /     ATLAS",18,SOLEIL))
	titre=_label("Marseille",36,PAPIER)
	heading.add_child(titre)
	top.name="Titre"
	var details: Array = ville.info.labels.duplicate()
	details.sort_custom(func(a,b): return str(a[0]).naturalnocasecmp_to(str(b[0]))<0)
	for l in details:
		if l[0] in ["L'Estaque","Château Gombert","La Valentine","Mazargues","Les Goudes","Hôtel-de-Ville","Malpassé","Les Îles","Saint-Antoine","Sormiou"]:
			var tag := _label("●  "+str(l[0]),21,SOLEIL if l[0]=="Malpassé" else PAPIER)
			tag.add_theme_color_override("font_outline_color",ENCRE)
			tag.add_theme_constant_override("outline_size",6)
			$Interface.add_child(tag)
			reperes[tag]=Vector2(l[2],l[3])
	menu=PanelContainer.new()
	menu.add_theme_stylebox_override("panel",_boite(ENCRE,5))
	$Interface.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	menu.offset_left=24;menu.offset_right=-24;menu.offset_bottom=-22;menu.offset_top=-162
	var v:=VBoxContainer.new()
	menu.add_child(v)
	var row:=HBoxContainer.new()
	v.add_child(row)
	row.add_theme_constant_override("separation",10)
	lieux=OptionButton.new()
	lieux.add_item("111 quartiers")
	for l in details: lieux.add_item("%02d  ·  %s"%[l[1],l[0]])
	lieux.custom_minimum_size.x=255
	lieux.add_theme_font_size_override("font_size",20)
	row.add_child(lieux)
	lieux.item_selected.connect(func(i):
		if i==0: _ensemble(); return
		var l: Array = details[i-1]
		point=Vector2(l[2],l[3]); echelle=850; titre.text=l[0])
	_bouton(row,"−",func(): _zoom(1.6))
	_bouton(row,"+",func(): _zoom(.62))
	_bouton(row,"Vue générale",_ensemble)
	_bouton(row,"Explorer ici",_descendre)
	_bouton(row,"Les Lauriers · 2014",func(): get_tree().change_scene_to_file("res://scenes/lauriers.tscn"),true)
	_bouton(row,"Tester Loums",func(): get_tree().change_scene_to_file("res://scenes/ilot_grey.tscn"))
	info=_label("Glisser pour déplacer la carte  ·  Molette pour zoomer  ·  Q / E pour pivoter",18,PAPIER)
	v.add_child(info)
	v.add_child(_label("© contributeurs OpenStreetMap (ODbL)  ·  IGN RGE ALTI  ·  Datactivist / contours IRIS 2015  ·  Socle urbain de novembre 2026",16,Color("#b6c2c1")))

func _descendre() -> void:
	# Cherche un tronçon accessible au centre ou dans les huit tuiles voisines.
	var centre := Vector2i(floori(point.x/512),floori(point.y/512))
	var choix := Vector2.ZERO
	var distance := INF
	var direction := Vector2.UP
	for dz in range(-1,2):
		for dx in range(-1,2):
			var paquet := ville.lire(centre+Vector2i(dx,dz))
			for r in paquet.r:
				if r[2] not in ["residential","pedestrian","footway","living_street","unclassified","tertiary","path"]: continue
				var pts: Array = r[3]
				for i in range(2,pts.size(),2):
					var p := Vector2((pts[i-2]+pts[i])*.5,(pts[i-1]+pts[i+1])*.5)
					var d := point.distance_squared_to(p)
					if d<distance and _dans_la_commune(p):
						distance=d
						choix=p
						direction=Vector2(pts[i]-pts[i-2],pts[i+1]-pts[i-1]).normalized()
	if distance==INF:
		info.text="Aucune voie de départ à proximité. Choisis un quartier ou déplace la carte."
		return
	if ville._coeur(choix):
		get_tree().change_scene_to_file("res://scenes/lauriers.tscn")
		return
	# Recrée les tuiles précédemment affichées avec leurs collisions.
	ville.demander(choix,-1)
	if ville.travail.is_started(): ville.travail.wait_to_finish()
	ville.solide=true
	ville.demander(choix,1)
	acteur=JOUEUR.instantiate()
	acteur.position=Vector3(choix.x,ville.altitude(choix.x,choix.y)+1,choix.y)
	dernier_sol=acteur.position
	acteur.chute_limite=-150
	var env: Environment = $WorldEnvironment.environment
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color=Color("#72aada")
	ciel.sky_horizon_color=Color("#f4d9b5")
	env.sky=Sky.new()
	env.sky.sky_material=ciel
	env.background_mode=Environment.BG_SKY
	env.fog_enabled=true
	env.fog_light_color=Color("#dfd9ce")
	env.fog_density=.0004
	add_child(acteur)
	acteur.set_physics_process(false)
	acteur.camera_pivot.global_position=acteur.global_position+Vector3.UP*1.5
	acteur.camera_pivot.rotation.y=atan2(-direction.x,-direction.y)
	acteur.visual.rotation.y=acteur.camera_pivot.rotation.y
	acteur.spring_arm.rotation.x=-0.20
	$Interface.hide()
	TouchControls.visible=true
