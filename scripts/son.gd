extends Node
## TRACE — le son (autoload « Son »).
##
## Principe : ce script ne modifie AUCUN fichier de gameplay. Il observe l'état du jeu à chaque image
## (Loums, la planche, le graffiti, les habitants, le scooter, l'heure) et déclenche les sons sur les
## changements d'état. Conséquence : si un nœud manque (îlot gris sans graffiti, par exemple),
## le son correspondant se tait, et rien ne casse.
##
## Les sons sont dans res://assets/sons/ (fabriqués par .tools/son_generer.py, voir LISEZMOI.md là-bas).
## Un fichier « nom.wav » ou « nom_1.wav, nom_2.wav… » (variantes) ; « …_loop » = son en boucle.
## Pour remplacer un son : déposer un fichier du même nom. Rien à changer ici.
##
## API pour les autres scripts : Son.jouer("nom", db, pitch) · Son.jouer_3d("nom", position, db, pitch).

const DOSSIER := "res://assets/sons/"
const WALK := 0
const SKATE := 1
const NB_VOIX := 24
const NB_VOIX_3D := 12
const BUS_EFFETS := "Effets"
const BUS_AMBIANCE := "Ambiance"

var journaliser := false          ## les tests l'allument : chaque son joué est noté dans `journal`
var journal: Array[String] = []

var banque := {}                  ## nom → [AudioStream, …]
var _manquants := {}
var _dernier := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _rr := 0
var _rr3 := 0
var _boucles := {}                ## id → {p, v, cible, pitch}
var _file: Array = []             ## sons différés : {t, nom, db, pitch}
var _t := 0.0
var _silence := true              ## la première image après un (re)chargement de scène ne joue rien

var _j: Node3D
var _graf: Node
var _hab: Node
var _temps: Node
var _cond: Node
var _recherche_t := 0.0

# --- états précédents (pour détecter les changements) -------------------------------------------
var _dist_pas := 0.8
var _au_sol_avant := true
var _vy_avant := 0.0
var _p_push := -1.0
var _p_pop := -1.0
var _p_trick := ""
var _p_reception := 0.0
var _p_grind := false
var _p_chute := -1.0
var _p_trans := ""
var _trans_fait := {}
var _p_mantle := false
var _p_susp := false
var _p_gout := false
var _p_bond := false
var _p_event := ""
var _p_pvel := 0.0
var _air_dur := 0.0
var _grind_beton := false
var _dist_decale := 0.0
var _pos_decale := Vector3.ZERO
var _y_gout := 0.0
var _dist_gout := 0.0
var _g_trace_id := 0
var _g_etape := 0
var _g_actif := false
var _g_touches := 0
var _g_coul := 0
var _g_msg := ""
var _p_veh: Object = null
var _veh_t0 := 0.0
var _p_vit := 0.0
var _p_cabre := 0.0
var _hab_etat := {}
var _amb_t := 6.0
var _dem_n := -1
var _dem_t := 0.0

# --- le sol sous les pieds ----------------------------------------------------------------------
var _sol_prep := false
var _sol: Array = []              ## {rect: Rect2, tri: PackedVector2Array, kind: String}
var _sol_cache := {}
const SOL_ZONE := {"terrain": "herbe", "jardin": "herbe", "friche": "gravier", "chantier": "gravier"}


func _ready() -> void:
	_creer_bus()
	_charger_banque()
	for i in NB_VOIX:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in NB_VOIX_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 9.0
		p3.max_distance = 90.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.bus = BUS_EFFETS
		add_child(p3)
		_pool3d.append(p3)


func _creer_bus() -> void:
	if AudioServer.get_bus_index(BUS_EFFETS) >= 0:
		return
	var lim := AudioEffectLimiter.new()
	AudioServer.add_bus_effect(0, lim)
	for nom in [BUS_EFFETS, BUS_AMBIANCE]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nom)
		AudioServer.set_bus_send(i, "Master")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.4
	rev.damping = 0.6
	rev.wet = 0.1
	rev.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(BUS_EFFETS), rev)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_AMBIANCE), -3.0)


## Règle le volume d'un bus (« Master », « Effets », « Ambiance »), pour un futur menu d'options.
func regler(bus: String, db: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, db)


