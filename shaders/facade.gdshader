shader_type spatial;
render_mode cull_disabled;
// Façade procédurale : fenêtres ou loggias dessinées par le calcul, sans image.
// Les murs portent UV.x = distance le long du contour (m), UV.y = hauteur (m).
// Sert à donner l'échelle et la vie des immeubles ; remplacée plus tard par de vrais modèles.
// Rendu BD : lumière en trois tons (bd_lumiere) et cadres de fenêtres encrés.

#include "res://shaders/bd_lumiere.gdshaderinc"
#include "res://shaders/bd_grain.gdshaderinc"
// La nuit (temps.gd, n°1) : une partie des fenêtres s'allume — lampes chaudes, néons de cuisine,
// lueur bleue d'une télé — et les cages d'escalier restent éclairées.
global uniform float nuit;

uniform vec3 mur : source_color = vec3(0.86, 0.84, 0.79);
uniform vec3 garde_corps : source_color = vec3(0.78, 0.76, 0.72);
uniform vec3 vitre : source_color = vec3(0.13, 0.17, 0.22);
uniform vec3 toit : source_color = vec3(0.45, 0.44, 0.42);
uniform float hauteur = 30.0;
uniform float etage = 2.8;
uniform float travee = 3.4;
uniform float rdc = 3.2;
uniform float loggias = 0.0;
uniform float vie = 0.35;
uniform vec3 persienne : source_color = vec3(0.62, 0.55, 0.46);
// Bandes de couleur (Cyprès) : angles peints sur `bande_largeur` m, murs courts (< `pignon_max` m) entièrement peints.
uniform vec3 bande : source_color = vec3(0.84, 0.46, 0.28);
uniform float bande_largeur = 0.0;
uniform float pignon_max = 0.0;
// Tour Cyprès B (photos 2013-2014) : l'orange n'est pas aux angles mais dans une bande verticale en creux,
// au milieu des faces dont la normale suit `bande_axe`, sur `bande_centre` m de large.
uniform float bande_centre = 0.0;
uniform vec2 bande_axe = vec2(0.0, 1.0);
// Petites barres de la rue de Marathon (Street View 2013-2014) : rez-de-chaussée peint en rouge brique
// et colonnes de panneaux rouges entre les fenêtres, sur enduit beige.
uniform vec3 soubassement : source_color = vec3(0.70, 0.30, 0.26);
uniform float soubassement_on = 0.0;
uniform vec3 panneaux : source_color = vec3(0.68, 0.30, 0.28);
uniform float panneaux_part = 0.0;
// Grande barre des Lauriers en 2013-2014 (Street View juin 2014) : façade plate, crème ; une colonne de loggias
// en creux (sombres, linge, paraboles) toutes les `rythme` travées, les autres avec deux petites fenêtres.
uniform float rythme = 0.0;
// Usure des cités en 2013 (Street View, image cible de Louma) : enduit taché par plaques, coulures sous
// les fenêtres, plâtre écaillé plus clair à bords francs, pied de mur noirci. 0 = façade propre.
uniform float usure = 0.0;
uniform vec3 encre : source_color = vec3(0.12, 0.09, 0.16);

varying vec3 ln;
varying vec3 monde;
// Au-delà de cette distance (m), les cadres encrés s'effacent pour éviter le fourmillement.
uniform float encre_portee = 90.0;

