extends Node3D
## Fond municipal et secteurs OSM. Données locales partagées entre la carte et le jeu.
const DOSSIER := "res://data/marseille/"
const TUILE := 512
var info: Dictionary
var grille: PackedByteArray
var domaine: Rect2
var pas: int
var colonnes: int
var archive: FileAccess
var secteurs := {}
var demandes: Array[Vector2i] = []
var centre_tuile := Vector2i(99999,99999)
var rayon_actif := -2
var materiau := ShaderMaterial.new()
var travail := Thread.new()
var en_cours := Vector2i.ZERO
var solide := false
var quartier: Node3D
var shader_bati: Shader = preload("res://shaders/ville_facades.gdshader")   ## l'accueil met sa version BD
var shader_sol: Shader = preload("res://shaders/ville_sol.gdshader")
var materiau_sol: ShaderMaterial
var carte_sol := "carte.png"          ## l'accueil met sa carte recolorée (carte_bd.png)
var teintes_murs: Array = []           ## si rempli : une teinte par bâtiment (accueil, style BD)
var teintes_toits: Array = []

func _ready() -> void:
	info = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER+"index.json"))
	grille = FileAccess.get_file_as_bytes(DOSSIER+"relief.bin")
	archive = FileAccess.open(DOSSIER+"secteurs.bin", FileAccess.READ)
	var b: Array = info.bounds
	domaine = Rect2(b[0], b[1], b[2]-b[0], b[3]-b[1])
	pas = int(info.step)
	colonnes = int(info.cols)
	materiau.shader = shader_bati
	_fond()

func altitude(x: float, z: float) -> float:
	var uv := (Vector2(x,z)-domaine.position)/pas
	var i := clampi(floori(uv.x),0,colonnes-2)
	var j := clampi(floori(uv.y),0,int(info.rows)-2)
	var fx := clampf(uv.x-i,0,1)
	var fz := clampf(uv.y-j,0,1)
	var k := 2*(j*colonnes+i)
	var a := grille.decode_s16(k)*0.1
	var b := grille.decode_s16(k+2)*0.1
	var c := grille.decode_s16(k+colonnes*2)*0.1
	var d := grille.decode_s16(k+colonnes*2+2)*0.1
	if fx+fz <= 1:
		return a+(b-a)*fx+(c-a)*fz-90.0
	return d+(c-d)*(1-fx)+(b-d)*(1-fz)-90.0

func _fond() -> void:
	var trou := Rect2()
	if quartier:
		var a := Vector2(quartier.gx[0],quartier.gz[0])
		var b := Vector2(quartier.gx[-1],quartier.gz[-1])
		trou = Rect2(a,b-a)
	var rows := int(info.rows)
	var m := ShaderMaterial.new()
	m.shader = shader_sol
	materiau_sol = m
	m.set_shader_parameter("carte",load(DOSSIER+carte_sol))
	m.set_shader_parameter("terre",load(DOSSIER+"terre.png"))
	# Patchs indexés de 2 km : à hauteur d'homme le moteur écarte le terrain hors champ.
	for z0 in range(0,rows-1,32):
		for x0 in range(0,colonnes-1,32):
			var nx := mini(32,colonnes-1-x0)
			var nz := mini(32,rows-1-z0)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in nz+1:
				for i in nx+1:
					var p := domaine.position+Vector2(x0+i,z0+j)*pas
					st.set_uv(Vector2(float(x0+i)/(colonnes-1),float(z0+j)/(rows-1)))
					var dx := altitude(p.x-pas,p.y)-altitude(p.x+pas,p.y)
					var dz := altitude(p.x,p.y-pas)-altitude(p.x,p.y+pas)
					st.set_normal(Vector3(dx,2*pas,dz).normalized())
					st.add_vertex(Vector3(p.x,altitude(p.x,p.y),p.y))
			for j in nz:
				for i in nx:
					if quartier and trou.has_point(domaine.position+Vector2(x0+i+.5,z0+j+.5)*pas): continue
					var a := j*(nx+1)+i
					for idx in [a,a+1,a+nx+1,a+1,a+nx+2,a+nx+1]: st.add_index(idx)
			var mi := MeshInstance3D.new()
			mi.mesh=st.commit()
			mi.material_override=m
			mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if quartier: mi.visibility_range_end=6300
			add_child(mi)

func _coeur(p: Vector2, marge := 0.0) -> bool:
	return Rect2(-125,-325,400,600).grow(marge).has_point(p)

func demander(p: Vector2, rayon: int) -> void:
	var centre := Vector2i(floori(p.x/TUILE),floori(p.y/TUILE))
	if centre == centre_tuile and rayon == rayon_actif: return
	centre_tuile = centre
	rayon_actif = rayon
	for cle: Vector2i in secteurs.keys():
		if rayon < 0 or maxi(absi(cle.x-centre.x),absi(cle.y-centre.y)) > rayon:
			secteurs[cle].queue_free()
			secteurs.erase(cle)
	demandes.clear()
	for z in range(-rayon,rayon+1):
		for x in range(-rayon,rayon+1):
			var cle := centre+Vector2i(x,z)
			if not secteurs.has(cle) and not (travail.is_started() and cle==en_cours):
				if solide or info.index.has("%d,%d"%[cle.x,cle.y]):
					demandes.append(cle)
	demandes.sort_custom(func(a,b): return a.distance_squared_to(centre)<b.distance_squared_to(centre))

