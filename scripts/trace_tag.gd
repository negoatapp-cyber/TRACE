class_name TraceTag
extends Node3D
## Le tag tracé à la main. Le joueur repasse à la souris sur le fantôme de son tag :
## la bombe dépose de la peinture là où passe le curseur. Trop vite, le trait est maigre ;
## trop lent ou immobile, la peinture s'accumule et coule. À la fin, on mesure la qualité :
## ce qui couvre le tag, ce qui déborde, les coulures.
##
## Le même outil sert à chaque couche d'un graffiti, avec trois gestes :
##   « trait »   : on repasse sur un trait (tag, contour, signature) ;
##   « remplir » : on balaie une surface au jet large (fond d'un flop ou d'une pièce, surcontour) ;
##   « taper »   : des points lumineux s'allument l'un après l'autre, on tape dessus en rythme (lights).
## Image de travail : 450 px pour un tag de 0,9 m (2 mm par pixel), un peu plus pour les grandes pièces.

signal fini(image: Image, qualite: Dictionary)
signal annule

const SEUIL_COULURE := 3.2    ## au-delà, la peinture coule
const LIGHT_DUREE := 0.85     ## temps pour taper un point lumineux (s)

var mode := "trait"
var RAYON := 7.0              ## rayon du jet, en pixels (1,4 cm pour un tag)
var DEBIT := 43.0             ## peinture déposée : ~1 en un passage à 400 px/s
var PAS := 2.5                ## espacement des impacts le long du geste (px)
var _cibles: Array = []       ## mode « taper » : [centre, liste de pixels] de chaque point lumineux
var _cible_i := -1
var _cible_t := 0.0
var _touches := 0
var _anneau: Sprite3D
var _avait_appuye := false

var largeur_m := 0.9
var guide: Image              ## le tag de Loums, en masque (alpha)
var peinture: Image           ## ce que le joueur a peint (blanc + alpha), teinté par la bombe
var _charge: PackedFloat32Array
var _w := 0
var _h := 0
var _tex: ImageTexture
var _calque_peinture: Sprite3D
var _fantome: Sprite3D
var _precedent := Vector2(-1000, -1000)   ## -1000 : pas de geste en cours
var _coulures: Array = []     ## [x, y, longueur, vitesse]
var _sale := false
var camera: Camera3D
var appuye := false           ## bouton de peinture maintenu (souris, ou forcé par les tests)
var curseur := Vector2(-1000, -1000)   ## position du jet sur l image (px), -1000 si inconnue
var depose := 0.0             ## peinture dépensée (pour la réserve de la bombe)
## Mode simple : Loums peint tout seul, la bombe parcourt le lettrage ligne par ligne.
var auto := false
var _chemin := PackedVector2Array()
var _levees := PackedByteArray()     ## 1 = on relâche la bombe avant ce point
var _ci := 0
var _vitesse := 400.0
var _auto_fini := false
var attente := 0.0                    ## mode simple : le temps de sortir la bombe ou la perche avant de peindre
var vertical := false                 ## rouleau : de haut en bas, lettre après lettre
var inertie := 0.0            ## perche : le jet suit la main avec retard et oscille un peu (s)
var _vise := Vector2(-1000, -1000)
var age := 0.0                ## depuis quand on est devant le tag (Loums secoue la bombe au début)


func preparer(tag: Image, teinte: Color, largeur: float, px := 450, rayon := 7.0, geste := "trait", fantome := 0.28) -> void:
	largeur_m = largeur
	mode = geste
	RAYON = rayon
	DEBIT = 300.0 / rayon
	PAS = maxf(2.0, rayon * 0.35)
	guide = tag.duplicate()
	if guide.is_compressed():
		guide.decompress()
	guide.convert(Image.FORMAT_RGBA8)
	guide.resize(px, int(round(tag.get_height() * float(px) / tag.get_width())), Image.INTERPOLATE_BILINEAR)
	_w = guide.get_width()
	_h = guide.get_height()
	_charge = PackedFloat32Array()
	_charge.resize(_w * _h)
	peinture = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	peinture.fill(Color(1, 1, 1, 0))
	_tex = ImageTexture.create_from_image(peinture)
	# Le fantôme : le tag de Loums, pâle, comme une esquisse à la craie.
	_fantome = _sprite(ImageTexture.create_from_image(guide), Color(1, 1, 1, fantome), 0)
	_calque_peinture = _sprite(_tex, teinte, 1)
	if mode == "taper":
		_fantome.modulate.a = 0.12
		_preparer_cibles()


