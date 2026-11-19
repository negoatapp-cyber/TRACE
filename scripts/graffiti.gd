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
const LARGEUR := {"tag": 0.9, "flop": 2.2, "piece": 3.8, "perche": 1.3, "rouleau": 5.6}   ## largeur sur le mur (m)
## Hauteur du centre du graffiti au-dessus des pieds (la perche monte le tag à plus de 4 m).
const HAUTEUR := {"tag": 1.45, "flop": 1.55, "piece": 1.9, "perche": 4.3, "rouleau": 1.35}
const NB_TAGS := 4
const PORTEE := 2.2
## Le tag se trace à la main (appui bref sur G). Maintenir G : flop, puis pièce.
const PALIERS := [["flop", 1.0], ["piece", 2.6]]
const APPUI_BREF := 0.35
const COULEURS := [Color(0.92, 0.15, 0.45), Color(0.12, 0.12, 0.14), Color(0.95, 0.95, 0.92), Color(0.15, 0.55, 0.95), Color(0.98, 0.82, 0.10), Color(0.25, 0.75, 0.35), Color(0.80, 0.15, 0.15), Color(0.55, 0.30, 0.80)]

@export var blaze := "LOUMS"

## Ce que coûte chaque taille, en part d'une bombe pleine.
const COUT := {"tag": 0.06, "flop": 0.25, "piece": 0.6, "perche": 0.08, "rouleau": 0.0}
var expert := false                 ## mode expert : on trace soi-même sur le calque ; sinon Loums peint tout seul
const DUREE_SIMPLE := {"tag": 1.6, "perche": 2.4, "flop": 2.0, "piece": 2.0, "rouleau": 4.5}   ## durée d'une couche (s)
var pot := 1.0                      ## peinture du rouleau (le pot, dans le sac), remplie au conteneur
const PORTEE_CONTENEUR := 3.5

var ceinture := [0, 4, 3, 1]        ## couleurs des quatre bombes (indices dans COULEURS)
var reserve := [1.0, 1.0, 1.0, 1.0]  ## peinture restante dans chaque bombe (0 → 1)
var bombe := 0                       ## bombe en main
var couleur := 0
var tenue := 0.0
var poses: Array = []       # tout ce qui est sur les murs (sauvegardé)
var compte := {"tag": 0, "flop": 0, "piece": 0, "perche": 0, "rouleau": 0}

var _joueur: Player
var _texte: Label
var _barre: ProgressBar
var _pastille: ColorRect
var _cible := {}
var _jauges: HBoxContainer
var _textures := {}
var _noeuds := {}              ## indice dans poses -> nœud dessiné
var _reprise := -1             ## indice (dans poses) d'un flop ou d'une pièce inachevés qu'on reprend
var _chantier: Node3D          ## le graffiti en cours : une couche par étape
var _etapes: Array = []
var _etape_i := 0
## Chargés par chemin (et non par nom de classe) : le jeu marche même lancé sans passer par l'éditeur.
const TRACE_TAG := preload("res://scripts/trace_tag.gd")
const AIDE := preload("res://scripts/aide.gd")
var _trace: TRACE_TAG          ## la couche en cours de tracé à la main
var _trace_g := {}
var _camera_trace: Camera3D
var _attendre_relache := false
var _message := ""
var _message_t := 0.0


