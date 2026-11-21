shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
// TRACE — l'encrage : un trait sombre sur les silhouettes et les arêtes, comme dans une BD.
// Posé sur tout l'écran par style_bd.gd. Il lit la profondeur et l'orientation des surfaces :
//  - rupture de profondeur (un immeuble devant le ciel, un muret devant le sol) → trait ;
//  - changement brusque d'orientation (l'angle d'un mur, le bord d'un trottoir) → trait.
// Le trait s'affine puis disparaît au loin, pour ne pas salir l'horizon.

uniform sampler2D tex_prof : hint_depth_texture, filter_nearest;
uniform sampler2D tex_norm : hint_normal_roughness_texture, filter_nearest;
uniform sampler2D tex_ecran : hint_screen_texture, filter_linear;
uniform vec4 encre : source_color = vec4(0.16, 0.08, 0.22, 1.0);
// Le trait prend la couleur de ce qu'il borde, assombrie (comme un trait de BD colorisé),
// mêlée à une encre violette. 0 = encre pure, 1 = couleur de la surface assombrie.
uniform float trait_colore = 0.65;
uniform float assombri = 0.38;
uniform float opacite = 0.9;
uniform float epaisseur = 1.3;      // en pixels (rapportés à 900 px de haut)
uniform float seuil_prof = 0.06;    // sensibilité aux ruptures de profondeur
uniform float seuil_angle = 0.40;   // 0,4 ≈ arêtes de plus de 50°
uniform float seuil_perso = 0.36;   // personnages : seuil propre (avant : seuil_prof × 6, qui noircissait Loums quand une scène baissait seuil_prof)
uniform float pres = 0.4;           // distance (m) en deçà de laquelle on n'encre pas (évite la caméra)
uniform float loin = 420.0;         // au-delà, plus de trait

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float distance_vue(float brut, vec2 uv, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, brut, 1.0);
	return -v.z / v.w;
}

vec3 normale(vec2 uv) {
	return normalize(texture(tex_norm, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 px = epaisseur * (VIEWPORT_SIZE.y / 900.0) / VIEWPORT_SIZE;
	vec2 dx = vec2(px.x, 0.0);
	vec2 dy = vec2(0.0, px.y);
	// La profondeur brute varie linéairement sur une surface plane : sa dérivée seconde est nulle
	// sur un plan et forte sur une rupture. Pas de faux traits sur les sols vus en rasant.
	float c = texture(tex_prof, SCREEN_UV).r;
	float g = texture(tex_prof, SCREEN_UV - dx).r;
	float d = texture(tex_prof, SCREEN_UV + dx).r;
	float h = texture(tex_prof, SCREEN_UV - dy).r;
	float b = texture(tex_prof, SCREEN_UV + dy).r;
	float ref = max(max(c, max(g, d)), max(h, b));
	float bord = 0.0;
	// Sur un personnage (marqué par une rugosité de 0,5), seul le contour extérieur est encré :
	// pas de trait sur le visage ni dans les plis des vêtements.
	bool perso = texture(tex_norm, SCREEN_UV).a < 0.75 && c > 0.0;
	if (ref > 0.0) {
		float lap = max(abs(g + d - 2.0 * c), abs(h + b - 2.0 * c));
		bord = step(perso ? seuil_perso : seuil_prof, lap / ref);
		// Personnage : jamais de trait À L'INTÉRIEUR de sa silhouette, seulement là où un voisin n'est pas lui.
		if (perso) {
			bool dedans = texture(tex_norm, SCREEN_UV - dx).a < 0.75 && texture(tex_norm, SCREEN_UV + dx).a < 0.75
					&& texture(tex_norm, SCREEN_UV - dy).a < 0.75 && texture(tex_norm, SCREEN_UV + dy).a < 0.75
					&& g > 0.0 && d > 0.0 && h > 0.0 && b > 0.0;
			if (dedans) bord = 0.0;
		}
		// Arêtes : seulement entre pixels de géométrie (le ciel n'a pas de normale).
		if (!perso && c > 0.0 && g > 0.0 && d > 0.0 && h > 0.0 && b > 0.0) {
			vec3 n = normale(SCREEN_UV);
			float m = min(min(dot(n, normale(SCREEN_UV - dx)), dot(n, normale(SCREEN_UV + dx))),
					min(dot(n, normale(SCREEN_UV - dy)), dot(n, normale(SCREEN_UV + dy))));
			bord = max(bord, step(seuil_angle, 1.0 - m));
		}
		float z = distance_vue(ref, SCREEN_UV, INV_PROJECTION_MATRIX);
		bord *= smoothstep(pres, pres + 0.3, z) * (1.0 - smoothstep(loin * 0.55, loin, z));
	}
	// Couleur du trait : la plus sombre des surfaces voisines, assombrie, teintée d'encre.
	vec3 c0 = texture(tex_ecran, SCREEN_UV).rgb;
	vec3 c1 = texture(tex_ecran, SCREEN_UV - dx * 2.0).rgb;
	vec3 c2 = texture(tex_ecran, SCREEN_UV + dx * 2.0).rgb;
	vec3 c3 = texture(tex_ecran, SCREEN_UV - dy * 2.0).rgb;
	vec3 c4 = texture(tex_ecran, SCREEN_UV + dy * 2.0).rgb;
	vec3 sombre = c0;
	for (int k = 0; k < 4; k++) {
		vec3 ck = k == 0 ? c1 : (k == 1 ? c2 : (k == 2 ? c3 : c4));
		if (dot(ck, vec3(0.3, 0.59, 0.11)) < dot(sombre, vec3(0.3, 0.59, 0.11))) sombre = ck;
	}
	ALBEDO = mix(encre.rgb, sombre * assombri, trait_colore);
	ALPHA = bord * encre.a * opacite;
}