func lire(cle: Vector2i) -> Dictionary:
	var ref: Array = info.index.get("%d,%d"%[cle.x,cle.y],[])
	if ref.is_empty(): return {"b":[],"r":[]}
	archive.seek(int(ref[0]))
	var raw := archive.get_buffer(int(ref[1])).decompress(int(ref[2]),FileAccess.COMPRESSION_GZIP)
	return JSON.parse_string(raw.get_string_from_utf8())

func _process(_dt: float) -> void:
	if travail.is_started():
		if travail.is_alive(): return
		var resultat: Array = travail.wait_to_finish()
		if maxi(absi(en_cours.x-centre_tuile.x),absi(en_cours.y-centre_tuile.y)) <= rayon_actif:
			_installer(en_cours,resultat)
	if not demandes.is_empty():
		en_cours = demandes.pop_front()
		var cle := "%d,%d"%[en_cours.x,en_cours.y]
		var blob := PackedByteArray()
		var size_raw := 0
		if info.index.has(cle):
			var ref: Array = info.index[cle]
			archive.seek(int(ref[0]))
			blob = archive.get_buffer(int(ref[1]))
			size_raw = int(ref[2])
		if OS.has_feature("web") and not OS.has_feature("threads"):
			_installer(en_cours,_preparer(en_cours,blob,size_raw,quartier!=null,solide))
		else:
			travail.start(_preparer.bind(en_cours,blob,size_raw,quartier!=null,solide))

func _exit_tree() -> void:
	if travail.is_started(): travail.wait_to_finish()

func _preparer(cle: Vector2i, blob: PackedByteArray, taille: int, historique: bool, physique: bool) -> Array:
	var data: Dictionary = {"b":[],"r":[]}
	if taille:
		data = JSON.parse_string(blob.decompress(taille,FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var nb := 0
	for b: Array in data.b:
		var coords: Array = b[3]
		var points := PackedVector3Array()
		var somme := 0.
		var overlap := false
		for i in range(0,coords.size(),2):
			var x: float = coords[i]
			var z: float = coords[i+1]
			var a := altitude(x,z)
			points.append(Vector3(x,a-1.0,z))
			somme += a
			if historique and _coeur(Vector2(x,z),10): overlap = true
		if overlap: continue
		var toit := somme/points.size()+float(b[1])
		var murs := Color("#e0cba9") if float(b[1])<12 else Color("#dfd5c4")
		var toit_c := Color("#c3977f")
		if not teintes_murs.is_empty():
			var hsh := absi(int(coords[0] * 7.0) * 73856093 ^ int(coords[1] * 7.0) * 19349663)
			murs = teintes_murs[hsh % teintes_murs.size()]
			toit_c = teintes_toits[(hsh / 7) % teintes_toits.size()]
		var debut := 0
		for fin in b[4]:
			for i in range(debut,int(fin)):
				var a := points[i]
				var c := points[debut if i+1==int(fin) else i+1]
				var at := Vector3(a.x,toit,a.z)
				var ct := Vector3(c.x,toit,c.z)
				var norm := Vector3(c.z-a.z,0,a.x-c.x).normalized()
				for ver in [a,at,ct,a,ct,c]:
					var along := Vector2(ver.x-a.x,ver.z-a.z).length()
					st.set_uv(Vector2(along, ver.y-toit+float(b[1])+1.5))
					st.set_color(murs); st.set_normal(norm); st.add_vertex(ver)
					if physique: faces.append(ver)
				nb += 6
			debut = int(fin)
		for idx in b[5]:
			var v := points[int(idx)]
			v.y = toit
			st.set_uv(Vector2(0,-1)); st.set_normal(Vector3.UP); st.set_color(toit_c); st.add_vertex(v)
			if physique: faces.append(v)
			nb += 1
	for route: Array in data.r:
		var coords: Array = route[3]
		for i in range(2,coords.size(),2):
			var a := Vector2(coords[i-2],coords[i-1])
			var b := Vector2(coords[i],coords[i+1])
			if historique and (_coeur(a,12) or _coeur(b,12)): continue
			var offset := (b-a).normalized().orthogonal()*float(route[1])*.5
			var parts := maxi(1,ceili(a.distance_to(b)/12))
			for k in parts:
				var c := a.lerp(b,float(k)/parts)
				var d := a.lerp(b,float(k+1)/parts)
				for p: Vector2 in [c-offset,c+offset,d+offset,c-offset,d+offset,d-offset]:
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(0,-1))
					st.set_color(Color("#676774") if float(route[1])>3.5 else Color("#cbbda5"))
					st.add_vertex(Vector3(p.x,altitude(p.x,p.y)+0.14,p.y))
				nb += 6
	if physique:
		for j in range(0,TUILE,pas):
			for i in range(0,TUILE,pas):
				var p := Vector2(cle.x*TUILE+i,cle.y*TUILE+j)
				for off in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
					var pt: Vector2 = p+off*pas
					faces.append(Vector3(pt.x,altitude(pt.x,pt.y),pt.y))
	return [st.commit_to_arrays() if nb else [],faces]

func _installer(cle: Vector2i, resultat: Array) -> void:
	var n := Node3D.new()
	n.name = "Secteur_%d_%d"%[cle.x,cle.y]
	if not resultat[0].is_empty():
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,resultat[0])
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = materiau
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	if not resultat[1].is_empty():
		var corps := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := ConcavePolygonShape3D.new()
		sh.backface_collision = true
		sh.set_faces(resultat[1])
		cs.shape = sh
		corps.add_child(cs)
		n.add_child(corps)
	add_child(n)
	secteurs[cle] = n