func _ready() -> void:
	_joueur = get_node_or_null("../Player") as Player
	_interface()
	_charger()
	var aide := AIDE.new()
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
		var e: Dictionary = _etapes[_etape_i]
		_texte.text = "%s   ·   %d/%d : %s" % [NOMS[_trace_g.t], _etape_i + 1, _etapes.size(), e.titre] if _etapes.size() > 1 else (("TRACE TON TAG" if expert else "TAG") if _trace_g.t == "tag" else NOMS[_trace_g.t])
		if _message_t > 0.0 and _message.begins_with("VU"):
			_texte.text += "\n" + _message
		_barre.visible = false
		if _trace.fini_de_taper():
			_etape_finie(_trace.peinture, _trace.qualite())
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
	if InputMap.has_action("graff_mode") and Input.is_action_just_pressed("graff_mode"):
		basculer_mode()
	for a in RACCOURCIS:
		if peut and InputMap.has_action(a) and Input.is_action_just_pressed(a):
			commande_tactile(RACCOURCIS[a])
			return
	if peut and Input.is_action_pressed("graff") and reserve[bombe] >= COUT["tag"]:
		tenue = minf(tenue + delta, PALIERS[1][1] + 0.2)
		# On ne peut pas choisir plus gros que ce que la bombe contient encore.
		for p in PALIERS:
			if reserve[bombe] < COUT[p[0]]:
				tenue = minf(tenue, p[1] - 0.01)
				break
	elif tenue > 0.0:
		var type := _palier()
		var a_reprendre := _a_reprendre()
		if peut and tenue < APPUI_BREF and a_reprendre >= 0:
			_commencer(poses[a_reprendre].t, a_reprendre)
		elif peut and tenue < APPUI_BREF:
			_commencer("tag")
		elif peut and type != "":
			_commencer(type)
		tenue = 0.0
	_afficher(peut)


const NOMS := {"tag": "TAG", "flop": "FLOP", "piece": "PIÈCE", "perche": "PERCHE", "rouleau": "ROULEAU"}
## Raccourcis clavier : 1 tag, 2 flop, 3 pièce, 4 perche, 5 rouleau (en plus de G).
const RACCOURCIS := {"graff_1": "tag", "graff_2": "flop", "graff_3": "piece", "graff_4": "perche", "graff_5": "rouleau"}


func couleur_en_cours() -> Color:
	return COULEURS[int(_trace_g.get("c", couleur)) % COULEURS.size()]


## Un habitant a vu Loums peindre (habitants.gd) : noté dans le graffiti en cours.
func vu_par(role: String) -> void:
	if _trace_g.is_empty():
		return
	var t: Array = _trace_g.get("temoins", [])
	t.append(role)
	_trace_g["temoins"] = t
	var qui := {"passant": "un passant", "voisine": "une voisine", "gardien": "le gardien", "jeune": "les jeunes"}
	_message = "VU par %s" % qui.get(role, role)
	_message_t = 2.5


## Le gardien arrive : on arrête là (un flop ou une pièce restent au mur, à moitié faits).
func chasse_par(qui: String) -> void:
	if _trace == null:
		return
	_interrompre()
	_message = "%s t'a fait partir" % (qui.substr(0, 1).to_upper() + qui.substr(1))
	_message_t = 3.5


## Simple (Loums peint tout seul) ou expert (on trace soi-même sur le calque).
func basculer_mode() -> void:
	expert = not expert
	_message = "Graffiti : mode %s" % ("EXPERT (tu traces toi-même)" if expert else "SIMPLE (Loums peint tout seul)")
	_message_t = 3.0
	_sauver()


## Pour les boutons du téléphone.
func peut_graffer() -> bool:
	return _trace == null and not _cible.is_empty() and _joueur.mode == Player.Mode.WALK and _joueur.is_on_floor()


func a_reprendre_ici() -> bool:
	return _a_reprendre() >= 0


func commande_tactile(c: String) -> void:
	if not peut_graffer():
		return
	if c == "reprendre":
		var i := _a_reprendre()
		if i >= 0:
			_commencer(poses[i].t, i)
	elif c == "rouleau" and pot < 0.1:
		_message = "Pot vide   ·   conteneur derrière la grande barre"
		_message_t = 3.0
	elif reserve[bombe] >= COUT[c]:
		_commencer(c)


## Un flop ou une pièce inachevés, sur le mur qu'on regarde : un appui bref les reprend.
func _a_reprendre() -> int:
	if _cible.is_empty():
		return -1
	var p: Vector3 = _cible.position
	for i in range(poses.size() - 1, -1, -1):
		var g: Dictionary = poses[i]
		if g.has("imgs") and not g.get("fini", true) and Vector2(g.x - p.x, g.z - p.z).length() < 2.5:
			return i
	return -1


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


## Le masque d'une couche du lettrage, à la résolution de travail.
func _masque(nom: String, px: int) -> Image:
	var t := _texture(nom)
	if t == null:
		return null
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(px, int(round(img.get_height() * float(px) / img.get_width())), Image.INTERPOLATE_BILINEAR)
	return img


