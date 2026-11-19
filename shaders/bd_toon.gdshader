shader_type spatial;
render_mode cull_disabled;
// Matériau BD générique : une couleur (et éventuellement une texture) en aplats.
// Le script style_bd.gd l'applique automatiquement à la place des matériaux standard.

#include "res://shaders/bd_lumiere.gdshaderinc"
#include "res://shaders/bd_grain.gdshaderinc"

uniform vec4 couleur : source_color = vec4(1.0);
uniform bool couleur_instance = false; // multimesh : chaque instance porte sa couleur (mosaïques)
uniform sampler2D texture_couleur : source_color, filter_linear_mipmap, repeat_enable;
uniform bool avec_texture = false;
uniform float paliers = 6.0; // une texture peinte est réduite à quelques teintes
uniform float grain = 1.0;    // part de la texture peinte (0 = aplat pur)
uniform bool personnage = false; // personnage : l'encrage ne dessine que sa silhouette
// Liseré de lumière sur les bords du personnage, comme sur les planches (jaune chaud).
uniform vec4 lisere : source_color = vec4(1.0, 0.80, 0.30, 1.0);
uniform float lisere_force = 0.4;

varying vec3 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = couleur_instance ? COLOR.rgb : couleur.rgb;
	if (avec_texture) {
		vec3 t = texture(texture_couleur, UV).rgb;
		if (bd_actif > 0.5) {
			t = floor(t * paliers + 0.5) / paliers;
		}
		c *= t;
	}
	if (bd_actif > 0.5) {
		c *= mix(1.0, bd_texture(monde), grain);
	}
	ALBEDO = c;
	if (personnage && bd_actif > 0.5) {
		float bord_vue = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		EMISSION = lisere.rgb * smoothstep(0.70, 0.80, bord_vue) * lisere_force;
	}
	// La rugosité ne sert pas à l'éclairage BD : elle sert de marqueur pour l'encrage.
	ROUGHNESS = personnage ? 0.5 : 1.0;
	SPECULAR = 0.0;
}
