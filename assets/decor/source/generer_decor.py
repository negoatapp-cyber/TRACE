"""TRACE — génère le mobilier et le décor en 3D avec Blender (conversation n°2, habillage).

Lancement (Blender 5.x) :
    blender --background --python assets/decor/source/generer_decor.py
ou, avec Blender installé comme module Python :
    python assets/decor/source/generer_decor.py

Chaque objet est exporté en .glb dans assets/decor/. Formes simples et silhouettes franches,
faites pour le rendu BD (aplats + encrage) : pas de textures, une couleur par matériau.
Origine au sol, au centre de l'objet. Unités : mètres. Aucune marque réelle.
"""
import math
import os

import bpy
import bmesh
from mathutils import Matrix, Vector

SORTIE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

# ───────────────────────── palette (couleurs d'aplat) ─────────────────────────
COULEURS = {
    "Carrosserie": (0.80, 0.80, 0.78),
    "Vitre": (0.10, 0.13, 0.18),
    "Pneu": (0.07, 0.07, 0.08),
    "Jante": (0.62, 0.63, 0.64),
    "Plastique": (0.16, 0.16, 0.17),
    "Phare": (0.95, 0.94, 0.86),
    "Feu": (0.80, 0.12, 0.10),
    "Metal": (0.30, 0.34, 0.33),
    "Alu": (0.70, 0.71, 0.72),
    "Beton": (0.78, 0.75, 0.69),
    "BetonSombre": (0.60, 0.58, 0.54),
    "Bois": (0.60, 0.40, 0.24),
    "Ecorce": (0.40, 0.29, 0.21),
    "Aiguilles": (0.25, 0.41, 0.21),
    "AiguillesClair": (0.33, 0.50, 0.25),
    "Terre": (0.45, 0.34, 0.24),
    "Conteneur": (0.20, 0.45, 0.30),
    "Hall": (0.86, 0.80, 0.55),
    "BoitesLettres": (0.55, 0.58, 0.60),
    "Carrelage": (0.84, 0.82, 0.76),
    "Siege": (0.10, 0.10, 0.11),
    "Interphone": (0.52, 0.54, 0.55),
}
_mats = {}


def lineaire(v):
    """La palette est écrite en sRGB (comme dans Godot) ; glTF attend des couleurs linéaires."""
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def mat(nom):
    if nom not in _mats:
        m = bpy.data.materials.new(nom)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        c = COULEURS[nom]
        bsdf.inputs["Base Color"].default_value = (lineaire(c[0]), lineaire(c[1]), lineaire(c[2]), 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
        if "Vitre" in nom:
            bsdf.inputs["Roughness"].default_value = 0.2
        _mats[nom] = m
    return _mats[nom]


def vider():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def _objet(nom, bm, matiere):
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat(matiere))
    o = bpy.data.objects.new(nom, me)
    bpy.context.collection.objects.link(o)
    return o


def boite(nom, taille, pos, matiere, rot_z=0.0, biseau=0.0, effile=None):
    """Boîte de dimensions `taille` (x, y, z) centrée en `pos`. `effile` = (fx, fy) rétrécit le dessus."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(taille), verts=bm.verts)
    if effile:
        for v in bm.verts:
            if v.co.z > 0:
                v.co.x *= effile[0]
                v.co.y *= effile[1]
    if biseau > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=biseau, segments=1, affect="EDGES")
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(rot_z, 3, "Z"))
    bmesh.ops.translate(bm, vec=Vector(pos), verts=bm.verts)
    return _objet(nom, bm, matiere)


def cylindre(nom, rayon, longueur, a, b, matiere, cotes=8):
    """Cylindre de `a` à `b`."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=cotes, radius1=rayon, radius2=rayon, depth=d.length)
    rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ rot, verts=bm.verts)
    return _objet(nom, bm, matiere)


def roue(nom, rayon, largeur, pos):
    """Roue couchée sur l'axe X (pneu + jante)."""
    x, y, z = pos
    p = cylindre(nom, rayon, largeur, (x - largeur / 2, y, z), (x + largeur / 2, y, z), "Pneu", 12)
    s = 1 if x > 0 else -1
    j = cylindre(nom + "_jante", rayon * 0.55, 0.02, (x + s * largeur / 2, y, z), (x + s * (largeur / 2 + 0.015), y, z), "Jante", 10)
    return [p, j]


