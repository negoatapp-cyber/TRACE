shader_type sky;
// TRACE — le ciel peint (conversation n°2, lumière et ciel).
// Un ciel « à la Miyazaki » au-dessus de Marseille : dégradé doux, grands cumulus aux bords francs,
// éclairés côté soleil (crème, pêche, rose selon l'heure) et ombrés de lavande. Les couleurs sont
// poussées heure par heure par scripts/ciel.gd ; ici on ne fait que peindre.

uniform vec3 haut : source_color = vec3(0.22, 0.46, 0.86);
uniform vec3 milieu : source_color = vec3(0.50, 0.70, 0.95);
uniform vec3 horizon : source_color = vec3(0.95, 0.90, 0.84);
uniform vec3 sol : source_color = vec3(0.80, 0.76, 0.72);
uniform vec3 nuage_clair : source_color = vec3(1.0, 0.98, 0.94);
uniform vec3 nuage_corps : source_color = vec3(0.90, 0.88, 0.92);
uniform vec3 nuage_ombre : source_color = vec3(0.66, 0.66, 0.84);
uniform vec3 halo : source_color = vec3(1.0, 0.86, 0.62);
uniform float couverture : hint_range(0.0, 1.0) = 0.62;
uniform float derive = 0.0;          // avance des nuages (m), poussée par ciel.gd
uniform float etoiles : hint_range(0.0, 1.0) = 0.0;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * bruit(p);
		p = r * p * 2.03 + 11.7;
		a *= 0.48;
	}
	return v;
}

// densité d'un champ de cumulus : de grosses masses (forme), des bourrelets ronds (détail)
float cumulus(vec2 p) {
	vec2 q = vec2(fbm(p * 0.35 + 3.1), fbm(p * 0.35 + 8.4));
	float forme = fbm(p * 0.22 + q * 1.4);
	float detail = fbm(p * 0.9 + q * 2.0);
	return forme * 0.85 + detail * 0.35 - (1.0 - couverture) * 0.30;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 sd = LIGHT0_DIRECTION;
	float soleil = max(dot(d, sd), 0.0);
	// fond : dégradé en trois couleurs, l'horizon s'échauffe du côté du soleil
	vec3 col = mix(horizon, milieu, smoothstep(0.0, 0.22, y));
	col = mix(col, haut, smoothstep(0.18, 0.85, y));
	col = mix(col, halo, pow(soleil, 6.0) * 0.55 * (1.0 - smoothstep(0.0, 0.5, y)) + pow(soleil, 40.0) * 0.5);
	if (y < 0.0) {
		col = mix(horizon, sol, smoothstep(0.0, 0.12, -y));
	}
	// soleil : un disque doux, sans éblouir
	col = mix(col, vec3(1.0, 0.97, 0.88), smoothstep(0.9993, 0.9997, soleil) * LIGHT0_ENERGY * 0.4);
	if (AT_CUBEMAP_PASS) {
		COLOR = col;
	} else {
		// étoiles, la nuit
		if (etoiles > 0.0 && y > 0.05) {
			vec2 e = d.xz / (y + 0.35) * 220.0;
			float s = h21(floor(e));
			float pt = smoothstep(0.35, 0.0, length(fract(e) - 0.5));
			col += vec3(0.9, 0.92, 1.0) * step(0.985, s) * pt * etoiles * smoothstep(0.05, 0.3, y);
		}
		// nuages : projetés sur un plafond, plus petits et plus serrés vers l'horizon
		if (y > 0.015) {
			vec2 p = d.xz / (y + 0.25) * 3.4 + vec2(-23.0 + derive * 0.02, 31.0 + derive * 0.006);
			float dn = cumulus(p);
			// lumière : on compare la densité un peu plus loin vers le soleil
			vec2 vers = normalize(sd.xz + vec2(0.0001));
			float dl = cumulus(p + vers * 0.35);
			float eclaire = clamp((dn - dl) * 6.0 + 0.5, 0.0, 1.0);
			float masque = smoothstep(0.50, 0.53, dn);       // bord franc, peint
			float coeur = smoothstep(0.62, 0.75, dn);
			vec3 c = mix(nuage_ombre, nuage_corps, smoothstep(0.30, 0.42, eclaire));
			c = mix(c, nuage_clair, smoothstep(0.60, 0.66, eclaire));
			c = mix(c, nuage_ombre * 0.92, coeur * (1.0 - eclaire) * 0.6);
			// liseré lumineux à contre-jour, près du soleil
			float lisere = smoothstep(0.50, 0.53, dn) - smoothstep(0.53, 0.58, dn);
			c = mix(c, halo * 1.08, lisere * pow(soleil, 3.0) * 0.9);
			float loin = smoothstep(0.015, 0.12, y);       // les nuages se fondent dans l'horizon
			col = mix(col, mix(horizon, c, 0.35 + 0.65 * loin), masque * (0.45 + 0.55 * loin));
		}
		COLOR = col;
	}
}
