class_name PoseProcedurale
extends SkeletonModifier3D
## Postures calculées de Loums, posées par-dessus l'AnimationPlayer et avant l'IK des jambes.
## personnage.gd remplit les cibles à chaque image ; ce modificateur les applique.
##
## Repère du squelette : +Z = devant Loums, +X = sa gauche, +Y = haut.
## Les directions des bras sont données dans ce repère (pas besoin d'être normalisées).

## 0 = l'animation décide, 1 = la pose calculée décide.
var poids_haut := 0.0      ## bassin, buste, tête, bras
var poids_bas := 0.0       ## jambes (debout à l'arrêt ; sur la planche, c'est l'IK)

var bassin := Vector3.ZERO     ## décalage du bassin (unités du squelette)
var bassin_rot := Vector3.ZERO ## tangage / lacet / roulis du bassin (rad)
var buste := Vector3.ZERO      ## x = penché en avant, y = tourné vers sa gauche, z = roulis (rad)
var tete := Vector3.ZERO       ## x = baisse la tête, y = regarde à gauche (rad)
var respiration := 0.0         ## amplitude du souffle (rad sur le haut du buste)
var poing_d := 0.0             ## 1 = doigts de la main droite refermés (tenir la bombe)
var axe_doigts := Vector3.RIGHT
## Bras : [direction du bras, direction de l'avant-bras]
var bras_g: Array[Vector3] = [Vector3(0.15, -1, 0), Vector3(0.1, -1, 0.3)]
var bras_d: Array[Vector3] = [Vector3(-0.15, -1, 0), Vector3(-0.1, -1, 0.3)]
## Jambes debout : [direction de la cuisse, direction du tibia]
var jambe_g: Array[Vector3] = [Vector3(0.03, -1, 0.0), Vector3(0.02, -1, -0.03)]
var jambe_d: Array[Vector3] = [Vector3(-0.03, -1, 0.0), Vector3(-0.02, -1, -0.03)]

var _pret := false
var _t := 0.0
var _rest_g := {}     ## os -> Quaternion global au repos
var _rest_o := {}     ## os -> origine globale au repos
var _rest_l := {}     ## os -> Quaternion local au repos
var _idx := {}        ## nom court -> index
var _doigts := []     ## index des doigts (ramenés au repos, mains détendues)
var _doigts_d := []   ## ceux de la main droite (hors pouce)

const NOMS := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]


func _preparer(sk: Skeleton3D) -> void:
	for n in NOMS:
		var i := sk.find_bone("mixamorig_" + n)
		if i < 0:
			return
		_idx[n] = i
	for i in sk.get_bone_count():
		var g := sk.get_bone_global_rest(i)
		_rest_g[i] = Quaternion(g.basis.orthonormalized())
		_rest_o[i] = g.origin
		_rest_l[i] = Quaternion(sk.get_bone_rest(i).basis.orthonormalized())
		var nom := sk.get_bone_name(i)
		if ("Hand" in nom and nom != "mixamorig_LeftHand" and nom != "mixamorig_RightHand"):
			_doigts.append(i)
			if nom.begins_with("mixamorig_RightHand") and not "Thumb" in nom:
				_doigts_d.append(i)
	_pret = true


