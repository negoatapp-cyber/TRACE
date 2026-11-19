class_name TraceTag
extends Node3D
## Le tag tracé à la main. Le joueur repasse à la souris sur le fantôme de son tag :
## la bombe dépose de la peinture là où passe le curseur. Trop vite, le trait est maigre ;
## trop lent ou immobile, la peinture s'accumule et coule. À la fin, on mesure la qualité :
## ce qui couvre le tag, ce qui déborde, les coulures.
##
## Image de travail à demi-résolution du tag (450 px pour 0,9 m : 2 mm par pixel).

signal fini(image: Image, qualite: Dictionary)
signal annule

const LARGEUR_PX := 450
const RAYON := 7.0            ## rayon du jet, en pixels (1,4 cm)
const DEBIT := 43.0           ## peinture déposée : ~1 en un passage à 400 px/s (0,8 m/s)
const SEUIL_COULURE := 3.2    ## au-delà, la peinture coule
const PAS := 2.5              ## espacement des impacts le long du geste (px)

var largeur_m := 0.9
var guide: Image              ## le tag de Loums, en masque (alpha)
var peinture: Image           ## ce que le joueur a peint (blanc + alpha), teinté par la bombe
var _charge: PackedFloat32Array
var _w := 0
var _h := 0
var _tex: ImageTexture
var _calque_peinture: Sprite3D
var _fantome: Sprite3D
var _precedent := Vector2(-1, -1)
var _coulures: Array = []     ## [x, y, longueur, vitesse]
var _sale := false
var camera: Camera3D
var appuye := false           ## bouton de peinture maintenu (souris, ou forcé par les tests)
var curseur := Vector2(-1, -1)   ## position du jet sur l'image (px), -1 si hors du tag
var depose := 0.0             ## peinture dépensée (pour la réserve de la bombe)
var age := 0.0                ## depuis quand on est devant le tag (Loums secoue la bombe au début)


func preparer(tag: Image, teinte: Color, largeur: float) -> void:
	largeur_m = largeur
	guide = tag.duplicate()
	guide.resize(LARGEUR_PX, int(round(tag.get_height() * float(LARGEUR_PX) / tag.get_width())), Image.INTERPOLATE_BILINEAR)
	_w = guide.get_width()
	_h = guide.get_height()
	_charge = PackedFloat32Array()
	_charge.resize(_w * _h)
	peinture = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	peinture.fill(Color(1, 1, 1, 0))
	_tex = ImageTexture.create_from_image(peinture)
	# Le fantôme : le tag de Loums, pâle, comme une esquisse à la craie.
	_fantome = _sprite(ImageTexture.create_from_image(guide), Color(1, 1, 1, 0.28), 0)
	_calque_peinture = _sprite(_tex, teinte, 1)


func _sprite(t: Texture2D, c: Color, ordre: int) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = t
	sp.pixel_size = largeur_m / _w
	sp.modulate = c
	sp.shaded = false
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sp.render_priority = ordre
	sp.position.z = ordre * 0.002
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sp)
	return sp


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		appuye = event.pressed
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		annule.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("graff") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		fini.emit(peinture, qualite())
		get_viewport().set_input_as_handled()


## Où tombe le curseur de la souris sur le tag (en pixels de l'image).
func point_souris() -> Vector2:
	if camera == null:
		return Vector2(-1, -1)
	var m := get_viewport().get_mouse_position()
	var o := camera.project_ray_origin(m)
	var d := camera.project_ray_normal(m)
	var plan := Plane(global_transform.basis.z, global_position)
	var hit = plan.intersects_ray(o, d)
	if hit == null:
		return Vector2(-1, -1)
	return vers_image(hit)


func vers_image(monde: Vector3) -> Vector2:
	var l := to_local(monde)
	var px := largeur_m / _w
	return Vector2(l.x / px + _w * 0.5, -l.y / px + _h * 0.5)


func vers_monde(p: Vector2) -> Vector3:
	var px := largeur_m / _w
	return to_global(Vector3((p.x - _w * 0.5) * px, -(p.y - _h * 0.5) * px, 0.01))


func _process(delta: float) -> void:
	age += delta
	if camera:
		curseur = point_souris()
	peindre(delta)


