shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// TRACE — feuillage des arbres (conversation n°2) : bouquets de feuilles peints (textures_arbres.py),
// balancés par le vent, éclairés en BD comme le reste du jeu, et un peu translucides à contre-jour.
// COLOR.r = occlusion calculée par arbres.py (sombre au cœur du houppier).

#include "res://shaders/bd_lumiere.gdshaderinc"

uniform sampler2D feuilles : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float vent = 1.0;
uniform float coupure = 0.45;

varying float occ;
varying vec3 monde;

void vertex() {
	occ = COLOR.r;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float t = TIME * 1.3 + base.x * 0.21 + base.z * 0.17;
	// grand balancement de l'arbre + frémissement des bouquets
	vec3 v = vec3(sin(t) * 0.5 + sin(t * 2.3) * 0.2, 0.0, cos(t * 0.8) * 0.4) * 0.012 * h * h * 0.12;
	v += vec3(sin(TIME * 4.0 + VERTEX.x * 3.0 + VERTEX.y * 2.0), sin(TIME * 3.3 + VERTEX.z * 3.0) * 0.6, cos(TIME * 4.4 + VERTEX.z * 2.6)) * 0.035;
	VERTEX += v * vent;
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = texture(feuilles, UV);
	if (c.a < coupure) discard;
	ALBEDO = c.rgb * teinte.rgb * mix(0.55, 1.08, occ);
	// petites variations de teinte d'un bouquet à l'autre
	ALBEDO *= 0.92 + 0.16 * fract(sin(dot(floor(monde.xz * 0.7), vec2(12.9898, 78.233))) * 43758.5453);
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	BACKLIGHT = vec3(0.35, 0.42, 0.18);
}