func _charger_banque() -> void:
	var vus := {}
	for f in DirAccess.get_files_at(DOSSIER):
		# dans un jeu exporté, la liste donne « x.wav.import » ou « x.wav.remap » : on retrouve le nom d'origine
		var nom := f.trim_suffix(".import").trim_suffix(".remap")
		if not (nom.ends_with(".wav") or nom.ends_with(".ogg") or nom.ends_with(".mp3")):
			continue
		if vus.has(nom):
			continue
		vus[nom] = true
		var flux := load(DOSSIER + nom) as AudioStream
		if flux == null:
			continue
		var base := nom.get_basename()
		var racine := base
		var morceaux := base.rsplit("_", true, 1)
		if morceaux.size() == 2 and morceaux[1].is_valid_int():
			racine = morceaux[0]
		if racine.ends_with("_loop"):
			flux = _en_boucle(flux)
		if not banque.has(racine):
			banque[racine] = []
		banque[racine].append(flux)


func _en_boucle(flux: AudioStream) -> AudioStream:
	if flux is AudioStreamWAV:
		var w := (flux as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		return w
	if "loop" in flux:
		var c := flux.duplicate()
		c.set("loop", true)
		return c
	return flux


func _un(nom: String) -> AudioStream:
	var l: Array = banque.get(nom, [])
	if l.is_empty():
		if not _manquants.has(nom):
			_manquants[nom] = true
			push_warning("Son : « %s » manque dans %s" % [nom, DOSSIER])
		return null
	if l.size() == 1:
		return l[0]
	var i := randi() % l.size()
	if i == int(_dernier.get(nom, -1)):
		i = (i + 1) % l.size()
	_dernier[nom] = i
	return l[i]


func _noter(nom: String) -> void:
	if journaliser:
		journal.append(nom)


func a_joue(nom: String) -> bool:
	return journal.has(nom)


# ==================================================================================================
#  API
# ==================================================================================================
func jouer(nom: String, db := 0.0, pitch := 1.0, bus := BUS_EFFETS, variation := 0.05) -> AudioStreamPlayer:
	if _silence:
		return null
	var s := _un(nom)
	if s == null:
		return null
	var p := _pool[_rr]
	for i in NB_VOIX:
		var k := (_rr + i) % NB_VOIX
		if not _pool[k].playing:
			p = _pool[k]
			break
	_rr = (_rr + 1) % NB_VOIX
	p.stream = s
	p.bus = bus
	p.volume_db = db + randf_range(-1.0, 1.0)
	p.pitch_scale = pitch * randf_range(1.0 - variation, 1.0 + variation)
	p.play()
	_noter(nom)
	return p


func jouer_3d(nom: String, pos: Vector3, db := 0.0, pitch := 1.0, unite := 9.0) -> void:
	if _silence:
		return
	var s := _un(nom)
	if s == null:
		return
	var p := _pool3d[_rr3]
	for i in NB_VOIX_3D:
		var k := (_rr3 + i) % NB_VOIX_3D
		if not _pool3d[k].playing:
			p = _pool3d[k]
			break
	_rr3 = (_rr3 + 1) % NB_VOIX_3D
	p.stream = s
	p.unit_size = unite
	p.global_position = pos
	p.volume_db = db + randf_range(-1.0, 1.0)
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()
	_noter(nom)


func apres(delai: float, nom: String, db := 0.0, pitch := 1.0) -> void:
	if _silence:
		return
	_file.append({"t": delai, "nom": nom, "db": db, "pitch": pitch})


## Un son qui tourne : à rappeler à chaque image avec le volume voulu (linéaire, 0 = éteint).
func boucle(id: String, nom: String, vol: float, pitch := 1.0, bus := BUS_EFFETS) -> void:
	var b = _boucles.get(id)
	if b == null:
		if vol <= 0.002:
			return
		var s := _un(nom)
		if s == null:
			return
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.bus = bus
		p.volume_db = -80.0
		add_child(p)
		b = {"p": p, "v": 0.0, "cible": 0.0, "pitch": pitch}
		_boucles[id] = b
	b.cible = maxf(float(b.cible), vol)
	b.pitch = pitch


func _lisser(delta: float) -> void:
	for id in _boucles:
		var b: Dictionary = _boucles[id]
		var p: AudioStreamPlayer = b.p
		var cible: float = b.cible
		var v: float = b.v
		v = lerpf(v, cible, 1.0 - exp(-delta * (14.0 if cible > v else 7.0)))
		b.v = v
		if v < 0.003 and cible <= 0.0:
			if p.playing:
				p.stop()
			continue
		if not p.playing:
			p.play()
			_noter("loop:" + str(id))
		p.volume_db = linear_to_db(v)
		p.pitch_scale = clampf(float(b.pitch), 0.3, 3.0)


func _differes(delta: float) -> void:
	var i := 0
	while i < _file.size():
		_file[i].t -= delta
		if _file[i].t <= 0.0:
			var e: Dictionary = _file[i]
			_file.remove_at(i)
			jouer(e.nom, e.db, e.pitch)
		else:
			i += 1


# ==================================================================================================
#  Observation du jeu
# ==================================================================================================
func _v(o: Object, nom: String, def: Variant) -> Variant:
	if o == null or not is_instance_valid(o):
		return def
	var r = o.get(nom)
	return def if r == null else r


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		jouer("ui_bascule", -8)   # T : l'époque (avant / aujourd'hui)


func _process(delta: float) -> void:
	_t += delta
	_retrouver(delta)
	for id in _boucles:
		_boucles[id].cible = 0.0
	_clavier()
	if _j != null:
		_joueur(delta)
	_graffiti()
	_habitants()
	_vehicule()
	_ambiance(delta)
	_demolition()
	_lisser(delta)
	_differes(delta)
	_silence = false


func _retrouver(delta: float) -> void:
	if not is_instance_valid(_j):
		_j = get_tree().get_first_node_in_group("player") as Node3D
		if _j != null:
			_silence = true
			_sol_prep = false
			_sol_cache.clear()
			_hab_etat.clear()
			_graf = null
			_hab = null
			_temps = null
			_cond = null
			_p_veh = null
			_g_trace_id = 0
	var sc := get_tree().current_scene
	if sc == null:
		return
	if not is_instance_valid(_graf):
		_graf = sc.get_node_or_null("Graffiti")
	if not is_instance_valid(_hab):
		_hab = sc.get_node_or_null("Habitants")
	if not is_instance_valid(_temps):
		_temps = sc.get_node_or_null("Temps")
	_recherche_t -= delta
	if not is_instance_valid(_cond) and _recherche_t <= 0.0:
		_recherche_t = 1.0
		_cond = sc.find_child("Conduite", true, false)


func _clavier() -> void:
	if InputMap.has_action("style_bd") and Input.is_action_just_pressed("style_bd"):
		jouer("ui_bascule", -8)
	for a in ["temps_demain", "temps_semaine"]:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			jouer("temps_saut", -6)
	if InputMap.has_action("graff_mode") and Input.is_action_just_pressed("graff_mode") and _graf != null:
		jouer("ui_bascule", -8)
	if Input.is_action_just_pressed("reset") and _j != null:
		jouer("respawn", -7)


# --------------------------------------------------------------------------------------------------
#  Loums : marche, saut, grimpe, planche, skate
# --------------------------------------------------------------------------------------------------
func _joueur(delta: float) -> void:
	var p := _j as CharacterBody3D
	if p == null:
		return
	var sk = p.get("skate")
	if sk == null:
		return
	var mode := int(_v(p, "mode", WALK))
	var au_sol := p.is_on_floor()
	var vel := p.velocity
	var plat := Vector2(vel.x, vel.z).length()
	var conduit: bool = is_instance_valid(_cond) and _cond.get("actuel") != null
	var chute_t := float(_v(p, "chute_t", -1.0))
	var transition := String(_v(p, "transition", ""))
	var mantle := bool(_v(p, "_mantling", false))
	var susp := bool(_v(p, "suspendu", false))
	var gout: bool = p.get("gouttiere") != null
	var bond := float(_v(p, "_bond_t", -1.0)) >= 0.0
	var trace_on: bool = is_instance_valid(_graf) and _graf.get("_trace") != null
	var ev := String(_v(sk, "last_event", ""))
	var vit := absf(float(_v(sk, "speed", 0.0)))

	# --- à pied : pas, saut, atterrissage ---
	var libre := mode == WALK and au_sol and not conduit and chute_t < 0.0 and transition == "" \
		and not mantle and not susp and not gout and not trace_on
	if libre and plat > 0.6:
		var course := plat > 4.5
		_dist_pas += plat * delta
		var foulee := 1.9 if course else 1.3
		if _dist_pas >= foulee:
			_dist_pas = fmod(_dist_pas, foulee)
			_pas(p.global_position, course)
	elif plat < 0.6:
		_dist_pas = 0.8
	if mode == WALK and not conduit and chute_t < 0.0:
		if _au_sol_avant and not au_sol and vel.y > 2.0 and not mantle and not susp and not gout:
			jouer("saut_pied", -8)
		if not _au_sol_avant and au_sol and _vy_avant < -2.5 and not mantle:
			jouer("atterri_pied", clampf(-14.0 - _vy_avant * 0.8 + 12.0, -12.0, -3.0))
	_au_sol_avant = au_sol
	_vy_avant = vel.y

	# --- grimpe ---
	if mantle and not _p_mantle:
		jouer("hisse", -4)
	if _p_mantle and not mantle:
		jouer("pas_dur", -11, 0.9)            # il se relève et pose le pied
	if susp and not _p_susp:
		jouer("main_mur", -3)
	if gout and not _p_gout:
		jouer("goutiere_agrippe", -4)
		_y_gout = p.global_position.y
		_dist_gout = 0.0
	if bond and not _p_bond:
		jouer("saut_pied", -6)
		apres(0.3, "main_mur", -4)
	if ev != _p_event:
		if ev == "Lâche":
			jouer("lache", -5)
		elif ev == "Course murale":
			jouer("course_murale", -4)
	if susp and not mantle and not bond:
		var d := Vector2(p.global_position.x - _pos_decale.x, p.global_position.z - _pos_decale.z).length()
		if d < 1.0:
			_dist_decale += d
		if _dist_decale >= 0.5:
			_dist_decale = 0.0
			jouer("decale", -8)
	_pos_decale = p.global_position
	if gout:
		_dist_gout += absf(p.global_position.y - _y_gout)
		_y_gout = p.global_position.y
		if _dist_gout >= 0.55:
			_dist_gout = 0.0
			jouer("goutiere_grimpe", -6)
	_p_mantle = mantle
	_p_susp = susp
	_p_gout = gout
	_p_bond = bond
	_p_event = ev

	# --- monter / descendre de la planche ---
	var tt := float(_v(p, "transition_t", 0.0))
	if transition != _p_trans:
		_trans_fait.clear()
	if transition == "decroche":
		if tt >= 0.10 and not _trans_fait.has("a"):
			_trans_fait["a"] = true
			jouer("planche_pose", -5)
		if tt >= 0.32 and not _trans_fait.has("b"):
			_trans_fait["b"] = true
			jouer("planche_pied", -6)
	elif transition == "accroche":
		if not _trans_fait.has("a"):
			_trans_fait["a"] = true
			jouer("planche_ramasse", -5)
		if tt >= 0.28 and not _trans_fait.has("b"):
			_trans_fait["b"] = true
			jouer("planche_range", -6)
	_p_trans = transition

	# --- chute (figure ratée) et planche qui part seule ---
	if chute_t >= 0.0 and _p_chute < 0.0:
		var fort := clampf(float(_v(sk, "vitesse_chute", 3.0)) / 9.0, 0.0, 1.0)
		jouer("chute", lerpf(-6.0, 0.0, fort))
		apres(0.14, "planche_chute", -4)
	_p_chute = chute_t
	if bool(_v(p, "planche_libre", false)):
		var pv: Vector3 = _v(p, "_planche_vel", Vector3.ZERO)
		var vs := pv.length()
		boucle("roule_planche", "roule_loop", clampf(vs / 6.0, 0.0, 1.0) * 0.4, 0.9 + vs * 0.06)
		if _p_pvel > 1.2 and vs < _p_pvel * 0.6:
			jouer("choc_planche", -5)
		_p_pvel = vs
	else:
		_p_pvel = 0.0

	# --- sur la planche ---
	if mode == SKATE and not conduit:
		var en_air := bool(_v(sk, "in_air", false))
		var grinding := bool(_v(sk, "grinding", false))
		var roule := not en_air and not grinding and transition == "" and chute_t < 0.0
		var surface := _surface(p.global_position)
		var v := clampf(vit / 9.0, 0.0, 1.0)
		var plein := pow(v, 0.7) * 0.55
		boucle("roule_dur", "roule_loop", plein if (roule and surface == "dur") else 0.0, 0.7 + 0.9 * v)
		boucle("roule_gravier", "roule_gravier_loop", plein if (roule and surface == "gravier") else 0.0, 0.7 + 0.8 * v)
		boucle("roule_herbe", "roule_herbe_loop", plein * 1.1 if (roule and surface == "herbe") else 0.0, 0.7 + 0.8 * v)
		boucle("frein", "frein_loop", clampf(vit / 6.0, 0.0, 1.0) * 0.5 if (roule and bool(_v(sk, "freine", false))) else 0.0, 0.8 + 0.05 * vit)

		var ph := float(_v(sk, "push_phase", -1.0))
		if _p_push >= 0.0 and _p_push < 0.25 and ph >= 0.25:
			jouer("pousse", -6, 0.95 + 0.02 * vit)
		_p_push = ph

		var pop := float(_v(sk, "pop_t", -1.0))
		if pop >= 0.0 and _p_pop < 0.0:
			var k := clampf((float(_v(sk, "ollie_v", 4.0)) - 4.0) / 2.0, 0.0, 1.0)
			jouer("ollie_pop", lerpf(-9.0, -3.0, k))
		_p_pop = pop

		var trick := String(_v(sk, "trick", ""))
		if trick != _p_trick:
			if trick == "Kickflip":
				jouer("kickflip", -4)
			elif trick == "Shove-it":
				jouer("shoveit", -4)
		_p_trick = trick

		if en_air:
			_air_dur = maxf(_air_dur, float(_v(sk, "air_t", 0.0)))
		var rec := float(_v(sk, "reception", 0.0))
		if rec > 0.9 and _p_reception <= 0.9:
			var fort2 := _air_dur > 0.6 or vit > 9.0
			jouer("atterri_dur" if fort2 else "atterri_leger", lerpf(-10.0, -2.0, clampf(_air_dur / 0.8, 0.0, 1.0)))
			_air_dur = 0.0
		elif not en_air and rec <= 0.0:
			_air_dur = 0.0
		_p_reception = rec

		if grinding and not _p_grind:
			var r = sk.get("_rail")
			_grind_beton = r != null and float(_v(r, "thickness", 0.08)) > 0.2
			jouer("grind_debut", -4 if not _grind_beton else -7, 0.8 if _grind_beton else 1.0)
		if _p_grind and not grinding:
			jouer("grind_fin", -6)
			if bool(_v(sk, "saute", false)):
				jouer("ollie_pop", -6)
		var gv := clampf(vit / 6.0, 0.4, 1.0)
		boucle("grind_metal", "grind_loop", 0.55 * gv if (grinding and not _grind_beton) else 0.0, 0.85 + 0.04 * vit)
		boucle("grind_beton", "grind_beton_loop", 0.6 * gv if (grinding and _grind_beton) else 0.0, 0.85 + 0.04 * vit)
		_p_grind = grinding
	else:
		_p_push = -1.0
		_p_pop = -1.0
		_p_grind = false
		_p_trick = ""


func _pas(pos: Vector3, course: bool) -> void:
	var s := _surface(pos)
	jouer("pas_" + s, -4.0 if course else -9.0, 1.08 if course else 1.0)


# --------------------------------------------------------------------------------------------------
#  Le sol : route / béton / bitume (« dur »), herbe, gravier-friche
# --------------------------------------------------------------------------------------------------
func _preparer_sols() -> void:
	_sol_prep = true
	_sol.clear()
	for groupe in ["sol_voie", "sol_zone"]:
		for n in get_tree().get_nodes_in_group(groupe):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var kind := "dur"
			if groupe == "sol_zone":
				kind = String(SOL_ZONE.get(str(mi.get_meta("type", "")), "dur"))
			var faces := mi.mesh.get_faces()
			var xf := mi.global_transform
			var tri := PackedVector2Array()
			var mn := Vector2(1e9, 1e9)
			var mx := Vector2(-1e9, -1e9)
			for f in faces:
				var w := xf * f
				var q := Vector2(w.x, w.z)
				tri.append(q)
				mn = mn.min(q)
				mx = mx.max(q)
			if tri.size() >= 3:
				_sol.append({"rect": Rect2(mn, mx - mn), "tri": tri, "kind": kind, "voie": groupe == "sol_voie"})


func _surface(pos: Vector3) -> String:
	if not _sol_prep:
		_preparer_sols()
	if _sol.is_empty():
		return "dur"
	var cle := Vector2i(floori(pos.x / 2.0), floori(pos.z / 2.0))
	if _sol_cache.has(cle):
		return _sol_cache[cle]
	var q := Vector2(pos.x, pos.z)
	var trouve := "dur"
	var gagne_voie := false
	for s in _sol:
		if not (s.rect as Rect2).has_point(q):
			continue
		if gagne_voie and not s.voie:
			continue
		var tri: PackedVector2Array = s.tri
		var i := 0
		var dedans := false
		while i + 2 < tri.size():
			if Geometry2D.point_is_inside_triangle(q, tri[i], tri[i + 1], tri[i + 2]):
				dedans = true
				break
			i += 3
		if dedans:
			trouve = s.kind
			if s.voie:
				gagne_voie = true
	if _sol_cache.size() > 6000:
		_sol_cache.clear()
	_sol_cache[cle] = trouve
	return trouve


# --------------------------------------------------------------------------------------------------
#  Graffiti
# --------------------------------------------------------------------------------------------------
func _graffiti() -> void:
	var g := _graf
	if not is_instance_valid(g):
		return
	var tr = g.get("_trace")
	var tid := 0
	if tr != null:
		tid = (tr as Object).get_instance_id()
	var type := ""
	var gt = g.get("_trace_g")
	if gt is Dictionary:
		type = str(gt.get("t", ""))
	var etape := int(_v(g, "_etape_i", 0))
	var msg := String(_v(g, "_message", ""))
	var msg_t := float(_v(g, "_message_t", 0.0))
	var reserve: Array = _v(g, "reserve", [1.0])
	var b := int(_v(g, "bombe", 0))
	var res := float(reserve[b]) if b < reserve.size() else 1.0
	var a_pied := _j != null and int(_v(_j, "mode", WALK)) == WALK

	if tid != _g_trace_id:
		if tid != 0 and _g_trace_id == 0:
			# début d'un graffiti : Loums sort la bombe (ou la perche, ou le rouleau)
			if type == "rouleau":
				jouer("rouleau_trempe", -4)
			elif type == "perche":
				jouer("perche_deplie", -4)
			else:
				jouer("bombe_secoue", -4)
			_g_etape = etape
		elif tid != 0:
			# couche suivante : la couche d'avant est finie, il change de bombe
			jouer("etape_ok", -9)
			if type != "rouleau" and type != "perche":
				apres(0.2, "bombe_change", -5)
			_g_etape = etape
		elif _g_trace_id != 0:
			# la séance s'arrête : posé, raté, ou interrompu
			var interrompu := msg.contains("partir") or msg.contains("reviens") or msg.begins_with("VU") or msg_t < 2.0
			if not interrompu:
				jouer("graff_rate" if msg.contains("raté") else "graff_pose", -6 if type == "tag" else -3)
		_g_trace_id = tid

	if tr != null:
		var age := float(_v(tr, "age", 0.0))
		var auto: bool = bool(_v(tr, "auto", false))
		var attente := float(_v(tr, "attente", 0.0))
		var appuye := bool(_v(tr, "appuye", false))
		var mode := String(_v(tr, "mode", "trait"))
		var actif := appuye and (age >= attente or not auto)
		if mode == "taper":
			var tch := int(_v(tr, "_touches", 0))
			if tch > _g_touches:
				jouer("spray_tap", -6)
			_g_touches = tch
		elif type == "rouleau":
			boucle("rouleau", "rouleau_loop", 0.5 if actif else 0.0, 1.0)
		else:
			var perche := type == "perche"
			boucle("spray", "spray_loop", (0.3 if perche else 0.45) if actif else 0.0, (0.7 if perche else 0.8) + 0.3 * res)
			if actif and not _g_actif:
				jouer("spray_debut", -8)
			if _g_actif and not actif:
				jouer("spray_fin", -8)
			_g_actif = actif
		var cs = tr.get("_coulures")
		if cs is Array:
			var n: int = (cs as Array).size()
			if n > _g_coul:
				apres(randf_range(0.1, 0.5), "goutte", -12)
			_g_coul = n
	else:
		_g_actif = false
		_g_touches = 0
		_g_coul = 0

	# hors graffiti : changer de bombe, bombe vide, conteneur
	if tr == null and a_pied:
		if Input.is_action_just_pressed("graff_color"):
			jouer("bombe_change", -5)
		var cible = g.get("_cible")
		if Input.is_action_just_pressed("graff") and cible is Dictionary and not (cible as Dictionary).is_empty() and res < 0.06:
			jouer("bombe_vide", -4)
		if Input.is_action_just_pressed("fouiller") and g.has_method("_conteneur_proche") and g.call("_conteneur_proche") != null:
			jouer("fouille", -3)
			apres(1.35, "bombes_pleines", -4)

	if msg != _g_msg:
		_g_msg = msg
		if msg.begins_with("VU"):
			jouer("vu", -6)
		elif msg.contains("fait partir"):
			jouer("chasse", -3)


# --------------------------------------------------------------------------------------------------
#  Habitants (sons placés dans l'espace)
# --------------------------------------------------------------------------------------------------
func _habitants() -> void:
	if not is_instance_valid(_hab) or _j == null:
		return
	var liste = _hab.get("habitants")
	if not (liste is Array):
		return
	var jp := _j.global_position
	for h in liste:
		if not is_instance_valid(h):
			continue
		var id: int = (h as Object).get_instance_id()
		var pos: Vector3 = (h as Node3D).global_position
		if not _hab_etat.has(id):
			_hab_etat[id] = {"pos": pos, "dist": 0.0, "bulle": false}
			continue
		var st: Dictionary = _hab_etat[id]
		var dh := Vector2(pos.x - st.pos.x, pos.z - st.pos.z).length()
		st.pos = pos
		var d := pos.distance_to(jp)
		if d < 26.0 and dh > 0.0005 and dh < 3.0:
			st.dist += dh
			if st.dist >= 0.95:
				st.dist = 0.0
				jouer_3d("pas_dur", pos, -8.0, randf_range(0.9, 1.0))
		var bulle = h.get("bulle")
		var visible: bool = bulle != null and bool(bulle.visible)
		if visible and not st.bulle and d < 45.0:
			var role := String(_v(h, "role", "passant"))
			jouer_3d("voix_" + role, pos + Vector3.UP * 1.6, -3.0, 1.0, 12.0)
		st.bulle = visible


# --------------------------------------------------------------------------------------------------
#  Scooter et voiture
# --------------------------------------------------------------------------------------------------
func _vehicule() -> void:
	if not is_instance_valid(_cond):
		return
	var v = _cond.get("actuel")
	if v != _p_veh:
		if v != null:
			var scooter := String(_v(v, "type", "voiture")) == "scooter"
			if scooter:
				jouer("bequille", -4)
				apres(0.25, "demarre_scooter", -4)
				_veh_t0 = _t + 0.8
			else:
				jouer("portiere", -3)
				apres(0.35, "demarre_voiture", -5)
				_veh_t0 = _t + 1.1
		elif _p_veh != null and is_instance_valid(_p_veh):
			var scooter2 := String(_v(_p_veh, "type", "voiture")) == "scooter"
			if _p_cabre >= 1.2 or bool(_cond.get("vient_de_chuter")):
				jouer("chute", -2)
				apres(0.1, "choc_vehicule", -5)
			else:
				jouer("coupe_scooter" if scooter2 else "coupe_voiture", -5)
				jouer("bequille" if scooter2 else "portiere", -5)
		_p_veh = v
		_p_vit = 0.0
		_p_cabre = 0.0
	# un scooter couché qui glisse sur le bitume
	boucle("racle_sol", "racle_loop", 0.7 * float(_v(_cond, "racle_sol", 0.0)), 0.8)
	if v == null:
		return
	var scooter3 := String(_v(v, "type", "voiture")) == "scooter"
	var vit := absf(float(_v(v, "vitesse", 0.0)))
	var vmax := float(_v(v, "vmax", 13.0 if scooter3 else 17.0))
	var r := clampf(vit / vmax, 0.0, 1.0)
	var cabre := float(_v(v, "cabre", 0.0))
	var gaz := Input.get_action_strength("move_forward") if _t >= _veh_t0 else 0.0
	if _t >= _veh_t0:
		if scooter3:
			boucle("moteur_scooter", "scooter_loop", 0.5 * (0.55 + 0.45 * r), 0.75 + 1.35 * r + cabre * 0.5 + 0.2 * gaz)
		else:
			boucle("moteur_voiture", "voiture_loop", 0.55 * (0.55 + 0.45 * r), 0.8 + 1.1 * r + 0.15 * gaz)
		# le vent monte avec la vitesse ; la bavette qui racle ; le pneu qui glisse en dérapage
		boucle("vent", "vent_loop", clampf((vit - 8.0) / 18.0, 0.0, 1.0) * 0.55, 0.8 + 0.5 * r)
		boucle("racle", "racle_loop", 0.6 * float(_v(v, "racle", 0.0)), 0.9 + 0.3 * r)
		if scooter3 and float(_v(v, "derive", 0.0)) > 0.4 and vit > 5.0:
			boucle("crisse", "pneu_crisse_loop", 0.35 * float(_v(v, "derive", 0.0)), 1.15 + 0.15 * r)
		elif not scooter3 and Input.is_action_pressed("jump") and vit > 4.0:
			boucle("crisse", "pneu_crisse_loop", 0.4 * r, 0.9 + 0.2 * r)
		elif Input.get_action_strength("move_back") > 0.5 and vit > 7.0:
			boucle("crisse", "pneu_crisse_loop", 0.25 * r, 0.9 + 0.2 * r)
	if _p_vit > 3.0 and vit < _p_vit * 0.55:
		jouer("choc_vehicule", lerpf(-9.0, -2.0, clampf(_p_vit / vmax, 0.0, 1.0)))
	_p_vit = vit
	_p_cabre = cabre


# --------------------------------------------------------------------------------------------------
#  Ambiance du quartier, jour et nuit
# --------------------------------------------------------------------------------------------------
func _ambiance(delta: float) -> void:
	if _j == null:
		return
	var n := 0.0
	if is_instance_valid(_temps) and _temps.has_method("nuit"):
		n = float(_temps.call("nuit"))
	boucle("amb_jour", "amb_jour_loop", 0.8 * (1.0 - n), 1.0, BUS_AMBIANCE)
	boucle("amb_nuit", "amb_nuit_loop", 0.8 * n, 1.0, BUS_AMBIANCE)
	_amb_t -= delta
	if _amb_t > 0.0:
		return
	_amb_t = randf_range(5.0, 14.0)
	var a := randf() * TAU
	var jp := _j.global_position
	var sol := Vector3(cos(a), 0.0, sin(a))
	var r := randf()
	if n < 0.5:
		if r < 0.45:
			jouer_3d("oiseau", jp + sol * randf_range(10.0, 30.0) + Vector3.UP * randf_range(5.0, 12.0), -6.0, randf_range(0.9, 1.2), 12.0)
		elif r < 0.6:
			jouer_3d("mouette", jp + sol * randf_range(25.0, 50.0) + Vector3.UP * randf_range(15.0, 30.0), -5.0, 1.0, 20.0)
		elif r < 0.92:
			jouer_3d("voiture_loin", jp + sol * randf_range(30.0, 60.0), -4.0, randf_range(0.9, 1.1), 25.0)
		elif r < 0.98:
			jouer_3d("moto_loin", jp + sol * randf_range(30.0, 60.0), -4.0, 1.0, 25.0)
		else:
			jouer_3d("sirene_loin", jp + sol * 70.0, -8.0, 1.0, 40.0)
	else:
		if r < 0.7:
			jouer_3d("voiture_loin", jp + sol * randf_range(35.0, 70.0), -7.0, randf_range(0.9, 1.1), 25.0)
		elif r < 0.9:
			jouer_3d("moto_loin", jp + sol * randf_range(35.0, 70.0), -7.0, 1.0, 25.0)
		else:
			jouer_3d("sirene_loin", jp + sol * 80.0, -10.0, 1.0, 40.0)


## La tour Cyprès B tombe le 21 juillet 2016 : le boum traverse le rechargement de la scène (Son survit).
func _demolition() -> void:
	if _t - _dem_t < 0.5:
		return
	_dem_t = _t
	var Q = load("res://scripts/quartier_reel.gd")
	var nb: int = (Q.demolies as Array).size()
	if _dem_n < 0:
		_dem_n = nb
	elif nb > _dem_n:
		_dem_n = nb
		_silence = false
		jouer("demolition", 0.0)
