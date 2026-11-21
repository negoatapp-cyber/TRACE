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
// 21.11 (Louma : « pas abuser avec les reflets jaunes ») : bande plus fine, plus douce, et la nuit il prend
// la teinte orangée des projecteurs au sodium des tours et baisse encore (variable globale « nuit »).
global uniform float nuit;
uniform vec4 lisere : source_color = vec4(1.0, 0.84, 0.50, 1.0);
uniform float lisere_force = 0.18;
// Métal et vernis (conversation n°2) : reflet du ciel, plus fort en incidence rasante. 0 = mat.
uniform float metal : hint_range(0.0, 1.0) = 0.0;

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
		vec3 teinte_ = mix(lisere.rgb, vec3(1.0, 0.62, 0.25), nuit);
		EMISSION = teinte_ * smoothstep(0.80, 0.90, bord_vue) * lisere_force * mix(1.0, 0.45, nuit);
	}
	if (metal > 0.0) {
		vec3 nw_ = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 vw_ = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 r_ = reflect(-vw_, nw_);
		vec3 ciel_ = r_.y > 0.0 ? mix(vec3(0.88, 0.91, 0.95), vec3(0.42, 0.60, 0.86), smoothstep(0.05, 0.5, r_.y)) : vec3(0.21, 0.20, 0.19);
		if (bd_actif > 0.5) {   // reflet en deux tons à bord franc, comme un celluloïd
			ciel_ = r_.y > 0.0 ? (r_.y > 0.22 ? vec3(0.45, 0.62, 0.86) : vec3(0.90, 0.92, 0.95)) : vec3(0.20, 0.19, 0.18);
		}
		float fres_ = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		float lum_ = dot(c, vec3(0.30, 0.59, 0.11));
		float k_ = metal * smoothstep(0.05, 0.18, lum_) * (0.35 + 0.65 * fres_);
		EMISSION += ciel_ * k_ * 0.55;
		ALBEDO = c * (1.0 - k_ * 0.5);
	}
	// La rugosité ne sert pas à l'éclairage BD : elle sert de marqueur pour l'encrage.
	ROUGHNESS = personnage ? 0.5 : 1.0;
	SPECULAR = 0.0;
}
