#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TRACE — fabrique TOUTE la banque de sons par synthèse (numpy seulement, aucune ressource tierce).

    python3 .tools/son_generer.py [dossier_de_sortie]      (par défaut : assets/sons)

Tout est original : bruits filtrés, résonances amorties, oscillateurs. Rien n'est tiré d'un enregistrement,
d'une banque de sons ou d'un fichier de quelqu'un d'autre, donc pas de licence à respecter et rien de privé
dans le dépôt public. Le tirage aléatoire est fixé : relancer le script redonne exactement les mêmes fichiers.

Pour remplacer un son par un vrai enregistrement : déposer un fichier du même nom dans assets/sons
(ou « nom_1.wav », « nom_2.wav »… pour des variantes). Le jeu choisit une variante au hasard à chaque fois.
Les sons qui tournent en boucle finissent par « _loop » : le jeu les boucle tout seul.
"""
import os, sys, wave
import numpy as np

SR = 44100
RNG = np.random.default_rng(2014)
TAU = 2 * np.pi


def n_(d): return int(round(SR * d))
def t_(d): return np.arange(n_(d)) / SR
def noise(n): return RNG.standard_normal(n)
def nz(x): return x / (np.std(x) + 1e-12)
def att(n, a): return np.minimum(1.0, np.arange(n) / (a * SR))
def dec(n, tau): return np.exp(-np.arange(n) / SR / tau)
def bell(n, centre, large): return np.exp(-(((np.arange(n) / SR) - centre) / large) ** 2)


def _f(x, gain):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1e-3
    return np.fft.irfft(X * gain(f), n)


def lp(x, fc, o=2): return _f(x, lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * o)))
def hp(x, fc, o=2): return _f(x, lambda f: 1.0 / np.sqrt(1.0 + (fc / f) ** (2 * o)))
def bp(x, lo, hi, o=2): return hp(lp(x, hi, o), lo, o)


def formant(x, fs):
    return _f(x, lambda f: sum(g * np.exp(-((f - c) / w) ** 2) for c, w, g in fs) + 0.02)


def shift(x, t, n=None):
    n = n or len(x)
    y = np.zeros(n)
    k = n_(t)
    if k < n:
        m = min(len(x), n - k)
        y[k:k + m] = x[:m]
    return y


def put(buf, x, t, g=1.0):
    k = n_(t)
    if k >= len(buf):
        return
    m = min(len(x), len(buf) - k)
    buf[k:k + m] += g * x[:m]


def put_wrap(buf, x, t, g=1.0):
    idx = (n_(t) + np.arange(len(x))) % len(buf)
    buf[idx] += g * x


def ping(d, freqs, taus, amps=None):
    t = t_(d)
    y = np.zeros_like(t)
    for i, (f, tau) in enumerate(zip(freqs, taus)):
        y += (1.0 if amps is None else amps[i]) * np.sin(TAU * f * t + RNG.uniform(0, TAU)) * np.exp(-t / tau)
    return y


def am(n, cycles, depth, phase=0.0):
    return 1.0 + depth * np.sin(TAU * cycles * np.arange(n) / n + phase)


def jitter(n, fc, depth):
    j = lp(noise(n), fc)
    return np.clip(1.0 + depth * j / (np.std(j) + 1e-12), 0.1, None)


def mallet(f, d=0.5):
    t = t_(d)
    return (np.sin(TAU * f * t) * np.exp(-t / 0.16) + 0.35 * np.sin(TAU * f * 3.99 * t) * np.exp(-t / 0.035)) * att(len(t), 0.003)


def chirp(f0, f1, d, env_tau=None):
    t = t_(d)
    f = f0 + (f1 - f0) * t / d
    y = np.sin(TAU * np.cumsum(f) / SR)
    e = np.sin(np.pi * t / d) ** 1.5
    return y * e


# ---------------------------------------------------------------- pas, saut, atterrissage (à pied)
def s_pas_dur():
    d = 0.22; n = n_(d); t = t_(d)
    f0 = RNG.uniform(85, 130)
    y = np.sin(TAU * f0 * t * (1 - 0.3 * t / d)) * np.exp(-t / 0.03) * 0.9
    y += bp(noise(n), 1500, 5500) * np.exp(-t / 0.012)
    y += shift(bp(noise(n), 2500, 7000) * np.exp(-t / 0.010), 0.045) * 0.5
    y += bp(noise(n), 3000, 9000) * np.exp(-t / 0.05) * 0.12
    return y


def s_pas_herbe():
    d = 0.26; n = n_(d); t = t_(d)
    y = bp(noise(n), 200, 2200) * att(n, 0.012) * np.exp(-t / 0.07)
    y += np.sin(TAU * RNG.uniform(70, 100) * t) * np.exp(-t / 0.04) * 0.5
    y += shift(bp(noise(n), 1000, 3500) * np.exp(-t / 0.05), 0.06) * 0.4
    return y


def s_pas_gravier():
    d = 0.28; n = n_(d); y = np.zeros(n)
    for _ in range(int(RNG.integers(10, 18))):
        g = bp(noise(n_(0.02)), RNG.uniform(1500, 3500), RNG.uniform(5000, 9000)) * dec(n_(0.02), 0.004)
        put(y, g, abs(RNG.normal(0, 0.06)), RNG.uniform(0.4, 1.0))
    y += lp(noise(n), 600) * np.exp(-t_(d) / 0.04) * 0.6
    return y


def s_atterri_pied():
    d = 0.32; n = n_(d); t = t_(d)
    y = np.sin(TAU * RNG.uniform(60, 80) * t) * np.exp(-t / 0.05) * 1.2
    y += bp(noise(n), 500, 4000) * np.exp(-t / 0.03) * 0.9
    y += lp(noise(n), 900) * np.exp(-t / 0.08) * 0.5
    return y


def s_saut_pied():
    d = 0.16; n = n_(d); t = t_(d)
    y = bp(noise(n), 600, 3000) * bell(n, 0.05, 0.035) * 0.6
    y += np.sin(TAU * 110 * t) * np.exp(-t / 0.03) * 0.7
    return y


# ---------------------------------------------------------------- skate
def s_roule_loop():
    D = 2.0; n = n_(D)
    y = nz(bp(noise(n), 250, 3200)) * am(n, 14, 0.25)
    y += nz(lp(noise(n), 220)) * 0.9 * am(n, 3, 0.3, 1.0)
    y += nz(hp(noise(n), 4500)) * 0.08
    for _ in range(9):
        c = bp(noise(n_(0.006)), 1500, 6000) * dec(n_(0.006), 0.0015)
        put_wrap(y, c, RNG.uniform(0, D), RNG.uniform(1.5, 3.5))
    return y


def s_roule_gravier_loop():
    D = 2.0; n = n_(D)
    y = nz(bp(noise(n), 400, 6500)) * am(n, 11, 0.3)
    y += nz(lp(noise(n), 300)) * 0.8
    for _ in range(70):
        c = bp(noise(n_(0.008)), 1200, 8000) * dec(n_(0.008), 0.002)
        put_wrap(y, c, RNG.uniform(0, D), RNG.uniform(1.5, 4.0))
    return y


def s_roule_herbe_loop():
    D = 2.0; n = n_(D)
    y = nz(bp(noise(n), 120, 1100)) * am(n, 5, 0.35)
    y += nz(lp(noise(n), 160)) * 0.8
    y += nz(bp(noise(n), 1500, 4000)) * 0.12 * am(n, 9, 0.4)
    return y


def s_frein_loop():
    D = 1.0; n = n_(D)
    return nz(bp(noise(n), 500, 5500)) * jitter(n, 35, 0.8) + nz(lp(noise(n), 250)) * 0.4


def s_pousse():
    d = 0.2; n = n_(d); t = t_(d)
    y = bp(noise(n), 700, 4500) * att(n, 0.006) * np.exp(-t / 0.05)
    y += np.sin(TAU * RNG.uniform(110, 160) * t) * np.exp(-t / 0.025) * 0.7
    y += shift(hp(noise(n), 3000) * np.exp(-t / 0.02), 0.09) * 0.35
    return y


def s_ollie_pop():
    d = 0.28; n = n_(d); t = t_(d)
    y = hp(noise(n), 2200) * np.exp(-t / 0.006) * 1.2
    y += ping(d, [RNG.uniform(340, 420), RNG.uniform(700, 820), RNG.uniform(1300, 1500)], [0.05, 0.03, 0.02], [1, 0.6, 0.3]) * 0.7
    y += np.sin(TAU * 150 * t) * np.exp(-t / 0.03) * 0.8
    y += shift(bp(noise(n), 900, 3500) * np.exp(-t / 0.05) * att(n, 0.01), 0.035) * 0.45
    return y


def s_atterri(fort):
    d = 0.5 if fort else 0.32; n = n_(d); t = t_(d); y = np.zeros(n)
    for dt, g in ((0.0, 1.0), (0.022, 0.8)):
        imp = ping(0.3, [RNG.uniform(230, 300), RNG.uniform(520, 640), RNG.uniform(900, 1100)], [0.05, 0.035, 0.02], [1, 0.7, 0.4])
        imp += hp(noise(n_(0.3)), 2000) * dec(n_(0.3), 0.008)
        put(y, imp, dt, g)
    if fort:
        y += np.sin(TAU * 85 * t) * np.exp(-t / 0.05) * 1.2
    y += nz(bp(noise(n), 900, 4500)) * np.exp(-t / (0.12 if fort else 0.07)) * (0.45 if fort else 0.3) * am(n, 40, 0.5)
    return y


def s_kickflip():
    d = 0.5; n = n_(d); y = np.zeros(n)
    put(y, s_ollie_pop()[:n_(0.2)], 0.0, 0.7)
    b = bell(n, 0.24, 0.09)
    y += bp(noise(n), 500, 2500) * b * 0.55 + hp(noise(n), 3000) * b * 0.18
    for tt in (0.14, 0.31):
        put(y, bp(noise(n_(0.03)), 2500, 7000) * dec(n_(0.03), 0.006), tt, 0.5)
    return y


def s_shoveit():
    d = 0.4; n = n_(d); y = np.zeros(n)
    put(y, s_ollie_pop()[:n_(0.2)], 0.0, 0.35)
    b = bell(n, 0.2, 0.08)
    y += bp(noise(n), 350, 1800) * b * 0.7
    y += bp(noise(n), 1800, 6000) * bell(n, 0.14, 0.05) * 0.35
    return y


def s_grind_debut():
    d = 0.3; n = n_(d); t = t_(d)
    y = ping(d, [1250, 2900, 4700, 6500], [0.09, 0.06, 0.04, 0.025], [1, 0.7, 0.5, 0.3])
    y += hp(noise(n), 2500) * np.exp(-t / 0.015) * 0.9
    y += bp(noise(n), 1500, 6500) * att(n, 0.02) * np.exp(-t / 0.12) * 0.5
    y += np.sin(TAU * 130 * t) * np.exp(-t / 0.03) * 0.6
    return y


def s_grind_loop():
    D = 1.2; n = n_(D)
    y = nz(bp(noise(n), 1800, 7500)) * 0.6
    for c, g in ((1800, 1.3), (3100, 1.0), (4600, 0.8)):
        y += nz(bp(noise(n), c * 0.93, c * 1.07, 3)) * g * 0.5
    return y * jitter(n, 50, 0.35) + nz(lp(noise(n), 400)) * 0.15


def s_grind_beton_loop():
    D = 1.2; n = n_(D)
    y = nz(bp(noise(n), 300, 2600)) * jitter(n, 60, 0.6)
    y += nz(lp(noise(n), 300)) * 0.8 * am(n, 6, 0.3)
    for _ in range(40):
        put_wrap(y, bp(noise(n_(0.01)), 800, 5000) * dec(n_(0.01), 0.002), RNG.uniform(0, D), RNG.uniform(1.0, 3.0))
    return y


def s_grind_fin():
    d = 0.3; n = n_(d); t = t_(d)
    y = ping(d, [1800, 3300, 5200], [0.07, 0.05, 0.03], [1, 0.6, 0.4])
    y += bp(noise(n), 1500, 6000) * np.exp(-t / 0.06) * 0.4
    return y


def s_planche_pose():
    d = 0.3; n = n_(d); t = t_(d)
    y = ping(d, [330, 690, 1250], [0.05, 0.035, 0.02], [1, 0.6, 0.3]) + hp(noise(n), 2500) * np.exp(-t / 0.008) * 0.8
    y += nz(bp(noise(n), 900, 4500)) * np.exp(-t / 0.1) * 0.25 * am(n, 30, 0.5)
    return y


def s_planche_pied():
    d = 0.18; n = n_(d); t = t_(d)
    return np.sin(TAU * 190 * t) * np.exp(-t / 0.03) + bp(noise(n), 800, 3500) * np.exp(-t / 0.015) * 0.6 + nz(bp(noise(n), 900, 4500)) * np.exp(-t / 0.06) * 0.2 * am(n, 30, 0.5)


def s_planche_ramasse():
    d = 0.35; n = n_(d); t = t_(d)
    y = bp(noise(n), 700, 3500) * bell(n, 0.06, 0.05) * 0.5
    put(y, ping(0.2, [360, 740], [0.05, 0.03], [1, 0.5]) + hp(noise(n_(0.2)), 2500) * dec(n_(0.2), 0.008), 0.1, 0.9)
    return y


def s_planche_range():
    d = 0.3; n = n_(d); t = t_(d)
    return bp(noise(n), 1000, 5000) * bell(n, 0.06, 0.05) * 0.6 + np.sin(TAU * 120 * t) * np.exp(-t / 0.04) * 0.9 + lp(noise(n), 1500) * np.exp(-t / 0.05) * 0.4


def s_chute():
    d = 0.8; n = n_(d); t = t_(d)
    y = np.sin(TAU * RNG.uniform(60, 85) * t * (1 - 0.2 * t)) * np.exp(-t / 0.06) * 1.3
    y += lp(noise(n), 900) * np.exp(-t / 0.05)
    y += bp(noise(n), 500, 3500) * att(n, 0.01) * np.exp(-t / 0.25) * 0.5
    y += shift(bp(noise(n), 1500, 5000) * np.exp(-t / 0.03), 0.16) * 0.4
    return y


def s_planche_chute():
    d = 1.1; n = n_(d); y = np.zeros(n)
    tt = 0.0; gap = 0.16; g = 1.0
    for _ in range(6):
        imp = ping(0.25, [RNG.uniform(300, 380), RNG.uniform(650, 780), RNG.uniform(1200, 1400)], [0.04, 0.03, 0.02], [1, 0.6, 0.3]) + hp(noise(n_(0.25)), 2500) * dec(n_(0.25), 0.006)
        put(y, imp, tt, g)
        tt += gap; gap *= 0.68; g *= 0.65
    y += nz(bp(noise(n), 900, 4500)) * np.exp(-t_(d) / 0.45) * 0.25 * am(n, 60, 0.6)
    return y


def s_choc_planche():
    d = 0.2; n = n_(d); t = t_(d)
    return ping(d, [RNG.uniform(320, 380), RNG.uniform(700, 780), 1300], [0.04, 0.03, 0.02], [1, 0.6, 0.3]) + hp(noise(n), 2500) * np.exp(-t / 0.006)


# ---------------------------------------------------------------- grimpe
def s_main_mur():
    d = 0.14; n = n_(d); t = t_(d)
    return bp(noise(n), 700, 3200) * np.exp(-t / 0.02) + np.sin(TAU * RNG.uniform(150, 190) * t) * np.exp(-t / 0.03) * 0.9


def s_hisse():
    d = 0.8; n = n_(d); t = t_(d); y = np.zeros(n)
    y += bp(noise(n), 1200, 5000) * bell(n, 0.3, 0.22) * 0.35
    for tt in (0.12, 0.38):
        put(y, bp(noise(n_(0.12)), 900, 4000) * att(n_(0.12), 0.01) * dec(n_(0.12), 0.04), tt, 0.5)
    put(y, np.sin(TAU * 95 * t_(0.2)) * dec(n_(0.2), 0.04) + lp(noise(n_(0.2)), 800) * dec(n_(0.2), 0.04) * 0.6, 0.6, 0.9)
    return y


def s_lache():
    d = 0.3; n = n_(d)
    return bp(noise(n), 500, 3500) * bell(n, 0.1, 0.07) * 0.6 + lp(noise(n), 700) * bell(n, 0.12, 0.06) * 0.5


def s_decale():
    d = 0.18; n = n_(d)
    return bp(noise(n), 900, 4000) * att(n, 0.01) * np.exp(-np.arange(n) / SR / 0.05)


def s_goutiere_agrippe():
    d = 0.6; n = n_(d); t = t_(d)
    y = ping(d, [430, 860, 1290, 1900], [0.25, 0.18, 0.12, 0.08], [1, 0.7, 0.5, 0.3])
    y += hp(noise(n), 2000) * np.exp(-t / 0.01) * 0.8
    return y


def s_goutiere_grimpe():
    d = 0.3; n = n_(d); t = t_(d)
    y = ping(d, [RNG.uniform(480, 560), RNG.uniform(980, 1100), 1570], [0.12, 0.08, 0.05], [1, 0.6, 0.4]) * 0.6
    y += bp(noise(n), 1500, 6000) * np.exp(-t / 0.02) * 0.4
    return y


def s_course_murale():
    d = 0.3; n = n_(d); t = t_(d)
    y = bp(noise(n), 1500, 6000) * np.exp(-t / 0.05) * 0.7 + np.sin(TAU * 110 * t) * np.exp(-t / 0.04) * 0.8
    sq = chirp(900, 1500, 0.07)
    put(y, sq, 0.02, 0.5)
    return y


# ---------------------------------------------------------------- graffiti
def s_bombe_secoue():
    d = 0.55; n = n_(d); y = np.zeros(n)
    for k in range(8):
        tt = 0.03 + k * 0.065 + RNG.uniform(-0.008, 0.008)
        hit = hp(noise(n_(0.12)), 2500) * dec(n_(0.12), 0.005) + ping(0.12, [RNG.uniform(900, 1300), RNG.uniform(1800, 2600)], [0.03, 0.02], [0.5, 0.3])
        put(y, hit, tt, RNG.uniform(0.5, 1.0))
        put(y, ping(0.25, [640, 1310, 2230], [0.1, 0.07, 0.04], [0.4, 0.25, 0.15]), tt, 0.35)
    return y * att(n, 0.03)


def s_spray_loop():
    D = 1.5; n = n_(D)
    y = nz(bp(noise(n), 2000, 11000)) * am(n, 2, 0.07)
    y += nz(bp(noise(n), 800, 2500)) * 0.25
    return y * jitter(n, 25, 0.06)


def s_spray_debut():
    d = 0.14; n = n_(d)
    y = bp(noise(n), 2000, 11000) * att(n, 0.05) * 0.8
    put(y, ping(0.05, [1800, 3600], [0.01, 0.006]), 0.0, 0.5)
    return y


def s_spray_fin():
    d = 0.22; n = n_(d); t = t_(d)
    y = bp(noise(n), 2000, 11000) * np.exp(-t / 0.05)
    put(y, ping(0.05, [2500], [0.008]), 0.0, 0.3)
    return y


def s_spray_tap():
    d = 0.1; n = n_(d)
    return bp(noise(n), 2000, 10000) * bell(n, 0.035, 0.03)


def s_bombe_vide():
    d = 0.9; n = n_(d); y = np.zeros(n)
    for i, tt in enumerate((0.0, 0.14, 0.31, 0.43, 0.62)):
        w = RNG.uniform(0.03, 0.07)
        put(y, bp(noise(n_(w)), 1000, 6000) * np.sin(np.pi * np.arange(n_(w)) / n_(w)), tt, 0.9 - 0.15 * i)
    y += bp(noise(n), 3000, 9000) * bell(n, 0.7, 0.12) * 0.1
    return y


def s_bombe_change():
    d = 0.32; n = n_(d); y = np.zeros(n)
    put(y, s_bombe_secoue()[:n_(0.25)], 0.05, 0.45)
    put(y, ping(0.1, [1500, 3100], [0.02, 0.012]) + hp(noise(n_(0.1)), 2500) * dec(n_(0.1), 0.006), 0.0, 0.7)
    return y


def s_perche_deplie():
    d = 0.85; n = n_(d); y = np.zeros(n)
    for tt in (0.05, 0.15, 0.23, 0.30, 0.36, 0.41, 0.45):
        put(y, ping(0.08, [2600, 4300], [0.012, 0.008]) + hp(noise(n_(0.08)), 3000) * dec(n_(0.08), 0.004), tt, 0.7)
    y += bp(noise(n), 2000, 7000) * bell(n, 0.25, 0.18) * 0.2
    put(y, ping(0.3, [700, 1400], [0.08, 0.05]), 0.55, 0.4)
    return y


def s_rouleau_trempe():
    d = 0.8; n = n_(d); t = t_(d); y = lp(noise(n), 700) * bell(n, 0.3, 0.18) * 0.5
    y += hp(noise(n), 1500) * np.exp(-t / 0.04) * 0.3
    for _ in range(6):
        f0 = RNG.uniform(250, 450)
        put(y, chirp(f0, f0 * 2.2, 0.07) * RNG.uniform(0.3, 0.7), RNG.uniform(0.05, 0.55))
    return y


def s_rouleau_loop():
    D = 1.6; n = n_(D)
    y = nz(bp(noise(n), 400, 2800)) * (0.45 + 0.55 * np.abs(np.sin(TAU * 2 * np.arange(n) / n)))
    for _ in range(40):
        put_wrap(y, bp(noise(n_(0.01)), 2000, 7000) * dec(n_(0.01), 0.002), RNG.uniform(0, D), RNG.uniform(0.5, 1.5))
    return y


def s_goutte():
    d = 0.14; n = n_(d); t = t_(d)
    y = chirp(RNG.uniform(1300, 1700), RNG.uniform(700, 900), 0.09) * 0.9
    return shift(y, 0.0, n) + hp(noise(n), 3000) * np.exp(-t / 0.004) * 0.15


def s_etape_ok():
    d = 0.4; y = np.zeros(n_(d))
    put(y, mallet(659, 0.4), 0.0, 0.7)
    put(y, mallet(988, 0.35), 0.06, 0.6)
    return y


def s_graff_pose():
    d = 0.9; y = np.zeros(n_(d))
    for i, f in enumerate((523, 659, 784, 1047)):
        put(y, mallet(f, 0.6), i * 0.07, 0.7)
    return y


def s_graff_rate():
    d = 0.5; n = n_(d); t = t_(d)
    y = np.sin(TAU * 196 * t * (1 - 0.08 * t)) * np.exp(-t / 0.15) + np.sin(TAU * 207 * t) * np.exp(-t / 0.15) * 0.7
    y += bp(noise(n), 400, 2500) * np.exp(-t / 0.05) * 0.3
    return y * att(n, 0.004)


def s_fouille():
    d = 1.7; n = n_(d); t = t_(d)
    y = ping(d, [150, 410, 870, 1400], [0.5, 0.3, 0.2, 0.12], [1, 0.7, 0.5, 0.3]) + hp(noise(n), 1500) * np.exp(-t / 0.02)
    for _ in range(14):
        c = ping(0.15, [RNG.uniform(1200, 3200), RNG.uniform(3300, 5500)], [0.03, 0.02], [0.5, 0.3]) + hp(noise(n_(0.15)), 2500) * dec(n_(0.15), 0.004)
        put(y, c, RNG.uniform(0.3, 1.5), RNG.uniform(0.2, 0.7))
    y += bp(noise(n), 700, 3500) * bell(n, 0.9, 0.5) * 0.2
    return y


def s_bombes_pleines():
    d = 0.8; y = np.zeros(n_(d))
    put(y, s_bombe_secoue()[:n_(0.4)], 0.0, 0.6)
    put(y, mallet(784, 0.5), 0.2, 0.5)
    put(y, mallet(1175, 0.45), 0.28, 0.45)
    return y


def s_vu():
    d = 0.8; n = n_(d); t = t_(d)
    y = (np.sin(TAU * 138 * t) + np.sin(TAU * 146 * t)) * bell(n, 0.35, 0.25) * 0.6
    put(y, hp(noise(n_(0.05)), 3500) * dec(n_(0.05), 0.01), 0.02, 0.4)
    return y


def s_chasse():
    d = 0.9; n = n_(d); t = t_(d)
    y = bp(noise(n), 300, 4000) * np.exp(-t / 0.25) * att(n, 0.01) * 0.6
    y += np.sin(TAU * 70 * t) * np.exp(-t / 0.08) * 1.0
    y += (np.sin(TAU * 220 * t) + np.sin(TAU * 233 * t)) * np.exp(-t / 0.3) * 0.35
    return y


def s_voix(f0, syl, voy):
    d = 0.1 + 0.11 * syl; n = n_(d); t = t_(d)
    f = f0 * (1 + 0.12 * np.sin(TAU * syl / (2 * d) * t + RNG.uniform(0, 3)))
    ph = TAU * np.cumsum(f) / SR
    src = sum(np.sin(h * ph) / h for h in range(1, 26))
    y = np.zeros(n)
    ds = d / syl
    for i in range(syl):
        F = voy[i % len(voy)]
        env = np.sin(np.pi * np.clip((t - i * ds) / ds, 0, 1)) ** 1.5
        y += formant(src * env, F)
    y += bp(noise(n), 2000, 7000) * 0.02 * np.abs(y).max()
    return y


VOYELLES = [[(700, 150, 1.0), (1200, 200, 0.7)], [(400, 120, 1.0), (2000, 250, 0.5)], [(500, 130, 1.0), (900, 150, 0.8)]]


# ---------------------------------------------------------------- véhicules
def s_scooter_loop():
    D = 1.0; n = n_(D); t = np.arange(n) / SR; y = np.zeros(n)
    f = 45
    for h in range(1, 41):
        y += np.sin(TAU * h * f * t + RNG.uniform(0, TAU)) / (h ** 0.7)
    y = formant(y, [(700, 500, 1.0), (1500, 800, 0.8), (3000, 1200, 0.3)])
    y *= (0.6 + 0.4 * np.abs(np.sin(np.pi * f * t))) * jitter(n, 8, 0.08)
    y += nz(bp(noise(n), 500, 3500)) * 0.15 * am(n, f, 0.8)
    return y


def s_voiture_loop():
    D = 1.0; n = n_(D); t = np.arange(n) / SR; y = np.zeros(n)
    f = 24
    for h in range(1, 31):
        y += np.sin(TAU * h * f * t + RNG.uniform(0, TAU)) / (h ** 1.2)
    y = lp(y, 900, 3)
    y *= am(n, f, 0.25) * jitter(n, 6, 0.05)
    y += nz(lp(noise(n), 400)) * 0.15 * am(n, f, 0.6)
    return y


def s_pneu_crisse_loop():
    D = 1.0; n = n_(D); t = np.arange(n) / SR
    y = np.sin(TAU * 1100 * t + 8 * np.sin(TAU * 3 * t)) + 0.4 * np.sin(TAU * 2200 * t + 16 * np.sin(TAU * 3 * t))
    y += nz(bp(noise(n), 800, 3500)) * 0.5
    return y * jitter(n, 20, 0.15)


def s_demarre(scooter):
    d = 1.0 if scooter else 1.2; n = n_(d); t = t_(d); y = np.zeros(n)
    tc = 0.55 if scooter else 0.7
    # démarreur / kick : à-coups qui s'accélèrent
    k = 0.0; gap = 0.14
    while k < tc:
        put(y, lp(noise(n_(0.06)), 700) * np.sin(np.pi * np.arange(n_(0.06)) / n_(0.06)), k, 0.8)
        k += gap; gap *= 0.82
    if not scooter:
        y += np.sin(TAU * np.cumsum(60 + 90 * np.clip(t / tc, 0, 1)) / SR) * (t < tc) * 0.25
    # le moteur prend
    f = (45 if scooter else 24) * (0.6 + 0.4 * np.clip((t - tc) / 0.3, 0, 1)) * 1.0
    ph = TAU * np.cumsum(f) / SR
    eng = sum(np.sin(h * ph) / (h ** (0.7 if scooter else 1.2)) for h in range(1, 31))
    eng = formant(eng, [(700, 500, 1.0), (1500, 800, 0.8)]) if scooter else lp(eng, 900, 3)
    y += eng * (t >= tc) * att(n, 0.001) * np.minimum(1, (t - tc + 1e-9) / 0.05) * 0.6
    return y


def s_moteur_coupe(scooter):
    d = 0.6; n = n_(d); t = t_(d)
    f = (45 if scooter else 24) * np.exp(-t / 0.25)
    ph = TAU * np.cumsum(f) / SR
    y = sum(np.sin(h * ph) / (h ** (0.7 if scooter else 1.2)) for h in range(1, 31)) * np.exp(-t / 0.25)
    return formant(y, [(700, 500, 1.0), (1500, 800, 0.8)]) if scooter else lp(y, 900, 3)


def s_portiere():
    d = 0.4; n = n_(d); t = t_(d)
    y = ping(d, [90, 180, 330], [0.08, 0.06, 0.04], [1, 0.6, 0.4]) + bp(noise(n), 500, 2500) * np.exp(-t / 0.025) * 0.6
    put(y, ping(0.1, [1200, 2400], [0.02, 0.012]), 0.07, 0.4)
    return y


def s_bequille():
    d = 0.22; n = n_(d); t = t_(d)
    return ping(d, [900, 1800, 3100], [0.05, 0.03, 0.02], [1, 0.6, 0.3]) + bp(noise(n), 1000, 5000) * np.exp(-t / 0.03) * 0.5


def s_choc_vehicule():
    d = 0.8; n = n_(d); t = t_(d)
    y = np.sin(TAU * 55 * t) * np.exp(-t / 0.1) * 1.2 + bp(noise(n), 300, 4000) * np.exp(-t / 0.15) * 0.7
    y += ping(d, [600, 1500, 2700], [0.15, 0.1, 0.06], [0.6, 0.4, 0.3])
    return y


# ---------------------------------------------------------------- ambiance
def s_amb_jour_loop():
    D = 12.0; n = n_(D)
    sw = 1 + 0.4 * np.sin(TAU * 1 * np.arange(n) / n) + 0.25 * np.sin(TAU * 3 * np.arange(n) / n + 1.1) + 0.15 * np.sin(TAU * 7 * np.arange(n) / n + 2.0)
    y = nz(lp(noise(n), 320)) * sw
    y += nz(bp(noise(n), 200, 900)) * 0.35 * (1 + 0.5 * np.sin(TAU * 2 * np.arange(n) / n + 0.4))
    y += nz(bp(noise(n), 2000, 5000)) * 0.03
    return y


def crickets(n, f, trains, pulses=3, rate=60.0):
    y = np.zeros(n)
    p = np.sin(TAU * f * t_(0.012)) * np.hanning(n_(0.012))
    D = n / SR
    for k in range(trains):
        t0 = k * D / trains + RNG.uniform(0, 0.03)
        for q in range(pulses):
            put_wrap(y, p, t0 + q / rate, 1.0)
    return y


def s_amb_nuit_loop():
    D = 12.0; n = n_(D)
    sw = 1 + 0.3 * np.sin(TAU * 1 * np.arange(n) / n + 0.7) + 0.2 * np.sin(TAU * 4 * np.arange(n) / n + 0.3)
    y = nz(lp(noise(n), 280)) * sw * 0.55
    y += nz(bp(noise(n), 200, 800)) * 0.12
    y += (crickets(n, 4300, 33) + 0.8 * crickets(n, 4800, 37, 4, 55) + 0.6 * crickets(n, 5300, 41, 2, 70)) * 0.12
    return y


def s_oiseau():
    d = 0.9; y = np.zeros(n_(d)); t = 0.0
    f0 = RNG.uniform(2400, 3600)
    for _ in range(int(RNG.integers(3, 7))):
        a, b = f0 * RNG.uniform(0.8, 1.3), f0 * RNG.uniform(0.8, 1.5)
        dur = RNG.uniform(0.05, 0.12)
        put(y, chirp(a, b, dur) * RNG.uniform(0.5, 1.0), t)
        t += dur + RNG.uniform(0.03, 0.09)
    return y


def s_mouette():
    d = 1.2; n = n_(d); t = t_(d)
    f = 800 + 700 * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) - 250 * np.clip((t - 0.55) / 0.5, 0, 1)
    f *= 1 + 0.03 * np.sin(TAU * 38 * t)
    ph = TAU * np.cumsum(f) / SR
    y = sum(np.sin(h * ph) / h for h in range(1, 8))
    e = np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 0.7 * (t < 0.5) + 0.8 * np.sin(np.pi * np.clip((t - 0.5) / 0.7, 0, 1)) * (t >= 0.5)
    y = bp(y, 500, 5000) * e
    return y + bp(noise(n), 1500, 6000) * e * 0.08


def s_voiture_loin():
    d = 4.5; n = n_(d); t = t_(d)
    b = bell(n, 2.2, 1.0)
    y = bp(noise(n), 300, 2500) * b * 0.8
    y += lp(noise(n), 250) * b * 0.8
    f = 70 * (1 + 0.15 * np.tanh(-(t - 2.2) / 0.5))
    y += np.sin(TAU * np.cumsum(f) / SR) * b * 0.4
    return lp(y, 2200)


def s_moto_loin():
    d = 3.5; n = n_(d); t = t_(d)
    b = bell(n, 1.7, 0.7)
    f = 95 * (1 + 0.18 * np.tanh(-(t - 1.7) / 0.35))
    ph = TAU * np.cumsum(f) / SR
    y = formant(sum(np.sin(h * ph) / (h ** 0.7) for h in range(1, 30)), [(800, 500, 1.0), (1800, 700, 0.7)]) * b
    return lp(y, 3500)


def s_sirene_loin():
    d = 5.0; n = n_(d); t = t_(d)
    f = np.where(np.floor(t / 0.65) % 2 == 0, 700.0, 930.0)
    f = np.convolve(f, np.ones(2000) / 2000, mode="same")
    y = (np.sin(TAU * np.cumsum(f) / SR) + 0.3 * np.sin(TAU * 2 * np.cumsum(f) / SR)) * bell(n, 2.5, 1.4)
    return bp(y, 500, 2500)


def s_demolition():
    d = 8.0; n = n_(d); t = t_(d)
    y = np.sin(TAU * np.cumsum(70 * np.exp(-t / 1.3) + 22) / SR) * np.exp(-t / 1.4) * 1.3
    y += lp(noise(n), 300) * np.exp(-t / 2.0) * 1.0 * att(n, 0.05)
    y += hp(noise(n), 1500) * np.exp(-t / 0.05) * 0.8
    for _ in range(90):
        tt = RNG.exponential(1.6) + 0.3
        if tt > 7.0:
            continue
        w = RNG.uniform(0.05, 0.3)
        put(y, bp(noise(n_(w)), RNG.uniform(150, 400), RNG.uniform(1200, 3500)) * dec(n_(w), w * 0.3), tt, RNG.uniform(0.1, 0.5) * np.exp(-tt / 3))
    return y


# ---------------------------------------------------------------- interface, temps
def s_ui_bascule():
    d = 0.22; n = n_(d); t = t_(d)
    y = bp(noise(n), 1500, 6000) * bell(n, 0.06, 0.04) * 0.4
    put(y, mallet(880, 0.2), 0.0, 0.35)
    return y


def s_temps_saut():
    d = 1.4; n = n_(d); y = np.zeros(n)
    tt = 0.0; gap = 0.2
    while tt < 1.0:
        put(y, ping(0.05, [2200], [0.008]) + hp(noise(n_(0.05)), 3000) * dec(n_(0.05), 0.004) * 0.5, tt, 0.6)
        tt += gap; gap = max(0.04, gap * 0.8)
    y += bp(noise(n), 400, 3500) * bell(n, 0.8, 0.35) * 0.3
    return y


def s_respawn():
    d = 0.6; n = n_(d); t = t_(d)
    y = bp(noise(n), 300, 3000) * bell(n, 0.3, 0.15) * 0.6
    y += np.sin(TAU * np.cumsum(200 + 400 * t / d) / SR) * bell(n, 0.4, 0.15) * 0.25
    return y


# ---------------------------------------------------------------- registre

def s_racle_loop():
    # bavette / flanc du scooter sur le bitume : grattement granuleux, crépitements métalliques
    D = 1.0; n = n_(D); y = nz(bp(noise(n), 1200, 7000)) * 0.6
    y *= 0.55 + 0.45 * jitter(n, 30, 0.9)
    crep = np.zeros(n)
    for _ in range(90):
        put_wrap(crep, ping(0.03, [RNG.uniform(2500, 6500)], [0.006]), RNG.uniform(0, D), RNG.uniform(0.3, 1.0))
    y += crep * 0.8
    y += nz(lp(noise(n), 300)) * 0.25 * am(n, 13, 0.6)
    return y


def s_vent_loop():
    # souffle du vent à pleine vitesse, avec des rafales
    D = 2.0; n = n_(D)
    y = nz(bp(noise(n), 150, 1800, 1)) * (0.6 + 0.4 * am(n, 1, 0.7)) * jitter(n, 3, 0.25)
    y += nz(bp(noise(n), 1500, 4000)) * 0.15 * am(n, 2, 0.8, 1.0)
    return y

BANQUE = [
    # (nom, fonction, variantes, crête, boucle)
    ("pas_dur", s_pas_dur, 4, 0.85, False),
    ("pas_herbe", s_pas_herbe, 3, 0.7, False),
    ("pas_gravier", s_pas_gravier, 4, 0.8, False),
    ("atterri_pied", s_atterri_pied, 2, 0.9, False),
    ("saut_pied", s_saut_pied, 2, 0.7, False),
    ("roule_loop", s_roule_loop, 1, 0.7, True),
    ("roule_gravier_loop", s_roule_gravier_loop, 1, 0.7, True),
    ("roule_herbe_loop", s_roule_herbe_loop, 1, 0.7, True),
    ("frein_loop", s_frein_loop, 1, 0.7, True),
    ("pousse", s_pousse, 3, 0.85, False),
    ("ollie_pop", s_ollie_pop, 3, 0.9, False),
    ("atterri_leger", lambda: s_atterri(False), 3, 0.85, False),
    ("atterri_dur", lambda: s_atterri(True), 3, 0.95, False),
    ("kickflip", s_kickflip, 2, 0.9, False),
    ("shoveit", s_shoveit, 2, 0.9, False),
    ("grind_debut", s_grind_debut, 2, 0.9, False),
    ("grind_loop", s_grind_loop, 1, 0.7, True),
    ("grind_beton_loop", s_grind_beton_loop, 1, 0.7, True),
    ("grind_fin", s_grind_fin, 2, 0.8, False),
    ("planche_pose", s_planche_pose, 2, 0.85, False),
    ("planche_pied", s_planche_pied, 2, 0.8, False),
    ("planche_ramasse", s_planche_ramasse, 2, 0.8, False),
    ("planche_range", s_planche_range, 1, 0.8, False),
    ("chute", s_chute, 3, 0.95, False),
    ("planche_chute", s_planche_chute, 2, 0.9, False),
    ("choc_planche", s_choc_planche, 3, 0.85, False),
    ("main_mur", s_main_mur, 3, 0.8, False),
    ("hisse", s_hisse, 2, 0.8, False),
    ("lache", s_lache, 2, 0.7, False),
    ("decale", s_decale, 3, 0.7, False),
    ("goutiere_agrippe", s_goutiere_agrippe, 1, 0.85, False),
    ("goutiere_grimpe", s_goutiere_grimpe, 3, 0.8, False),
    ("course_murale", s_course_murale, 2, 0.8, False),
    ("bombe_secoue", s_bombe_secoue, 2, 0.8, False),
    ("spray_loop", s_spray_loop, 1, 0.65, True),
    ("spray_debut", s_spray_debut, 1, 0.7, False),
    ("spray_fin", s_spray_fin, 1, 0.7, False),
    ("spray_tap", s_spray_tap, 3, 0.7, False),
    ("bombe_vide", s_bombe_vide, 1, 0.7, False),
    ("bombe_change", s_bombe_change, 1, 0.75, False),
    ("perche_deplie", s_perche_deplie, 1, 0.8, False),
    ("rouleau_trempe", s_rouleau_trempe, 1, 0.8, False),
    ("rouleau_loop", s_rouleau_loop, 1, 0.65, True),
    ("goutte", s_goutte, 3, 0.6, False),
    ("etape_ok", s_etape_ok, 1, 0.6, False),
    ("graff_pose", s_graff_pose, 1, 0.65, False),
    ("graff_rate", s_graff_rate, 1, 0.65, False),
    ("fouille", s_fouille, 1, 0.85, False),
    ("bombes_pleines", s_bombes_pleines, 1, 0.8, False),
    ("vu", s_vu, 1, 0.6, False),
    ("chasse", s_chasse, 1, 0.85, False),
    ("voix_gardien", lambda: s_voix(92, 3, VOYELLES), 3, 0.6, False),
    ("voix_passant", lambda: s_voix(125, 2, VOYELLES), 3, 0.6, False),
    ("voix_voisine", lambda: s_voix(215, 3, VOYELLES), 3, 0.6, False),
    ("voix_jeune", lambda: s_voix(165, 2, VOYELLES), 3, 0.6, False),
    ("scooter_loop", s_scooter_loop, 1, 0.7, True),
    ("voiture_loop", s_voiture_loop, 1, 0.7, True),
    ("pneu_crisse_loop", s_pneu_crisse_loop, 1, 0.55, True),
    ("demarre_scooter", lambda: s_demarre(True), 1, 0.8, False),
    ("demarre_voiture", lambda: s_demarre(False), 1, 0.8, False),
    ("coupe_scooter", lambda: s_moteur_coupe(True), 1, 0.7, False),
    ("coupe_voiture", lambda: s_moteur_coupe(False), 1, 0.7, False),
    ("portiere", s_portiere, 1, 0.9, False),
    ("bequille", s_bequille, 1, 0.8, False),
    ("choc_vehicule", s_choc_vehicule, 2, 0.95, False),
    ("amb_jour_loop", s_amb_jour_loop, 1, 0.5, True),
    ("amb_nuit_loop", s_amb_nuit_loop, 1, 0.5, True),
    ("oiseau", s_oiseau, 4, 0.5, False),
    ("mouette", s_mouette, 2, 0.5, False),
    ("voiture_loin", s_voiture_loin, 2, 0.5, False),
    ("moto_loin", s_moto_loin, 1, 0.5, False),
    ("sirene_loin", s_sirene_loin, 1, 0.4, False),
    ("demolition", s_demolition, 1, 0.95, False),
    ("ui_bascule", s_ui_bascule, 1, 0.5, False),
    ("temps_saut", s_temps_saut, 1, 0.6, False),
    ("respawn", s_respawn, 1, 0.6, False),
    ("racle_loop", s_racle_loop, 1, 0.55, True),
    ("vent_loop", s_vent_loop, 1, 0.5, True),
]


def fin(x, peak, loop):
    x = np.asarray(x, dtype=np.float64)
    x = x - x.mean()
    x = x / (np.max(np.abs(x)) + 1e-12) * peak
    if not loop:
        a = min(len(x) // 2, n_(0.002)); b = min(len(x) // 2, n_(0.012))
        x[:a] *= np.linspace(0, 1, a)
        x[len(x) - b:] *= np.linspace(1, 0, b)
    return x


def ecrire(chemin, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(chemin, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    sortie = sys.argv[1] if len(sys.argv) > 1 else "assets/sons"
    os.makedirs(sortie, exist_ok=True)
    total = 0; nb = 0
    for nom, fn, k, crete, boucle in BANQUE:
        for i in range(1, k + 1):
            x = fin(fn(), crete, boucle)
            fichier = f"{nom}_{i}.wav" if k > 1 else f"{nom}.wav"
            ecrire(os.path.join(sortie, fichier), x)
            total += len(x) * 2; nb += 1
            print(f"{fichier:28s} {len(x) / SR:5.2f} s  crête {np.max(np.abs(x)):.2f}  eff. {np.sqrt(np.mean(x ** 2)):.3f}")
    print(f"\n{nb} fichiers, {total / 1e6:.1f} Mo")


if __name__ == "__main__":
    main()
