shader_type spatial;
render_mode cull_back;
#include "res://shaders/bd_lumiere.gdshaderinc"
uniform vec4 couleur : source_color = vec4(0.82,0.80,0.71,1.0);
varying float axe_stries;
void vertex() {
	// La façade regarde Marathon (+X) ; ses nervures suivent l'axe Z du monde.
	axe_stries = (MODEL_MATRIX * vec4(VERTEX,1.0)).z;
}
void fragment() {
	float phase = abs(fract(axe_stries / 0.17)-0.5);
	float filtre = max(fwidth(axe_stries / 0.17),0.015);
	float creux = 1.0-smoothstep(0.10-filtre,0.10+filtre,phase);
	float distance_lisible = 1.0-smoothstep(0.3,1.0,filtre);
	ALBEDO = couleur.rgb * (1.0-creux*0.12*distance_lisible);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
