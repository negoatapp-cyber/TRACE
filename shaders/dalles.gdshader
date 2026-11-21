shader_type spatial;
render_mode cull_disabled;
// TRACE — dalles grises du hall du lycée (carreaux 40 cm, joints, usure), en coordonnées du monde.
#include "res://shaders/bd_lumiere.gdshaderinc"
#include "res://shaders/bd_grain.gdshaderinc"
uniform vec4 dalle : source_color = vec4(0.66, 0.66, 0.65, 1.0);
uniform vec4 dalle2 : source_color = vec4(0.60, 0.60, 0.60, 1.0);
uniform vec4 joint : source_color = vec4(0.42, 0.42, 0.43, 1.0);
uniform float taille = 0.4;
varying vec3 monde;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = monde.xz / taille;
	vec2 c = floor(g);
	vec2 f = fract(g);
	float r = h21(c);
	vec3 col = mix(dalle.rgb, dalle2.rgb, step(0.55, r));
	if (r > 0.97) col *= 0.82;            // dalle fêlée / tachée
	float fin = clamp(fwidth(g.x) * 1.5, 0.03, 0.3);
	if (f.x < fin || f.y < fin) col = joint.rgb;
	if (bd_actif > 0.5) col *= mix(1.0, bd_texture(monde), 0.5);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
