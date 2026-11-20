extends Node3D
## Visite de la façade ancienne, indépendante de la chronologie sauvegardée de TRACE.
var mission_active: bool
var mission_visible: bool

func _enter_tree() -> void:
	var mission = get_node("/root/Mission")
	mission_active = mission.is_processing()
	mission_visible = mission.visible
	mission.set_process(false)
	mission.hide()

func _ready() -> void:
	var p = $Player
	var point := Vector2(141.2,83.0)
	p.spawn_position = Vector3(point.x,$Quartier.h(point.x,point.y)+0.18,point.y)
	p._respawn()
	p.camera_pivot.rotation.y = deg_to_rad(125.)
	p.visual.rotation.y = p.camera_pivot.rotation.y
	p.spring_arm.rotation.x = -0.04

func _exit_tree() -> void:
	var mission = get_node_or_null("/root/Mission")
	if mission:
		mission.set_process(mission_active)
		mission.visible = mission_visible
