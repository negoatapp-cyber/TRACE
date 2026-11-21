shader_type spatial;
render_mode cull_disabled, depth_draw_never;
// TRACE — tag, fresque, affiche ou enseigne posée à plat sur un mur (quad transparent).
// Remplace les Decal là où le moteur ne les dessine pas (version web / mobile, rendu « compatibility »).
#include "res://shaders/bd_lumiere.gdshaderinc"
uniform sampler2D motif : source_color, filter_linear_mipmap;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float fondu_debut = 55.0;
uniform float fondu_long = 15.0;
void fragment() {
	vec4 t = texture(motif, UV);
	ALBEDO = t.rgb * teinte.rgb;
	float d = length(VERTEX);
	ALPHA = t.a * teinte.a * (1.0 - clamp((d - fondu_debut) / fondu_long, 0.0, 1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
