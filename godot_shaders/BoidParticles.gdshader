shader_type particles;

uniform sampler2D boid_data;
uniform float scale = .5;

vec4 fetch_boid_data(sampler2D texture_data, uint particle_index) {
	ivec2 texture_dimensions = textureSize(texture_data, 0);
	ivec2 pixel_coordinates = ivec2(
		int(mod(float(particle_index), float(texture_dimensions.x))),
		int(float(particle_index) / float(texture_dimensions.x))
	);
	return texelFetch(texture_data, pixel_coordinates, 0);
}

void process() {
	vec4 pos_angle = fetch_boid_data(boid_data, INDEX);
	vec2 position = pos_angle.xy;
	float angle   = pos_angle.z;
	
	mat2 orientation_matrix = mat2(vec2( cos(angle), sin(angle)),
	                               vec2(-sin(angle), cos(angle))) * scale;
	
	TRANSFORM[0].xy = orientation_matrix[0];
	TRANSFORM[1].xy = orientation_matrix[1];
	TRANSFORM[3].xy = position;
}