## Fige la couche une fois finie : plus de fantôme, plus d'entrée, la peinture reste visible
## sous les couches suivantes.
func figer(ordre: int) -> void:
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	_fantome.visible = false
	if _anneau:
		_anneau.visible = false
	_calque_peinture.render_priority = ordre
	_calque_peinture.position.z = ordre * 0.002


## Lights : chaque tache lumineuse du lettrage devient une cible (les plus grosses d'abord ;
## les petites éclaboussures suivent la cible la plus proche).
func _preparer_cibles() -> void:
	var vu := PackedByteArray()
	vu.resize(_w * _h)
	var taches: Array = []
	for y in _h:
		for x in _w:
			if vu[y * _w + x] == 1 or guide.get_pixel(x, y).a < 0.5:
				continue
			var pile := [Vector2i(x, y)]
			vu[y * _w + x] = 1
			var pts: Array = []
			var somme := Vector2.ZERO
			while not pile.is_empty():
				var p: Vector2i = pile.pop_back()
				pts.append(p)
				somme += Vector2(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if q.x >= 0 and q.y >= 0 and q.x < _w and q.y < _h and vu[q.y * _w + q.x] == 0 and guide.get_pixel(q.x, q.y).a >= 0.5:
						vu[q.y * _w + q.x] = 1
						pile.append(q)
			taches.append([somme / pts.size(), pts])
	taches.sort_custom(func(a, b): return a[1].size() > b[1].size())
	var grosses := taches.slice(0, mini(8, taches.size()))
	for t in taches.slice(grosses.size()):
		var meilleure: Array = grosses[0]
		for gr in grosses:
			if (gr[0] as Vector2).distance_to(t[0]) < (meilleure[0] as Vector2).distance_to(t[0]):
				meilleure = gr
		meilleure[1].append_array(t[1])
	# de gauche à droite, comme on lit le blaze
	grosses.sort_custom(func(a, b): return a[0].x < b[0].x)
	_cibles = grosses
	_cible_i = 0 if not _cibles.is_empty() else -1
	_cible_t = 0.0
	var anneau := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length()
			anneau.set_pixel(x, y, Color(1, 1, 0.85, clampf(1.0 - absf(d - 26.0) / 4.0, 0.0, 1.0)))
	_anneau = Sprite3D.new()
	_anneau.texture = ImageTexture.create_from_image(anneau)
	_anneau.shaded = false
	_anneau.render_priority = 3
	_anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_anneau)


func _taper(delta: float) -> void:
	if _cible_i < 0 or _cible_i >= _cibles.size():
		if _anneau:
			_anneau.visible = false
		return
	var c: Array = _cibles[_cible_i]
	var centre: Vector2 = c[0]
	_cible_t += delta
	# l'anneau se resserre : on tape quand il touche la tache
	var k := clampf(_cible_t / LIGHT_DUREE, 0.0, 1.0)
	_anneau.visible = true
	_anneau.position = Vector3((centre.x - _w * 0.5) * largeur_m / _w, -(centre.y - _h * 0.5) * largeur_m / _w, 0.006)
	_anneau.pixel_size = largeur_m / _w * lerpf(1.6, 0.45, k)
	var tape := appuye and not _avait_appuye
	_avait_appuye = appuye
	if tape and curseur.distance_to(centre) < 45.0:
		for p in c[1]:
			peinture.set_pixel(p.x, p.y, Color(1, 1, 1, 1))
		_sale = true
		_touches += 1
		depose += 3.0
		_suivante()
	elif _cible_t > LIGHT_DUREE:
		_suivante()


func _suivante() -> void:
	_cible_i += 1
	_cible_t = 0.0


## Mode « taper » : toutes les cibles sont passées.
func fini_de_taper() -> bool:
	return mode == "taper" and _cible_i >= _cibles.size()


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


var _doigt := Vector2(-1, -1)
var _index_doigt := -1


## Sur téléphone : le doigt peint (sauf sur les boutons, et GRAFF pose le tag).
func _input(event: InputEvent) -> void:
	if not TouchControls.actif or auto:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not (TouchControls.call("_bouton_sous", event.position) as Array).is_empty():
			return
		if event.pressed and _index_doigt < 0:
			_index_doigt = event.index
			_doigt = event.position
			appuye = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _index_doigt:
			_index_doigt = -1
			appuye = false
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _index_doigt:
		_doigt = event.position
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if auto:
		if event.is_action_pressed("ui_cancel"):
			annule.emit()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("graff") or event.is_action_pressed("ui_accept"):
			terminer_auto()
			get_viewport().set_input_as_handled()
		return
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
		return Vector2(-1000, -1000)
	var m := _doigt if TouchControls.actif else get_viewport().get_mouse_position()
	var o := camera.project_ray_origin(m)
	var d := camera.project_ray_normal(m)
	var plan := Plane(global_transform.basis.z, global_position)
	var hit = plan.intersects_ray(o, d)
	if hit == null:
		return Vector2(-1000, -1000)
	return vers_image(hit)


