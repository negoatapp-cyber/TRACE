shader_type canvas_item;
// Traits de vitesse sur les bords de l'écran (skate rapide) : des rayons qui filent depuis le centre,
// plus un léger voile sur les bords. « force » 0 → 1 selon la vitesse.

uniform float force : hint_range(0.0, 1.0) = 0.0;
uniform float temps = 0.0;

float bruit(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	// 90 rayons, chacun avec sa propre phase : des traits qui défilent vers l'extérieur
	float id = floor((a + 3.14159) / 6.28318 * 90.0);
	float phase = bruit(id);
	float trait = step(0.84, bruit(id + 7.0));
	float defile = fract(r * 2.2 - temps * (1.6 + phase * 1.4) + phase);
	float ligne = smoothstep(0.0, 0.15, defile) * (1.0 - smoothstep(0.15, 0.55, defile));
	float bord = smoothstep(0.32, 0.75, r);
	float alpha = trait * ligne * bord * force * 0.4;
	// voile léger sur les bords (impression de flou)
	alpha += bord * bord * force * 0.08;
	COLOR = vec4(1.0, 1.0, 1.0, alpha * 0.9);
}
