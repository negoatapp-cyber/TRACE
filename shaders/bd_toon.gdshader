shader_type spatial;
render_mode cull_disabled;
// Matériau BD générique : une couleur (et éventuellement une texture) en aplats.
// Le script style_bd.gd l'applique automatiquement à la place des matériaux standard.

#include "res://shaders/bd_lumiere.gdshaderinc"

uniform vec4 couleur : source_color = vec4(1.0);
uniform sampler2D texture_couleur : source_color, filter_linear_mipmap, repeat_enable;
uniform bool avec_texture = false;
uniform float paliers = 6.0; // une texture peinte est réduite à quelques teintes

void fragment() {
	vec3 c = couleur.rgb;
	if (avec_texture) {
		vec3 t = texture(texture_couleur, UV).rgb;
		if (bd_actif > 0.5) {
			t = floor(t * paliers + 0.5) / paliers;
		}
		c *= t;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
