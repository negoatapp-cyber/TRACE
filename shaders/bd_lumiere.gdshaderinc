// TRACE — lumière « bande dessinée », partagée par tous les matériaux du jeu.
// Trois tons francs au lieu d'un dégradé : plein soleil, demi-teinte, ombre.
// L'ombre n'est pas noire : elle est teintée (violet par défaut), comme une ombre posée au pinceau.
// Réglages communs à tout le jeu (Projet > Paramètres > Shader Globals) :
//   bd_actif  1 = rendu BD, 0 = éclairage d'origine (touche B pour comparer)
//   bd_ombre  couleur de l'ombre
//   bd_trame  intensité des hachures dans les ombres profondes (0 = aucune)

global uniform float bd_actif;
global uniform vec4 bd_ombre : source_color;
global uniform float bd_trame;

uniform float bd_seuil : hint_range(0.0, 1.0) = 0.30;
uniform float bd_demi : hint_range(0.0, 1.0) = 0.55;
// Reflet du soleil (conversation n°2) : 0 = mat (défaut). Métal, peintures vernies, carrosseries :
// réglé par style_bd.gd (_eclat) et habillage.gd. Petit et franc en rendu BD, comme une touche de gouache blanche.
uniform float bd_brillance : hint_range(0.0, 1.0) = 0.0;

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (bd_actif < 0.5) {
		DIFFUSE_LIGHT += nl * ATTENUATION * LIGHT_COLOR / PI;
	} else {
		float e = nl * ATTENUATION;
		float plein = smoothstep(bd_seuil - 0.015, bd_seuil + 0.015, e);
		float demi = smoothstep(0.035, 0.06, e) * bd_demi;
		float t = max(plein, demi);
		vec3 ombre = bd_ombre.rgb;
		// Hachures diagonales, seulement dans l'ombre franche.
		float hachure = step(0.62, fract((FRAGCOORD.x + FRAGCOORD.y) / 7.0));
		ombre *= 1.0 - bd_trame * hachure * (1.0 - smoothstep(0.0, 0.06, e));
		// Une lampe locale ne doit pas additionner un aplat violet hors de son faisceau.
		if (LIGHT_IS_DIRECTIONAL) {
			DIFFUSE_LIGHT += mix(ombre, LIGHT_COLOR / PI, t);
		} else {
			DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * smoothstep(0.02, 0.38, nl);
		}
	}
	if (bd_brillance > 0.0) {
		vec3 hv = normalize(LIGHT + VIEW);
		float sp = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), mix(12.0, 140.0, bd_brillance)) * ATTENUATION * nl;
		float franc = bd_actif > 0.5 ? smoothstep(0.40, 0.48, sp) * 0.9 + sp * 0.25 : sp;
		SPECULAR_LIGHT += LIGHT_COLOR * franc * bd_brillance;
	}
}
