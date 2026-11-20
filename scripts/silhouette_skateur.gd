extends Node3D
## Doublure originale et articulée pour les copies dépourvues du modèle privé.
var jambes: Array[Node3D] = []
var bras: Array[Node3D] = []
var phase := 0.
var torse := Node3D.new()
const VESTE := Color("#9c3440")
const JEAN := Color("#35465a")
const PEAU := Color("#ae7657")
const ENCRE := Color("#27222a")
const ECRU := Color("#ebe1cd")

func volume(parent: Node3D, p: Vector3, taille: Vector3, couleur: Color, rond:=true) -> void:
	var n := MeshInstance3D.new()
	if rond:
		var s := SphereMesh.new()
		s.radial_segments=8; s.rings=4; s.radius=.5; s.height=1
		n.mesh=s
	else: n.mesh=BoxMesh.new()
	n.position=p; n.scale=taille
	var m := StandardMaterial3D.new()
	m.albedo_color=couleur; m.roughness=1
	n.material_override=m
	parent.add_child(n)

func _ready() -> void:
	add_child(torse)
	volume(torse,Vector3(0,1.12,.015),Vector3(.47,.64,.30),VESTE)
	volume(torse,Vector3(0,1.35,.065),Vector3(.33,.23,.25),Color("#672f3a"))
	volume(torse,Vector3(0,1.51,0),Vector3(.245,.315,.24),PEAU)
	volume(torse,Vector3(0,1.64,.025),Vector3(.275,.225,.265),ENCRE)
	volume(torse,Vector3(0,1.63,-.125),Vector3(.23,.035,.16),ENCRE,false)
	volume(torse,Vector3(0,.885,0),Vector3(.395,.19,.26),JEAN)
	for cote in [-1.,1.]:
		var j := Node3D.new()
		j.position=Vector3(.12*cote,.86,0);torse.add_child(j);jambes.append(j)
		volume(j,Vector3(0,-.22,0),Vector3(.21,.52,.24),JEAN)
		volume(j,Vector3(0,-.59,.014),Vector3(.19,.46,.20),JEAN.darkened(.12))
		volume(j,Vector3(0,-.785,-.043),Vector3(.19,.125,.31),ENCRE)
		volume(j,Vector3(0,-.833,-.043),Vector3(.19,.043,.30),ECRU,false)
		var arm := Node3D.new()
		arm.position=Vector3(cote*.218,1.34,0);torse.add_child(arm);bras.append(arm)
		volume(arm,Vector3(0,-.155,0),Vector3(.16,.39,.19),VESTE)
		volume(arm,Vector3(0,-.37,-.038),Vector3(.13,.275,.14),VESTE.darkened(.14))
		volume(arm,Vector3(0,-.52,-.055),Vector3(.115,.15,.12),PEAU)
		volume(torse,Vector3(.13*cote,.925,.125),Vector3(.065,.18,.065),ECRU,false)

func animer(p: Player, dt: float) -> void:
	var v := Vector2(p.velocity.x,p.velocity.z).length()
	var skate := p.mode==p.Mode.SKATE
	var air := not p.is_on_floor()
	phase=fmod(phase+v*dt*3.1,TAU)
	torse.rotation.y=lerp_angle(torse.rotation.y,-1.32 if skate else 0.,minf(1,dt*12))
	torse.position.y=.085 if skate else .0
	for i in 2:
		var signe: float = -1 if i==0 else 1
		var pas := sin(phase)*minf(v/5.,.72)*signe
		jambes[i].rotation.x=pas if not skate else (-.16 if air else -.04)*signe
		jambes[i].rotation.z=.07*signe if skate else 0.
		bras[i].rotation.x=-pas if not skate else -.15
		bras[i].rotation.z=signe*(-.58 if skate or air else -.12)