## La bande entre deux masques (ex. le contour = la forme du contour moins le fond).
func _bande(dehors: Image, dedans: Image) -> Image:
	var r := dehors.duplicate()
	for y in r.get_height():
		for x in r.get_width():
			if dedans.get_pixel(x, y).a > 0.5:
				r.set_pixel(x, y, Color(1, 1, 1, 0))
	return r


## Les étapes d'un graffiti, dans l'ordre de la règle (Louma) :
##   tag   : un trait ;
##   flop  : fond (balayé), contour (tracé) ; le surcontour se fait tout seul ;
##   pièce : esquisse (déjà là), fond (balayé), contour (tracé), lights (tapées en rythme),
##           surcontour (balayé), signature (petit tag tracé).
func _etapes_de(g: Dictionary, avec_guides := true) -> Array:
	var G := avec_guides
	var c: Color = COULEURS[int(g.c) % COULEURS.size()]
	var autre: Color = COULEURS[(int(g.c) + 3) % COULEURS.size()]
	var contour := ENCRE if c.get_luminance() > 0.35 else Color(0.97, 0.96, 0.92)
	var lumiere := Color(1, 0.99, 0.95)
	match g.t:
		"tag":
			return [{"nom": "tag", "titre": "le trait", "guide": _masque("tag_%d" % (int(g.v) % NB_TAGS + 1), 450) if G else null, "geste": "trait", "rayon": 7.0, "teinte": c, "largeur": LARGEUR.tag}]
		"perche":
			# un tag au bout de la perche : plus gros, et le trait suit la main avec retard (moins précis)
			return [{"nom": "tag", "titre": "le tag à la perche", "guide": _masque("tag_%d" % (int(g.v) % NB_TAGS + 1), 450) if G else null, "geste": "trait", "rayon": 8.0, "teinte": c, "largeur": LARGEUR.perche, "inertie": 0.12}]
		"rouleau":
			# grosses lettres pleines au rouleau, en une passe : on balaie lettre après lettre
			return [{"nom": "lettres", "titre": "les lettres au rouleau", "guide": _masque("rouleau", 640) if G else null, "geste": "remplir", "rayon": 16.0, "teinte": c, "largeur": LARGEUR.rouleau}]
		"flop":
			var f := _masque("flop_fond", 512) if G else null
			var ct := _masque("flop_contour", 512) if G else null
			return [
				{"nom": "fond", "titre": "le fond", "guide": f, "geste": "remplir", "rayon": 12.0, "teinte": c, "largeur": LARGEUR.flop},
				{"nom": "contour", "titre": "le contour", "guide": _bande(ct, f) if G else null, "geste": "trait", "rayon": 7.0, "teinte": contour, "largeur": LARGEUR.flop},
			]
		"piece":
			var f := _masque("piece_fond", 600) if G else null
			var ct := _masque("piece_contour", 600) if G else null
			var sc := _masque("piece_surcontour", 600) if G else null
			return [
				{"nom": "fond", "titre": "le fond", "guide": f, "geste": "remplir", "rayon": 11.0, "teinte": c, "largeur": LARGEUR.piece},
				{"nom": "contour", "titre": "le contour", "guide": _bande(ct, f) if G else null, "geste": "trait", "rayon": 6.0, "teinte": contour, "largeur": LARGEUR.piece},
				{"nom": "lights", "titre": "les lights", "guide": _masque("piece_lights", 600) if G else null, "geste": "taper", "rayon": 6.0, "teinte": lumiere, "largeur": LARGEUR.piece},
				{"nom": "surcontour", "titre": "le surcontour", "guide": _bande(sc, ct) if G else null, "geste": "remplir", "rayon": 10.0, "teinte": autre, "largeur": LARGEUR.piece},
				{"nom": "signature", "titre": "la signature", "guide": _masque("tag_4", 300) if G else null, "geste": "trait", "rayon": 4.0, "teinte": ENCRE,
					"largeur": LARGEUR.piece * 0.22, "decalage": Vector2(LARGEUR.piece * 0.42, -0.62)},
			]
	return []


