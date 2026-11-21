extends RefCounted
## TRACE — arbres de Marseille (conversation n°2). Modèles générés par assets/decor/source/arbres/arbres.py
## (platanes, micocouliers, pins parasols, pins d'Alep, cyprès), textures par textures_arbres.py.
## arbre("platane", graine) → un Node3D prêt à poser, pied à l'origine, matériaux en place.

const DOSSIER := "res://assets/decor/arbres/"
const VARIANTES := {"platane": 4, "feuillu": 3, "pin_parasol": 4, "pin_alep": 3, "cypres": 2}
const TEXTURE := {"platane": "platane", "feuillu": "feuillu", "pin_parasol": "pin", "pin_alep": "pin", "cypres": "cypres"}
const FEUILLAGE := preload("res://shaders/feuillage.gdshader")

static var _scenes := {}
static var _mats := {}


static func hauteur_type(espece: String) -> float:
	return {"platane": 9.5, "feuillu": 7.3, "pin_parasol": 10.4, "pin_alep": 6.1, "cypres": 10.6}.get(espece, 8.0)


static func arbre(espece: String, graine: int) -> Node3D:
	var n: int = VARIANTES.get(espece, 0)
	if n == 0:
		return null
	var nom := "%s_%d" % [espece, absi(graine) % n]
	if not _scenes.has(nom):
		var chemin := DOSSIER + nom + ".glb"
		_scenes[nom] = load(chemin) if ResourceLoader.exists(chemin) else null
	var ps = _scenes[nom]
	if ps == null:
		return null
	var a := (ps as PackedScene).instantiate() as Node3D
	var tex: String = TEXTURE[espece]
	for mi in a.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for s in m.mesh.get_surface_count():
			var orig := m.mesh.surface_get_material(s)
			var nm := orig.resource_name if orig else ""
			m.set_surface_override_material(s, _feuilles(tex) if nm == "feuilles" else _ecorce(tex))
	a.name = "Arbre_" + espece
	return a


static func _feuilles(tex: String) -> ShaderMaterial:
	var cle := "f_" + tex
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = FEUILLAGE
		m.set_shader_parameter("feuilles", load(DOSSIER + "feuilles_%s.png" % tex))
		_mats[cle] = m
	return _mats[cle]


static func _ecorce(tex: String) -> ShaderMaterial:
	# directement en matériau BD (les MultiMesh ne passent pas par style_bd.gd)
	var cle := "e_" + tex
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/bd_toon.gdshader")
		m.set_shader_parameter("texture_couleur", load(DOSSIER + "ecorce_%s.png" % tex))
		m.set_shader_parameter("avec_texture", true)
		m.set_shader_parameter("paliers", 8.0)
		m.set_shader_parameter("grain", 0.3)
		_mats[cle] = m
	return _mats[cle]


## Le maillage d'une variante, matériaux posés (pour les MultiMesh : forêts, alignements relevés).
static func maillage(nom: String) -> Mesh:
	var cle := "m_" + nom
	if _scenes.has(cle):
		return _scenes[cle]
	var espece := nom.substr(0, nom.rfind("_"))
	var chemin := DOSSIER + nom + ".glb"
	if not ResourceLoader.exists(chemin):
		_scenes[cle] = null
		return null
	var sc := (load(chemin) as PackedScene).instantiate()
	var mi := sc.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var m := mi.mesh.duplicate() as ArrayMesh
	var tex: String = TEXTURE[espece]
	for s in m.get_surface_count():
		var orig := m.surface_get_material(s)
		var nm := orig.resource_name if orig else ""
		m.surface_set_material(s, _feuilles(tex) if nm == "feuilles" else _ecorce(tex))
	sc.free()
	_scenes[cle] = m
	return m
