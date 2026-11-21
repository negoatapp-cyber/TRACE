shader_type spatial;
render_mode cull_disabled;
// TRACE — chaussées et trottoirs du quartier (conversation n°2).
// 70 % de la surface reprend les textures peintes de la rue de la Paix (enrobé rapiécé, béton rosé),
// 30 % garde l'aplat d'origine : de grandes plaques, comme des reprises de voirie.
// mode 0 : la texture suit la voie (UV.x en travers, UV.y le long, en mètres) ; mode 1 : projetée au sol.

#include "res://shaders/bd_lumiere.gdshaderinc"
#include "res://shaders/bd_grain.gdshaderinc"

uniform sampler2D paix : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 base : source_color = vec4(0.5, 0.49, 0.53, 1.0);
uniform int mode = 0;
uniform float largeur_tex = 11.4;   // mètres couverts par la largeur de l'image
uniform float longueur_tex = 104.8; // mètres couverts par sa hauteur
uniform float largeur_voie = 7.0;   // mode 0 : largeur réelle de la voie
uniform float seuil = 0.634;        // 0.634 ≈ 70 % de la surface en texture Paix

varying vec3 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = vec3(monde.x, 0.0, monde.z);
	float m = 0.6 * bd_bruit(p * 0.02) + 0.4 * bd_bruit(p * 0.07 + vec3(13.0, 0.0, 5.0));
	vec2 uv;
	if (mode == 0) {
		// la largeur de la voie tient dans l'image, la longueur garde les proportions
		uv = vec2(UV.x, UV.y / (largeur_voie * longueur_tex / largeur_tex));
	} else {
		uv = vec2(monde.x / largeur_tex, monde.z / longueur_tex);
	}
	vec3 t = texture(paix, uv).rgb;
	vec3 c = mix(t, base.rgb, smoothstep(seuil - 0.01, seuil + 0.01, m));
	c *= mix(1.0, bd_texture(monde), 0.5);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
