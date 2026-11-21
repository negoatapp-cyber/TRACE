shader_type spatial;
uniform sampler2D carte : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D terre : filter_nearest, repeat_disable;
void fragment(){
	if (texture(terre,UV).r < 0.5) { discard; }
	ALBEDO=texture(carte,UV).rgb;
	ROUGHNESS=1.;
}
