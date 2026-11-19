"""TRACE — génère les vieux graffitis du décor (conversation n°2, habillage).

    python assets/decor/source/generer_graffitis.py

Produit des images PNG transparentes dans assets/decor/graff/ :
  tag_XX.png      tags d'une couleur, tracés au marqueur (blanc : la couleur est donnée dans le jeu)
  flop_XX.png     flops (lettres rondes, remplissage + contour), couleurs incluses
  affiche_XX.png  affiches collées puis arrachées
  efface_XX.png   rectangles de peinture grise passés par-dessus d'anciens tags
Ce sont des signatures INVENTÉES, sans lettres lisibles : aucun graffeur réel n'est reproduit.
Ces décors sont distincts des graffitis du joueur (graffiti.gd, conversation n°1).
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

SORTIE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "graff"))
os.makedirs(SORTIE, exist_ok=True)
R = random.Random(13013)


def glyphe(x, h):
    """Une « lettre » de tag : un fût vertical et un geste (boucle, crochet ou zigzag), sans être une vraie lettre."""
    traits = []
    haut = R.uniform(0.75, 1.1) * h
    base = h
    traits.append([(x, base), (x + R.uniform(-0.05, 0.1) * h, base - haut)])  # fût
    forme = R.choice(["boucle", "crochet", "zigzag", "arche"])
    if forme == "boucle":
        cx, cy, r = x + 0.22 * h, base - haut * 0.7, 0.2 * h
        traits.append([(x, base - haut), (cx + r, cy - r * 0.5), (cx + r * 0.6, cy + r), (x, cy + r * 0.3)])
        largeur = 0.45 * h
    elif forme == "crochet":
        traits.append([(x, base - haut), (x + 0.35 * h, base - haut * 1.05), (x + 0.3 * h, base - haut * 0.55)])
        largeur = 0.42 * h
    elif forme == "zigzag":
        traits.append([(x, base), (x + 0.18 * h, base - haut * 0.8), (x + 0.32 * h, base - 0.05 * h), (x + 0.45 * h, base - haut)])
        largeur = 0.55 * h
    else:
        traits.append([(x, base), (x + 0.2 * h, base - haut), (x + 0.4 * h, base)])
        largeur = 0.5 * h
    return traits, x + largeur


def enregistrer(im, nom):
    """Recadre sur le dessin (marge de 8 px) et enregistre."""
    b = im.getchannel("A").getbbox()
    if b:
        im = im.crop((max(0, b[0] - 8), max(0, b[1] - 8), min(im.width, b[2] + 8), min(im.height, b[3] + 8)))
    im.save(os.path.join(SORTIE, nom))


def courbe(pts, n=8):
    """Lisse une ligne brisée (Chaikin) pour un geste plus fluide."""
    for _ in range(2):
        nv = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            nv.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            nv.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        nv.append(pts[-1])
        pts = nv
    return pts


def penche(pts, ox, oy, angle):
    c = math.tan(angle)
    return [(ox + x - (y) * c, oy + y) for x, y in pts]


def tag(i):
    W, H = 640, 256
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    h = 150.0
    x = 0.0
    traits = []
    for _ in range(R.randint(3, 5)):
        t, x = glyphe(x, h)
        traits += t
    if R.random() < 0.6:  # soulignement d'un seul geste, pas systématique
        traits.append([(-10, h * 1.08), (x * 0.5, h * 1.2), (x + 25, h * 0.95)])
    largeur = R.randint(11, 16)
    ech = min(1.0, (W - 80) / max(x + 40, 1))
    angle = R.uniform(0.15, 0.35)
    for t in traits:
        t = penche([(a * ech, b * ech) for a, b in courbe(t)], 50, (H - h * ech * 1.25) / 2, angle)
        d.line(t, fill=(255, 255, 255, 255), width=largeur, joint="curve")
        for p in (t[0], t[-1]):
            d.ellipse([p[0] - largeur / 2, p[1] - largeur / 2, p[0] + largeur / 2, p[1] + largeur / 2], fill=(255, 255, 255, 255))
    enregistrer(im, "tag_%02d.png" % i)


PALETTE_FLOP = [
    ((236, 236, 228), (24, 22, 30)), ((245, 205, 40), (30, 30, 70)), ((230, 50, 120), (20, 20, 25)),
    ((60, 170, 235), (250, 250, 245)), ((200, 200, 205), (180, 30, 40)), ((250, 140, 40), (40, 20, 60)),
]


def flop(i):
    """Lettres rondes posées l'une sur l'autre, chacune avec son contour, comme un flop peint vite."""
    W, H = 900, 400
    remplissage, contour = PALETTE_FLOP[i % len(PALETTE_FLOP)]
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = 70
    for _ in range(R.randint(3, 5)):
        w = R.uniform(130, 180)
        hh = R.uniform(200, 250)
        y = (H - hh) / 2 + R.uniform(-15, 15)
        lettre = Image.new("L", (W, H), 0)
        dl = ImageDraw.Draw(lettre)
        dl.rounded_rectangle([x, y, x + w, y + hh], radius=w * R.uniform(0.3, 0.48), fill=255)
        if R.random() < 0.5:  # une jambe ou une bosse qui dépasse
            dl.rounded_rectangle([x + w * 0.55, y + hh * 0.5, x + w * 1.05, y + hh + 15], radius=40, fill=255)
        bord = lettre.filter(ImageFilter.MaxFilter(23))
        im.paste(Image.new("RGBA", (W, H), contour + (255,)), (0, 0), bord)
        im.paste(Image.new("RGBA", (W, H), remplissage + (255,)), (0, 0), lettre)
        # Le jour de la lettre : une fente verticale de la couleur du contour.
        if R.random() < 0.75:
            fx = x + w * R.uniform(0.38, 0.55)
            ImageDraw.Draw(im).rounded_rectangle([fx, y + hh * 0.22, fx + 16, y + hh * 0.72], radius=8, fill=contour + (255,))
        x += w * R.uniform(0.62, 0.75)
    # Reflets blancs : petits traits obliques en haut des lettres.
    d = ImageDraw.Draw(im)
    for _ in range(R.randint(3, 6)):
        rx = R.uniform(100, x)
        ry = R.uniform(H * 0.22, H * 0.32)
        if im.getpixel((int(rx), int(ry)))[:3] == remplissage:
            d.line([(rx, ry), (rx + 22, ry - 10)], fill=(255, 255, 255, 255), width=7)
    enregistrer(im, "flop_%02d.png" % i)


AFFICHES = [(225, 60, 50), (245, 200, 50), (40, 90, 170), (235, 230, 215), (30, 30, 35), (90, 160, 90)]


def affiche(i):
    W, H = 300, 420
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for k in range(R.randint(2, 4)):  # plusieurs affiches collées les unes sur les autres
        c = AFFICHES[R.randrange(len(AFFICHES))]
        x0, y0 = R.uniform(0, 40), R.uniform(0, 60)
        x1, y1 = W - R.uniform(0, 40), H - R.uniform(0, 60)
        d.rectangle([x0, y0, x1, y1], fill=c + (255,))
        fonce = tuple(int(v * 0.55) for v in c)
        for _ in range(R.randint(2, 5)):  # bandeaux de « texte » illisible
            ty = R.uniform(y0 + 20, y1 - 30)
            d.rectangle([x0 + 20, ty, x0 + 20 + R.uniform(60, x1 - x0 - 40), ty + R.uniform(8, 26)], fill=fonce + (255,))
    # Arrachements : des morceaux enlevés laissent voir le mur.
    gomme = Image.new("L", (W, H), 255)
    dg = ImageDraw.Draw(gomme)
    for _ in range(R.randint(2, 5)):
        cx, cy = R.uniform(0, W), R.uniform(0, H)
        pts = [(cx + R.uniform(-90, 90), cy + R.uniform(-90, 90)) for _ in range(6)]
        dg.polygon(pts, fill=0)
    a = im.getchannel("A")
    im.putalpha(Image.composite(a, Image.new("L", (W, H), 0), gomme))
    enregistrer(im, "affiche_%02d.png" % i)


def efface(i):
    W, H = 512, 256
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(R.randint(1, 3)):
        x0, y0 = R.uniform(0, 120), R.uniform(0, 60)
        d.rectangle([x0, y0, x0 + R.uniform(200, 380), y0 + R.uniform(120, 190)], fill=(255, 255, 255, 255))
    # Bords au rouleau, un peu irréguliers.
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    enregistrer(im, "efface_%02d.png" % i)


if __name__ == "__main__":
    for i in range(14):
        tag(i)
    for i in range(6):
        flop(i)
    for i in range(6):
        affiche(i)
    for i in range(4):
        efface(i)
    print("graffitis générés dans", SORTIE)
