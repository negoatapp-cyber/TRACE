shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/bd_lumiere.gdshaderinc"
uniform vec4 email : source_color = vec4(0.79,0.80,0.77,1.);
uniform vec4 joint : source_color = vec4(0.55,0.56,0.54,1.);
uniform vec4 faience : source_color = vec4(0.30,0.55,0.53,1.);
uniform bool aile = false;
varying vec3 monde;
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz; }
void fragment() {
	vec2 uv = vec2(dot(monde.xz,normalize(vec2(41.,55.))),monde.y);
	vec2 carreau = uv / 0.22;
	vec2 distance_joint = 0.5 - abs(fract(carreau)-0.5);
	vec2 filtre = max(fwidth(carreau),vec2(0.001));
	vec2 plein = smoothstep(vec2(0.014)-filtre*0.5,vec2(0.014)+filtre*0.5,distance_joint);
	float variation = fract(sin(dot(floor(carreau),vec2(12.3,34.7))) * 4375.1);
	vec3 c = mix(joint.rgb,email.rgb*(0.965+0.035*variation),mix(0.96,plein.x*plein.y,1.-smoothstep(0.25,0.9,max(filtre.x,filtre.y))));
	if(aile){
		float sous_toit=UV.y;
		float bande=step(2.1,sous_toit)*step(sous_toit,2.48);
		c=mix(c,faience.rgb,bande);
		if(sous_toit>2.66 && sous_toit<3.88){
			vec2 fen=fract(vec2(uv.x/1.25,(sous_toit-2.66)/1.22));
			c=mix(vec3(.062,.095,.105)+.042*fen.y,vec3(.42,.46,.46),float(fen.x<.055 || fen.y<.07 || abs(fen.y-.70)<.023));
		}
		if(sous_toit>4.05){
			float lame=smoothstep(.03,.14,fract(sous_toit/.18));
			c=mix(vec3(.30,.29,.25),vec3(.53,.50,.43),lame);
		}
	}
	ALBEDO=c; EMISSION=c*0.14; ROUGHNESS=1.; SPECULAR=0.;
}
