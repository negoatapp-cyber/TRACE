extends SceneTree
## TRACE — export du quartier Godot vers Unreal (pilote Unreal, 26.11.2026)
##
## Le quartier est construit au lancement : un export depuis l'éditeur serait vide.
## Ce script lance la scène, attend que la construction soit finie, retire Loums,
## caméras et interface, puis écrit un fichier .glb que Unreal sait importer.
##
## À placer dans : TRACE\.tools\export_unreal.gd
## À lancer (fenêtre visible, PAS --headless, sinon les maillages sont vides) :
##   Godot_v4.7.2-stable_win64.exe --path "C:\Users\Chishan\Downloads\TRACE" -s res://.tools/export_unreal.gd
## Résultat : TRACE\export_unreal\quartier_2013.glb (dossier ignoré par Godot)
##
## Les matières avec shader maison (style BD) sortent en gris : c'est voulu,
## elles seront refaites dans Unreal. Ne modifie aucun fichier du projet.

const NOM_SCENE := "marseille_2013.tscn"
const DOSSIER := "res://export_unreal"
const FICHIER := "quartier_2013.glb"
const ATTENTE_MAX := 3600 # images

func _initialize() -> void:
	_lancer.call_deferred() # comme les scripts verify_* : l'arbre doit être prêt

func _lancer() -> void:
	var chemin := _trouver("res://", NOM_SCENE)
	if chemin == "":
		push_error("Scène introuvable : " + NOM_SCENE)
		quit(1)
		return
	print("[export] scène : ", chemin)
	var scene: Node = (load(chemin) as PackedScene).instantiate()
	root.add_child(scene)

	# Attendre que la construction du quartier soit terminée (nombre de nœuds stable).
	var precedent := -1
	var stables := 0
	var images := 0
	while stables < 3 and images < ATTENTE_MAX:
		for i in 30:
			await process_frame
		images += 30
		var n := _compter(scene)
		stables = stables + 1 if n == precedent else 0
		precedent = n
		print("[export] nœuds : ", n)

	# Figer la scène : sans ça, les scripts du jeu cherchent Loums/caméra retirés et inondent la console.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var retires := _nettoyer(scene)
	print("[export] retirés (Loums, caméras, interface, invisibles) : ", retires)
	for i in 3:
		await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	var ignore := FileAccess.open(DOSSIER + "/.gdignore", FileAccess.WRITE)
	if ignore:
		ignore.close()

	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	var err := doc.append_from_scene(scene, etat)
	if err != OK:
		push_error("[export] échec de la conversion : " + error_string(err))
		quit(1)
		return
	var sortie := ProjectSettings.globalize_path(DOSSIER + "/" + FICHIER)
	err = doc.write_to_filesystem(etat, sortie)
	if err != OK:
		push_error("[export] échec de l'écriture : " + error_string(err))
		quit(1)
		return
	print("[export] terminé : ", sortie)
	quit()

func _compter(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _compter(c)
	return total

func _nettoyer(scene: Node) -> int:
	var a_retirer: Array[Node] = []
	_collecter(scene, a_retirer)
	for n in a_retirer:
		if is_instance_valid(n) and n.get_parent():
			n.get_parent().remove_child(n)
			n.free()
	return a_retirer.size()

func _collecter(n: Node, liste: Array[Node]) -> void:
	for c in n.get_children():
		var retirer := false
		if c is CharacterBody3D or c is Camera3D or c is Skeleton3D:
			retirer = true # Loums, caméras, squelettes
		elif c.name == "Habitants":
			retirer = true # PNJ (Node3D, pas CharacterBody3D) : sinon restent figés au milieu du décor
		elif c is MeshInstance3D and (c as MeshInstance3D).skin != null:
			retirer = true # maillage skinné orphelin
		elif c is CanvasItem or c is CanvasLayer:
			retirer = true # interface, carte, lecteur MP3
		elif c is GPUParticles3D or c is CPUParticles3D:
			retirer = true
		elif c is VisualInstance3D and not (c as VisualInstance3D).is_visible_in_tree():
			retirer = true
		if retirer:
			liste.append(c)
		else:
			_collecter(c, liste)

func _trouver(dossier: String, nom: String) -> String:
	var d := DirAccess.open(dossier)
	if d == null:
		return ""
	if d.file_exists(nom):
		return dossier.path_join(nom)
	for sous in d.get_directories():
		if sous.begins_with(".") or sous.begins_with("_") or sous == "export_unreal":
			continue
		var r := _trouver(dossier.path_join(sous), nom)
		if r != "":
			return r
	return ""
