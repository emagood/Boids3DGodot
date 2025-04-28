shader_type particles;

uniform sampler2D boid_data;
uniform float scale = .5;


vec4 texel_color(sampler2D data, uint index) {
	ivec2 pos_image_size = textureSize(data, 0);
	ivec2 texel_pos = ivec2(int(mod(float(index), float(pos_image_size.x))),
							int(float(index) / float(pos_image_size.x)));
	vec4 data_color = texelFetch(data, texel_pos, 0);
	return data_color;
}


void process() {
	vec4 boid_pos_rot = texel_color(boid_data, INDEX);
	float angle = boid_pos_rot.z;
	
	mat2 scale_rot_mat = mat2(vec2(cos(angle), sin(angle)),
							  vec2(-sin(angle), cos(angle)));
	scale_rot_mat *= scale;
	
	TRANSFORM[0].xy = scale_rot_mat[0];
	TRANSFORM[1].xy = scale_rot_mat[1];
	TRANSFORM[3].xy = vec2(boid_pos_rot.x, boid_pos_rot.y);
}