void vertex() {
	ln = NORMAL;
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bruit2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 user(vec3 c, float u, float v) {
	float plaques = bruit2(vec2(u / 7.0, v / 5.0)) * 0.65 + bruit2(vec2(u / 2.1, v / 1.7)) * 0.35;
	c *= 1.0 - usure * 0.17 * smoothstep(0.50, 0.72, plaques);                       // salissures
	float coulure = bruit2(vec2(u * 1.7, v * 0.06)) * smoothstep(0.0, 1.0, bruit2(vec2(u * 0.3, v * 0.2)));
	c *= 1.0 - usure * 0.12 * smoothstep(0.55, 0.85, coulure);                       // coulures verticales
	float ecaille = bruit2(vec2(u / 1.6, v / 1.2) + 31.0) * 0.7 + bruit2(vec2(u * 1.3, v * 1.1)) * 0.3;
	float e = smoothstep(0.70, 0.72, ecaille) * usure;
	c = mix(c, c * 0.80 + vec3(0.10, 0.10, 0.10), e * 0.85);                        // plâtre tombé, gris
	c *= 1.0 - (smoothstep(0.69, 0.70, ecaille) - smoothstep(0.70, 0.71, ecaille)) * usure * 0.35;   // bord de l'écaille
	c *= 1.0 - usure * 0.18 * (1.0 - smoothstep(0.0, 1.6, v));                       // pied de mur noirci
	return c;
}

vec3 fenetre_allumee(vec2 cell) {
	float a = h21(cell * 3.1 + vec2(7.0, 2.0));
	if (a > 0.42) return vec3(0.0);
	float t = h21(cell * 5.3 + vec2(1.0, 9.0));
	if (t < 0.12) return vec3(0.35, 0.50, 1.0) * 0.8;       // télé
	if (t < 0.30) return vec3(0.85, 0.95, 0.88);             // néon
	return vec3(1.0, 0.72, 0.38);                            // lampe
}

void fragment() {
	vec3 em = vec3(0.0);
	vec3 mc = mur;
	vec3 col = mc;
	bool encrer = bd_actif > 0.5 && length(VERTEX) < encre_portee;
	float rough = 0.92;
	if (abs(ln.y) > 0.5) {
		col = toit;
	} else {
		float u = UV.x;
		float v = UV.y;
		if (usure > 0.0) {
			mc = user(mc, u, v);
			col = mc;
		}
		bool plein = false;  // bande pleine, sans fenêtres (angles et pignons des Cyprès)
		if (UV2.y > 0.0) {
			plein = min(UV2.x, UV2.y - UV2.x) < bande_largeur || UV2.y < pignon_max;
		}
		float creux = 0.0;   // ombre portée sur le bord de la bande en creux
		if (bande_centre > 0.0 && UV2.y > 0.0 && length(ln.xz) > 0.1 && abs(dot(normalize(ln.xz), bande_axe)) > 0.7) {
			float dx = UV2.x - UV2.y * 0.5;
			if (abs(dx) < bande_centre * 0.5) {
				plein = true;
				if (dx < -bande_centre * 0.5 + 0.45) creux = 1.0;
			}
		}
		if (plein) {
			col = v < rdc ? bande * 0.85 : bande;
			if (creux > 0.5) col *= 0.72;
			if (encrer && abs(abs(UV2.x - UV2.y * 0.5) - bande_centre * 0.5) < 0.05 && bande_centre > 0.0) col = encre;
			// petits jours de ventilation dans la bande, un par étage
			if (bande_centre > 0.0 && v > rdc && v < hauteur - 0.5) {
				vec2 fb = fract(vec2((UV2.x - UV2.y * 0.5) / 1.2 + 0.5, (v - rdc) / etage));
				if (abs(UV2.x - UV2.y * 0.5) < 0.6 && fb.y > 0.45 && fb.y < 0.62) col = vitre * 1.4;
			}
		} else if (v < rdc) {
			col = soubassement_on > 0.5 ? soubassement : mc * 0.82;
			// grilles devant les fenêtres du rez-de-chaussée
			if (soubassement_on > 0.5) {
				float fx = fract(u / travee);
				if (fx > 0.25 && fx < 0.75 && v > 0.9 && v < rdc - 0.6) col = fract(u * 6.0) < 0.25 ? vec3(0.18) : vitre;
			}
		} else if (v < hauteur - 0.5) {
			vec2 g = vec2(u / travee, (v - rdc) / etage);
			vec2 cell = floor(g);
			vec2 f = fract(g);
			float r = h21(cell);
			float r2 = h21(cell * 1.7 + 4.0);
			bool en_loggia = loggias > 0.5;
			if (rythme > 0.5) en_loggia = mod(cell.x, rythme) < 0.5;
			if (en_loggia) {
				bool trait = encrer && ((f.x > 0.04 && f.x < 0.065) || (f.x > 0.935 && f.x < 0.96) || (f.y > 0.915 && f.y < 0.935) || (f.y > 0.37 && f.y < 0.39 && f.x > 0.05 && f.x < 0.95));
				if (trait) {
					col = encre;
				} else if (f.x < 0.05 || f.x > 0.95 || f.y > 0.93) {
					col = mc;
				} else if (f.y < 0.38) {
					col = garde_corps;
					if (r < vie && f.x > 0.15 && f.x < 0.15 + 0.5 * r2 + 0.2 && f.y > 0.12) {
						col = mix(vec3(0.85, 0.3, 0.25), vec3(0.25, 0.45, 0.8), r2);
						if (r2 > 0.6) col = vec3(0.92, 0.9, 0.86);
					}
				} else {
					col = mc * 0.42;
					if (f.x > 0.25 && f.x < 0.75) { col = vitre; em = fenetre_allumee(cell); }
					if (f.x > 0.25 && f.x < 0.75 && h21(cell * 2.3 + 1.0) > 0.8) { col = persienne * (0.9 + 0.1 * step(0.5, fract(f.y * 18.0))); em *= 0.15 * step(0.5, fract(f.y * 18.0)); }
					if (r > 0.82 && f.y > 0.7) col = mix(vec3(0.8, 0.5, 0.2), vec3(0.3, 0.55, 0.4), r2);
				}
			} else {
				if (rythme > 0.5) {
					// deux petites fenêtres côte à côte, volets roulants plus ou moins baissés
					bool w1 = f.x > 0.12 && f.x < 0.42 && f.y > 0.32 && f.y < 0.78;
					bool w2 = f.x > 0.58 && f.x < 0.88 && f.y > 0.32 && f.y < 0.78;
					if (w1 || w2) {
						col = vitre;
						float store = 0.32 + 0.46 * h21(cell * 3.1 + (w1 ? 0.0 : 5.0));
						if (f.y > 0.78 - (store - 0.32)) col = mc * 0.86;
						if (encrer && (abs(f.y - 0.32) < 0.012 || abs(f.y - 0.78) < 0.012)) col = encre;
					}
					if (f.y < 0.03) col = mc * 0.93;   // trait de dalle
				} else {
				bool cadre = f.x > 0.20 && f.x < 0.80 && f.y > 0.28 && f.y < 0.82;
				// colonnes de panneaux rouges (par travée) et fins bandeaux entre les étages
				if (panneaux_part > 0.0) {
					if (h21(vec2(cell.x, 9.0)) < panneaux_part && h21(vec2(cell.x, floor(cell.y / 2.0) + 3.0)) > 0.25) col = panneaux;
					if (f.y < 0.05) col = panneaux * 0.95;
				}
				if (encrer && cadre && !(f.x > 0.22 && f.x < 0.78 && f.y > 0.3 && f.y < 0.8)) {
					col = encre;
				} else if (f.x > 0.22 && f.x < 0.78 && f.y > 0.3 && f.y < 0.8) {
					col = vitre;
					em = fenetre_allumee(cell);
					rough = 0.25;
					if (r < vie && f.y > 0.3 + 0.5 * r2) col = mix(vec3(0.75, 0.72, 0.65), vec3(0.5, 0.3, 0.25), r2);
					if (abs(f.x - 0.5) < 0.012) col = mc * 0.9;
					// Persiennes fermées, au hasard d'un logement à l'autre (lames horizontales).
					if (h21(cell * 2.3 + 1.0) > 0.78) { col = persienne * (0.9 + 0.1 * step(0.5, fract(f.y * 18.0))); em *= 0.15 * step(0.5, fract(f.y * 18.0)); }
				}
			}
				}
		} else {
			col = mc * 0.9;
		}
	}
	if (bd_actif > 0.5 && abs(ln.y) < 0.5) {
		// Coulures : sous certaines fenêtres, une traînée plus sombre descend sur l'enduit.
		vec2 g2 = vec2(UV.x / travee, (UV.y - rdc) / etage);
		float r3 = h21(floor(g2) + vec2(7.0, 3.0));
		float fx = fract(g2.x);
		if (r3 > 0.55 && fx > 0.42 && fx < 0.46 + 0.1 * r3 && fract(g2.y) < 0.3 && col == mc) {
			col *= 0.86;
		}
		// Pied de façade sali par la pluie et les passages.
		if (UV.y < 1.2) col *= 0.88;
		col *= bd_texture(monde);
	}
	ALBEDO = col;
	EMISSION = em * nuit * 1.6;
	ROUGHNESS = rough;
	if (bd_actif > 0.5) {
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
}
