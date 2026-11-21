shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, depth_prepass_alpha;
// TRACE — décor peint AJOURÉ (grilles, feuillages) : même lumière que decor_peint, avec découpe par la transparence.
// La texture est peinte à la main dans les couleurs exactes de l'image modèle : au soleil, on l'affiche
// telle quelle. Trois états, en aplats francs comme un décor d'animé :
//   - au soleil ............ la couleur peinte ;
//   - face détournée ....... à peine plus sourde (pas d'ombre violette sur une façade entière) ;
//   - ombre portée ......... violette et chaude, mesurée sur l'image (arbre sur le pignon, immeuble sur la rue).

uniform vec4 couleur : source_color = vec4(1.0);
uniform sampler2D texture_couleur : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool avec_texture = false;
uniform float face_detournee = 0.78;   // valeur d'une face qui tourne le dos au soleil
uniform float seuil_ombre = 0.5;
uniform bool sans_ombre = false;       // feuillages : les masses peintes portent déjà leur ombre

global uniform float bd_actif;

void fragment() {
	vec3 c = couleur.rgb;
	if (avec_texture) {
		c *= texture(texture_couleur, UV).rgb;
	}
	ALBEDO = c;
	if (avec_texture) {
		ALPHA = texture(texture_couleur, UV).a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	ROUGHNESS = 0.5;   // herbes, feuillages, grilles : seul le contour extérieur est encré (sinon chaque brin devient noir)   // marqueur « décor » pour l'encrage
	SPECULAR = 0.0;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 c = max(ALBEDO, vec3(0.003));
		vec3 s = pow(c, vec3(1.0 / 2.2));
		float lum = dot(s, vec3(0.30, 0.59, 0.11));
		vec3 ombre = s * 0.42 + lum * vec3(0.16, 0.10, 0.30);
		// grande façade : à peine plus sourde, sans virer au rose ; petit volume : franchement plus sombre et violacé
		vec3 teinte = face_detournee > 0.72 ? vec3(0.98, 0.93, 1.0) : vec3(1.0, 0.90, 1.04);
		vec3 propre = s * face_detournee * teinte;
		vec3 f_ombre = pow(ombre, vec3(2.2)) / c;
		vec3 f_propre = pow(propre, vec3(2.2)) / c;
		float nl = dot(NORMAL, LIGHT);
		float face = smoothstep(0.02, 0.07, nl);
		float soleil = smoothstep(seuil_ombre - 0.08, seuil_ombre + 0.08, ATTENUATION);
		if (sans_ombre) {
			soleil = 1.0;
			face = 1.0;
		}
		float energie = clamp(max(LIGHT_COLOR.r, max(LIGHT_COLOR.g, LIGHT_COLOR.b)) / PI, 0.0, 1.0);
		DIFFUSE_LIGHT += mix(f_propre, mix(f_ombre, vec3(1.0), soleil), face) * energie;
	} else {
		DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
}
