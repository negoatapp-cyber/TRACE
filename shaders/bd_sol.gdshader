shader_type spatial;
render_mode cull_disabled;
// TRACE — le sol du quartier hors chaussées (conversation n°2).
// Du béton et de l'enrobé usés sur le plat (ni sable ni terre), de l'herbe sèche sur les talus,
// et quelques touffes encore vertes. Taches peintes calculées, sans image.

#include "res://shaders/bd_lumiere.gdshaderinc"
#include "res://shaders/bd_grain.gdshaderinc"

uniform vec4 beton : source_color = vec4(0.72, 0.71, 0.69, 1.0);   // gris, pas sable
uniform vec4 enrobe : source_color = vec4(0.62, 0.61, 0.62, 1.0);
uniform vec4 terre : source_color = vec4(0.70, 0.58, 0.44, 1.0);
uniform vec4 herbe_seche : source_color = vec4(0.70, 0.67, 0.44, 1.0);
uniform vec4 herbe : source_color = vec4(0.46, 0.56, 0.30, 1.0);
// Béton rosé peint de la rue de la Paix (sol_1.png, 24,8 × 72 m) sur 70 % du plat.
uniform sampler2D paix : source_color, filter_linear_mipmap, repeat_enable;
uniform bool avec_paix = false;
uniform float seuil_paix = 0.634;   // ≈ 70 % de la surface
// Sol de ville vieilli : l'enrobé des chaussées (goudron_couleur.png, 2 m) délavé par le soleil, poussiéreux, fissuré.
uniform float metres_paix = 2.0;
uniform sampler2D fissures : hint_default_black, filter_linear_mipmap, repeat_enable;

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
	if (zone > 0.60) c = beton.rgb * 0.94;   // plus de terre battue au bord des routes : béton usé
	if (avec_paix) {
		float m = 0.6 * bd_bruit(p * 0.02) + 0.4 * bd_bruit(p * 0.07 + vec3(13.0, 0.0, 5.0));
		vec3 t = mix(texture(paix, monde.xz / metres_paix).rgb, vec3(0.28,0.275,0.27), 0.60);
		// délavé et poussiéreux : gris clair chaud, plus sombre par plaques
		float use = bd_bruit(p * 0.09) * 0.6 + bd_bruit(p * 0.4) * 0.4;
		t = mix(t * 1.9 + vec3(0.13, 0.12, 0.10), t * 1.3 + vec3(0.06, 0.055, 0.05), smoothstep(0.45, 0.7, use));
		float f = max(texture(fissures, monde.xz / 16.0).r, texture(fissures, monde.xz / 9.0 + vec2(0.3, 0.7)).r);
		t = mix(t, vec3(0.10, 0.10, 0.09), f * 0.32);
		// herbes dans les fissures et le long des bordures
		t = mix(t, herbe.rgb * 0.55, f * step(0.72, bd_bruit(p * 0.6)) * 0.7);
		c = mix(t, c, smoothstep(seuil_paix - 0.10, seuil_paix + 0.10, m));
	}
	// talus
	float talus = smoothstep(0.035, 0.07, pente + (zone - 0.5) * 0.04);
	vec3 t = herbe_seche.rgb;
	if (vert > 0.72) t = mix(herbe_seche.rgb, herbe.rgb, 0.6);
	c = mix(c, t, talus);
	// Touffes d'herbe et cailloux, en petites taches.
	float touffe = bd_bruit(p * 1.6);
	if (talus > 0.5 && touffe > 0.74) c = mix(herbe_seche.rgb, herbe.rgb, step(0.6, vert)) * 0.86;
	if (talus < 0.5 && touffe > 0.88) c *= 0.92;
	c *= bd_texture(monde);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
