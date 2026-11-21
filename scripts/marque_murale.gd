extends RefCounted
## TRACE — poser un motif (tag, fresque, enseigne, affiche) sur un mur (conversation n°2).
## Sur PC (Forward+) : un Decal, qui épouse le relief. En version web et mobile (rendu « gl_compatibility »),
## Godot ne dessine pas les Decal : on pose à la place un quad transparent collé au mur.
## `surface` = point sur la face du mur ; `le_long` = direction du mur ; `dehors` = normale vers l'extérieur.

const SHADER := preload("res://shaders/bd_marque.gdshader")
static var _mats := {}


static func sans_decal() -> bool:
	return OS.has_feature("web") or RenderingServer.get_current_rendering_method() == "gl_compatibility"


static func poser(parent: Node, tex: Texture2D, surface: Vector3, le_long: Vector3, dehors: Vector3, largeur: float, teinte := Color.WHITE, fondu := 55.0, ordre := 0, nom := "Marque") -> Node3D:
	if tex == null:
		return null
	var x := le_long.normalized()
	var y := dehors.normalized()
	var ratio := float(tex.get_height()) / float(tex.get_width())
	if not sans_decal():
		var dec := Decal.new()
		dec.texture_albedo = tex
		dec.modulate = teinte
		dec.size = Vector3(largeur, 0.8, largeur * ratio)
		dec.normal_fade = 0.4
		dec.distance_fade_enabled = true
		dec.distance_fade_begin = fondu
		dec.distance_fade_length = fondu * 0.25
		dec.sorting_offset = ordre
		dec.transform = Transform3D(Basis(x, y, x.cross(y)), surface + y * 0.1)
		dec.name = nom
		parent.add_child(dec, true)
		return dec
	var haut := y.cross(x)   # le haut de l'image
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(largeur, largeur * ratio)
	mi.mesh = q
	var cle := "%d|%s|%d" % [tex.get_instance_id(), teinte.to_html(), int(fondu)]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("motif", tex)
		m.set_shader_parameter("teinte", teinte)
		m.set_shader_parameter("fondu_debut", fondu)
		m.set_shader_parameter("fondu_long", fondu * 0.25)
		_mats[cle] = m
	mi.material_override = _mats[cle]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(x, haut, y), surface + y * (0.025 + 0.004 * ordre))
	mi.name = nom
	parent.add_child(mi, true)
	return mi
