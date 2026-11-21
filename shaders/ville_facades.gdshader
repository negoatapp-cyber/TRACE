shader_type spatial;
render_mode cull_disabled;
varying vec4 teinte;
void vertex() { teinte=COLOR; }
void fragment() {
	vec3 c=teinte.rgb;
	if (UV.y>=0.) {
		vec2 baie=fract(vec2(UV.x/3.2,UV.y/3.0));
		float vitre=step(.29,baie.x)*step(baie.x,.68)*step(.26,baie.y)*step(baie.y,.79);
		float distance_vue=length(VERTEX);
		c=mix(c,vec3(.23,.32,.34),vitre*(1.-smoothstep(140.,450.,distance_vue)));
	}
	ALBEDO=c;
	ROUGHNESS=1.;
}
