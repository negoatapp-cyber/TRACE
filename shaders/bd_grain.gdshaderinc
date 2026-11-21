// TRACE — texture « peinte » calculée, sans image : de grandes taches (salissures, reprises d'enduit)
// et un grain fin (béton, bitume), réduits à quelques teintes pour garder l'aspect d'aplats au pinceau.
// Intensité réglable pour tout le jeu : Shader Globals > bd_grain (0 = surfaces lisses).

global uniform float bd_grain;

float bd_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float bd_bruit(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(bd_hash(i), bd_hash(i + vec3(1, 0, 0)), f.x),
			mix(bd_hash(i + vec3(0, 1, 0)), bd_hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(bd_hash(i + vec3(0, 0, 1)), bd_hash(i + vec3(1, 0, 1)), f.x),
			mix(bd_hash(i + vec3(0, 1, 1)), bd_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Facteur à multiplier par la couleur (autour de 1).
float bd_texture(vec3 monde) {
	if (bd_grain <= 0.0) return 1.0;
	float taches = bd_bruit(monde * 0.12) * 0.65 + bd_bruit(monde * 0.45) * 0.35;
	taches = floor(taches * 4.0) / 4.0;            // 4 teintes franches
	float fin = step(0.72, bd_bruit(monde * 3.1)); // mouchetis
	return 1.0 + bd_grain * ((taches - 0.5) * 1.6 - fin * 0.45);
}
