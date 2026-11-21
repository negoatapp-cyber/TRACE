shader_type spatial;
// TRACE — la ville vue du ciel, en BD : les couleurs de la carte réduites à quelques teintes,
// la lumière en trois tons (bd_lumiere), et le quartier jouable baigné de vert.
// La mer est peinte ici même (plus de plan d'eau séparé qui se bat avec la côte).
// La nuit : sol bleu nuit, rues en traits de lumière orange (sodium), boulevards plus vifs,
// toits sombres piqués de fenêtres, parcs noirs, mer d'encre.
#include "res://shaders/bd_lumiere.gdshaderinc"
uniform sampler2D carte : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D terre : filter_nearest, repeat_disable;
uniform vec4 zone_jouable = vec4(-125.0, -325.0, 275.0, 275.0); // x0, z0, x1, z1
uniform vec4 vert : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform vec4 mer : source_color = vec4(0.20, 0.58, 0.80, 1.0);
uniform float pouls = 1.0;
uniform float nuit = 0.0;
varying vec3 monde;
varying vec3 n_monde;
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; n_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }

float proche(vec3 c, vec3 ref) { return 1.0 - smoothstep(0.025, 0.06, distance(c, ref)); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = monde.xz;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// on lit la carte AVANT tout embranchement (sinon le GPU perd le bon niveau de détail : sol uni)
	vec3 c = texture(carte, UV).rgb;   // carte_bd.png : déjà en aplats aux couleurs du jeu
	float est_terre = texture(terre, UV).r;
	if (est_terre < 0.5) {
		// la mer : aplat, petits traits de vagues au feutre ; la nuit, encre et reflets de lune
		vec2 q = p / vec2(260.0, 90.0);
		vec2 o = fract(q) - 0.5;
		float hm = hash(floor(q));
		float trait = step(abs(o.y + sin(o.x * 6.0 + TIME + hm * 6.0) * 0.06), 0.035) * step(abs(o.x), 0.22) * step(0.55, hm);
		vec3 mer_jour = mix(mer.rgb, vec3(0.75, 0.9, 1.0), trait * 0.7);
		vec3 sombre = mix(vec3(0.015, 0.035, 0.10), vec3(0.25, 0.32, 0.55), trait * 0.5);
		ALBEDO = mix(mer_jour, sombre, nuit);
		EMISSION = vec3(0.6, 0.7, 1.0) * trait * nuit * 0.15;
	} else {
	// le relief se lit : versants raides un peu plus sombres et violets (ombre BD)
	float pente = 1.0 - clamp(n_monde.y, 0.0, 1.0);
	vec3 jour = mix(c, c * vec3(0.78, 0.72, 0.9), smoothstep(0.08, 0.35, pente) * 0.6);

	// ce que montre la carte (palette de carte_bd.png)
	float rue = max(max(proche(c, vec3(1.0, 0.945, 0.816)), proche(c, vec3(1.0, 0.98, 0.91))), proche(c, vec3(0.969, 0.871, 0.667)));
	float boulevard = proche(c, vec3(0.957, 0.776, 0.439));
	float bati = proche(c, vec3(0.886, 0.557, 0.384));
	float parc = max(proche(c, vec3(0.439, 0.659, 0.329)), proche(c, vec3(0.588, 0.8, 0.376)));
	float eau = proche(c, vec3(0.204, 0.588, 0.804));

	// la nuit : fond bleu nuit, toits plus clairs que la rue noire, parcs presque noirs
	vec3 n = vec3(0.045, 0.05, 0.11);
	n = mix(n, vec3(0.11, 0.10, 0.20), bati);
	n = mix(n, vec3(0.02, 0.05, 0.04), parc);
	n = mix(n, vec3(0.015, 0.035, 0.10), eau);
	n = mix(n, vec3(0.08, 0.06, 0.07), rue + boulevard);
	// fenêtres allumées sur les toits (petits points, fixes, plus rares de loin)
	vec2 cel = p / 9.0;
	float h = hash(floor(cel));
	float point = 1.0 - smoothstep(0.18, 0.32, length(fract(cel) - 0.5));
	float loin = smoothstep(2500.0, 9000.0, length(VERTEX));
	vec3 lumieres = vec3(1.0, 0.75, 0.38) * bati * step(0.72, h) * point * (1.0 - loin) * 1.2;
	// les rues : un réseau de lumière sodium ; de loin il se fond en halo orange
	lumieres += vec3(1.0, 0.55, 0.18) * rue * 0.5 + vec3(1.0, 0.72, 0.32) * boulevard * 0.95;
	lumieres += vec3(0.9, 0.5, 0.2) * bati * loin * 0.12;

	// le quartier jouable : un aplat vert lumineux, bord net
	float dedans = step(zone_jouable.x, p.x) * step(p.x, zone_jouable.z) * step(zone_jouable.y, p.y) * step(p.y, zone_jouable.w);
	float bord = 1.0 - smoothstep(0.0, 14.0, min(min(p.x - zone_jouable.x, zone_jouable.z - p.x), min(p.y - zone_jouable.y, zone_jouable.w - p.y)));
	vec3 couleur = mix(jour, n, nuit);
	couleur = mix(couleur, mix(couleur, vert.rgb, 0.45), dedans);
	ALBEDO = couleur;
	EMISSION = vert.rgb * dedans * (0.25 + 0.75 * bord) * 0.6 * pouls * (1.0 + 1.5 * nuit) + lumieres * nuit;
	}
}