## Avance la bombe d'une image : dépose la peinture entre la position précédente et le curseur.
func peindre(delta: float) -> void:
	var dedans := curseur.x > -RAYON and curseur.y > -RAYON and curseur.x < _w + RAYON and curseur.y < _h + RAYON
	if appuye and dedans and delta > 0.0:
		var depart := _precedent if _precedent.x >= -RAYON else curseur
		var long := depart.distance_to(curseur)
		var n := maxi(1, int(ceil(long / PAS)))
		var vitesse := long / delta
		# Immobile : la bombe crache toujours, la peinture s'accumule au même endroit.
		var quantite := DEBIT * PAS / maxf(vitesse, 40.0) if long > 0.5 else 3.0 * delta
		for i in n:
			_impact(depart.lerp(curseur, float(i + 1) / n), quantite)
		depose += quantite * n
		_precedent = curseur
	else:
		_precedent = Vector2(-1, -1)
	_faire_couler(delta)
	if _sale:
		_tex.update(peinture)
		_sale = false


func _coulure_voisine(x: int, y: int) -> bool:
	for c in _coulures:
		if absf(c[0] - x) < 6.0 and absf(c[1] - y) < 12.0:
			return true
	return false


func _impact(c: Vector2, quantite: float) -> void:
	var r := int(ceil(RAYON))
	for y in range(maxi(0, int(c.y) - r), mini(_h, int(c.y) + r + 1)):
		for x in range(maxi(0, int(c.x) - r), mini(_w, int(c.x) + r + 1)):
			var d2 := (Vector2(x, y) - c).length_squared() / (RAYON * RAYON)
			if d2 >= 1.0:
				continue
			var i := y * _w + x
			var avant := _charge[i]
			_charge[i] = avant + quantite * (1.0 - d2)
			if avant < SEUIL_COULURE and _charge[i] >= SEUIL_COULURE and d2 < 0.3 and not _coulure_voisine(x, y):
				_coulures.append([float(x), float(y), 0.0, 0.0])
			var a := smoothstep(0.0, 0.9, _charge[i])
			peinture.set_pixel(x, y, Color(1, 1, 1, a))
	_sale = true


## Les coulures descendent tant qu'il y a trop de peinture au-dessus, puis s'arrêtent.
func _faire_couler(delta: float) -> void:
	for c in _coulures:
		var exces := _charge[clampi(int(c[1]), 0, _h - 1) * _w + clampi(int(c[0]), 0, _w - 1)] - SEUIL_COULURE
		if c[2] > 6.0 + exces * 10.0 or c[2] > 45.0:
			continue
		var avant: float = c[2]
		c[2] += delta * 28.0
		for y in range(int(c[1] + avant), int(c[1] + c[2]) + 1):
			if y >= _h:
				break
			for dx in [-1, 0, 1]:
				var x := clampi(int(c[0]) + dx, 0, _w - 1)
				peinture.set_pixel(x, y, Color(1, 1, 1, 1.0 if dx == 0 else 0.6))
		_sale = true


## Ce qu'on retient du tag : couverture du tracé, débordement, coulures, et une note de 0 à 1.
func qualite() -> Dictionary:
	var dans := 0
	var couvert := 0
	var peint := 0
	var deborde := 0
	for y in range(0, _h, 2):
		for x in range(0, _w, 2):
			var g := guide.get_pixel(x, y).a > 0.5
			var p := peinture.get_pixel(x, y).a > 0.4
			if g:
				dans += 1
				if p:
					couvert += 1
			if p:
				peint += 1
				if not g and not _pres_du_trace(x, y, int(RAYON)):
					deborde += 1
	var couverture := float(couvert) / maxf(1.0, float(dans))
	var debordement := float(deborde) / maxf(1.0, float(peint))
	var note := clampf(couverture * pow(1.0 - debordement, 2.0) - 0.03 * _coulures.size(), 0.0, 1.0)
	var mot := "propre" if note >= 0.7 else ("correct" if note >= 0.45 else "raté")
	return {"couverture": couverture, "debordement": debordement, "coulures": _coulures.size(), "note": note, "mot": mot}


## On tolère un peu de flou autour du trait : un point à moins de r px du tag n'est pas un débord.
func _pres_du_trace(x: int, y: int, r: int) -> bool:
	for yy in range(maxi(0, y - r), mini(_h, y + r + 1)):
		for xx in range(maxi(0, x - r), mini(_w, x + r + 1)):
			if guide.get_pixel(xx, yy).a > 0.5:
				return true
	return false