## Ce que le joueur doit faire à l'étape en cours (pour l'aide à l'écran).
func consigne() -> Array:
	if _trace == null:
		return []
	var e: Dictionary = _etapes[_etape_i]
	if not expert:
		return [["G", "finir la couche tout de suite"], ["Échap", "s'arrêter là" if _etapes.size() > 1 else "laisser tomber"], ["M", "passer en mode expert (tracer soi-même)"]]
	var geste := {"trait": "repasser sur le trait (maintenir)", "remplir": "balayer pour remplir (maintenir)", "taper": "taper quand l'anneau se referme"}
	var suite := "étape suivante" if _etape_i < _etapes.size() - 1 else "poser"
	return [["Clic", geste[e.geste]], ["G", suite], ["Échap", "s'arrêter là (on reviendra)" if _etapes.size() > 1 else "laisser tomber"]]


## Commence un tag, un flop ou une pièce (ou reprend celui qui est inachevé à l'indice donné).
## La caméra se met face au mur, la première couche apparaît en fantôme.
func _commencer(type: String, reprise := -1, variante := -1) -> void:
	tenue = 0.0
	_reprise = reprise
	var g: Dictionary
	if reprise >= 0:
		g = (poses[reprise] as Dictionary).duplicate(true)
		var vieux: Node = _noeuds.get(reprise)
		if vieux:
			vieux.visible = false
	else:
		g = _nouveau(type)
		g["a"] = 0.0
		if variante >= 0:
			g["v"] = variante
		if type != "tag" and type != "perche":
			g["imgs"] = {}
			g["e"] = 0
			g["fini"] = false
	_trace_g = g
	_etapes = _etapes_de(g)
	if _etapes.is_empty() or _etapes[0].guide == null:
		_trace_g = {}
		return
	_etape_i = int(g.get("e", 0))
	_chantier = Node3D.new()
	_chantier.name = "Chantier"
	add_child(_chantier)
	_placer(_chantier, g)
	# Une pièce commence avec son esquisse au mur ; les couches déjà faites (reprise) sont là.
	if type == "piece":
		var esq := _texture("piece_esquisse")
		if esq:
			_chantier.add_child(_calque(esq, LARGEUR.piece, Color(0.2, 0.2, 0.22, 0.55), -1))
	for i in _etape_i:
		var deja := _texture(g.imgs.get(_etapes[i].nom, ""))
		if deja:
			var sp := _calque(deja, _etapes[i].largeur, _etapes[i].teinte, i)
			var d: Vector2 = _etapes[i].get("decalage", Vector2.ZERO)
			sp.position += Vector3(d.x, d.y, 0)
			_chantier.add_child(sp)
	var n := Vector3(g.nx, 0, g.nz)
	var droite := (-n).cross(Vector3.UP).normalized()
	var centre := _chantier.global_position
	var l: float = LARGEUR[type]
	_joueur.global_position = Vector3(g.x, float(g.y), g.z) + n * 0.55 - droite * 0.38
	_joueur.velocity = Vector3.ZERO
	_joueur.visual.rotation.y = atan2(n.x, n.z)
	_joueur.set_physics_process(false)
	_joueur.set_process_unhandled_input(false)
	_camera_trace = Camera3D.new()
	_camera_trace.fov = 55.0
	add_child(_camera_trace)
	_camera_trace.global_position = centre + n * (0.95 * l + 0.6) + droite * (0.15 * l + 0.4) + Vector3.UP * 0.2
	_camera_trace.look_at(centre, Vector3.UP)
	_camera_trace.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_lancer_etape()


func _lancer_etape() -> void:
	var e: Dictionary = _etapes[_etape_i]
	_trace = TRACE_TAG.new()
	_trace.name = "Couche_" + e.nom
	_chantier.add_child(_trace)
	_trace.preparer(e.guide, e.teinte, e.largeur, e.guide.get_width(), e.rayon, e.geste)
	_trace.inertie = e.get("inertie", 0.0)
	if not expert:
		# le temps de sortir la bombe (ou de prendre la perche dans le dos) avant de peindre
		var attente := 0.7 if _etape_i == 0 and (_trace_g.t == "perche" or _trace_g.t == "rouleau") else (0.4 if _etape_i == 0 else 0.0)
		_trace.attente = attente
		_trace.vertical = _trace_g.t == "rouleau"
		_trace.lancer_auto(float(DUREE_SIMPLE.get(_trace_g.t, 2.0)))
	var d: Vector2 = e.get("decalage", Vector2.ZERO)
	_trace.position = Vector3(d.x, d.y, 0.003 * (_etape_i + 1))
	_trace.camera = _camera_trace
	_trace.fini.connect(_etape_finie)
	_trace.annule.connect(_interrompre)


