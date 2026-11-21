shader_type spatial;
render_mode cull_disabled;
// TRACE — les bâtiments de Marseille vus du ciel : aplats crème et terre cuite, baies sombres,
// lumière BD en trois tons ; ceux du quartier jouable s'allument en vert.
#include "res://shaders/bd_lumiere.gdshaderinc"
uniform vec4 zone_jouable = vec4(-125.0, -325.0, 275.0, 275.0);
uniform vec4 vert : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform float pouls = 1.0;
uniform float nuit = 0.0;   // 0 = jour, 1 = nuit : les fenêtres s'allument
varying vec4 teinte;
varying vec3 monde;
void vertex() {
	teinte = COLOR;
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 c = teinte.rgb;
	c = mix(c, c * vec3(0.16, 0.16, 0.30), nuit);   // la nuit : murs bleu sombre
	vec3 lampes = vec3(0.0);
	if (UV.y >= 0.0) {
		vec2 cellule = vec2(UV.x / 3.2, UV.y / 3.0);
		vec2 baie = fract(cellule);
		float vitre = step(0.29, baie.x) * step(baie.x, 0.68) * step(0.26, baie.y) * step(baie.y, 0.79);
		c = mix(c, vec3(0.22, 0.20, 0.32), vitre * (1.0 - smoothstep(160.0, 520.0, length(VERTEX))) * (1.0 - nuit));
		// la nuit : une fenêtre sur trois allumée, jaune chaud ou bleu télé
		float h = fract(sin(dot(floor(cellule) + floor(monde.xz * 0.05), vec2(12.9898, 78.233))) * 43758.5453);
		float allume = step(0.55, h) * vitre;
		lampes = mix(vec3(1.0, 0.72, 0.32), vec3(0.55, 0.7, 1.0), step(0.93, h)) * allume * nuit * 2.2;
	}
	vec2 p = monde.xz;
	float dedans = step(zone_jouable.x, p.x) * step(p.x, zone_jouable.z) * step(zone_jouable.y, p.y) * step(p.y, zone_jouable.w);
	c = mix(c, mix(c, vert.rgb, 0.55), dedans);
	ALBEDO = c;
	EMISSION = vert.rgb * dedans * 0.35 * pouls * (1.0 + nuit) + lampes;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
