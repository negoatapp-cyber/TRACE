extends Node3D
## Un vrai skateboard, construit par le code aux cotes d'une planche de street :
## plateau 8" × 31,75" (20,3 × 80,6 cm), empattement 14,25", nose et tail relevés, concave,
## trucks de 8", roues de 52 mm. L'origine du nœud est au centre du plateau (pour les flips) ;
## le sol est à -HAUTEUR en dessous. L'avant de la planche regarde vers -Z.

const LONGUEUR := 0.806
const LARGEUR := 0.203
const EPAISSEUR := 0.011
const EMPATTEMENT := 0.362
const RAYON_ROUE := 0.026
const LARGEUR_ROUE := 0.032
const HAUTEUR := 0.085          ## du sol au centre du plateau
const RELEVE := 0.048           ## hauteur du nose et du tail
const CONCAVE := 0.007

@export var couleur_dessous := Color(0.78, 0.10, 0.22)
@export var couleur_roues := Color(0.93, 0.90, 0.82)


func _ready() -> void:
	_plateau()
	for z in [-EMPATTEMENT * 0.5, EMPATTEMENT * 0.5]:
		_truck(z)


func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Demi-largeur du plateau à la position z : droit au milieu, arrondi aux deux bouts.
func _demi_largeur(z: float) -> float:
	var debut := LONGUEUR * 0.5 - 0.13
	var a := absf(z)
	if a <= debut:
		return LARGEUR * 0.5
	var t := clampf((a - debut) / 0.13, 0.0, 1.0)
	return LARGEUR * 0.5 * sqrt(maxf(1.0 - t * t, 0.0))


## Hauteur du plateau à la position z : plat entre les trucks, relevé au nose et au tail.
func _releve(z: float) -> float:
	var plat := EMPATTEMENT * 0.5 + 0.025
	var a := absf(z)
	if a <= plat:
		return 0.0
	var t := (a - plat) / (LONGUEUR * 0.5 - plat)
	return RELEVE * pow(t, 1.5) * (1.06 if z < 0.0 else 1.0)  # le nose un peu plus haut que le tail


func _plateau() -> void:
	var n := 40
	var across := [-1.0, -0.6, 0.0, 0.6, 1.0]
	var dessus := []
	var dessous := []
	for i in n + 1:
		var z := -LONGUEUR * 0.5 + LONGUEUR * float(i) / n
		var w := maxf(_demi_largeur(z), 0.004)
		var ligne_h := []
		var ligne_b := []
		for u in across:
			var y: float = _releve(z) + CONCAVE * u * u
			ligne_h.append(Vector3(u * w, y + EPAISSEUR * 0.5, z))
			ligne_b.append(Vector3(u * w, y - EPAISSEUR * 0.5, z))
		dessus.append(ligne_h)
		dessous.append(ligne_b)
	var st_h := SurfaceTool.new()
	var st_b := SurfaceTool.new()
	var st_c := SurfaceTool.new()
	for st in [st_h, st_b, st_c]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		for k in across.size() - 1:
			_quad(st_h, dessus[i][k], dessus[i][k + 1], dessus[i + 1][k + 1], dessus[i + 1][k], Vector3.UP)
			_quad(st_b, dessous[i][k], dessous[i][k + 1], dessous[i + 1][k + 1], dessous[i + 1][k], Vector3.DOWN)
		var d: int = across.size() - 1
		_quad(st_c, dessus[i][0], dessus[i + 1][0], dessous[i + 1][0], dessous[i][0], Vector3.LEFT)
		_quad(st_c, dessus[i][d], dessus[i + 1][d], dessous[i + 1][d], dessous[i][d], Vector3.RIGHT)
	_piece("Grip", st_h.commit(), _mat(Color(0.06, 0.06, 0.065), 0.98))
	_piece("Dessous", st_b.commit(), _mat(couleur_dessous, 0.45))
	_piece("Chant", st_c.commit(), _mat(Color(0.80, 0.66, 0.46), 0.7))
	# Les huit vis.
	for z in [-EMPATTEMENT * 0.5, EMPATTEMENT * 0.5]:
		for dx in [-0.0205, 0.0205]:
			for dz in [-0.027, 0.027]:
				_cylindre("Vis", Vector3(dx, EPAISSEUR * 0.5 + 0.0005, z + dz), 0.0035, 0.002, Vector3.UP, _mat(Color(0.55, 0.56, 0.58), 0.4, 0.8))


func _truck(z: float) -> void:
	var metal := _mat(Color(0.72, 0.73, 0.75), 0.35, 0.85)
	var sens := -1.0 if z < 0.0 else 1.0   # le pivot regarde vers le centre de la planche
	var bas := -EPAISSEUR * 0.5
	var axe_y := -HAUTEUR + RAYON_ROUE
	_boite("Embase", Vector3(0, bas - 0.004, z), Vector3(0.056, 0.008, 0.082), metal)
	_boite("Gomme", Vector3(0, (bas - 0.008 + axe_y + 0.012) * 0.5, z - sens * 0.008), Vector3(0.026, absf(bas - 0.008 - axe_y - 0.012), 0.026), _mat(Color(0.85, 0.75, 0.2), 0.6))
	_cylindre("Hanger", Vector3(0, axe_y + 0.002, z), 0.013, 0.136, Vector3.RIGHT, metal)
	_boite("Pivot", Vector3(0, axe_y + 0.012, z - sens * 0.022), Vector3(0.03, 0.02, 0.03), metal)
	_cylindre("Axe", Vector3(0, axe_y, z), 0.004, LARGEUR + 0.012, Vector3.RIGHT, _mat(Color(0.45, 0.46, 0.48), 0.3, 0.9))
	for sx in [-1.0, 1.0]:
		var x: float = sx * (LARGEUR * 0.5 - LARGEUR_ROUE * 0.5 + 0.002)
		_cylindre("Roue", Vector3(x, axe_y, z), RAYON_ROUE, LARGEUR_ROUE, Vector3.RIGHT, _mat(couleur_roues, 0.5), 20)
		_cylindre("Roulement", Vector3(x, axe_y, z), 0.011, LARGEUR_ROUE + 0.002, Vector3.RIGHT, _mat(Color(0.2, 0.2, 0.22), 0.4, 0.6))


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for p in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(p)


func _piece(nom: String, mesh: Mesh, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.name = nom
	add_child(mi)


func _boite(nom: String, pos: Vector3, taille: Vector3, m: Material) -> void:
	var bm := BoxMesh.new()
	bm.size = taille
	_piece(nom, bm, m)
	get_child(get_child_count() - 1).position = pos


func _cylindre(nom: String, pos: Vector3, rayon: float, long: float, axe: Vector3, m: Material, segments := 12) -> void:
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon
	c.height = long
	c.radial_segments = segments
	c.rings = 1
	_piece(nom, c, m)
	var mi := get_child(get_child_count() - 1) as MeshInstance3D
	mi.position = pos
	if axe == Vector3.RIGHT:
		mi.rotation.z = PI * 0.5
