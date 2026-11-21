shader_type spatial;
render_mode cull_disabled;
// TRACE — mur de soutènement en moellons (le grand mur de l'impasse « PAIX », rue de Marathon).
// Assises de pierres de longueurs variées, joints sombres, calculé en coordonnées du monde.

#include "res://shaders/bd_lumiere.gdshaderinc"
#include "res://shaders/bd_grain.gdshaderinc"

uniform vec4 pierre_a : source_color = vec4(0.80, 0.70, 0.55, 1.0);
uniform vec4 pierre_b : source_color = vec4(0.70, 0.60, 0.47, 1.0);
uniform vec4 pierre_c : source_color = vec4(0.76, 0.72, 0.66, 1.0);
uniform vec4 joint : source_color = vec4(0.45, 0.40, 0.36, 1.0);
uniform float assise = 0.34;

varying vec3 monde;
varying vec3 nm;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// coordonnée horizontale le long de la face
	float s = abs(nm.x) > abs(nm.z) ? monde.z : monde.x;
	float t = monde.y;
	if (abs(nm.y) > 0.6) { s = monde.x; t = monde.z; }
	float rang = t / assise;
	float ir = floor(rang);
	float dec = h21(vec2(ir, 2.0)) * 3.0;
	float lg = 0.55 + 0.35 * h21(vec2(ir, 5.0));
	float le_long = (s + dec) / lg;
	float il = floor(le_long);
	vec2 f = vec2(fract(le_long), fract(rang));
	float r = h21(vec2(il, ir));
	vec3 col = r < 0.45 ? pierre_a.rgb : (r < 0.8 ? pierre_b.rgb : pierre_c.rgb);
	col *= 0.93 + 0.07 * h21(vec2(ir, il) + 3.0);
	float fin = clamp(fwidth(rang) * 1.4, 0.07, 0.35);
	if (f.y < fin || f.x < fin * 0.7) col = mix(col, joint.rgb, 0.7);
	// coulures et pied sali
	if (bd_actif > 0.5) {
		col *= mix(1.0, bd_texture(monde), 0.5);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
