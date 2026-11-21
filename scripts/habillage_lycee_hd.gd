extends "res://scripts/habillage_lycee.gd"

# Le propriétaire de chaque forme garde la transformation exacte de la collision.
# Les petits corps spatiaux évitent de reconstruire un grand assemblage à chaque ajout.
var _secteurs_physiques := {}
var _boites_partagees := {}

func _boite(b: Basis, taille: Vector3, o: Vector3) -> void:
	var cellule := Vector3i(floori(o.x / 16.0), floori(o.y / 4.0), floori(o.z / 16.0))
	var corps: StaticBody3D = _secteurs_physiques.get(cellule)
	if corps == null:
		corps = StaticBody3D.new()
		_secteurs_physiques[cellule] = corps
		_corps.add_child(corps)
	var forme: BoxShape3D = _boites_partagees.get(taille)
	if forme == null:
		forme = BoxShape3D.new()
		forme.size = taille
		_boites_partagees[taille] = forme
	var id := corps.create_shape_owner(corps)
	corps.shape_owner_set_transform(id, Transform3D(b.orthonormalized(), o))
	corps.shape_owner_add_shape(id, forme)
