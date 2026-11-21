shader_type spatial;
render_mode cull_back, ambient_light_disabled;
// TRACE — décor peint (rue pilote « impasse de la Paix »).
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
uniform bool voiture = false;          // voitures : couleurs plus contrastées, vitres à reflet de ciel
uniform bool sans_ombre = false;
// Métal et vernis (conversation n°2) : reflet du soleil et du ciel. 0 = mat.
uniform float brillance : hint_range(0.0, 1.0) = 0.0;
uniform float metal : hint_range(0.0, 1.0) = 0.0;       // feuillages : les masses peintes portent déjà leur ombre
// Habillage photographique optionnel : coordonnées métriques, palette peinte conservée.
uniform bool avec_crepi_photo = false;
uniform sampler2D crepi_photo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

global uniform float bd_actif;

varying vec3 pos_locale;

void vertex() {
	pos_locale = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = couleur.rgb;
	if (avec_texture) {
		c *= texture(texture_couleur, UV).rgb;
	}
	if (avec_crepi_photo) {
		// Répétition miroir : les bords du fichier généré ne créent pas de couture.
		vec2 uv_mur = abs(fract(pos_locale.zy * 0.5) * 2.0 - 1.0);
		vec3 grain = texture(crepi_photo, uv_mur).rgb;
		float valeur = dot(grain, vec3(0.30, 0.59, 0.11));
		c *= clamp(0.84 + valeur * 0.34, 0.88, 1.13);
	}
	if (voiture) {
		vec3 s = c;
		// vitres : les zones bleu-vert de la texture (rapports de couleur : ni le rouge, ni le blanc, ni les ombres
		// violettes, ni les pneus). Un reflet de ciel en deux tons, à bord franc, à la manière d'un celluloïd,
		// au lieu d'un aplat sombre et opaque.
		float vitre = smoothstep(0.55, 0.38, s.r / max(s.b, 0.01)) * smoothstep(1.3, 1.8, s.g / max(s.r, 0.01));
		float bande = step(0.52, fract(pos_locale.x * 0.5 + pos_locale.z * 0.3 + pos_locale.y * 1.3));
		vec3 reflet = mix(vec3(0.30, 0.36, 0.56), vec3(0.66, 0.78, 0.94), bande);
		// carrosserie : contraste et saturation relevés
		vec3 corps = clamp((s - 0.46) * 1.14 + 0.46, 0.0, 1.0);
		float l2 = dot(corps, vec3(0.30, 0.59, 0.11));
		corps = clamp(mix(vec3(l2), corps, 1.12), 0.0, 1.0);
		c = mix(corps, reflet, vitre * 0.8);
	}
	ALBEDO = c;
	if (metal > 0.0) {
		vec3 nw_ = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 vw_ = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 r_ = reflect(-vw_, nw_);
		vec3 ciel_ = r_.y > 0.0 ? mix(vec3(0.88, 0.91, 0.95), vec3(0.42, 0.60, 0.86), smoothstep(0.05, 0.5, r_.y)) : vec3(0.21, 0.20, 0.19);
		if (bd_actif > 0.5) {   // reflet en deux tons à bord franc, comme un celluloïd
			ciel_ = r_.y > 0.0 ? (r_.y > 0.22 ? vec3(0.45, 0.62, 0.86) : vec3(0.90, 0.92, 0.95)) : vec3(0.20, 0.19, 0.18);
		}
		float fres_ = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		float lum_ = dot(c, vec3(0.30, 0.59, 0.11));
		float k_ = metal * smoothstep(0.05, 0.18, lum_) * (0.35 + 0.65 * fres_);
		EMISSION += ciel_ * k_ * 0.5;
		ALBEDO = c * (1.0 - k_ * 0.5);
	}
	ROUGHNESS = 1.0;   // marqueur « décor » pour l'encrage
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
		float br = voiture ? max(brillance, 0.75) : brillance;
		if (br > 0.0) {
			vec3 hv = normalize(LIGHT + VIEW);
			float sp = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), mix(12.0, 140.0, br)) * soleil * clamp(nl, 0.0, 1.0);
			SPECULAR_LIGHT += vec3(1.0, 0.98, 0.92) * energie * (smoothstep(0.40, 0.48, sp) * 0.9 + sp * 0.25) * br;
		}
	} else {
		DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
}
