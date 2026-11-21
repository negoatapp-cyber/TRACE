extends Node3D
## Adaptation de jeu demandée : six jardinières, cour ouverte et curb grindable.
## Repère du quartier, indépendant de la rotation du modèle de tour.
const SOL := 3.5   ## = greffe_paix.gd PLATEAU_Y (place de la Tour à sa cote réelle, 21.11)
const TOON := preload("res://shaders/bd_toon.gdshader")

func boite(nom: String, p: Vector3, taille: Vector3, couleur: Color, solide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	var forme := BoxMesh.new()
	forme.size = taille
	mi.mesh = forme
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("couleur", couleur)
	mat.set_shader_parameter("grain", 0.10)
	mi.material_override = mat
	mi.position = p
	add_child(mi)
	if solide:
		mi.create_trimesh_collision()
	return mi

func _ready() -> void:
	name = "CourArriereCypres"
	add_to_group("cour_arriere_cypres")
	# Ouvrir uniquement l'axe de skate ; conserver les arbres des côtés.
	for arbre in get_tree().get_nodes_in_group("arbre"):
		var p: Vector3 = arbre.global_position
		if p.x > -27 and p.x < -23 and p.z > -40 and p.z < -4:
			arbre.queue_free()
	# Sol mince, même cote que le terrain recalé : aucun escalier artificiel.
	# la cour s'arrête au palier du grand escalier (z = -11,6), qui descend vers la place des pins
	boite("SolCour", Vector3(-25,SOL-0.035,-24.8), Vector3(16,0.09,26.4), Color(0.46,0.45,0.43), true)
	for x in [-29.0,-20.0]:
		for z in [-33.0,-22.0,-13.8]:
			_jardiniere(Vector3(x,SOL,z))
	# Long axe de roulement, 7 m libres de part et d'autre en bout de curb.
	var curb := Rail.new()
	curb.name = "CurbArriereSkatable"
	curb.length = 8.0
	curb.height = 0.25
	curb.thickness = 0.45
	curb.color = Color(0.70,0.69,0.65)
	curb.position = Vector3(-25,SOL,-18)
	curb.rotation.y = PI * 0.5
	add_child(curb)
	curb.add_to_group("curb_cypres")
	curb.add_to_group("muret")
	# Bande supérieure usée : même hauteur que la collision, sans marche parasite.
	boite("UsureCurb", Vector3(-25,SOL+0.251,-22), Vector3(0.36,0.002,7.8),Color(0.79,0.78,0.72))
	print("Cour arrière Cyprès : six jardinières et curb grindable de 8 m")

func _jardiniere(p: Vector3) -> void:
	var groupe := Node3D.new()
	groupe.name = "JardiniereArriere"
	groupe.position = p
	add_child(groupe)
	groupe.add_to_group("jardinieres_arriere_cypres")
	var beton := Color(0.66,0.64,0.57)
	# Quatre parois : la terre est en retrait, la jardinière n'est pas un bloc plein.
	for dx in [-1.0,1.0]:
		var mur := boite("ParoiJardiniere",p+Vector3(dx,0.23,0),Vector3(0.18,0.46,2.4),beton,true)
		mur.reparent(groupe,true)
	for dz in [-1.11,1.11]:
		var mur := boite("ParoiJardiniere",p+Vector3(0,0.23,dz),Vector3(1.82,0.46,0.18),beton,true)
		mur.reparent(groupe,true)
	var terre := boite("Terre",p+Vector3(0,0.34,0),Vector3(1.82,0.08,2.04),Color(0.28,0.24,0.17),true)
	terre.reparent(groupe,true)
	for i in 3:
		var arbuste := MeshInstance3D.new()
		arbuste.name = "Arbuste"
		var forme := SphereMesh.new()
		forme.radius = 0.48
		forme.height = 1.10
		forme.radial_segments = 9
		forme.rings = 5
		arbuste.mesh = forme
		var mat := ShaderMaterial.new()
		mat.shader = TOON
		mat.set_shader_parameter("couleur",Color(0.25+0.025*i,0.35+0.025*i,0.16))
		arbuste.material_override = mat
		arbuste.position = Vector3(0.10 if i == 1 else -0.10,0.86,(i-1)*0.62)
		groupe.add_child(arbuste)