func vers_image(monde: Vector3) -> Vector2:
	var l := to_local(monde)
	var px := largeur_m / _w
	return Vector2(l.x / px + _w * 0.5, -l.y / px + _h * 0.5)


func vers_monde(p: Vector2) -> Vector3:
	var px := largeur_m / _w
	return to_global(Vector3((p.x - _w * 0.5) * px, -(p.y - _h * 0.5) * px, 0.01))


## Mode simple : prépare le trajet de la bombe (lignes en zigzag sur le lettrage) pour finir en « duree » s.
func lancer_auto(duree: float) -> void:
	auto = true
	if mode == "taper":
		return
	var pas := maxf(3.0, RAYON * 0.9)
	var dx := maxi(2, int(PAS))   # un impact par pas de jet : la même épaisseur de peinture qu'à la main
	var lignes := _h if not vertical else _w
	var long_ligne := _w if not vertical else _h
	var y := pas * 0.5
	var sens := 1
	while y < lignes:
		var xs := range(0, long_ligne, dx) if sens > 0 else range(long_ligne - 1, -1, -dx)
		var precedent := -1000
		for x in xs:
			var pt := Vector2(x, y) if not vertical else Vector2(y, x)
			if guide.get_pixel(int(pt.x), int(pt.y)).a > 0.5:
				_chemin.append(pt)
				_levees.append(1 if absi(x - precedent) > maxf(pas * 1.5, dx * 1.5) else 0)
				precedent = x
		y += pas
		sens = -sens
	var longueur := _chemin.size() * maxf(2.0, PAS)
	_vitesse = maxf(250.0, longueur / maxf(duree, 0.2))
	DEBIT = 300.0 / RAYON * _vitesse / 400.0   # même épaisseur de peinture, plus vite


func _auto_step(delta: float) -> void:
	if mode == "taper" or _auto_fini:
		return
	var budget := _vitesse * delta
	while budget > 0.0 and _ci < _chemin.size():
		var p := _chemin[_ci]
		if _levees[_ci] == 1:
			appuye = false
			peindre(0.0001)
			curseur = p
			_precedent = Vector2(-1000, -1000)
		appuye = true
		var d := maxf(curseur.distance_to(p), 1.0)
		curseur = p
		peindre(d / _vitesse)
		budget -= d
		_ci += 1
	if _ci >= _chemin.size():
		appuye = false
		_auto_fini = true
		fini.emit.call_deferred(peinture, qualite())


## Mode simple, G : on finit la couche d'un coup.
func terminer_auto() -> void:
	if mode == "taper":
		while _cible_i >= 0 and _cible_i < _cibles.size():
			_cible_t = LIGHT_DUREE
			curseur = _cibles[_cible_i][0]
			appuye = true
			_avait_appuye = false
			_taper(0.0)
		return
	_vitesse *= 1000.0
	_auto_step(1.0)


func _process(delta: float) -> void:
	age += delta
	if auto and age < attente:
		return
	if auto:
		if mode == "taper":
			# les lights se posent toutes seules quand l'anneau se referme
			if _cible_i >= 0 and _cible_i < _cibles.size() and _cible_t > LIGHT_DUREE * 0.5:
				curseur = _cibles[_cible_i][0]
				appuye = not _avait_appuye
		else:
			_auto_step(delta)
		if mode == "taper":
			peindre(delta)
		if _sale:
			_tex.update(peinture)
			_sale = false
		return
	if camera:
		var main := point_souris()
		if inertie > 0.0 and main.x > -999.0:
			# au bout de 3 m de perche : le jet traîne derrière la main et balance doucement
			if _vise.x < -999.0:
				_vise = main
			_vise = _vise.lerp(main, 1.0 - exp(-delta / inertie))
			curseur = _vise + Vector2(sin(age * 2.3), cos(age * 1.7)) * 3.0
		else:
			curseur = main
	peindre(delta)


## Avance la bombe d'une image : dépose la peinture entre la position précédente et le curseur.
func peindre(delta: float) -> void:
	if mode == "taper":
		_taper(delta)
		if _sale:
			_tex.update(peinture)
			_sale = false
		return
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
		_precedent = Vector2(-1000, -1000)
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
	if mode == "taper":
		var n := float(maxi(1, _cibles.size()))
		var note_l := float(_touches) / n
		return {"couverture": note_l, "debordement": 0.0, "coulures": 0, "note": note_l,
			"mot": "propre" if note_l >= 0.7 else ("correct" if note_l >= 0.45 else "raté")}
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
