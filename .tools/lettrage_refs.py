"""Fabrique les couches du lettrage LOUMS à partir des planches de référence de Louma
(images sur fond transparent : tags, flop, pièce, lettres en bloc pour le rouleau).

Les couches sont des aplats nets (pas de grain de bombe) pour coller au rendu BD du jeu :
  tag_1..n        : un trait, teinté par la bombe
  flop_*          : surcontour / contour / fond / lights
  piece_*         : surcontour2 / surcontour / contour / fond / lights / esquisse / signature
  rouleau         : lettres en bloc pour le rouleau
Usage : python3 lettrage_refs.py <dossier des références> <dossier de sortie>
Références attendues (noms libres, repérés par leur contenu, voir REFS ci-dessous).
"""
import sys, os
import numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
REFS = {
    "piece": ("pieces.png", (1590, 2172)),       # 4e étape de la planche pièce
    "flop": ("flops.png", (1430, 2172)),         # 3e étape de la planche flop
    "rouleau": ("bloc.png", None),
    "tags": ["tag_bleu.png", "tag_fleche.png", "tag_violet.png", "tag_blanc.png"],
}


def disque(r):
    y, x = np.ogrid[-r:r + 1, -r:r + 1]
    return x * x + y * y <= r * r


def net(m, r=2.0):
    """Lisse un masque en bord franc (aplat BD) : ni grain, ni flou."""
    return ndi.gaussian_filter(m.astype(float), r) > 0.5


def ecrire(masques, prefixe, largeur, marge=12):
    union = np.zeros_like(next(iter(masques.values())))
    for m in masques.values():
        union |= m
    ys, xs = np.where(union)
    y0, y1 = max(ys.min() - marge, 0), ys.max() + marge
    x0, x1 = max(xs.min() - marge, 0), xs.max() + marge
    for nom, m in masques.items():
        f = ndi.gaussian_filter(m.astype(float), 0.9)
        a = (np.clip((f - 0.5) * 3 + 0.5, 0, 1) * 255).astype(np.uint8)[y0:y1, x0:x1]
        out = np.zeros(a.shape + (4,), np.uint8)
        out[..., :3] = 255
        out[..., 3] = a
        img = Image.fromarray(out)
        img.resize((largeur, max(1, int(largeur * img.height / img.width))), Image.LANCZOS).save(os.path.join(OUT, prefixe + nom + ".png"))


def charger(nom, cols=None):
    a = np.array(Image.open(os.path.join(SRC, nom)).convert("RGBA"))
    if cols:
        a = a[:, cols[0]:cols[1]]
    hsv = cv2.cvtColor(a[..., :3], cv2.COLOR_RGB2HSV)
    return a, hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)


def propre(m, mini=60):
    lab, n = ndi.label(m)
    if n == 0:
        return m
    taille = ndi.sum(m, lab, range(1, n + 1))
    return np.isin(lab, [i + 1 for i, t in enumerate(taille) if t >= mini])


# ── PIÈCE : fond rose, contour noir, lights blancs, surcontour bleu puis jaune ──
a, h, s, v = charger(*REFS["piece"])
present = a[..., 3] > 90
noir = present & (v < 80)
rose = present & (s > 80) & (v > 90) & ((h > 145) | (h < 8))
blanc = present & (s < 50) & (v > 200)
bleu = present & (s > 80) & (h > 80) & (h < 115)
fond = propre(net(ndi.binary_fill_holes(ndi.binary_closing(rose | blanc, structure=disque(3))) & ~noir | rose, 1.5), 400)
lights = propre(blanc & ndi.binary_erosion(fond | blanc, structure=disque(2)), 30)
contour = net(ndi.binary_fill_holes(ndi.binary_closing(noir | fond, structure=disque(4))), 2.0)
surcontour = net(ndi.binary_fill_holes(ndi.binary_closing(bleu | contour, structure=disque(5))), 2.5)
surcontour2 = net(ndi.binary_closing(present, structure=disque(3)), 2.0)
# Esquisse : le tracé du bord des lettres, en trait fin (première étape de la pièce).
esquisse = fond & ~ndi.binary_erosion(fond, structure=disque(3))
masques = {"surcontour2": surcontour2, "surcontour": surcontour, "contour": contour, "fond": fond, "lights": lights, "esquisse": esquisse}
ecrire(masques, "piece_", 1600)

# ── FLOP : fond clair, contour rouge, lights blancs ; surcontour ajouté (règle du flop) ──
a, h, s, v = charger(*REFS["flop"])
present = a[..., 3] > 90
rouge = present & (s > 90) & ((h < 12) | (h > 165))
clair = present & (s < 60) & (v > 170)
lights = propre(present & (s < 20) & (v > 248) & ndi.binary_erosion(clair, structure=disque(3)), 40)
fond = propre(net(ndi.binary_fill_holes(ndi.binary_closing(clair, structure=disque(3))) & ~rouge | clair, 1.5), 400)
contour = net(ndi.binary_fill_holes(ndi.binary_closing(rouge | fond, structure=disque(4))) | present, 2.0)
surcontour = net(ndi.binary_dilation(contour, structure=disque(18)), 3.0)
ecrire({"surcontour": surcontour, "contour": contour, "fond": fond, "lights": lights}, "flop_", 1024, marge=24)

# ── ROULEAU : lettres en bloc ──
a, h, s, v = charger(*REFS["rouleau"])
ecrire({"rouleau": net(a[..., 3] > 120, 1.2)}, "", 1600)

# ── TAGS : un trait net par référence ──
for i, nom in enumerate(REFS["tags"], 1):
    if not os.path.exists(os.path.join(SRC, nom)):
        continue
    a, h, s, v = charger(nom)
    m = propre(net(a[..., 3] > 110, 1.4), 30)
    ecrire({f"tag_{i}": m}, "", 900)
print("couches écrites dans", OUT)
