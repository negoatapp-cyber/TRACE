shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/bd_lumiere.gdshaderinc"
uniform vec4 dalle : source_color = vec4(0.72,0.68,0.61,1.);
void fragment() {
	vec2 module = UV/vec2(2.0,1.45);
	vec2 bord = .5-abs(fract(module)-.5);
	vec2 aa = max(fwidth(module),vec2(.001));
	vec2 interieur = smoothstep(vec2(.004)-aa*.5,vec2(.004)+aa*.5,bord);
	float lot = fract(sin(dot(floor(module),vec2(31.9,73.2)))*4287.);
	float joint = mix(.96,interieur.x*interieur.y,1.-smoothstep(.07,.4,max(aa.x,aa.y)));
	ALBEDO = dalle.rgb * mix(.72,1.,joint) * (.97+.03*lot);
	ROUGHNESS = 1.; SPECULAR = 0.;
}
