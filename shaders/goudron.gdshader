shader_type spatial;
render_mode cull_disabled;
// TRACE — enrobé des chaussées (conversation n°2) : goudron noir-gris, granulats, un peu brillant au soleil.
// Images calculées par assets/decor/source/goudron.py (aucune photo). Par-dessus : usure des voies,
// reprises d'enrobé plus noires et fissures. Les plaques d'égout sont posées à part (habillage.gd).
// mode 0 : suit la voie (UV.x en travers 0→1, UV.y le long en mètres) ; mode 1 : projeté au sol.

global uniform float bd_actif;
global uniform vec4 bd_ombre : source_color;
global uniform float bd_trame;

uniform sampler2D couleur : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brillant : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D fissures : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform int mode = 0;
uniform float largeur_voie = 7.0;
uniform float metres_image = 2.0;      // goudron_*.png : 2 m par image
uniform float metres_fissures = 16.0;  // fissures.png : 16 m par image
uniform float teinte : hint_range(0.5, 3.0) = 1.0;
uniform float eclat : hint_range(0.0, 2.0) = 1.0;      // force des reflets
uniform float bd_seuil : hint_range(0.0, 1.0) = 0.30;
uniform float bd_demi : hint_range(0.0, 1.0) = 0.55;

varying vec3 monde;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// coordonnées en mètres : le long / en travers de la voie, ou au sol
	vec2 m = mode == 0 ? vec2(UV.x * largeur_voie, UV.y) : monde.xz;
	vec2 uv = m / metres_image;
	vec3 echantillon = texture(couleur, uv).rgb;
	// Trottoir sec, plus clair que la chaussée. Le granulat conserve son échelle réelle.
	vec3 c = mode == 1 ? vec3(0.46, 0.445, 0.425) + (echantillon - vec3(0.26)) * 0.24 :
		mix(echantillon, vec3(0.22, 0.225, 0.235), 0.48) * teinte;
	float proche = 1.0 - smoothstep(12.0, 60.0, length(VERTEX));
	float b = texture(brillant, uv).r;

	vec2 w = monde.xz;
	float x = mode == 0 ? UV.x : 0.5;
	// usure : deux bandes de roulement plus claires et polies, liant arraché
	if (mode == 0) {
		float roule = smoothstep(0.13, 0.0, abs(x - 0.3)) + smoothstep(0.13, 0.0, abs(x - 0.7));
		roule *= 0.55 + 0.45 * bruit(m * vec2(0.8, 0.12));
		c = mix(c, c * 1.22 + 0.02, roule * 0.65);
		b = max(b, roule * 0.4);
		// taches d'huile au milieu de chaque file, là où les voitures attendent
		float huile = smoothstep(0.1, 0.0, abs(x - 0.5) - 0.02) + smoothstep(0.08, 0.0, abs(x - 0.15)) * 0.5;
		huile *= smoothstep(0.55, 0.8, bruit(m * vec2(1.3, 0.45)) * 0.7 + bruit(m * 3.1) * 0.3);
		c = mix(c, vec3(0.05, 0.05, 0.06), huile * 0.55);
		b = max(b, huile * 0.6);
		// crasse au fil d'eau : poussière, gravillons, terre rapportée contre la bordure
		float bord = smoothstep(0.16, 0.0, min(x, 1.0 - x));
		bord *= 0.6 + 0.4 * bruit(m * vec2(2.0, 0.5));
		c = mix(c, vec3(0.30, 0.28, 0.25) * (0.8 + 0.4 * bruit(m * 9.0)), bord * 0.55);
		b *= 1.0 - bord * 0.8;
	}
	// rapiéçages : pavés d'enrobé plus noirs, bords francs et joint de bitume brillant
	vec2 cel = mode == 0 ? vec2(floor(x * 2.0), floor(m.y / 6.5)) : floor(w / vec2(4.0, 6.5));
	float tire = hash(cel + vec2(3.1, 7.7));
	vec2 loc = mode == 0 ? vec2(fract(x * 2.0), fract(m.y / 6.5)) : fract(w / vec2(4.0, 6.5));
	vec2 marge = vec2(0.08 + 0.25 * hash(cel + 1.3), 0.06 + 0.3 * hash(cel + 4.2));
	vec2 marge2 = vec2(0.1 + 0.2 * hash(cel + 2.7), 0.1 + 0.3 * hash(cel + 5.9));
	float dedans = step(marge.x, loc.x) * step(loc.x, 1.0 - marge2.x) * step(marge.y, loc.y) * step(loc.y, 1.0 - marge2.y);
	float plaque = step(0.72, tire) * dedans;
	float lw = mode == 0 ? 0.006 : 0.003;
	float joint = step(0.72, tire) * (1.0 - step(marge.x + lw, loc.x) * step(loc.x, 1.0 - marge2.x - lw) * step(marge.y + lw * 0.3, loc.y) * step(loc.y, 1.0 - marge2.y - lw * 0.3)) * dedans;
	float neuf = hash(cel + 9.1);
	c = mix(c, c * mix(0.77, 0.91, neuf), plaque);
	b = mix(b, 0.3, plaque * 0.5);
	c = mix(c, vec3(0.03), joint * 0.48);
	b = max(b, joint * 0.9);
	// grandes nuances : bitume délavé, auréoles sèches
	float nuance = bruit(w * 0.07) * 0.6 + bruit(w * 0.3) * 0.4;
	c *= 0.85 + 0.3 * nuance;
	float aureole = smoothstep(0.62, 0.66, bruit(w * 0.18)) - smoothstep(0.66, 0.72, bruit(w * 0.18));
	c = mix(c, c * 1.25 + 0.03, aureole * 0.35);
	// fissures : ouvertes sur le vieil enrobé, pontées au bitume (larges traits noirs brillants) par endroits
	float f = texture(fissures, w / metres_fissures).r * (1.0 - plaque);
	float f2 = texture(fissures, w / (metres_fissures * 0.55) + vec2(0.37, 0.61)).r * (1.0 - plaque);
	c = mix(c, vec3(0.03, 0.03, 0.035), max(f, f2 * 0.40) * (mode == 0 ? 0.58 : 0.28));
	b *= 1.0 - f;
	float ponte = textureLod(fissures, w / metres_fissures + vec2(0.5, 0.13), 3.0).r;
	ponte = smoothstep(0.08, 0.2, ponte) * step(0.5, bruit(w * 0.05)) * (1.0 - plaque);
	c = mix(c, vec3(0.025, 0.025, 0.03), ponte * 0.9);
	b = max(b, ponte * 0.3);
	// chewing-gums et petites taches claires
	float gum = step(0.985, hash(floor(w * 6.0))) * step(0.4, bruit(w * 0.4));
	c = mix(c, vec3(0.42, 0.41, 0.40), gum * proche * 0.27);

	ALBEDO = c;
	// relief des granulats : on penche la normale du sol (presque plat) sans passer par les tangentes,
	// absentes des maillages de voie et de trottoir
	vec2 nt = texture(relief, uv).rg * 2.0 - 1.0;
	vec3 nm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (nm.y < 0.0) nm = -nm;   // trottoirs tracés à l'envers : le sol regarde toujours le ciel
	vec3 wn = normalize(nm + vec3(nt.x, 0.0, -nt.y) * mix(0.035, 0.24, proche));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ROUGHNESS = clamp(1.0 - b * 0.75, 0.58, 1.0);
	SPECULAR = 0.28;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	vec3 h = normalize(LIGHT + VIEW);
	float nh = clamp(dot(NORMAL, h), 0.0, 1.0);
	float lisse = 1.0 - ROUGHNESS;
	float spec = pow(nh, mix(8.0, 90.0, lisse)) * lisse * eclat * nl * ATTENUATION;
	if (bd_actif < 0.5) {
		DIFFUSE_LIGHT += nl * ATTENUATION * LIGHT_COLOR / PI;
		SPECULAR_LIGHT += spec * LIGHT_COLOR * 0.6;
	} else {
		// même lumière BD que le reste du jeu (bd_lumiere.gdshaderinc), plus un reflet franc
		float e = nl * ATTENUATION;
		float plein = smoothstep(bd_seuil - 0.015, bd_seuil + 0.015, e);
		float demi = smoothstep(0.035, 0.06, e) * bd_demi;
		float t = max(plein, demi);
		vec3 ombre = bd_ombre.rgb;
		float hachure = step(0.62, fract((FRAGCOORD.x + FRAGCOORD.y) / 7.0));
		ombre *= 1.0 - bd_trame * hachure * (1.0 - smoothstep(0.0, 0.06, e));
		// Une lampe locale ne doit pas additionner un aplat violet hors de son faisceau.
		if (LIGHT_IS_DIRECTIONAL) {
			DIFFUSE_LIGHT += mix(ombre, LIGHT_COLOR / PI, t);
		} else {
			DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * smoothstep(0.02, 0.38, nl);
		}
		SPECULAR_LIGHT += LIGHT_COLOR * (smoothstep(0.18, 0.26, spec) * 0.18 + spec * 0.2);
	}
}
