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
varying vec3 nmonde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nmonde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = vec3(monde.x, 0.0, monde.z);
	// Grandes plaques douces sur le plat ; les pentes deviennent des talus d'herbe sèche
	// (comme sous la grande barre, rue Raymonde Martin), ravinés de terre.
	float zone = bd_bruit(p * 0.012) * 0.6 + bd_bruit(p * 0.05) * 0.4;
	float vert = bd_bruit(p * 0.03 + vec3(31.0, 0.0, 7.0));
	float pente = 1.0 - clamp(nmonde.y, 0.0, 1.0);
	vec3 c = beton.rgb;
	if (zone < 0.33) c = mix(beton.rgb, enrobe.rgb, 0.7);
	if (zone > 0.60) c = mix(beton.rgb, terre.rgb, 0.65);
	// talus
	float talus = smoothstep(0.035, 0.07, pente + (zone - 0.5) * 0.04);
	vec3 t = herbe_seche.rgb;
	if (bd_bruit(p * 0.09) > 0.62) t = terre.rgb;
	if (vert > 0.72) t = mix(herbe_seche.rgb, herbe.rgb, 0.6);
	c = mix(c, t, step(0.5, talus));
	// Touffes d'herbe et cailloux, en petites taches.
	float touffe = bd_bruit(p * 1.6);
	if (talus > 0.5 && touffe > 0.74) c = mix(herbe_seche.rgb, herbe.rgb, step(0.6, vert)) * 0.86;
	if (talus < 0.5 && touffe > 0.88) c *= 0.92;
	c *= bd_texture(monde);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
