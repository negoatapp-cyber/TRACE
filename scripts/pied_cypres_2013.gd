extends Node3D
## Détails natifs 3D d'après les cinq vues du pied de tour : aucun pixel photo intégré.
const TOON := preload("res://shaders/bd_toon.gdshader")
const STRIES := preload("res://shaders/cypres_soubassement.gdshader")
const SOL := -0.43
const PALIER := 0.02
var _mats: Dictionary = {}

func mat(c: Color) -> ShaderMaterial:
	if not _mats.has(c):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("couleur", c)
		m.set_shader_parameter("grain", 0.12)
		_mats[c] = m
	return _mats[c]

func boite(nom: String, p: Vector3, taille: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	var box := BoxMesh.new()
	box.size = taille
	mi.mesh = box
	mi.position = p
	mi.material_override = mat(c)
	if nom in ["Soubassement", "ParementClair"]:
		var strie := ShaderMaterial.new()
		strie.shader = STRIES
		strie.set_shader_parameter("couleur", c)
		mi.material_override = strie
	add_child(mi)
	return mi

func construire() -> void:
	name = "DetailsPiedCypres"
	# Les cotes ci-dessous sont celles de l'ancien parvis (-0,43) : tout le pied de tour monte avec la place
	# de la Tour, remise à sa cote réelle (greffe_paix.gd PLATEAU_Y, 21.11).
	position.y += 3.5 - SOL
	# Les soubassements visibles sont striés et fermés, pas des fenêtres à grilles rouges.
	for face in [[-17.0, -8.48, -14.0], [-1.52, 7.0, -11.0]]:
		var x0: float = face[0]
		var x1: float = face[1]
		var z: float = face[2] + 0.05
		boite("Soubassement", Vector3((x0+x1)*0.5, 0.30, z), Vector3(x1-x0, 1.46, 0.06), Color(0.67, 0.65, 0.59))
		boite("ParementClair", Vector3((x0+x1)*0.5, 2.01, z), Vector3(x1-x0, 1.96, 0.06), Color(0.82, 0.80, 0.71))
		for x in [x0+1.2, x1-1.2]:
			boite("VentilationHaute", Vector3(x,2.66,z+0.075), Vector3(0.38,0.15,0.035), Color(0.10,0.12,0.15))
	_acces_annexe()
	_potelets()
	add_to_group("details_pied_cypres")
	print("Pied des Cyprès : parements, second accès, rampe, portes techniques et potelets bleus")

func _acces_annexe() -> void:
	var bleu := Color(0.27,0.39,0.46)
	# Accès de la lame basse, sous un auvent discret ; position relative estimée.
	boite("PorteAnnexe", Vector3(-12.8,PALIER+1.2,-13.82), Vector3(1.35,2.4,0.10), Color(0.12,0.19,0.24)).create_trimesh_collision()
	for x in [-13.52,-12.08,-12.8]:
		boite("MontantAnnexe", Vector3(x,PALIER+1.2,-13.74), Vector3(0.055,2.45,0.08),bleu)
	for y in [0.15,0.65,1.15,1.65,2.15,2.45]:
		boite("TraverseAnnexe", Vector3(-12.8,PALIER+y,-13.74), Vector3(1.48,0.045,0.08),bleu)
	var toit := boite("PetitAuvent", Vector3(-12.8,2.62,-13.35),Vector3(1.9,0.12,1.15),Color(0.40,0.27,0.22))
	toit.rotation.x = -0.04
	boite("PorteTechnique",Vector3(-10.1,0.94,-13.80),Vector3(1.0,2.50,0.10),Color(0.49,0.53,0.58))
	boite("PoigneeTechnique",Vector3(-9.73,0.93,-13.72),Vector3(0.05,0.17,0.05),bleu)
	var plateforme := boite("PalierAnnexe",Vector3(-12.8,SOL+0.225,-12.9),Vector3(3.0,0.45,2.2),Color(0.69,0.68,0.63))
	plateforme.create_trimesh_collision()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-20,SOL,-12.1),Vector3(-13.6,PALIER,-12.1),Vector3(-13.6,PALIER,-10.8),Vector3(-20,SOL,-12.1),Vector3(-13.6,PALIER,-10.8),Vector3(-20,SOL,-10.8)]:
		st.add_vertex(v)
	st.generate_normals()
	var rampe := MeshInstance3D.new()
	rampe.name = "RampeAnnexe"
	rampe.mesh = st.commit()
	rampe.material_override = mat(Color(0.69,0.68,0.63))
	add_child(rampe)
	rampe.create_trimesh_collision()
	for i in 6:
		var x := -20+float(i)*6.4/5.0
		var y := lerpf(SOL,PALIER,float(i)/5.0)
		boite("MontantGardeCorps",Vector3(x,y+0.48,-10.8),Vector3(0.045,0.96,0.045),Color(0.56,0.58,0.56))
	for hauteur in [0.45,0.9]:
		var lisse := boite("GardeCorps",Vector3(-16.8,(SOL+PALIER)*0.5+hauteur,-10.8),Vector3(sqrt(6.4*6.4+0.45*0.45),0.035,0.035),Color(0.56,0.58,0.56))
		lisse.rotation.z = atan2(0.45,6.4)
	# Murets de la zone des conteneurs, sous la rampe comme sur les vues fournies.
	for x in [-20.5,-18.0]:
		boite("MuretTechnique",Vector3(x,SOL+0.48,-8.9),Vector3(0.16,0.96,1.5),Color(0.76,0.75,0.68)).create_trimesh_collision()

func _potelets() -> void:
	var mesh := CylinderMesh.new()
	mesh.height = 0.82
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.045
	mesh.radial_segments = 10
	var quartier: Node = get_tree().current_scene.get_node("Quartier")
	for i in 15:
		var x := -19.5+float(i)*1.6
		if absf(x+5)<2.5 or absf(x+12.8)<1.5:
			continue # laisser des passages vers les deux entrées
		var mi := MeshInstance3D.new()
		mi.name = "PoteletBleu"
		mi.mesh = mesh
		mi.material_override = mat(Color(0.29,0.49,0.57))
		var p := Vector3(x,0,-7.4)
		var monde := to_global(p)
		p.y = quartier.h(monde.x,monde.z)+0.41
		mi.position = p
		add_child(mi)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.height = 0.82
		cyl.radius = 0.045
		cs.shape = cyl
		body.add_child(cs)
		mi.add_child(body)
