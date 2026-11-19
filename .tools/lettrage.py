"""Fabrique le lettrage LOUMS du jeu, dans le style graphique de TRACE (aplats + encre).

Règles du graffiti (données par Louma) :
  tag   : une signature, un seul trait, ça va vite ;
  flop  : fond + contour + surcontour (lettres rondes, deux ou trois couches) ;
  pièce : fond + contour + lights (touches lumineuses) + surcontour, plus gros, signé d'un petit tag.
Chaque couche est une image blanche à transparence ; le jeu la teinte avec la couleur de la bombe.
Les lettres doivent rester lisibles : L-O-U-M-S, liées entre elles.

Usage : python3 lettrage.py <dossier de sortie> [tag.png]
"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

SORTIE = sys.argv[1]
TAG = sys.argv[2] if len(sys.argv) > 2 else None
os.makedirs(SORTIE, exist_ok=True)
POLICE_RONDE = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
POLICE_PIECE = "/usr/share/fonts/truetype/google-fonts/ofl/archivoblack/ArchivoBlack-Regular.ttf"


def disque(r):
    y, x = np.ogrid[-r:r + 1, -r:r + 1]
    return x * x + y * y <= r * r


def dil(m, r):
    return ndi.binary_dilation(m, structure=disque(r)) if r > 0 else m


def arrondi(m, r):
    return ndi.gaussian_filter(m.astype(float), r) > 0.5


def lettres(police, taille, poses, chevauche, marge=200):
    """Dessine L O U M S une à une (rotation, décalage vertical, échelle) et les lie."""
    font = ImageFont.truetype(police, taille)
    W, H = int(taille * 5.2) + 2 * marge, int(taille * 1.9) + 2 * marge
    total = np.zeros((H, W), bool)
    x = marge
    for lettre, (angle, dy, ech) in zip("LOUMS", poses):
        f = ImageFont.truetype(police, int(taille * ech))
        boite = f.getbbox(lettre)
        w, h = boite[2] - boite[0], boite[3] - boite[1]
        im = Image.new("L", (w + 80, h + 80), 0)
        ImageDraw.Draw(im).text((40 - boite[0], 40 - boite[1]), lettre, font=f, fill=255)
        im = im.rotate(angle, resample=Image.BICUBIC, expand=True)
        a = np.array(im) > 128
        y = marge + int(taille * 0.35) + dy - (a.shape[0] - h - 80) // 2
        total[y:y + a.shape[0], x:x + a.shape[1]] |= a
        x += int((a.shape[1] - 80) * chevauche)
    return total


def sauver(couches, nom_base, largeur):
    tout = np.zeros_like(next(iter(couches.values())))
    for m in couches.values():
        tout |= m
    ys, xs = np.where(tout)
    y0, y1, x0, x1 = ys.min() - 6, ys.max() + 6, xs.min() - 6, xs.max() + 6
    for nom, m in couches.items():
        f = ndi.gaussian_filter(m.astype(float), 1.2)
        a = (np.clip((f - 0.5) * 3 + 0.5, 0, 1) * 255).astype(np.uint8)[y0:y1, x0:x1]
        out = np.zeros(a.shape + (4,), np.uint8)
        out[..., :3] = 255
        out[..., 3] = a
        img = Image.fromarray(out)
        img.resize((largeur, int(largeur * img.height / img.width)), Image.LANCZOS).save(os.path.join(SORTIE, f"{nom_base}_{nom}.png"))
    return (y0, y1, x0, x1)


# ── FLOP : lettres rondes et gonflées ; fond, contour, surcontour (+ trait d'encre du jeu) ──
L = lettres(POLICE_RONDE, 300, [(6, 14, 1.0), (-7, -16, 0.95), (8, 10, 1.0), (-6, -14, 1.02), (10, 8, 1.05)], 0.82)
fond = arrondi(dil(L, 17), 10)
contour = arrondi(dil(fond, 16), 6)
surcontour = arrondi(dil(contour, 18), 6)
encre = dil(surcontour, 5) & ~surcontour
sauver({"surcontour": surcontour, "contour": contour, "fond": fond, "encre": encre}, "flop", 1024)

# ── PIÈCE : lettres plus nerveuses, penchées ; fond, contour, lights, surcontour, petit tag ──
P = lettres(POLICE_PIECE, 300, [(-13, 26, 1.12), (9, -24, 0.9), (-7, 16, 1.0), (11, -20, 1.06), (-14, 8, 1.16)], 0.80)
fond = arrondi(dil(P, 8), 3)
# Biseaux : les pointes des lettres sont étirées vers le haut à droite (style « sharp »).
pointes = arrondi(ndi.binary_erosion(np.roll(fond, (-14, 10), axis=(0, 1)), structure=disque(6)), 3) & ~fond
fond = fond | arrondi(dil(pointes, 4), 2)
contour = arrondi(dil(fond, 12), 3)
surcontour = arrondi(dil(contour, 22), 5)
# Lights : un liseré lumineux en haut à gauche de chaque lettre, plus quelques touches.
bord = fond & ~np.roll(fond, (11, 8), axis=(0, 1))
lights = ndi.binary_opening(bord & ndi.binary_erosion(fond, structure=disque(3)), structure=disque(2))
rng = np.random.default_rng(13013)
ys, xs = np.where(ndi.binary_erosion(fond, structure=disque(20)))
eclat = Image.new("L", fond.shape[::-1], 0)
d = ImageDraw.Draw(eclat)
for i in rng.choice(len(ys), 10, replace=False):
    y, x = int(ys[i]), int(xs[i])
    long = int(rng.integers(26, 46))
    d.line([(x - long, y + long // 2), (x + long, y - long // 2)], fill=255, width=9)   # trait de lumière en biais
    d.ellipse([x + long + 8, y - long // 2 - 18, x + long + 22, y - long // 2 - 4], fill=255)  # petit point
lights |= np.array(eclat) > 128
lights &= fond
encre = (dil(surcontour, 5) & ~surcontour) | (dil(fond, 2) & ~fond)
couches = {"surcontour": surcontour, "contour": contour, "fond": fond, "lights": lights, "encre": encre}
y0, y1, x0, x1 = sauver(couches, "piece", 1600)

# Le petit tag en signature, en bas à droite de la pièce (même cadre que les autres couches).
if TAG and os.path.exists(TAG):
    t = Image.open(TAG).split()[3]
    H, W = y1 - y0, x1 - x0
    ht = int(H * 0.30)
    t = t.resize((int(t.width * ht / t.height), ht), Image.LANCZOS)
    cadre = Image.new("L", (W, H), 0)
    cadre.paste(t, (W - t.width - 10, H - t.height - 4))
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = np.array(cadre)
    img = Image.fromarray(out)
    img.resize((1600, int(1600 * H / W)), Image.LANCZOS).save(os.path.join(SORTIE, "piece_signature.png"))
print("lettrage écrit dans", SORTIE)
