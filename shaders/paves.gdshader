shader_type spatial;
render_mode cull_disabled;
// TRACE — pavés posés en cercles concentriques autour du sommet de chaque colline
// (les « collines de pavés » des places de grands ensembles des années 1970).
// UV = position locale (m) ; COLOR.rg = centre de la colline la plus proche, codé sur ±20 m.

#include "res://shaders/bd_lumiere.gdshaderinc"
#include "res://shaders/bd_grain.gdshaderinc"

uniform vec4 pave_clair : source_color = vec4(0.78, 0.75, 0.70, 1.0);
uniform vec4 pave_fonce : source_color = vec4(0.58, 0.57, 0.58, 1.0);
uniform vec4 pave_ocre : source_color = vec4(0.80, 0.66, 0.48, 1.0);
uniform vec4 joint : source_color = vec4(0.42, 0.40, 0.42, 1.0);
uniform float longueur = 0.36;
uniform float largeur = 0.24;

varying vec3 monde;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 c = COLOR.rg * 40.0 - 20.0;
	vec2 q = UV - c;
	float d = length(q);
	float a = atan(q.y, q.x);
	float rang = d / largeur;
	float ir = floor(rang);
	// Le long d'un anneau : la longueur d'arc, décalée d'un rang à l'autre (appareil en quinconce).
	float le_long = a * max(d, 0.3) / longueur + h21(vec2(ir, 3.0)) * 7.0;
	float il = floor(le_long);
	vec2 f = vec2(fract(le_long), fract(rang));
	float r = h21(vec2(ir, il));
	vec3 col = mix(pave_clair.rgb, pave_fonce.rgb, step(0.6, r));
	if (r > 0.9) col = pave_ocre.rgb;
	col *= 0.92 + 0.08 * h21(vec2(il, ir) + 5.0);
	// Joints sombres (plus fins de loin pour ne pas griser toute la place).
	float fin = clamp(fwidth(rang) * 1.5, 0.06, 0.4);
	if (f.y < fin || f.x < fin * 0.8) col = mix(col, joint.rgb, 0.75);
	if (bd_actif > 0.5) {
		col *= mix(1.0, bd_texture(monde), 0.4);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
