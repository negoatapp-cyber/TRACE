shader_type spatial;
// Façade procédurale : fenêtres ou loggias dessinées par le calcul, sans
// image. Sert à donner l'échelle et la vie des immeubles pendant le
// blockout ; remplacée plus tard par de vrais modèles.

uniform vec3 mur : source_color = vec3(0.86, 0.84, 0.79);
uniform vec3 garde_corps : source_color = vec3(0.78, 0.76, 0.72);
uniform vec3 vitre : source_color = vec3(0.13, 0.17, 0.22);
uniform vec3 toit : source_color = vec3(0.45, 0.44, 0.42);
uniform float hauteur = 30.0;   // hauteur totale du bloc (m)
uniform float etage = 2.8;      // hauteur d'un étage
uniform float travee = 3.4;     // largeur d'une travée
uniform float rdc = 3.2;        // socle sans fenêtres
uniform float loggias = 0.0;    // 1 = grille de balcons, 0 = fenêtres simples
uniform float vie = 0.35;       // part de balcons avec linge / store

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = mur;
	float rough = 0.92;
	if (abs(ln.y) > 0.5) {
		col = toit;
	} else {
		float u = abs(ln.x) > 0.5 ? lp.z : lp.x;
		float v = lp.y + hauteur * 0.5;
		float face = floor(ln.x * 3.0 + ln.z * 7.0 + 0.5);
		if (v < rdc) {
			col = mur * 0.82;
		} else if (v < hauteur - 0.5) {
			vec2 g = vec2(u / travee, (v - rdc) / etage);
			vec2 cell = floor(g);
			vec2 f = fract(g);
			float r = h21(cell + face);
			float r2 = h21(cell * 1.7 + face + 4.0);
			if (loggias > 0.5) {
				// dalle, refend, garde-corps, creux sombre
				if (f.x < 0.05 || f.x > 0.95 || f.y > 0.93) {
					col = mur;
				} else if (f.y < 0.38) {
					col = garde_corps;
					if (r < vie && f.x > 0.15 && f.x < 0.15 + 0.5 * r2 + 0.2 && f.y > 0.12) {
						// linge qui pend
						col = mix(vec3(0.85, 0.3, 0.25), vec3(0.25, 0.45, 0.8), r2);
						if (r2 > 0.6) col = vec3(0.92, 0.9, 0.86);
					}
				} else {
					col = mur * 0.42;
					if (f.x > 0.25 && f.x < 0.75) col = vitre;
					if (r > 0.82 && f.y > 0.7) col = mix(vec3(0.8, 0.5, 0.2), vec3(0.3, 0.55, 0.4), r2);
				}
			} else {
				if (f.x > 0.22 && f.x < 0.78 && f.y > 0.3 && f.y < 0.8) {
					col = vitre;
					rough = 0.25;
					if (r < vie && f.y > 0.3 + 0.5 * r2) col = mix(vec3(0.75, 0.72, 0.65), vec3(0.5, 0.3, 0.25), r2);
					if (abs(f.x - 0.5) < 0.012) col = mur * 0.9;
				}
			}
		} else {
			col = mur * 0.9;
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