def boule(nom, rayon, pos, echelle, matiere, subdiv=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=rayon)
    bmesh.ops.scale(bm, vec=Vector(echelle), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(pos), verts=bm.verts)
    return _objet(nom, bm, matiere)


def exporter(nom):
    for o in bpy.data.objects:
        o.select_set(True)
    chemin = os.path.join(SORTIE, nom + ".glb")
    bpy.ops.export_scene.gltf(filepath=chemin, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    print("exporté", chemin, len(bpy.data.objects), "objets")


# ───────────────────────── véhicules ─────────────────────────
# Longueur sur l'axe Y de Blender (devient l'axe Z de Godot). L'avant est en -Y.

def voiture(nom, longueur, largeur, haut_caisse, haut_toit, avant_cabine, arriere_cabine, hayon=True):
    vider()
    garde = 0.18
    l2 = longueur / 2
    # Caisse basse, arrondie aux bords.
    boite("Caisse", (largeur, longueur, haut_caisse), (0, 0, garde + haut_caisse / 2), "Carrosserie", biseau=0.06)
    # Cabine : vitrée, effilée vers le haut, posée entre avant_cabine et arriere_cabine.
    lc = arriere_cabine - avant_cabine
    yc = (avant_cabine + arriere_cabine) / 2
    hc = haut_toit - haut_caisse - garde
    boite("Cabine", (largeur * 0.9, lc, hc), (0, yc, garde + haut_caisse + hc / 2), "Vitre", effile=(0.86, 0.72 if hayon else 0.62))
    # Toit et montants couleur carrosserie (la vitre se lit comme des fenêtres).
    boite("Toit", (largeur * 0.78, lc * (0.78 if hayon else 0.62), 0.05), (0, yc + (0.04 if hayon else 0.0), haut_toit + 0.02), "Carrosserie")
    boite("Montant", (largeur * 0.92, 0.10, hc * 0.95), (0, yc + lc * 0.08, garde + haut_caisse + hc / 2), "Carrosserie", effile=(0.86, 1.0))
    # Pare-chocs, phares, feux.
    boite("PareChocAv", (largeur * 1.01, 0.16, 0.22), (0, -l2 + 0.05, garde + 0.12), "Plastique", biseau=0.03)
    boite("PareChocAr", (largeur * 1.01, 0.16, 0.22), (0, l2 - 0.05, garde + 0.12), "Plastique", biseau=0.03)
    for s in (-1, 1):
        boite("Phare", (0.34, 0.04, 0.14), (s * largeur * 0.33, -l2 - 0.005, garde + haut_caisse * 0.72), "Phare")
        boite("Feu", (0.22, 0.04, 0.16), (s * largeur * 0.38, l2 + 0.005, garde + haut_caisse * 0.75), "Feu")
        boite("Retro", (0.14, 0.08, 0.09), (s * (largeur / 2 + 0.06), avant_cabine + 0.15, garde + haut_caisse + 0.08), "Plastique")
    # Roues.
    r = 0.30
    for y in (-l2 + 0.72, l2 - 0.68):
        for s in (-1, 1):
            roue("Roue", r, 0.19, (s * (largeur / 2 - 0.07), y, r))
    exporter(nom)


def scooter():
    vider()
    # Scooter de cité : petites roues, tablier haut, selle longue, guidon nu.
    roue("RoueAv", 0.22, 0.10, (0, -0.62, 0.22))
    roue("RoueAr", 0.22, 0.12, (0, 0.55, 0.22))
    boite("Plancher", (0.30, 0.55, 0.10), (0, -0.05, 0.30), "Plastique")
    boite("Tablier", (0.34, 0.14, 0.55), (0, -0.42, 0.62), "Carrosserie", biseau=0.03, effile=(0.8, 1.0))
    boite("Coque", (0.36, 0.70, 0.32), (0, 0.42, 0.52), "Carrosserie", biseau=0.06, effile=(0.85, 0.9))
    boite("Selle", (0.28, 0.62, 0.10), (0, 0.38, 0.73), "Siege", biseau=0.03)
    cylindre("Fourche", 0.03, 0.6, (0, -0.60, 0.22), (0, -0.48, 0.92), "Metal")
    cylindre("Guidon", 0.025, 0.62, (-0.31, -0.47, 0.95), (0.31, -0.47, 0.95), "Plastique")
    boite("Phare", (0.16, 0.06, 0.10), (0, -0.52, 0.86), "Phare")
    cylindre("Pot", 0.05, 0.5, (0.14, 0.25, 0.25), (0.14, 0.75, 0.32), "Alu")
    exporter("scooter")


# ───────────────────────── végétation et mobilier ─────────────────────────

def pin_parasol():
    vider()
    # Tronc courbé en trois tronçons, puis un houppier large et plat fait de coussins d'aiguilles.
    pts = [(0, 0, -0.2), (0.25, 0.1, 2.8), (0.75, 0.2, 5.6), (1.0, 0.25, 7.6)]
    for k in range(3):
        cylindre("Tronc", 0.22 - k * 0.04, 0, pts[k], pts[k + 1], "Ecorce", 7)
    cylindre("Branche", 0.09, 0, (0.75, 0.2, 5.6), (-0.9, 0.4, 7.2), "Ecorce", 6)
    cylindre("Branche", 0.08, 0, (0.9, 0.22, 6.8), (2.4, -0.4, 7.6), "Ecorce", 6)
    coussins = [((1.0, 0.25, 8.0), 2.6, "Aiguilles"), ((-0.9, 0.5, 7.6), 1.9, "Aiguilles"),
                ((2.6, -0.4, 7.9), 1.8, "Aiguilles"), ((0.4, -1.3, 7.7), 1.7, "AiguillesClair"),
                ((0.9, 1.7, 7.8), 1.8, "AiguillesClair")]
    for p, r, m in coussins:
        boule("Houppier", r, p, (1.0, 1.0, 0.42), m)
    exporter("pin_parasol")


def lampadaire():
    vider()
    h = 7.5
    cylindre("Mat", 0.09, 0, (0, 0, 0), (0, 0, h), "Metal", 8)
    cylindre("Socle", 0.16, 0, (0, 0, 0), (0, 0, 0.6), "Metal", 8)
    # Crosse : le bras part vers -Y (côté chaussée) et retombe.
    cylindre("Crosse", 0.06, 0, (0, 0, h), (0, -0.9, h + 0.35), "Metal", 6)
    cylindre("Crosse2", 0.06, 0, (0, -0.9, h + 0.35), (0, -1.6, h + 0.25), "Metal", 6)
    boite("Lanterne", (0.36, 0.75, 0.16), (0, -1.75, h + 0.15), "Plastique", biseau=0.03, effile=(0.7, 0.8))
    boite("Verre", (0.28, 0.6, 0.03), (0, -1.75, h + 0.06), "Phare")
    exporter("lampadaire")


def conteneur():
    vider()
    # Bac roulant de 660 L, couvercle bombé, quatre roulettes.
    boite("Cuve", (1.26, 0.78, 1.0), (0, 0, 0.62), "Conteneur", biseau=0.04, effile=(1.06, 1.12))
    boite("Couvercle", (1.40, 0.92, 0.10), (0, 0.02, 1.16), "Conteneur", biseau=0.04)
    boite("Poignee", (1.0, 0.06, 0.06), (0, -0.48, 1.0), "Plastique")
    for x in (-0.5, 0.5):
        for y in (-0.28, 0.28):
            roue("Roulette", 0.06, 0.05, (x, y, 0.06))
    exporter("conteneur")


def banc():
    vider()
    # Banc public : deux pieds en béton, trois lattes d'assise, deux de dossier.
    for x in (-0.72, 0.72):
        boite("Pied", (0.14, 0.50, 0.42), (x, 0, 0.21), "BetonSombre", biseau=0.02)
        boite("Montant", (0.10, 0.08, 0.55), (x, 0.24, 0.62), "Metal")
    for k in range(3):
        boite("Latte", (1.80, 0.12, 0.05), (0, -0.16 + k * 0.15, 0.45), "Bois", biseau=0.01)
    for k in range(2):
        boite("Dossier", (1.80, 0.05, 0.11), (0, 0.27, 0.66 + k * 0.17), "Bois", biseau=0.01)
    exporter("banc")


# ───────────────────────── l'entrée de la tour des Cyprès ─────────────────────────
# Une entrée d'immeuble HLM des années 1960 : dalle-auvent en béton sur deux poteaux,
# hall vitré à cadres alu, interphone, boîtes aux lettres au fond du hall, perron de
# deux marches avec une rampe, et deux jardinières en béton (ledges) de part et d'autre.
# Le hall forme une avancée de 3 m devant la façade de la tour.
# L'origine est au pied du vitrage, au milieu de l'entrée ; -Y = vers l'extérieur, +Y = vers la tour.

def entree_tour():
    vider()
    larg = 4.2
    # Perron : deux marches devant le seuil (0,32 m au total).
    boite("Seuil", (larg + 1.2, 1.6, 0.32), (0, -0.8, 0.16), "Beton")
    boite("Marche", (larg + 1.2, 0.4, 0.16), (0, -1.8, 0.08), "Beton")
    # Dalle-auvent : épaisse, débordante, portée par deux poteaux carrés.
    boite("Auvent", (larg + 1.6, 3.0, 0.28), (0, -1.3, 3.15), "Beton", biseau=0.02)
    boite("AuventBord", (larg + 1.64, 0.12, 0.40), (0, -2.82, 3.10), "BetonSombre")
    for s in (-1, 1):
        boite("Poteau", (0.28, 0.28, 3.0), (s * (larg / 2 + 0.55), -2.5, 1.5 + 0.16), "Beton")
    # Façade du hall : cadre alu, vitrage, double porte.
    boite("Imposte", (larg, 0.16, 0.5), (0, 0.02, 2.75), "Alu")
    for x in (-larg / 2, -0.9, 0.0, 0.9, larg / 2):
        boite("Montant", (0.07, 0.16, 2.5), (x, 0.02, 0.32 + 1.25), "Alu")
    boite("Traverse", (larg, 0.16, 0.07), (0, 0.02, 1.25), "Alu")
    boite("Vitrage", (larg - 0.05, 0.03, 2.4), (0, 0.0, 0.32 + 1.2), "Vitre")
    boite("Barre", (0.5, 0.05, 0.04), (-0.45, -0.1, 1.35), "Alu")
    boite("Barre", (0.5, 0.05, 0.04), (0.45, -0.1, 1.35), "Alu")
    # Interphone sur le poteau de droite du cadre.
    boite("Interphone", (0.26, 0.05, 0.4), (larg / 2 + 0.25, -0.05, 1.4), "Interphone")
    # Le hall derrière la vitre : sol, murs clairs, boîtes aux lettres.
    boite("SolHall", (larg, 3.0, 0.05), (0, 1.5, 0.33), "Carrelage")
    boite("FondHall", (larg, 0.1, 2.6), (0, 3.0, 0.32 + 1.3), "Hall")
    # Le hall forme une avancée devant la tour : murs latéraux et toit en béton.
    for s in (-1, 1):
        boite("MurHall", (0.25, 3.2, 2.95), (s * (larg / 2 + 0.12), 1.5, 0.32 + 1.47), "Beton")
    boite("ToitHall", (larg + 0.5, 3.3, 0.3), (0, 1.55, 3.0), "Beton")
    boite("BoitesLettres", (2.4, 0.3, 1.1), (0, 2.8, 1.25), "BoitesLettres")
    for k in range(6):
        boite("Fente", (0.34, 0.02, 0.03), (-1.0 + k * 0.4, 2.64, 1.55), "Plastique")
    # Rampe métallique le long des marches (côté gauche).
    x = -(larg / 2 + 0.25)
    cylindre("Rampe", 0.03, 0, (x, -2.1, 0.95), (x, -0.2, 1.25), "Metal", 6)
    cylindre("RampeMontant", 0.025, 0, (x, -2.1, 0.0), (x, -2.1, 0.95), "Metal", 6)
    cylindre("RampeMontant", 0.025, 0, (x, -0.2, 0.32), (x, -0.2, 1.25), "Metal", 6)
    # Jardinières en béton : ledges bas, terre et petit arbuste.
    for s in (-1, 1):
        cx = s * (larg / 2 + 2.6)
        boite("Jardiniere", (3.0, 1.2, 0.5), (cx, -1.6, 0.25), "Beton", biseau=0.03)
        boite("Terre", (2.8, 1.0, 0.04), (cx, -1.6, 0.49), "Terre")
        boule("Arbuste", 0.55, (cx + 0.6, -1.6, 0.85), (1.2, 0.9, 0.8), "AiguillesClair")
    exporter("entree_tour")


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    voiture("voiture_citadine", 3.8, 1.64, 0.62, 1.40, -0.55, 1.45, hayon=True)
    voiture("voiture_compacte", 4.1, 1.70, 0.64, 1.42, -0.45, 1.35, hayon=False)
    voiture("utilitaire", 4.1, 1.72, 0.70, 1.82, -1.05, 1.95, hayon=True)
    scooter()
    pin_parasol()
    lampadaire()
    conteneur()
    banc()
    entree_tour()
