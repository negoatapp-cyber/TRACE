shader_type spatial;
render_mode cull_disabled;
// TRACE — le sol du quartier hors chaussées (conversation n°2).
// Au lieu d'une couleur de sable uniforme : du béton et de l'enrobé usés, des plaques de terre battue,
// de l'herbe sèche, et quelques touffes encore vertes. Taches peintes calculées, sans image.

#include "res://shaders/bd_lumiere.gdshaderinc"
#include "res://shaders/bd_grain.gdshaderinc"

uniform vec4 beton : source_color = vec4(0.76, 0.73, 0.67, 1.0);
uniform vec4 enrobe : source_color = vec4(0.62, 0.61, 0.62, 1.0);
uniform vec4 terre : source_color = vec4(0.70, 0.58, 0.44, 1.0);
uniform vec4 herbe_seche : source_color = vec4(0.70, 0.67, 0.44, 1.0);
uniform vec4 herbe : source_color = vec4(0.46, 0.56, 0.30, 1.0);

varying vec3 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = vec3(monde.x, 0.0, monde.z);
	float zone = bd_bruit(p * 0.028) * 0.7 + bd_bruit(p * 0.09) * 0.3;  // grandes plaques
	float vert = bd_bruit(p * 0.045 + vec3(31.0, 0.0, 7.0));
	vec3 c = beton.rgb;
	if (zone < 0.36) c = enrobe.rgb;
	if (zone > 0.56) c = terre.rgb;
	if (zone > 0.66) c = herbe_seche.rgb;
	if (zone > 0.62 && vert > 0.70) c = herbe.rgb;
	// Touffes d'herbe et cailloux, en petites taches.
	float touffe = bd_bruit(p * 1.6);
	if (zone > 0.5 && touffe > 0.80) c = mix(herbe_seche.rgb, herbe.rgb, step(0.65, vert)) * 0.88;
	if (zone < 0.5 && touffe > 0.86) c *= 0.9;
	c *= bd_texture(monde);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