## Position de repos d'un os (repère du squelette), p. ex. "RightArm" pour l'épaule droite.
func origine_repos(nom: String) -> Vector3:
	if not _pret or not _idx.has(nom):
		return Vector3.ZERO
	return _rest_o[_idx[nom]]


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _pret:
		_preparer(sk)
		if not _pret:
			return
	_t += delta
	var wh := clampf(poids_haut, 0.0, 1.0)
	var wb := clampf(poids_bas, 0.0, 1.0)
	if wh <= 0.0 and wb <= 0.0:
		return
	var g := {}   # os -> Quaternion global voulu

	# Bassin.
	var h: int = _idx.Hips
	var q_bassin: Quaternion = Quaternion.from_euler(bassin_rot) * _rest_g[h]
	g[h] = q_bassin
	_poser(sk, h, Quaternion.IDENTITY, q_bassin, wh)
	var p0: Vector3 = sk.get_bone_pose_position(h)
	var p_voulu: Vector3 = sk.get_bone_rest(h).origin + bassin
	sk.set_bone_pose_position(h, p0.lerp(p_voulu, wh))
	var r_bassin := Quaternion.from_euler(bassin_rot)

	# Buste : la torsion se répartit sur les trois vertèbres ; le souffle gonfle le haut.
	var souffle := sin(_t * TAU / 4.2) * respiration
	var r := r_bassin
	var parent: Quaternion = q_bassin
	var k := 0
	for n in ["Spine", "Spine1", "Spine2"]:
		k += 1
		var e := Vector3(buste.x / 3.0, buste.y / 3.0, buste.z / 3.0)
		if n == "Spine2":
			e.x -= souffle
		r = r * Quaternion.from_euler(e)
		var i: int = _idx[n]
		var qi: Quaternion = r * _rest_g[i]
		g[i] = qi
		_poser(sk, i, parent, qi, wh)
		parent = qi
	var r_buste := r
	var r_cou := r * Quaternion.from_euler(Vector3(tete.x * 0.4, tete.y * 0.4, 0) + Vector3(souffle * 0.5, 0, 0))
	g[_idx.Neck] = r_cou * _rest_g[_idx.Neck]
	_poser(sk, _idx.Neck, parent, g[_idx.Neck], wh)
	var r_tete := r_cou * Quaternion.from_euler(Vector3(tete.x * 0.6, tete.y * 0.6, 0))
	g[_idx.Head] = r_tete * _rest_g[_idx.Head]
	_poser(sk, _idx.Head, g[_idx.Neck], g[_idx.Head], wh)

	# Bras.
	for cote in ["Left", "Right"]:
		var cibles: Array[Vector3] = bras_g if cote == "Left" else bras_d
		var ep: int = _idx[cote + "Shoulder"]
		var q_ep: Quaternion = r_buste * _rest_g[ep]
		g[ep] = q_ep
		_poser(sk, ep, g[_idx.Spine2], q_ep, wh)
		_chaine(sk, g, r_buste, q_ep, [_idx[cote + "Arm"], _idx[cote + "ForeArm"], _idx[cote + "Hand"]], cibles, wh)
	for i in _doigts:
		var cur := sk.get_bone_pose_rotation(i)
		var voulu: Quaternion = _rest_l[i]
		if poing_d > 0.0 and i in _doigts_d:
			voulu = voulu * Quaternion(axe_doigts, 1.1 * poing_d)
		sk.set_bone_pose_rotation(i, cur.slerp(voulu, wh))

	# Jambes (debout).
	if wb > 0.0:
		for cote in ["Left", "Right"]:
			var cibles: Array[Vector3] = jambe_g if cote == "Left" else jambe_d
			_chaine(sk, g, r_bassin, q_bassin, [_idx[cote + "UpLeg"], _idx[cote + "Leg"], _idx[cote + "Foot"]], cibles, wb)


## Deux segments (bras + avant-bras, ou cuisse + tibia) orientés vers des directions données ;
## le troisième os (main, pied) garde son attitude de repos par rapport au deuxième.
func _chaine(sk: Skeleton3D, g: Dictionary, r_parent: Quaternion, q_parent: Quaternion, os: Array, cibles: Array[Vector3], w: float) -> void:
	var a: int = os[0]
	var b: int = os[1]
	var c: int = os[2]
	# segment 1 : de a vers b
	var d_repos: Vector3 = (_rest_o[b] - _rest_o[a]).normalized()
	var d0: Vector3 = r_parent * d_repos
	var r1 := Quaternion(d0, cibles[0].normalized()) * r_parent
	var qa: Quaternion = r1 * _rest_g[a]
	g[a] = qa
	_poser(sk, a, q_parent, qa, w)
	# segment 2 : de b vers c
	var e_repos: Vector3 = (_rest_o[c] - _rest_o[b]).normalized()
	var e0: Vector3 = r1 * e_repos
	var r2 := Quaternion(e0, cibles[1].normalized()) * r1
	var qb: Quaternion = r2 * _rest_g[b]
	var qc: Quaternion = r2 * _rest_g[c]
	_poser(sk, b, qa, qb, w)
	_poser(sk, c, qb, qc, w)


func _poser(sk: Skeleton3D, i: int, q_parent: Quaternion, q_global: Quaternion, w: float) -> void:
	var local := (q_parent.inverse() * q_global).normalized()
	var cur := sk.get_bone_pose_rotation(i)
	sk.set_bone_pose_rotation(i, cur.slerp(local, w))