func g_type_bombe(t: String) -> bool:
	return t != "rouleau"


## Une couche est finie : on l'enregistre, puis on passe à la suivante (ou on pose le graffiti).
func _etape_finie(img: Image, q: Dictionary) -> void:
	var e: Dictionary = _etapes[_etape_i]
	if q.couverture < 0.05 and e.geste != "taper":
		_interrompre()
		return
	if g_type_bombe(_trace_g.t):
		reserve[bombe] = maxf(0.0, reserve[bombe] - clampf(_trace.depose * 0.00007, 0.01, 0.3))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://traces"))
	var chemin := "user://traces/%s_%s_%d_%d.png" % [_trace_g.t, e.nom, Time.get_unix_time_from_system(), randi() % 100000]
	img.save_png(ProjectSettings.globalize_path(chemin))
	var g := _trace_g
	var notes: Dictionary = g.get("notes", {})
	notes[e.nom] = snappedf(q.note, 0.01)
	g["notes"] = notes
	if g.t == "rouleau":
		pot = maxf(0.0, pot - clampf(_trace.depose * 0.00002, 0.05, 0.5))
	if g.t == "tag" or g.t == "perche":
		g["img"] = chemin
		g["q"] = snappedf(q.note, 0.01)
	else:
		g.imgs[e.nom] = chemin
		g["e"] = _etape_i + 1
	if OS.get_cmdline_user_args().has("--debug-graffiti"):
		print("qualité ", e.nom, " ", q)
	_message = "%s %s   ·   %s" % [e.titre.substr(0, 1).to_upper() + e.titre.substr(1), q.mot, ("%d coulure%s" % [q.coulures, "s" if q.coulures > 1 else ""]) if q.coulures > 0 else "%d %%" % int(q.couverture * 100)]
	_message_t = 3.0
	_trace.figer(_etape_i)
	_trace = null
	_etape_i += 1
	if _etape_i < _etapes.size():
		_lancer_etape()
		return
	if g.t != "tag" and g.t != "perche":
		g["fini"] = true
		var somme := 0.0
		for k in notes:
			somme += float(notes[k])
		g["q"] = snappedf(somme / maxf(1.0, notes.size()), 0.01)
		_message = "%s posé   ·   %s" % [NOMS[g.t], "propre" if g.q >= 0.7 else ("correct" if g.q >= 0.45 else "raté")]
	_enregistrer(g)
	_sortir_trace()


## Échap (ou une couche laissée vide) : un tag est abandonné ; un flop ou une pièce restent
## au mur tels quels, et un appui bref sur G devant eux les reprend où on les a laissés.
func _interrompre() -> void:
	var g := _trace_g
	if g.has("imgs") and int(g.get("e", 0)) > 0:
		_enregistrer(g)
		_message = "%s en cours : reviens le finir (G bref devant le mur)" % NOMS[g.t]
		_message_t = 3.5
	elif _reprise >= 0:
		var vieux: Node = _noeuds.get(_reprise)
		if vieux:
			vieux.visible = true
	_sortir_trace()


func _enregistrer(g: Dictionary) -> void:
	if _reprise >= 0:
		var vieux: Node = _noeuds.get(_reprise)
		if vieux:
			vieux.queue_free()
		poses[_reprise] = g
		_dessiner(g, _reprise)
	else:
		poses.append(g)
		_dessiner(g, poses.size() - 1)
	_sauver()


## Compatibilité : l'ancien nom, encore utilisé par les captures.
func _commencer_trace(variante := -1) -> void:
	_commencer("tag", -1, variante)


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
	_etape_finie(img, q)


