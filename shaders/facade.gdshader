shader_type spatial;
render_mode cull_disabled;
// Façade procédurale : fenêtres ou loggias dessinées par le calcul, sans image.
// Les murs portent UV.x = distance le long du contour (m), UV.y = hauteur (m).
// Sert à donner l'échelle et la vie des immeubles ; remplacée plus tard par de vrais modèles.
// Rendu BD : lumière en trois tons (bd_lumiere) et cadres de fenêtres encrés.

#include "res://shaders/bd_lumiere.gdshaderinc"

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
// Bandes de couleur (Cyprès) : angles peints sur `bande_largeur` m, murs courts (< `pignon_max` m) entièrement peints.
uniform vec3 bande : source_color = vec3(0.84, 0.46, 0.28);
uniform float bande_largeur = 0.0;
uniform float pignon_max = 0.0;
uniform vec3 encre : source_color = vec3(0.12, 0.09, 0.16);

varying vec3 ln;
// Au-delà de cette distance (m), les cadres encrés s'effacent pour éviter le fourmillement.
uniform float encre_portee = 90.0;

void vertex() {
	ln = NORMAL;
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 mc = mur;
	vec3 col = mc;
	bool encrer = bd_actif > 0.5 && length(VERTEX) < encre_portee;
	float rough = 0.92;
	if (abs(ln.y) > 0.5) {
		col = toit;
	} else {
		float u = UV.x;
		float v = UV.y;
		bool plein = false;  // bande pleine, sans fenêtres (angles et pignons des Cyprès)
		if (UV2.y > 0.0) {
			plein = min(UV2.x, UV2.y - UV2.x) < bande_largeur || UV2.y < pignon_max;
		}
		if (plein) {
			col = v < rdc ? bande * 0.85 : bande;
		} else if (v < rdc) {
			col = mc * 0.82;
		} else if (v < hauteur - 0.5) {
			vec2 g = vec2(u / travee, (v - rdc) / etage);
			vec2 cell = floor(g);
			vec2 f = fract(g);
			float r = h21(cell);
			float r2 = h21(cell * 1.7 + 4.0);
			if (loggias > 0.5) {
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
					if (f.x > 0.25 && f.x < 0.75) col = vitre;
					if (r > 0.82 && f.y > 0.7) col = mix(vec3(0.8, 0.5, 0.2), vec3(0.3, 0.55, 0.4), r2);
				}
			} else {
				bool cadre = f.x > 0.20 && f.x < 0.80 && f.y > 0.28 && f.y < 0.82;
				if (encrer && cadre && !(f.x > 0.22 && f.x < 0.78 && f.y > 0.3 && f.y < 0.8)) {
					col = encre;
				} else if (f.x > 0.22 && f.x < 0.78 && f.y > 0.3 && f.y < 0.8) {
					col = vitre;
					rough = 0.25;
					if (r < vie && f.y > 0.3 + 0.5 * r2) col = mix(vec3(0.75, 0.72, 0.65), vec3(0.5, 0.3, 0.25), r2);
					if (abs(f.x - 0.5) < 0.012) col = mc * 0.9;
				}
			}
		} else {
			col = mc * 0.9;
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	if (bd_actif > 0.5) {
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
}
