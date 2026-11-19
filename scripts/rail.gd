@tool
class_name Rail
extends StaticBody3D
## Obstacle « grindable » (rail ou ledge). Il construit lui-même sa forme
## et sa collision : on le pose dans la scène, on règle les trois valeurs.
## Il s'étend le long de son axe X local, de 0 à `length`.

@export var length := 6.0:
	set(v):
		length = v
		_rebuild()
@export var height := 0.5:
	set(v):
		height = v
		_rebuild()
@export var thickness := 0.08:  ## 0.08 = rail tube, 0.4 = ledge béton
	set(v):
		thickness = v
		_rebuild()
@export var color := Color(0.55, 0.55, 0.6):
	set(v):
		color = v
		_rebuild()

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group("grindable")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
		_shape = CollisionShape3D.new()
		add_child(_shape)
	var size := Vector3(length, height, thickness)
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.6 if thickness < 0.2 else 0.0
	box_mesh.material = mat
	_mesh.mesh = box_mesh
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	_shape.shape = box_shape
	var center := Vector3(length * 0.5, height * 0.5, 0.0)
	_mesh.position = center
	_shape.position = center


## Début et fin de l'arête supérieure, en coordonnées globales.
func top_start() -> Vector3:
	return to_global(Vector3(0.0, height, 0.0))


func top_end() -> Vector3:
	return to_global(Vector3(length, height, 0.0))
