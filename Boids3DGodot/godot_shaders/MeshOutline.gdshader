shader_type spatial;
 
render_mode unshaded, cull_front;
 
uniform float border_width : hint_range(0, 1, 0.005);
uniform vec4 color : source_color = vec4(1.0);
 
void vertex() {
	VERTEX += VERTEX * border_width * 0.001;
}
 
void fragment() {
	ALBEDO = color.rgb;
}