func _sortir_trace() -> void:
	_trace = null
	if _chantier:
		_chantier.queue_free()
		_chantier = null
	_etapes = []
	_reprise = -1
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
	return {
		"t": type, "c": couleur, "b": blaze,
		"x": p.x, "y": _joueur.global_position.y, "z": p.z,
		"nx": n.x, "nz": n.z, "a": randf_range(-0.06, 0.06) if type == "piece" else randf_range(-0.10, 0.10),
		"v": randi() % NB_TAGS,
	}


func _texture(nom: String) -> Texture2D:
	if nom == "":
		return null
	if not _textures.has(nom):
		var tex: Texture2D = null
		if nom.begins_with("user://"):
			# tag tracé par le joueur, enregistré à part
			var img := Image.load_from_file(ProjectSettings.globalize_path(nom))
			if img:
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
		else:
			var chemin := LETTRAGE + nom + ".png"
			if ResourceLoader.exists(chemin):
				tex = load(chemin) as Texture2D
			elif FileAccess.file_exists(ProjectSettings.globalize_path(chemin)):
				# pas encore importé par l'éditeur : on lit l'image directement
				var brute := Image.load_from_file(ProjectSettings.globalize_path(chemin))
				if brute:
					brute.generate_mipmaps()
					tex = ImageTexture.create_from_image(brute)
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
	if g.has("imgs"):
		return _dessiner_couches(g)
	var etape: int = int(g.get("e", 99))   # étapes visibles (aperçu pendant qu'on peint)
	match g.t:
		"tag", "perche":
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


## Un flop ou une pièce peints à la main : les couches enregistrées, dans l'ordre de la peinture,
## avec le surcontour automatique (flop) ou le second surcontour (pièce) une fois fini.
func _dessiner_couches(g: Dictionary) -> Node3D:
	var racine := Node3D.new()
	var fini: bool = g.get("fini", false)
	var troisieme: Color = COULEURS[(int(g.c) + 5) % COULEURS.size()]
	var autre: Color = COULEURS[(int(g.c) + 3) % COULEURS.size()]
	if fini and (g.t == "flop" or g.t == "piece"):
		var auto := _texture("flop_surcontour" if g.t == "flop" else "piece_surcontour2")
		if auto:
			racine.add_child(_calque(auto, LARGEUR[g.t], autre if g.t == "flop" else troisieme, 0))
	elif g.t == "piece":
		var esq := _texture("piece_esquisse")
		if esq:
			racine.add_child(_calque(esq, LARGEUR.piece, Color(0.2, 0.2, 0.22, 0.55), 0))
	var k := 1
	for e in _etapes_de(g, false):
		var t := _texture(g.imgs.get(e.nom, ""))
		if t == null:
			continue
		var sp := _calque(t, e.largeur, e.teinte, k)
		var d: Vector2 = e.get("decalage", Vector2.ZERO)
		sp.position += Vector3(d.x, d.y, 0)
		racine.add_child(sp)
		k += 1
	return racine


func _placer(n: Node3D, g: Dictionary) -> void:
	var nn := Vector3(g.nx, 0, g.nz)
	var h: float = HAUTEUR.get(g.t, 1.5)
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
	pot = 1.0
	var depart: int = (int(ceinture[0]) + 1) % COULEURS.size()
	for i in ceinture.size():
		ceinture[i] = (depart + i * 2) % COULEURS.size()
		reserve[i] = 1.0
	_joueur.skate.last_event = "Quatre bombes pleines"
	_sauver()


func _sauver() -> void:
	var f := FileAccess.open(SAUVEGARDE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"murs": poses, "ceinture": ceinture, "reserve": reserve, "pot": pot, "expert": expert}))


func _charger() -> void:
	if not FileAccess.file_exists(SAUVEGARDE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAUVEGARDE))
	if data is Dictionary:
		if data.get("ceinture") is Array and data.ceinture.size() == 4:
			ceinture = data.ceinture.map(func(v): return int(v))
		if data.get("reserve") is Array and data.reserve.size() == 4:
			reserve = data.reserve.map(func(v): return float(v))
		pot = float(data.get("pot", 1.0))
		expert = bool(data.get("expert", false))
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
	_barre.max_value = PALIERS[1][1]
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
		if p != "":
			_texte.text = "%s   (relâche pour commencer)" % noms[p]
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
